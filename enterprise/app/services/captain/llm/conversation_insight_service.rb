class Captain::Llm::ConversationInsightService
  VALID_FUNNEL_STAGES = Crm::Constants::STAGES

  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def generate_and_save_insight
    # Layer 1: Automatic metrics (pure Ruby, no LLM)
    metrics = ConversationInsight::AutomaticMetricsCalculator.new(@conversation).calculate

    # Layer 2: Qualitative analysis (LLM)
    llm_analysis = ConversationInsight::QualitativeAnalysisService.new(@assistant, @conversation).analyze

    # Layer 3: Score calculation (pure Ruby)
    score_result = ConversationInsight::ScoreCalculator.new(
      automatic_metrics: metrics,
      llm_analysis: llm_analysis
    ).calculate

    save_insight(metrics, llm_analysis, score_result)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @conversation.account).capture_exception
    # If LLM failed but metrics succeeded, save partial insight
    save_partial_insight(metrics) if metrics.present?
    nil
  end

  private

  def save_insight(metrics, llm_analysis, score_result)
    insight = find_or_build_insight

    attrs = build_metrics_attrs(metrics)
    attrs.merge!(build_llm_attrs(llm_analysis)) if llm_analysis.present?
    attrs.merge!(build_score_attrs(score_result))
    attrs[:raw_llm_response] = llm_analysis || {}

    insight.update!(attrs)

    auto_set_funnel_stage(llm_analysis['suggested_funnel_stage']) if llm_analysis&.dig('suggested_funnel_stage').present?

    insight
  end

  def save_partial_insight(metrics)
    insight = find_or_build_insight

    attrs = build_metrics_attrs(metrics)
    attrs[:raw_llm_response] = {}

    # Calculate score with metrics only (no LLM criteria)
    score_result = ConversationInsight::ScoreCalculator.new(
      automatic_metrics: metrics,
      llm_analysis: nil
    ).calculate
    attrs.merge!(build_score_attrs(score_result))

    insight.update!(attrs)
    insight
  end

  def find_or_build_insight
    @conversation.conversation_insight || @conversation.build_conversation_insight(account: @conversation.account)
  end

  def build_metrics_attrs(metrics)
    {
      no_response: metrics[:no_response] || false,
      abandonment_severity: metrics[:abandonment_severity],
      media_sent: metrics[:media_sent] || false,
      automatic_metrics: {
        tpr_seconds: metrics[:tpr_seconds],
        tpr_score: metrics[:tpr_score],
        tmer_seconds: metrics[:tmer_seconds],
        message_count: metrics[:message_count],
        human_response_count: metrics[:human_response_count],
        incoming_count: metrics[:incoming_count]
      }
    }
  end

  def build_llm_attrs(analysis)
    {
      conversation_classification: analysis['conversation_classification'],
      estimated_value: analysis['estimated_value'],
      product_category: analysis['product_category'],
      customer_sentiment: analysis['customer_sentiment'],
      key_topics: analysis['key_topics'] || [],
      quality_breakdown: analysis['criteria'] || {},
      feedback_summary: analysis['feedback_summary']
    }
  end

  def build_score_attrs(score_result)
    {
      final_score: score_result[:final_score],
      quality_score: score_result[:final_score],
      penalties: score_result[:penalties] || []
    }
  end

  def auto_set_funnel_stage(suggested_stage)
    current_stage = @conversation.custom_attributes&.dig('crm_funnel_stage')
    return if current_stage.present?
    return unless VALID_FUNNEL_STAGES.include?(suggested_stage)

    @conversation.update!(
      custom_attributes: (@conversation.custom_attributes || {}).merge('crm_funnel_stage' => suggested_stage)
    )
  end
end
