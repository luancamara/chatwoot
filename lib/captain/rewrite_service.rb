class Captain::RewriteService < Captain::BaseTaskService
  pattr_initialize [:account!, :content!, :operation!, { conversation_display_id: nil }]

  TONE_OPERATIONS = %i[casual professional friendly confident straightforward].freeze
  ALLOWED_OPERATIONS = (%i[fix_spelling_grammar auto_fix_grammar improve] + TONE_OPERATIONS).freeze

  def perform
    operation_sym = operation.to_sym
    raise ArgumentError, "Invalid operation: #{operation}" unless ALLOWED_OPERATIONS.include?(operation_sym)

    send(operation_sym)
  end

  TONE_OPERATIONS.each do |tone|
    define_method(tone) do
      call_llm_with_prompt(tone_rewrite_prompt(tone.to_s))
    end
  end

  private

  def auto_fix_grammar
    guard = Captain::GrammarLanguageGuard.new(content)
    return { message: content } unless guard.revisable?

    result = call_llm_with_prompt(prompt_from_file('auto_fix_grammar'))
    reason = result[:error] ? 'llm_error' : guard.rejection_reason(result[:message])
    return { message: result[:message] } unless reason

    original_grammar_message(reason)
  rescue StandardError
    original_grammar_message('revision_error')
  end

  def original_grammar_message(reason)
    Rails.logger.info({ event: 'auto_fix_grammar_rejected', account_id: account.id,
                        conversation_display_id: conversation_display_id, reason: reason }.to_json)
    { message: content }
  end

  def fix_spelling_grammar
    call_llm_with_prompt(prompt_from_file('fix_spelling_grammar'))
  end

  def improve
    template = prompt_from_file('improve')

    system_prompt = render_liquid_template(template, {
                                             'conversation_context' => conversation.to_llm_text(include_contact_details: true),
                                             'draft_message' => content
                                           })

    call_llm_with_prompt(system_prompt, content)
  end

  def call_llm_with_prompt(system_content, user_content = content)
    make_api_call(
      feature: 'editor',
      messages: [
        { role: 'system', content: system_content },
        { role: 'user', content: user_content }
      ]
    )
  end

  def render_liquid_template(template_content, variables = {})
    Liquid::Template.parse(template_content).render(variables)
  end

  def tone_rewrite_prompt(tone)
    template = prompt_from_file('tone_rewrite')
    render_liquid_template(template, 'tone' => tone)
  end

  def event_name
    operation
  end

  def use_account_openai_hook?
    true
  end
end
