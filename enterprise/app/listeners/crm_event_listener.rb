class CrmEventListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    ConversationInsightJob.perform_later(conversation)
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
  end

  private

  def handle_funnel_stage_change(conversation, previous_attrs, current_attrs)
    old_stage = previous_attrs['crm_funnel_stage']
    new_stage = current_attrs['crm_funnel_stage']

    return if old_stage == new_stage || new_stage.blank?

    # Schedule follow-ups when entering "Orcamento" stage
    Crm::FollowUpSchedulerService.new(conversation).schedule! if new_stage == 'Orçamento'
  end
end
