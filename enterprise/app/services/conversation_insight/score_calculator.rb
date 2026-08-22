class ConversationInsight::ScoreCalculator
  CRITERIA_WEIGHTS = {
    'needs_qualification' => { max: 5, weight: 0.20 },
    'closing_conduct' => { max: 5, weight: 0.20 },
    'media_usage' => { max: 3, weight: 0.10 },
    'personalization' => { max: 3, weight: 0.10 },
    'alternatives_offered' => { max: 3, weight: 0.05 },
    'tone_communication' => { max: 3, weight: 0.10 },
    'return_client_continuity' => { max: 3, weight: 0.05 },
    'cross_sell' => { max: 2, weight: 0.05 }
  }.freeze

  TPR_WEIGHT = 0.15
  NO_RESPONSE_SCORE = 0.0
  SEVERE_ABANDONMENT_PENALTY = -3.0
  LIGHT_ABANDONMENT_PENALTY = -1.5
  UNFULFILLED_PROMISES_PENALTY = -2.0

  def initialize(automatic_metrics:, llm_analysis:)
    @metrics = automatic_metrics || {}
    @analysis = llm_analysis || {}
    @criteria = @analysis['criteria'] || {}
  end

  def calculate
    penalties = collect_penalties

    # No response = automatic 0
    if @metrics[:no_response]
      return {
        final_score: NO_RESPONSE_SCORE,
        penalties: penalties,
        criteria_scores: {}
      }
    end

    # Calculate weighted score
    applicable, inapplicable_weight = partition_criteria
    tpr_contribution = calculate_tpr_contribution
    criteria_contribution = calculate_criteria_contribution(applicable, inapplicable_weight)

    raw_score = (tpr_contribution + criteria_contribution) * 10.0
    penalty_total = penalties.sum { |p| p[:value] }
    final = (raw_score + penalty_total).clamp(0.0, 10.0).round(2)

    {
      final_score: final,
      penalties: penalties,
      criteria_scores: build_criteria_scores(applicable)
    }
  end

  private

  def collect_penalties
    penalties = []

    penalties << { type: 'no_response', value: 0, description: 'Conversa sem resposta humana - nota automatica 0' } if @metrics[:no_response]

    case @metrics[:abandonment_severity]
    when 'severe'
      penalties << { type: 'severe_abandonment', value: SEVERE_ABANDONMENT_PENALTY, description: 'Abandono grave (>12h uteis sem resposta)' }
    when 'light'
      penalties << { type: 'light_abandonment', value: LIGHT_ABANDONMENT_PENALTY, description: 'Abandono leve (4-12h uteis sem resposta)' }
    end

    if @criteria.dig('unfulfilled_promises', 'flagged')
      penalties << { type: 'unfulfilled_promises', value: UNFULFILLED_PROMISES_PENALTY, description: 'Promessa nao cumprida pelo vendedor' }
    end

    penalties
  end

  def partition_criteria
    applicable = {}
    inapplicable_weight = 0.0

    CRITERIA_WEIGHTS.each do |key, config|
      criterion = @criteria[key]

      if criterion.nil? || criterion['score'].nil?
        inapplicable_weight += config[:weight]
      else
        applicable[key] = {
          score: criterion['score'].to_f,
          max: config[:max],
          weight: config[:weight],
          justification: criterion['justification']
        }
      end
    end

    [applicable, inapplicable_weight]
  end

  def calculate_tpr_contribution
    tpr_score = @metrics[:tpr_score]
    return 0.0 if tpr_score.nil?

    (tpr_score.to_f / 5.0) * TPR_WEIGHT
  end

  def calculate_criteria_contribution(applicable, inapplicable_weight)
    return 0.0 if applicable.empty?

    total_applicable_weight = applicable.values.sum { |c| c[:weight] }
    return 0.0 if total_applicable_weight.zero?

    # Redistribution factor: redistribute N/A weights proportionally
    redistribution_factor = if inapplicable_weight.positive? && total_applicable_weight.positive?
                              (total_applicable_weight + inapplicable_weight) / total_applicable_weight
                            else
                              1.0
                            end

    applicable.sum do |_key, config|
      normalized = config[:score] / config[:max]
      normalized * config[:weight] * redistribution_factor
    end
  end

  def build_criteria_scores(applicable)
    applicable.transform_values do |config|
      {
        score: config[:score],
        max: config[:max],
        weight: config[:weight],
        normalized: (config[:score] / config[:max]).round(3)
      }
    end
  end
end
