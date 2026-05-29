class CrmEventListener < BaseListener
  LOST_DISPOSITIONS = ['Sem Resposta', 'Perda'].freeze
  ACTIVE_FUNNEL_STAGES = %w[Lead Qualificado Orcamento Negociacao].freeze

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    ConversationInsightJob.perform_later(conversation)
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming?

    conversation = message.conversation
    return unless conversation.open?

    Captain::Llm::ConversationAutoLabelService.schedule_debounce(conversation)
  end

  def conversation_updated(event)
    conversation = extract_conversation_and_account(event)[0]
    changed = event.data[:changed_attributes]
    return unless changed.is_a?(Hash)

    custom_attrs_change = changed['custom_attributes']
    return unless custom_attrs_change

    previous_attrs = custom_attrs_change[0] || {}
    current_attrs = custom_attrs_change[1] || {}

    handle_funnel_stage_change(conversation, previous_attrs, current_attrs)
    handle_disposition_change(conversation, previous_attrs, current_attrs)
  end

  private

  # When a conversation is resolved as a lost outcome ("Sem Resposta" / "Perda"),
  # move an active funnel-stage card to "Perda" so the kanban stays in sync with
  # the disposition instead of being frozen at its first stage.
  def handle_disposition_change(conversation, previous_attrs, current_attrs)
    old_disposition = previous_attrs['crm_disposition_result']
    new_disposition = current_attrs['crm_disposition_result']

    return if old_disposition == new_disposition
    return unless LOST_DISPOSITIONS.include?(new_disposition)
    return unless ACTIVE_FUNNEL_STAGES.include?(current_attrs['crm_funnel_stage'])

    conversation.update!(
      custom_attributes: conversation.custom_attributes.merge(
        'crm_funnel_stage' => 'Perda',
        'crm_stage_changed_at' => Time.current.iso8601
      )
    )
  end

  def handle_funnel_stage_change(conversation, previous_attrs, current_attrs)
    old_stage = previous_attrs['crm_funnel_stage']
    new_stage = current_attrs['crm_funnel_stage']

    return if old_stage == new_stage || new_stage.blank?

    # Schedule follow-ups when entering "Orcamento" stage
    Crm::FollowUpSchedulerService.new(conversation).schedule! if new_stage == 'Orçamento'
  end
end
