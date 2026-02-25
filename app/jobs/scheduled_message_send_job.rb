class ScheduledMessageSendJob < ApplicationJob
  queue_as :default

  def perform(scheduled_message)
    return unless scheduled_message.pending?

    conversation = scheduled_message.conversation

    message = conversation.messages.create!(
      account: scheduled_message.account,
      inbox: scheduled_message.inbox,
      sender: scheduled_message.sender,
      content: scheduled_message.content,
      message_type: :outgoing,
      content_attributes: scheduled_message.content_attributes
    )

    scheduled_message.sent!
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    scheduled_message.update!(status: :failed, content_attributes: scheduled_message.content_attributes.merge('error' => e.message))
    Rails.logger.error "Failed to send scheduled message #{scheduled_message.id}: #{e.message}"
  end
end
