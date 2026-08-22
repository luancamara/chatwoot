class Api::V1::Accounts::ConversationInsightsController < Api::V1::Accounts::EnterpriseAccountsController
  INSIGHT_ATTRIBUTES = %w[
    id conversation_id conversation_classification final_score estimated_value product_category customer_sentiment key_topics quality_score
    quality_breakdown no_response abandonment_severity media_sent automatic_metrics penalties feedback_summary created_at updated_at
  ].freeze

  before_action :check_admin_authorization?
  before_action :set_conversation
  before_action :set_insight, only: [:show]

  def show
    render json: insight_payload
  end

  def create
    ConversationInsightJob.perform_later(@conversation)
    render json: { message: 'Analysis queued' }, status: :accepted
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end

  def set_insight
    @insight = @conversation.conversation_insight
  end

  def insight_payload
    return {} unless @insight

    @insight.attributes.slice(*INSIGHT_ATTRIBUTES)
  end
end
