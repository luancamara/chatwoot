class ConversationAutoLabelJob < ApplicationJob
  queue_as :default

  def perform(conversation, scheduled_at)
    return unless Captain::Llm::ConversationAutoLabelService.debounce_valid?(conversation, scheduled_at)

    assistant = find_assistant(conversation)
    return unless assistant

    Captain::Llm::ConversationAutoLabelService.new(assistant, conversation).generate_and_apply_labels
  end

  private

  def find_assistant(conversation)
    conversation.inbox.captain_assistant || Captain::Assistant.find_by(account: conversation.account)
  end
end
