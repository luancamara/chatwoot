class ConversationInsight::AutomaticMetricsCalculator
  TPR_THRESHOLDS = [
    { max_seconds: 5 * 60,    score: 5 },  # <5 min
    { max_seconds: 15 * 60,   score: 4 },  # 5-15 min
    { max_seconds: 30 * 60,   score: 3 },  # 15-30 min
    { max_seconds: 60 * 60,   score: 2 },  # 30-60 min
    { max_seconds: 2 * 3600,  score: 1 },  # 1-2 hours
    { max_seconds: Float::INFINITY, score: 0 } # >2 hours
  ].freeze

  ABANDONMENT_LIGHT_THRESHOLD = 4 * 3600   # 4 hours in seconds
  ABANDONMENT_SEVERE_THRESHOLD = 12 * 3600 # 12 hours in seconds
  CLIENT_GAP_THRESHOLD = 3600              # 1 hour - client response gap to exclude

  def initialize(conversation)
    @conversation = conversation
    @messages = load_messages
    @biz_calculator = build_biz_calculator
  end

  def calculate
    human_outgoing = human_outgoing_messages
    incoming = incoming_messages

    {
      tpr_seconds: calculate_tpr(incoming, human_outgoing),
      tpr_score: tpr_to_score(calculate_tpr(incoming, human_outgoing)),
      tmer_seconds: calculate_tmer(incoming, human_outgoing),
      no_response: human_outgoing.empty? && incoming.any?,
      abandonment_severity: calculate_abandonment(incoming, human_outgoing),
      media_sent: media_sent?(human_outgoing),
      message_count: @messages.size,
      human_response_count: human_outgoing.size,
      incoming_count: incoming.size
    }
  end

  private

  def load_messages
    @conversation.messages
                 .where.not(message_type: [:activity, :template])
                 .order(created_at: :asc)
  end

  def build_biz_calculator
    assignee_id = @conversation.assignee_id
    return nil unless assignee_id

    ConversationInsight::BusinessHoursCalculator.new(
      user_id: assignee_id,
      account_id: @conversation.account_id,
      inbox: @conversation.inbox
    )
  end

  def incoming_messages
    @messages.select { |m| m.message_type == 'incoming' }
  end

  def human_outgoing_messages
    @messages.select { |m| m.message_type == 'outgoing' && human_sender?(m) }
  end

  def human_sender?(message)
    message.sender_type == 'User' && !bot_user?(message.sender)
  end

  def bot_user?(sender)
    return true if sender.nil?
    return true if sender.respond_to?(:type) && sender.type.in?(%w[AgentBot])

    false
  end

  def calculate_tpr(incoming, human_outgoing)
    first_incoming = incoming.first
    first_human_response = human_outgoing.first
    return nil if first_incoming.nil? || first_human_response.nil?

    business_seconds(first_incoming.created_at, first_human_response.created_at)
  end

  def calculate_tmer(incoming, human_outgoing)
    return nil if incoming.empty? || human_outgoing.empty?

    intervals = incoming.filter_map { |message| response_interval(message, human_outgoing) }

    return nil if intervals.empty?

    (intervals.sum.to_f / intervals.size).round
  end

  def response_interval(incoming_message, human_outgoing)
    next_response = human_outgoing.find { |message| message.created_at > incoming_message.created_at }
    return unless next_response
    return if client_gap_exceeded?(incoming_message, human_outgoing)

    business_seconds(incoming_message.created_at, next_response.created_at)
  end

  def client_gap_exceeded?(incoming_message, human_outgoing)
    previous_outgoing = human_outgoing.reverse.find { |message| message.created_at < incoming_message.created_at }
    previous_outgoing && (incoming_message.created_at - previous_outgoing.created_at).to_i > CLIENT_GAP_THRESHOLD
  end

  def calculate_abandonment(_incoming, _human_outgoing)
    last_message = @messages.last
    return nil if last_message.nil?
    return nil unless last_message.message_type == 'incoming'

    # Last message is incoming - check how long without response
    elapsed = business_seconds(last_message.created_at, Time.current)
    return nil if elapsed.nil? || elapsed < ABANDONMENT_LIGHT_THRESHOLD

    elapsed >= ABANDONMENT_SEVERE_THRESHOLD ? 'severe' : 'light'
  end

  def media_sent?(human_outgoing)
    human_outgoing.any? { |m| m.attachments.any? }
  end

  def tpr_to_score(tpr_seconds)
    return nil if tpr_seconds.nil?

    TPR_THRESHOLDS.find { |t| tpr_seconds <= t[:max_seconds] }&.dig(:score) || 0
  end

  def business_seconds(start_time, end_time)
    if @biz_calculator
      @biz_calculator.business_seconds_between(start_time, end_time)
    else
      (end_time - start_time).to_i
    end
  end
end
