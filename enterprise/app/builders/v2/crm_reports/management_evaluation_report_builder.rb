class V2::CrmReports::ManagementEvaluationReportBuilder
  CRITERIA_KEYS = %w[
    needs_qualification closing_conduct media_usage personalization
    alternatives_offered tone_communication return_client_continuity cross_sell
  ].freeze

  attr_reader :account, :period_start, :period_end

  def initialize(account:, period_start:, period_end:)
    @account = account
    @period_start = period_start
    @period_end = period_end
  end

  def build
    {
      period_start: period_start,
      period_end: period_end,
      ranking: build_ranking,
      aggregated_metrics: build_aggregated_metrics,
      inbox_comparison: build_inbox_comparison,
      worst_conversations: worst_conversations(5),
      best_conversations: best_conversations(3),
      systemic_issues: build_systemic_issues,
      weekly_evolution: build_weekly_evolution
    }
  end

  private

  def insights
    @insights ||= ConversationInsight.by_account(account.id).in_period(period_start, period_end)
  end

  def agent_ids
    @agent_ids ||= account.account_users.pluck(:user_id)
  end

  def build_ranking
    agent_ids.filter_map do |uid|
      agent_insights = insights.by_agent(uid)
      scored = agent_insights.with_final_score
      next if scored.empty?

      avg = scored.average(:final_score)&.round(2)
      prev_avg = previous_avg_for_agent(uid)

      {
        user_id: uid,
        avg_score: avg,
        total_evaluated: agent_insights.count,
        trend: calculate_trend(avg, prev_avg),
        no_response_count: agent_insights.no_response.count,
        abandonment_count: agent_insights.with_abandonment.count
      }
    end.sort_by { |a| -(a[:avg_score] || 0) }
  end

  def build_aggregated_metrics
    scored = insights.with_final_score
    tpr_values = scored.pluck(:automatic_metrics).filter_map { |m| m&.dig('tpr_seconds') }

    {
      team_avg_score: scored.average(:final_score)&.round(2),
      total_evaluated: insights.count,
      avg_tpr_seconds: tpr_values.any? ? (tpr_values.sum / tpr_values.size.to_f).round : nil,
      abandonment_rate: insights.any? ? ((insights.with_abandonment.count.to_f / insights.count) * 100).round(1) : 0,
      no_response_rate: insights.any? ? ((insights.no_response.count.to_f / insights.count) * 100).round(1) : 0
    }
  end

  def build_inbox_comparison
    inbox_ids = account.inboxes.pluck(:id)
    inbox_ids.filter_map do |inbox_id|
      inbox_insights = insights.joins(:conversation).where(conversations: { inbox_id: inbox_id })
      scored = inbox_insights.where.not(final_score: nil)
      next if scored.empty?

      {
        inbox_id: inbox_id,
        avg_score: scored.average(:final_score)&.round(2),
        total: inbox_insights.count
      }
    end
  end

  def worst_conversations(limit)
    insights.with_final_score
            .order(final_score: :asc)
            .limit(limit)
            .includes(:conversation)
            .map { |i| conversation_summary(i) }
  end

  def best_conversations(limit)
    insights.with_final_score
            .order(final_score: :desc)
            .limit(limit)
            .includes(:conversation)
            .map { |i| conversation_summary(i) }
  end

  def build_systemic_issues
    issues = []
    breakdowns = insights.with_final_score.pluck(:quality_breakdown)
    return issues if breakdowns.empty?

    CRITERIA_KEYS.each do |key|
      scores = breakdowns.filter_map { |b| b&.dig(key, 'score') }
      next if scores.empty?

      max = criterion_max(key)
      avg_normalized = scores.sum.to_f / (scores.size * max)
      issues << { criterion: key, avg_normalized: avg_normalized.round(3), agents_below_50pct: count_agents_below(key, 0.5) } if avg_normalized < 0.5
    end

    issues.sort_by { |i| i[:avg_normalized] }
  end

  def build_weekly_evolution
    weeks = []
    current = period_start.to_date.beginning_of_week
    end_date = period_end.to_date

    while current <= end_date
      week_end = [current + 6.days, end_date].min
      week_insights = ConversationInsight.by_account(account.id).in_period(current, week_end.end_of_day).with_final_score
      weeks << {
        week_start: current,
        avg_score: week_insights.average(:final_score)&.round(2),
        count: week_insights.count
      }
      current += 7.days
    end

    weeks
  end

  def conversation_summary(insight)
    conv = insight.conversation
    {
      conversation_id: conv.display_id,
      final_score: insight.final_score,
      classification: insight.conversation_classification,
      assignee_id: conv.assignee_id,
      feedback: insight.feedback_summary
    }
  end

  def previous_avg_for_agent(user_id)
    duration = period_end.to_date - period_start.to_date
    prev_start = period_start - duration.days
    prev_end = period_start

    ConversationInsight
      .by_agent(user_id)
      .by_account(account.id)
      .in_period(prev_start, prev_end)
      .with_final_score
      .average(:final_score)&.round(2)
  end

  def count_agents_below(criterion, threshold)
    agent_ids.count do |uid|
      agent_breakdowns = insights.by_agent(uid).with_final_score.pluck(:quality_breakdown)
      scores = agent_breakdowns.filter_map { |b| b&.dig(criterion, 'score') }
      next false if scores.empty?

      max = criterion_max(criterion)
      (scores.sum.to_f / (scores.size * max)) < threshold
    end
  end

  def criterion_max(key)
    { 'needs_qualification' => 5, 'closing_conduct' => 5, 'media_usage' => 3, 'personalization' => 3,
      'alternatives_offered' => 3, 'tone_communication' => 3, 'return_client_continuity' => 3, 'cross_sell' => 2 }[key] || 3
  end

  def calculate_trend(current, previous)
    return 'stable' if current.nil? || previous.nil?

    diff = current - previous
    if diff > 0.3
      'up'
    elsif diff < -0.3
      'down'
    else
      'stable'
    end
  end
end
