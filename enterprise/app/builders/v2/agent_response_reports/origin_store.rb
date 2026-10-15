# The origin-store rule of SalesRouting::Classifier.origin_store in SQL, for the store filter and its coverage note.
class V2::AgentResponseReports::OriginStore
  CONVERSATION_ROUTE = "store_conversations.additional_attributes -> 'store_routing'".freeze
  LEDGER_ROUTE = 'conversation_assignment_events.routing'.freeze

  # Origin of a store_routing jsonb; NULL when unknown or without store signal.
  def self.sql(route)
    "(CASE WHEN #{route} -> 'origin_store' IS NOT NULL THEN #{route} ->> 'origin_store' " \
      "WHEN #{route} ->> 'rule' IS DISTINCT FROM 'manual-team' THEN #{route} ->> 'store' END)"
  end

  # Why a route has no origin: `unknown` when it was re-routed by hand before origins were kept (no origin_store key),
  # `without_store` when the lead never had a store (explicit null origin, no signal, or not store-routed).
  def self.missing_sql(route)
    "(CASE WHEN #{route} -> 'origin_store' IS NULL AND #{route} ->> 'rule' = 'manual-team' THEN 'unknown' ELSE 'without_store' END)"
  end

  LIVE_SQL = 'EXISTS (SELECT 1 FROM conversations live_conversations WHERE live_conversations.id = %<column>s)'.freeze
  STORE_SQL = 'EXISTS (SELECT 1 FROM conversations store_conversations WHERE store_conversations.id = %<column>s ' \
              "AND #{sql(CONVERSATION_ROUTE)} IN (?))".freeze

  # `filters` must have no store filter: these are the rows a store filter would leave out.
  pattr_initialize [:filters!]

  # `unknown` / `without_store` for live conversations; `deleted_unknown` for deleted ones whose kept history (ledger
  # event, deadline window) does not prove a store either.
  def unattributed
    live = Conversation.from('conversations store_conversations')
                       .where('store_conversations.id IN (?) OR store_conversations.id IN (?) OR store_conversations.id IN (?)',
                              filters.attempts.select(:conversation_id), filters.agent_messages.select(:conversation_id),
                              filters.assignment_events.select(:conversation_id))
                       .where("#{self.class.sql(CONVERSATION_ROUTE)} IS NULL")
                       .group(Arel.sql(self.class.missing_sql(CONVERSATION_ROUTE))).count
    { unknown: live.fetch('unknown', 0), without_store: live.fetch('without_store', 0), deleted_unknown: deleted_without_origin }
  end

  private

  def deleted_without_origin
    attempts = filters.attempts.where.not(format(LIVE_SQL, column: 'conversation_response_attempts.conversation_id'))
                      .where(store_code: nil).distinct.pluck(:conversation_id)
    events = filters.assignment_events.where.not(format(LIVE_SQL, column: 'conversation_assignment_events.conversation_id'))
                    .where("#{self.class.sql(LEDGER_ROUTE)} IS NULL").distinct.pluck(:conversation_id)
    (attempts | events).size
  end
end
