class CrmEventListener < BaseListener
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

  # Keep the kanban stage in sync with the closing outcome the salesperson sets,
  # so a deal marked as won/lost lands in the matching terminal column instead of
  # being frozen at its first stage.
  def handle_disposition_change(conversation, previous_attrs, current_attrs)
    old_disposition = previous_attrs['crm_disposition_result']
    new_disposition = current_attrs['crm_disposition_result']

    return if old_disposition == new_disposition || new_disposition.blank?

    target_stage = stage_for_disposition(new_disposition)
    return if target_stage.blank?
    return if current_attrs['crm_funnel_stage'] == target_stage

    move_stage(conversation, target_stage)
  end

  def handle_funnel_stage_change(conversation, previous_attrs, current_attrs)
    old_stage = previous_attrs['crm_funnel_stage']
    new_stage = current_attrs['crm_funnel_stage']

    return if old_stage == new_stage || new_stage.blank?

    Crm::FollowUpSchedulerService.new(conversation).schedule! if new_stage == Crm::Constants::QUOTE_STAGE
    ensure_disposition_for_stage(conversation, new_stage, current_attrs)
  end

  # When a card is dragged straight into a terminal column without a disposition,
  # default one so the sales reports still count the outcome.
  def ensure_disposition_for_stage(conversation, stage, current_attrs)
    return if current_attrs['crm_disposition_result'].present?

    disposition = disposition_for_stage(stage)
    return if disposition.blank?

    conversation.update!(
      custom_attributes: conversation.custom_attributes.merge('crm_disposition_result' => disposition)
    )
  end

  def stage_for_disposition(disposition)
    return Crm::Constants::WON_STAGE if disposition == Crm::Constants::WON_DISPOSITION
    return Crm::Constants::LOST_STAGE if Crm::Constants::LOST_DISPOSITIONS.include?(disposition)

    nil
  end

  def disposition_for_stage(stage)
    return Crm::Constants::WON_DISPOSITION if stage == Crm::Constants::WON_STAGE
    return Crm::Constants::LOST_DISPOSITION if stage == Crm::Constants::LOST_STAGE

    nil
  end

  def move_stage(conversation, stage)
    conversation.update!(
      custom_attributes: conversation.custom_attributes.merge(
        'crm_funnel_stage' => stage,
        'crm_stage_changed_at' => Time.current.iso8601
      )
    )
  end
end
