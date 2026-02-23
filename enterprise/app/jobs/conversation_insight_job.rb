class ConversationInsightJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    assistant = find_assistant(conversation)
    return unless assistant

    Captain::Llm::ConversationInsightService.new(assistant, conversation).generate_and_save_insight
  end

  private

  def find_assistant(conversation)
    conversation.inbox.captain_assistant || Captain::Assistant.find_by(account: conversation.account)
  end
end
