# Paginated drilldown behind each card, chart and agent row of the agent response summary, using the same filters.
class V2::AgentResponseReports::DetailsBuilder
  ATTEMPT_OUTCOMES = ConversationResponseAttempt::OUTCOMES
  CONVERSATION_METRICS = %w[received handled resolved].freeze

  pattr_initialize [:filters!, :kind!, :metric, :page!, :per_page!]
  delegate :account, to: :filters

  def build
    kind == 'attempts' ? attempts : conversations
  end

  private

  def attempts
    scope = filters.attempts
    scope = scope.where("#{filters.effective_outcome_sql} = ?", metric) if metric
    rows = scope.select('conversation_response_attempts.*', "#{filters.effective_outcome_sql} AS effective_outcome")
                .order(started_at: :desc, id: :desc).offset(offset).limit(per_page).to_a
    names = user_names(rows.flat_map { |row| [row.assignee_id, row.responder_id] })

    { meta: meta(scope.count), payload: rows.map { |row| attempt_payload(row, names) } }
  end

  def attempt_payload(row, names)
    times = %i[waiting_since started_at due_at ended_at replied_at].index_with { |field| row[field]&.iso8601 }
    {
      id: row.id, conversation_display_id: row.conversation_display_id, conversation_url: conversation_url(row.conversation_display_id),
      inbox_id: row.inbox_id, agent: { id: row.assignee_id, name: names[row.assignee_id] }, response_kind: row.response_kind,
      outcome: row.effective_outcome, end_reason: row.end_reason, response_seconds: row.response_seconds, wait_seconds: row.wait_seconds,
      responder: row.responder_id && { id: row.responder_id, name: names[row.responder_id] }
    }.merge(times)
  end

  # One row per conversation and agent: when it entered the metric in the period, plus the period's message volume.
  def conversations
    rows = conversation_scope.klass.unscoped.from(conversation_scope, :grouped_rows)
    page = rows.order('grouped_rows.occurred_at DESC, grouped_rows.conversation_id DESC, grouped_rows.agent_id DESC')
               .offset(offset).limit(per_page).pluck('grouped_rows.conversation_id', 'grouped_rows.agent_id', 'grouped_rows.occurred_at')
    { meta: meta(rows.count), payload: conversation_rows(page) }
  end

  def conversation_scope
    case metric
    when 'received'
      filters.assignment_events.group(:conversation_id, :agent_id)
             .select('conversation_id, agent_id, MIN(conversation_assignment_events.assigned_at) AS occurred_at')
    when 'handled'
      filters.agent_messages.group(:conversation_id, :sender_id)
             .select('messages.conversation_id, messages.sender_id AS agent_id, MIN(messages.created_at) AS occurred_at')
    else
      filters.resolutions.group(:conversation_id, :user_id)
             .select('conversation_id, user_id AS agent_id, MAX(reporting_events.created_at) AS occurred_at')
    end
  end

  def conversation_rows(page)
    ids = page.map(&:first)
    conversations = Conversation.where(account_id: account.id, id: ids).pluck(:id, :display_id, :inbox_id).to_h { |id, *rest| [id, rest] }
    sent, received = message_counts(ids)
    names = user_names(page.map(&:second))

    page.map do |conversation_id, agent_id, occurred_at|
      display_id, inbox_id = conversations[conversation_id]
      { conversation_display_id: display_id, conversation_url: (conversation_url(display_id) if display_id), inbox_id: inbox_id,
        agent: { id: agent_id, name: names[agent_id] }, occurred_at: occurred_at.iso8601,
        agent_messages: sent.fetch([conversation_id, agent_id], 0), customer_messages: received.fetch(conversation_id, 0) }
    end
  end

  def message_counts(ids)
    [filters.agent_messages.where(conversation_id: ids).group(:conversation_id, :sender_id).count,
     filters.customer_messages.where(conversation_id: ids).group(:conversation_id).count]
  end

  def user_names(ids)
    account.users.where(id: ids.compact.uniq).pluck(:id, :name).to_h
  end

  def conversation_url(display_id)
    Rails.application.routes.url_helpers.app_account_conversation_url(account_id: account.id, id: display_id)
  end

  def offset
    (page - 1) * per_page
  end

  def meta(total)
    { kind: kind, metric: metric, page: page, per_page: per_page, total: total, range: filters.payload }
  end
end
