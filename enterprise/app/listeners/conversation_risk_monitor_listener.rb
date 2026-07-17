class ConversationRiskMonitorListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming? && !message.private?

    config = message.inbox.conversation_risk_monitor_config
    ConversationRiskMonitor::ProcessMessageJob.schedule(message) if config&.operational?
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless conversation.inbox.conversation_risk_monitor_config&.operational?

    ConversationRiskMonitor::IncidentService.new(conversation: conversation).resolve!
  end
end
