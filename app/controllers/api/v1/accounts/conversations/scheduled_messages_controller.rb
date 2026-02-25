class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  def index
    @scheduled_messages = @conversation.scheduled_messages.pending.order(scheduled_at: :asc)
    render json: @scheduled_messages.map { |sm| scheduled_message_payload(sm) }
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

  def scheduled_message_payload(sm)
    {
      id: sm.id,
      content: sm.content,
      scheduled_at: sm.scheduled_at,
      status: sm.status,
      sender: { id: sm.sender_id, name: sm.sender.name },
      created_at: sm.created_at
    }
  end
end
