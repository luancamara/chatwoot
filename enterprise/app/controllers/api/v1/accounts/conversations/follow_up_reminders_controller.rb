class Api::V1::Accounts::Conversations::FollowUpRemindersController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :set_conversation
  before_action :set_reminder, only: [:update, :destroy]

  def index
    @reminders = @conversation.follow_up_reminders.order(remind_at: :asc)
    render json: @reminders.map { |r| reminder_payload(r) }
  end

  def create
    @reminder = @conversation.follow_up_reminders.create!(reminder_params.merge(account: Current.account, user: Current.user))
    render json: reminder_payload(@reminder), status: :created
  end

  def update
    @reminder.update!(reminder_params)
    render json: reminder_payload(@reminder)
  end

  def destroy
    @reminder.destroy!
    head :no_content
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end

  def set_reminder
    @reminder = @conversation.follow_up_reminders.find(params[:id])
  end

  def reminder_params
    params.permit(:remind_at, :notes, :status)
  end

  def reminder_payload(reminder)
    {
      id: reminder.id,
      conversation_id: reminder.conversation_id,
      user_id: reminder.user_id,
      remind_at: reminder.remind_at,
      reminder_type: reminder.reminder_type,
      status: reminder.status,
      notes: reminder.notes,
      created_at: reminder.created_at,
      updated_at: reminder.updated_at
    }
  end
end
