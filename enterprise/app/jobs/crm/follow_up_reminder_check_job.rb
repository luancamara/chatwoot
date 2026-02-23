class Crm::FollowUpReminderCheckJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    FollowUpReminder.due.find_each do |reminder|
      create_notification(reminder)
      reminder.triggered!
    end
  end

  private

  def create_notification(reminder)
    Notification.create!(
      account: reminder.account,
      user_id: reminder.user_id,
      notification_type: :follow_up_alert,
      primary_actor: reminder.conversation
    )
  end
end
