# Agent response dashboard: deadline compliance, reply speed after receiving the conversation, authored messages and
# unique conversations versus assignment events. Metrics without data coverage are nil (unavailable), never zero.
class V2::AgentResponseReports::SummaryBuilder
  include V2::AgentResponseReports::Metrics

  pattr_initialize [:filters!]
  delegate :account, to: :filters

  def build
    { generated_at: filters.now.iso8601, range: filters.payload, coverage: coverage, summary: summary,
      agents: agents, trend: trend, heatmap: heatmap, options: V2::AgentResponseReports::OptionsBuilder.new(filters: filters).build }
  end

  private

  # Explicit coverage so the dashboard can tell "no misses" from "not recorded": deadline history exists only inside
  # tracking periods, assignment history only for ledger inboxes.
  def coverage
    {
      response_attempts: deadline_coverage,
      assignments: { available: filters.assignments_available?, complete: (filters.inbox_ids - filters.ledger_inbox_ids).empty?,
                     inbox_ids: filters.ledger_inbox_ids, since: filters.assignments_since&.iso8601 },
      origin_store: filters.unattributed_origins
    }
  end

  def deadline_coverage
    periods = filters.tracking_periods.map do |period|
      { inbox_id: period.inbox_id, started_at: period.started_at.iso8601, ended_at: period.ended_at&.iso8601 }
    end
    { available: filters.deadline_available?, complete: filters.deadline_complete?, periods: periods,
      unmonitored_inbox_ids: filters.unmonitored_inbox_ids, monitoring_inbox_ids: filters.monitoring_inbox_ids }
  end

  def summary
    received, *assignment_values = aggregate(filters.assignment_events, assignment_columns)
    sent, handled = aggregate(filters.agent_messages, message_columns)

    deadline_summary.merge(
      conversations: { received: (received if filters.assignments_available?), handled: handled,
                       resolved: filters.resolutions.distinct.count(:conversation_id) },
      assignments: assignments(*assignment_values),
      messages: messages(sent, handled, total_customer_messages)
    )
  end

  def deadline_summary
    values = aggregate(filters.attempts, deadline_columns + response_columns + wait_columns)
    { deadline: deadline(values.first(6)), response_time: duration(*values[6, 3]), customer_wait: duration(*values[9, 3]) }
  end

  def agents
    rows = agent_rows
    names = account.users.where(id: rows.keys).pluck(:id, :name).to_h
    rows.values.map { |row| agent_row(row, names[row[:id]]) }.sort_by { |row| [row[:name].to_s.downcase, row[:id]] }
  end

  # Selected agents appear even without activity, so a quiet seller shows as zero instead of disappearing.
  def agent_rows
    rows = Hash.new { |hash, id| hash[id] = empty_agent_row(id) }
    merge_agent_deadlines(rows)
    merge_agent_assignments(rows)
    merge_agent_messages(rows)
    filters.resolutions.group(:user_id).distinct.count(:conversation_id).each { |id, resolved| rows[id][:resolved] = resolved }
    filters.agent_ids&.each { |id| rows[id] }
    rows
  end

  def empty_agent_row(id)
    { id: id, deadline: deadline([0] * 6), response_time: duration(0, nil, nil), received: 0, assignments: assignments(0, 0, 0),
      handled: 0, resolved: 0, messages: messages(0, 0, 0) }
  end

  def merge_agent_deadlines(rows)
    filters.attempts.group(:assignee_id).pluck(:assignee_id, *deadline_columns, *response_columns).each do |id, *values|
      rows[id].merge!(deadline: deadline(values.first(6)), response_time: duration(*values.last(3)))
    end
  end

  def merge_agent_assignments(rows)
    filters.assignment_events.group(:agent_id).pluck(:agent_id, *assignment_columns).each do |id, received, *values|
      rows[id].merge!(received: received, assignments: assignments(*values))
    end
  end

  def merge_agent_messages(rows)
    filters.agent_messages.group(:sender_id).pluck(:sender_id, *message_columns).each do |id, sent, handled|
      rows[id].merge!(handled: handled, messages: messages(sent, handled, agent_customer_messages[id]))
    end
  end

  def agent_row(row, name)
    conversations = { received: (row[:received] if filters.assignments_available?), handled: row[:handled], resolved: row[:resolved] }
    row.except(:received, :handled, :resolved).merge(name: name, conversations: conversations)
  end

  # Customer volume inside the conversations each agent handled in the period.
  def agent_customer_messages
    @agent_customer_messages ||= begin
      handled = filters.agent_messages.select('DISTINCT messages.sender_id AS agent_id, messages.conversation_id')
      filters.customer_messages.joins("INNER JOIN (#{handled.to_sql}) handled ON handled.conversation_id = messages.conversation_id")
             .group('handled.agent_id').count
    end
  end

  def total_customer_messages
    filters.customer_messages.where(conversation_id: filters.agent_messages.select(:conversation_id)).count
  end

  # Days without collection are nil, not zero.
  def trend
    met, breached = %w[met breached].map { |outcome| daily_outcome(outcome) }
    received = daily(filters.assignment_events, 'assigned_at', distinct: true)
    handled = daily(filters.agent_messages, 'created_at', distinct: true)

    filters.dates.map do |date|
      deadline = filters.day_tracked?(date)
      assigned = filters.assignments_day?(date)
      { date: date.iso8601, met: (met.fetch(date, 0) if deadline), breached: (breached.fetch(date, 0) if deadline),
        received: (received.fetch(date, 0) if assigned), handled: handled.fetch(date, 0) }
    end
  end

  def daily_outcome(outcome)
    daily(filters.attempts.where("#{filters.effective_outcome_sql} = ?", outcome), 'started_at')
  end

  def daily(scope, column, distinct: false)
    grouped = scope.group(Arel.sql("DATE(#{filters.local_time_sql("#{scope.table_name}.#{column}")})"))
    distinct ? grouped.distinct.count(:conversation_id) : grouped.count
  end

  # Breaches by weekday (0 = Sunday) and hour of the deadline, in the requested timezone; nil when not recorded.
  def heatmap
    return unless filters.deadline_available?

    local_due = filters.local_time_sql('conversation_response_attempts.due_at')
    filters.attempts.where("#{filters.effective_outcome_sql} = 'breached'")
           .group(Arel.sql("EXTRACT(DOW FROM #{local_due})::integer"), Arel.sql("EXTRACT(HOUR FROM #{local_due})::integer"))
           .count.map { |(weekday, hour), breached| { weekday: weekday, hour: hour, breached: breached } }
           .sort_by { |cell| [cell[:weekday], cell[:hour]] }
  end
end
