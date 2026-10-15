# Aggregate columns and payload shapes for the agent response summary. Expects `filters` (V2::AgentResponseReports::Filters).
module V2::AgentResponseReports::Metrics
  OWNER_REPLY = 'conversation_response_attempts.replied_at IS NOT NULL AND ' \
                'conversation_response_attempts.responder_id = conversation_response_attempts.assignee_id'.freeze

  private

  # Only the owner's reply before the deadline is credited; a reply by someone else before it is reported apart and
  # leaves the window without verdict, so it neither raises nor lowers the owner's compliance.
  def deadline(counts)
    return unless filters.deadline_available?

    met, breached, answered_by_other, pending, canceled, lost_to_reassignment = counts
    eligible = met + breached
    { met: met, breached: breached, eligible: eligible, answered_by_other: answered_by_other, pending: pending, canceled: canceled,
      lost_to_reassignment: lost_to_reassignment, compliance_rate: (eligible.zero? ? nil : (met.to_f / eligible).round(4)) }
  end

  def duration(count, mean, median)
    return unless filters.deadline_available?

    { count: count, mean_seconds: mean&.to_f&.round, median_seconds: median&.to_f&.round }
  end

  def assignments(initial, reassignments, timeout_reassignments)
    return unless filters.assignments_available?

    { initial: initial, reassignments: reassignments, timeout_reassignments: timeout_reassignments }
  end

  def messages(sent, handled, customer)
    { agent: sent, customer: customer || 0, per_handled_conversation: (handled.zero? ? nil : (sent.to_f / handled).round(2)) }
  end

  def deadline_columns
    outcome = filters.effective_outcome_sql
    counts = %w[met breached answered_by_other pending canceled].map { |value| "COUNT(*) FILTER (WHERE #{outcome} = '#{value}')" }
    sql_columns(*counts, "COUNT(*) FILTER (WHERE conversation_response_attempts.end_reason = 'reassigned')")
  end

  # Reply speed only counts the owner's own reply, measured from when that owner received the window.
  def response_columns
    sql_columns(
      "COUNT(*) FILTER (WHERE #{OWNER_REPLY})",
      "AVG(conversation_response_attempts.response_seconds) FILTER (WHERE #{OWNER_REPLY})",
      "percentile_cont(0.5) WITHIN GROUP (ORDER BY conversation_response_attempts.response_seconds) FILTER (WHERE #{OWNER_REPLY})"
    )
  end

  # Customer wait runs from the customer message to whichever human reply closed the cycle.
  def wait_columns
    sql_columns(
      'COUNT(conversation_response_attempts.wait_seconds)',
      'AVG(conversation_response_attempts.wait_seconds)',
      'percentile_cont(0.5) WITHIN GROUP (ORDER BY conversation_response_attempts.wait_seconds)'
    )
  end

  def assignment_columns
    sql_columns(
      'COUNT(DISTINCT conversation_assignment_events.conversation_id)',
      "COUNT(*) FILTER (WHERE conversation_assignment_events.event_kind = 'initial')",
      "COUNT(*) FILTER (WHERE conversation_assignment_events.event_kind = 'reassignment')",
      "COUNT(*) FILTER (WHERE conversation_assignment_events.routing ->> 'assignment_rule' = 'response-timeout')"
    )
  end

  def message_columns
    sql_columns('COUNT(*)', 'COUNT(DISTINCT messages.conversation_id)')
  end

  def sql_columns(*sql)
    sql.map { |column| Arel.sql(column) }
  end
end
