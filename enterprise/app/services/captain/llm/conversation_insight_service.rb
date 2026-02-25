class Captain::Llm::ConversationInsightService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  VALID_FUNNEL_STAGES = %w[Lead Qualificado Orcamento Negociacao Venda Perda].freeze

  def initialize(assistant, conversation)
    super()
    @assistant = assistant
    @conversation = conversation
    @content = "#Conversation\n\n#{@conversation.to_llm_text}"
  end

  def generate_and_save_insight
    data = generate_insight
    return if data.blank?

    insight = @conversation.conversation_insight || @conversation.build_conversation_insight(account: @conversation.account)
    insight.update!(
      estimated_value: data['estimated_value'],
      product_category: data['product_category'],
      customer_sentiment: data['customer_sentiment'],
      key_topics: data['key_topics'] || [],
      quality_score: data['quality_score'],
      quality_breakdown: data['quality_breakdown'] || {},
      raw_llm_response: data
    )

    auto_set_funnel_stage(data['suggested_funnel_stage']) if data['suggested_funnel_stage'].present?

    insight
  end

  private

  attr_reader :content

  def auto_set_funnel_stage(suggested_stage)
    current_stage = @conversation.custom_attributes&.dig('crm_funnel_stage')
    return if current_stage.present?
    return unless VALID_FUNNEL_STAGES.include?(suggested_stage)

    @conversation.update!(
      custom_attributes: (@conversation.custom_attributes || {}).merge('crm_funnel_stage' => suggested_stage)
    )
  end

  def generate_insight
    response = instrument_llm_call(instrumentation_params) do
      chat
        .with_params(response_format: { type: 'json_object' })
        .with_instructions(system_prompt)
        .ask(@content)
    end
    parse_response(response.content)
  rescue RubyLLM::Error => e
    ChatwootExceptionTracker.new(e, account: @conversation.account).capture_exception
    nil
  end

  def instrumentation_params
    {
      span_name: 'llm.captain.conversation_insight',
      model: @model,
      temperature: @temperature,
      account_id: @conversation.account_id,
      conversation_id: @conversation.display_id,
      feature_name: 'conversation_insight',
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: @content }
      ],
      metadata: { assistant_id: @assistant.id }
    }
  end

  def system_prompt
    <<~SYSTEM_PROMPT
      Voce e um analista de vendas de uma loja de moveis. Analise a conversa e extraia informacoes comerciais.
      Responda SOMENTE em JSON valido com a seguinte estrutura:

      {
        "estimated_value": 0.00,
        "product_category": "string",
        "customer_sentiment": "positive|neutral|negative",
        "key_topics": ["topic1", "topic2"],
        "quality_score": 7,
        "quality_breakdown": {
          "greeting": 2,
          "needs_identification": 2,
          "product_presentation": 2,
          "objection_handling": 1,
          "closing_attempt": 0
        },
        "suggested_funnel_stage": "Lead"
      }

      Regras:
      - estimated_value: valor estimado em reais (0 se nao mencionado)
      - product_category: categoria do produto (ex: "Sofa", "Mesa", "Cama", "Guarda-roupa", "Outro")
      - customer_sentiment: sentimento geral do cliente
      - key_topics: lista dos principais assuntos discutidos
      - quality_score: nota de 1 a 10 para qualidade do atendimento
      - quality_breakdown: nota de 0 a 2 para cada criterio (0=nao fez, 1=parcial, 2=completo)
      - suggested_funnel_stage: etapa sugerida do funil de vendas. Opcoes EXATAS (sem acentos):
        "Lead" = primeiro contato, sem interesse claro
        "Qualificado" = demonstrou interesse em produto especifico
        "Orcamento" = pediu preco, orcamento ou condicoes de pagamento
        "Negociacao" = discutindo desconto, prazo, condicoes
        "Venda" = confirmou compra ou fechou negocio
        "Perda" = desistiu, nao respondeu, ou recusou
    SYSTEM_PROMPT
  end

  def parse_response(response)
    return nil if response.nil?

    JSON.parse(response.strip)
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing conversation insight response: #{e.message}"
    nil
  end
end
