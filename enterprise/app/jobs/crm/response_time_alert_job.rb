class Crm::ResponseTimeAlertJob < ApplicationJob
  queue_as :scheduled_jobs

  DEFAULT_THRESHOLD_MINUTES = 30

  def perform
    Account.find_each do |account|
      threshold = (account.crm_response_time_alert_minutes || DEFAULT_THRESHOLD_MINUTES).to_i.minutes.ago
      conversations = account.conversations
                             .where(status: :open)
                             .where('waiting_since IS NOT NULL AND waiting_since < ?', threshold)
                             .where.not(assignee_id: nil)

      conversations.find_each do |conversation|
        create_alert_notification(account, conversation)
      end
    end
  end

  private

  def create_alert_notification(account, conversation)
    existing = Notification.find_by(
      account: account,
      user_id: conversation.assignee_id,
      notification_type: :follow_up_alert,
      primary_actor: conversation,
      read_at: nil
    )
    return if existing

    Notification.create!(
      account: account,
      user_id: conversation.assignee_id,
      notification_type: :follow_up_alert,
      primary_actor: conversation
    )
  end
end
