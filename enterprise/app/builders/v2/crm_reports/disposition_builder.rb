class V2::CrmReports::DispositionBuilder
  include DateRangeHelper

  RESULTS = ['Venda', 'Perda', 'Indecisao', 'Sem Resposta'].freeze
  LOSS_REASONS = %w[Preco Prazo Estoque Atendimento Outro].freeze

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    {
      disposition_results: result_counts,
      loss_reasons: loss_reason_counts,
      total_resolved: resolved_conversations.count
    }
  end

  private

  def resolved_conversations
    scope = account.conversations.where(status: :resolved)
    scope = scope.where(created_at: range) if range.present?
    scope = scope.where(assignee_id: params[:agent_id]) if params[:agent_id].present?
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope
  end

  def result_counts
    counts = resolved_conversations
             .where("custom_attributes->>'crm_disposition_result' IS NOT NULL")
             .group("custom_attributes->>'crm_disposition_result'")
             .count

    RESULTS.map do |result|
      { result: result, count: counts[result] || 0 }
    end
  end

  def loss_reason_counts
    losses = resolved_conversations.where("custom_attributes->>'crm_disposition_result' = ?", 'Perda')
    counts = losses
             .where("custom_attributes->>'crm_loss_reason' IS NOT NULL")
             .group("custom_attributes->>'crm_loss_reason'")
             .count

    LOSS_REASONS.map do |reason|
      { reason: reason, count: counts[reason] || 0 }
    end
  end
end
