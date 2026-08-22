class V2::CrmReports::AgentPerformanceBuilder
  include DateRangeHelper

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    agent_stats = account.account_users.map do |account_user|
      build_agent_stats(account_user.user_id)
    end
    agent_stats.sort_by { |stats| -(stats[:avg_quality_score] || 0) }
  end

  private

  def base_conversations
    scope = account.conversations
    scope = scope.where(created_at: range) if range.present?
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope
  end

  def build_agent_stats(user_id)
    convos = base_conversations.where(assignee_id: user_id)
    resolved = convos.where(status: :resolved)
    vendas = resolved.where("custom_attributes->>'crm_disposition_result' = ?", 'Venda')

    {
      id: user_id,
      total_conversations: convos.count,
      resolved_conversations: resolved.count,
      vendas_count: vendas.count,
      conversion_rate: resolved.count.positive? ? (vendas.count.to_f / resolved.count * 100).round(1) : 0,
      avg_quality_score: avg_quality_score(resolved),
      total_estimated_revenue: total_revenue(vendas)
    }
  end

  def avg_quality_score(resolved_scope)
    return nil unless defined?(ConversationInsight)

    ConversationInsight
      .where(conversation_id: resolved_scope.select(:id))
      .average(:quality_score)
      &.round(1)
  rescue StandardError
    nil
  end

  def total_revenue(vendas_scope)
    return 0 unless defined?(ConversationInsight)

    ConversationInsight
      .where(conversation_id: vendas_scope.select(:id))
      .sum(:estimated_value)
  rescue StandardError
    0
  end
end
