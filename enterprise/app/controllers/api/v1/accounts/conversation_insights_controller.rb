class Api::V1::Accounts::ConversationInsightsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :check_admin_authorization?
  before_action :set_conversation
  before_action :set_insight, only: [:show]

  def show
    render json: insight_payload
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

    {
      id: @insight.id,
      conversation_id: @insight.conversation_id,
      estimated_value: @insight.estimated_value,
      product_category: @insight.product_category,
      customer_sentiment: @insight.customer_sentiment,
      key_topics: @insight.key_topics,
      quality_score: @insight.quality_score,
      quality_breakdown: @insight.quality_breakdown,
      created_at: @insight.created_at,
      updated_at: @insight.updated_at
    }
  end
end
