class WhatsappTriageListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming? && !message.private?

    configuration = Whatsapp::Triage::Configuration.new
    if configuration.enabled_for?(message.inbox)
      Whatsapp::Triage::ProcessMessageJob.schedule(message, configuration: configuration)
    else
      open_conversation_without_triage(message)
    end
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    configuration = Whatsapp::Triage::Configuration.new
    return unless configuration.configured_for?(conversation.inbox)

    Whatsapp::Triage::CycleService.new(conversation: conversation, configuration: configuration).mark_resolved!
  end

  private

  def open_conversation_without_triage(message)
    return unless message.inbox.agent_bot&.name == Whatsapp::Triage::SetupService::BOT_NAME

    message.conversation.open! if message.conversation.pending?
  end
end
