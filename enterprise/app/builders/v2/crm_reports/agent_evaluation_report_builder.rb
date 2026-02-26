class V2::CrmReports::AgentEvaluationReportBuilder
  CRITERIA_KEYS = %w[
    needs_qualification closing_conduct media_usage personalization
    alternatives_offered tone_communication return_client_continuity cross_sell
  ].freeze

  attr_reader :account, :user_id, :period_start, :period_end

  def initialize(account:, user_id:, period_start:, period_end:)
    @account = account
    @user_id = user_id
    @period_start = period_start
    @period_end = period_end
  end

  def build
    {
      user_id: user_id,
      period_start: period_start,
      period_end: period_end,
      overview: build_overview,
      highlights: build_highlights,
      improvements: build_improvements,
      alerts: build_alerts,
      time_metrics: build_time_metrics,
      weekly_goal: build_weekly_goal
    }
  end

  private

  def insights
    @insights ||= ConversationInsight
                    .by_agent(user_id)
                    .by_account(account.id)
                    .in_period(period_start, period_end)
  end

  def previous_insights
    duration = period_end.to_date - period_start.to_date
    prev_start = period_start - duration.days
    prev_end = period_start

    @previous_insights ||= ConversationInsight
                             .by_agent(user_id)
                             .by_account(account.id)
                             .in_period(prev_start, prev_end)
  end

  def build_overview
    avg = insights.with_final_score.average(:final_score)&.round(2)
    prev_avg = previous_insights.with_final_score.average(:final_score)&.round(2)
    trend = calculate_trend(avg, prev_avg)

    {
      avg_score: avg,
      previous_avg_score: prev_avg,
      trend: trend,
      total_evaluated: insights.count,
      with_score: insights.with_final_score.count
    }
  end

  def build_highlights
    criteria_averages.sort_by { |_k, v| -v }.first(3).map do |key, avg|
      { criterion: key, avg_score: avg.round(2) }
    end
  end

  def build_improvements
    criteria_averages.sort_by { |_k, v| v }.first(3).map do |key, avg|
      { criterion: key, avg_score: avg.round(2) }
    end
  end

  def build_alerts
    alerts = []

    no_response_ids = insights.no_response.joins(:conversation).pluck('conversations.display_id')
    alerts << { type: 'no_response', conversation_ids: no_response_ids } if no_response_ids.any?

    abandonment_ids = insights.with_abandonment.joins(:conversation).pluck('conversations.display_id')
    alerts << { type: 'abandonment', conversation_ids: abandonment_ids } if abandonment_ids.any?

    promise_ids = insights.where("quality_breakdown -> 'unfulfilled_promises' ->> 'flagged' = ?", 'true')
                          .joins(:conversation).pluck('conversations.display_id')
    alerts << { type: 'unfulfilled_promises', conversation_ids: promise_ids } if promise_ids.any?

    alerts
  end

  def build_time_metrics
    scored = insights.with_final_score
    tpr_values = scored.pluck(:automatic_metrics).filter_map { |m| m&.dig('tpr_seconds') }
    tmer_values = scored.pluck(:automatic_metrics).filter_map { |m| m&.dig('tmer_seconds') }
    fast_responses = tpr_values.count { |t| t <= 900 } # <15 min

    {
      avg_tpr_seconds: tpr_values.any? ? (tpr_values.sum / tpr_values.size.to_f).round : nil,
      avg_tmer_seconds: tmer_values.any? ? (tmer_values.sum / tmer_values.size.to_f).round : nil,
      pct_responded_under_15min: tpr_values.any? ? ((fast_responses.to_f / tpr_values.size) * 100).round(1) : nil
    }
  end

  def build_weekly_goal
    worst = criteria_averages.min_by { |_k, v| v }
    return nil unless worst

    { criterion: worst[0], current_avg: worst[1].round(2) }
  end

  def criteria_averages
    @criteria_averages ||= begin
      avgs = {}
      breakdowns = insights.with_final_score.pluck(:quality_breakdown)
      return avgs if breakdowns.empty?

      CRITERIA_KEYS.each do |key|
        scores = breakdowns.filter_map { |b| b&.dig(key, 'score') }
        avgs[key] = scores.sum.to_f / scores.size if scores.any?
      end
      avgs
    end
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
