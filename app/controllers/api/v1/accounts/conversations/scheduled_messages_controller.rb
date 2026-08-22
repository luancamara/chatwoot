class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  def index
    @scheduled_messages = @conversation.scheduled_messages.pending.order(scheduled_at: :asc)
    render json: @scheduled_messages.map { |scheduled_message| scheduled_message_payload(scheduled_message) }
  end

  def create
    @scheduled_message = @conversation.scheduled_messages.create!(
      account: Current.account,
      inbox: @conversation.inbox,
      sender: Current.user,
      content: permitted_params[:content],
      scheduled_at: permitted_params[:scheduled_at],
      content_attributes: permitted_params[:content_attributes] || {}
    )
    render json: scheduled_message_payload(@scheduled_message), status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @scheduled_message = @conversation.scheduled_messages.pending.find(params[:id])
    @scheduled_message.cancelled!
    head :ok
  end

  private

  def permitted_params
    params.permit(:content, :scheduled_at, content_attributes: {})
  end

  def scheduled_message_payload(scheduled_message)
    {
      id: scheduled_message.id,
      content: scheduled_message.content,
      scheduled_at: scheduled_message.scheduled_at,
      status: scheduled_message.status,
      sender: { id: scheduled_message.sender_id, name: scheduled_message.sender.name },
      created_at: scheduled_message.created_at
    }
  end
end
