class Crm::FollowUpSchedulerService
  SCHEDULE = {
    auto_d1: 1.day,
    auto_d3: 3.days,
    auto_d7: 7.days
  }.freeze

  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
  end

  def schedule!
    return unless @conversation.assignee_id

    SCHEDULE.each do |reminder_type, offset|
      FollowUpReminder.find_or_create_by!(
        conversation: @conversation,
        account: @account,
        user_id: @conversation.assignee_id,
        reminder_type: reminder_type
      ) do |reminder|
        reminder.remind_at = Time.current + offset
        reminder.status = :pending
      end
    end
  end
end
