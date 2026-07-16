class Whatsapp::Triage::ClassifierService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  AREAS = (Whatsapp::Triage::Configuration::AREAS + ['unknown']).freeze
  SEVERITIES = %w[normal complaint critical].freeze
  CONTEXT_MESSAGE_LIMIT = 10
  CONTENT_LIMIT = 8_000

  def initialize(conversation:)
    super()
    @conversation = conversation
    @account = conversation.account
  end

  def perform
    content = conversation_content
    return if content.blank?

    response = instrument_llm_call(instrumentation_params(content)) do
      chat(temperature: 0.0)
        .with_params(response_format: { type: 'json_object' })
        .with_instructions(system_prompt)
        .ask(content)
    end

    parse(response.content)
  rescue RubyLLM::Error => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    nil
  end

  private

  attr_reader :conversation, :account

  def conversation_content
    lines = recent_public_messages.filter_map do |message|
      next if message.content_attributes['whatsapp_triage'].present?

      content = message_content(message)
      next if content.blank?

      role = message.incoming? ? 'Cliente' : 'Atendente'
      "#{role}: #{content.truncate(2_000)}"
    end

    lines.join("\n").truncate(CONTENT_LIMIT)
  end

  def recent_public_messages
    relation = conversation.messages.where(private: false, message_type: %i[incoming outgoing])
    relation = relation.where('created_at >= ?', cycle_started_at) if cycle_started_at.present?
    relation.order(created_at: :desc).limit(CONTEXT_MESSAGE_LIMIT).reverse
  end

  def cycle_started_at
    @cycle_started_at ||= Time.iso8601(conversation.custom_attributes['triage_started_at'])
  rescue ArgumentError, TypeError
    nil
  end

  def message_content(message)
    return message.content.squish if message.content.present?

    message.attachments.filter_map { |attachment| attachment.meta&.dig('transcribed_text') }.join(' ').squish
  end

  def parse(content)
    data = JSON.parse(sanitize_json_response(content)).with_indifferent_access
    area = data[:area].to_s
    severity = data[:severity].to_s
    confidence = Float(data[:confidence])
    reason = data[:reason].to_s.squish.truncate(500)

    return unless valid_classification?(area, severity, confidence, reason)

    area, severity = normalize_complaint(area, severity)
    {
      'area' => area,
      'severity' => severity,
      'confidence' => confidence,
      'reason' => reason,
      'source' => 'ai'
    }
  rescue JSON::ParserError, ArgumentError, TypeError
    nil
  end

  def valid_classification?(area, severity, confidence, reason)
    AREAS.include?(area) && SEVERITIES.include?(severity) && confidence.between?(0, 1) && reason.present?
  end

  def normalize_complaint(area, severity)
    area = 'complaints' if severity.in?(%w[complaint critical])
    severity = 'complaint' if area == 'complaints' && severity == 'normal'
    [area, severity]
  end

  def instrumentation_params(content)
    {
      span_name: 'llm.whatsapp_triage.classification',
      model: model,
      temperature: 0.0,
      account_id: account.id,
      conversation_id: conversation.display_id,
      feature_name: 'whatsapp_triage',
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: content }
      ]
    }
  end

  def system_prompt
    <<~PROMPT
      Você classifica conversas de atendimento de uma loja de móveis.

      Sua única tarefa é identificar a área, a gravidade e o motivo. Não responda ao cliente e não sugira soluções.

      Áreas permitidas:
      - sales: compra, orçamento ou informação comercial
      - finance: pagamento, boleto, nota fiscal ou cobrança sem conflito
      - after_sales: entrega, montagem, assistência ou suporte sem reclamação
      - complaints: insatisfação, falha, defeito, demora, cancelamento por problema ou risco jurídico
      - general: assunto que precisa de atendimento humano mas não se encaixa nas áreas anteriores
      - unknown: conteúdo insuficiente para decidir

      Gravidades permitidas:
      - normal: atendimento comum
      - complaint: problema ou insatisfação que exige equipe independente
      - critical: risco de cancelamento, cobrança indevida reiterada, Procon, advogado, processo ou falha grave sem solução

      Regras:
      - Dê prioridade à proteção do cliente quando houver uma reclamação real.
      - Não trate palavras isoladas como reclamação se o contexto mostrar um pedido operacional comum.
      - Se severity for complaint ou critical, area deve ser complaints.
      - Não inclua nomes, telefones ou outros dados pessoais no motivo.
      - Retorne somente JSON no formato:
        {"area":"unknown","severity":"normal","confidence":0.0,"reason":"Motivo curto"}
    PROMPT
  end
end
