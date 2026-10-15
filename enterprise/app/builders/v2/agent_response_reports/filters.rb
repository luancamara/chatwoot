# Validated filters shared by the agent response summary and its drilldowns, so cards, charts and detail lists always
# read the same rows.
#
# "Store" means the conversation's ORIGIN store in every section: the store the customer was first routed to
# (SalesRouting::Classifier.origin_store). It survives manual team transfers, fallback sellers from other stores and
# sellers changing teams. Conversations whose origin is unknown (re-routed by hand before origins were kept) or that had
# no store signal are left out of any store filter and counted in coverage instead of being guessed.
class V2::AgentResponseReports::Filters
  class Invalid < StandardError; end

  MAX_DAYS = 93
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  ID_FORMAT = /\A[1-9]\d*\z/
  ROUTE_SQL = "store_conversations.additional_attributes -> 'store_routing'".freeze
  # SQL twin of SalesRouting::Classifier.origin_store; NULL when unknown or without store signal.
  ORIGIN_STORE_SQL = "(CASE WHEN #{ROUTE_SQL} -> 'origin_store' IS NOT NULL THEN #{ROUTE_SQL} ->> 'origin_store' " \
                     "WHEN #{ROUTE_SQL} ->> 'rule' IS DISTINCT FROM 'manual-team' THEN #{ROUTE_SQL} ->> 'store' END)".freeze
  STORE_SQL = 'EXISTS (SELECT 1 FROM conversations store_conversations WHERE store_conversations.id = %<column>s ' \
              "AND #{ORIGIN_STORE_SQL} IN (?))".freeze

  attr_reader :account, :since, :until, :timezone, :range, :now, :store_codes

  # Reads raw request params on purpose: a malformed list must be rejected, not silently dropped into "everything".
  def initialize(account:, params:)
    @account = account
    @now = Time.current
    parse_period(params)
    @requested_inbox_ids = account_ids(params[:inbox_ids], account.inboxes, 'inbox_ids')
    @store_codes = store_codes_param(params[:store_codes])
    # Ids that are not users of this account match nothing, so a stale selection is empty instead of an error (and
    # never everyone).
    @agent_ids = account.users.where(id: id_list(params[:agent_ids], 'agent_ids')).pluck(:id) unless params[:agent_ids].nil?
  end

  # nil means every agent; an empty array means a selection that matches nobody.
  attr_reader :agent_ids

  def inbox_ids
    @inbox_ids ||= @requested_inbox_ids || account.inboxes.pluck(:id)
  end

  def stores
    account.internal_attributes.dig('store_routing', 'stores') || {}
  end

  # --- coverage -----------------------------------------------------------------------------------------------------

  # Spans in which deadline history was collected for the selected inboxes during the period.
  def tracking_periods
    @tracking_periods ||= ResponseTrackingPeriod.where(account_id: account.id, inbox_id: inbox_ids).overlapping(range)
                                                .order(:inbox_id, :started_at).to_a
  end

  def deadline_available?
    tracking_periods.any?
  end

  # Complete only when every selected inbox was collected without gaps from the start of the period until its end (or
  # now), and the ones still collecting are actually monitoring.
  def deadline_complete?
    inbox_ids.all? do |inbox_id|
      periods = tracking_periods.select { |period| period.inbox_id == inbox_id }
      periods.any? && covered_until(periods) >= [range.end, now].min &&
        (periods.last.ended_at.present? || monitoring_inbox_ids.include?(inbox_id))
    end
  end

  def unmonitored_inbox_ids
    inbox_ids - tracking_periods.map(&:inbox_id)
  end

  def monitoring_inbox_ids
    @monitoring_inbox_ids ||= account.inboxes.where(id: inbox_ids).where.not(response_attempts_tracked_since: nil)
                                     .select(&:response_reassignment_active?).map(&:id)
  end

  def day_tracked?(date)
    day = timezone.local(date.year, date.month, date.day)...day_end(date)
    tracking_periods.any? { |period| period.started_at < day.end && (period.ended_at.nil? || period.ended_at > day.begin) }
  end

  def ledger_inbox_ids
    @ledger_inbox_ids ||= inbox_ids & Array(account.internal_attributes.dig('assignment_ledger', 'inbox_ids'))
  end

  def assignments_available?
    ledger_inbox_ids.any?
  end

  def assignments_since
    return unless assignments_available?

    @assignments_since ||= ConversationAssignmentEvent.where(account_id: account.id, inbox_id: ledger_inbox_ids).minimum(:assigned_at)
  end

  # Days before the first ledger event of the selected inboxes have no assignment history.
  def assignments_day?(date)
    assignments_since.present? && day_end(date) > assignments_since
  end

  # Conversations of the period that a store filter leaves out because their origin store is not known: `unknown` were
  # re-routed by hand before origins were kept, `without_store` never had a store (no signal or not store-routed).
  def unattributed_origins
    return unless store_codes

    every_store = dup.tap { |filters| filters.store_codes = nil }
    Conversation.from('conversations store_conversations')
                .where('store_conversations.id IN (?) OR store_conversations.id IN (?)',
                       every_store.attempts.select(:conversation_id), every_store.agent_messages.select(:conversation_id))
                .where("#{ORIGIN_STORE_SQL} IS NULL")
                .group(Arel.sql("CASE WHEN #{ROUTE_SQL} ->> 'rule' = 'manual-team' THEN 'unknown' ELSE 'without_store' END"))
                .count
  end

  # --- scopes -------------------------------------------------------------------------------------------------------

  # Every recorded window counts; coverage gaps are reported separately instead of hiding evidence.
  def attempts
    scope = ConversationResponseAttempt.where(account_id: account.id, inbox_id: inbox_ids, started_at: range)
    scope = scope.where(store_code: store_codes) if store_codes
    with_agents(scope, :assignee_id)
  end

  # Authored human replies: public outgoing messages sent by a user, excluding automation, campaigns and forwards.
  def agent_messages
    scope = Message.outgoing.not_forwarded
                   .where(account_id: account.id, inbox_id: inbox_ids, created_at: range, private: false, sender_type: 'User')
                   .where("(messages.additional_attributes -> 'campaign_id') IS NULL")
                   .where("((messages.content_attributes #>> '{}')::jsonb ->> 'automation_rule_id') IS NULL").unscope(:order)
    with_agents(with_store(scope, 'messages.conversation_id'), :sender_id)
  end

  def customer_messages
    scope = Message.incoming.where(account_id: account.id, inbox_id: inbox_ids, created_at: range, private: false).unscope(:order)
    with_store(scope, 'messages.conversation_id')
  end

  def assignment_events
    scope = ConversationAssignmentEvent.where(account_id: account.id, inbox_id: ledger_inbox_ids, assigned_at: range)
    scope = with_store(scope, 'conversation_assignment_events.conversation_id')
    with_agents(scope, :agent_id)
  end

  # Native resolution events credit the assignee at the moment of resolution.
  def resolutions
    scope = ReportingEvent.where(account_id: account.id, inbox_id: inbox_ids, name: 'conversation_resolved', created_at: range)
                          .where.not(user_id: nil)
    with_agents(with_store(scope, 'reporting_events.conversation_id'), :user_id)
  end

  # Overdue windows count as breached as soon as the deadline passes, before the deadline job records it, but only
  # while the live timer still exists: an open row without a timer has no verdict.
  def effective_outcome_sql
    ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, { now: now }])
      CASE WHEN conversation_response_attempts.outcome <> 'pending' THEN conversation_response_attempts.outcome
      WHEN NOT EXISTS (SELECT 1 FROM conversation_response_timers live_timers
                       WHERE live_timers.conversation_id = conversation_response_attempts.conversation_id) THEN 'canceled'
      WHEN conversation_response_attempts.due_at <= :now THEN 'breached' ELSE 'pending' END
    SQL
  end

  def local_time_sql(column)
    "((#{column} AT TIME ZONE 'UTC') AT TIME ZONE #{ActiveRecord::Base.connection.quote(timezone.tzinfo.name)})"
  end

  def dates
    (since..self.until).to_a
  end

  def day_end(date)
    timezone.local(date.year, date.month, date.day) + 1.day
  end

  def payload
    { since: since.iso8601, until: self.until.iso8601, timezone: timezone.tzinfo.name }
  end

  protected

  attr_writer :store_codes

  private

  def parse_period(params)
    @timezone = ActiveSupport::TimeZone[params[:timezone].to_s] if params[:timezone].is_a?(String)
    raise Invalid, I18n.t('errors.agent_response_reports.invalid_timezone') unless @timezone

    @since = parse_date(params[:since], 'since')
    @until = parse_date(params[:until], 'until')
    raise Invalid, I18n.t('errors.agent_response_reports.inverted_range') if @until < @since
    raise Invalid, I18n.t('errors.agent_response_reports.range_too_long', days: MAX_DAYS) if (@until - @since).to_i >= MAX_DAYS

    @range = timezone.local(@since.year, @since.month, @since.day)...day_end(@until)
  end

  def parse_date(value, name)
    raise Invalid, I18n.t('errors.agent_response_reports.invalid_date', field: name) unless value.is_a?(String) && value.match?(DATE_FORMAT)

    Date.iso8601(value)
  rescue Date::Error
    raise Invalid, I18n.t('errors.agent_response_reports.invalid_date', field: name)
  end

  def account_ids(values, relation, name)
    return if values.nil?

    ids = id_list(values, name)
    raise Invalid, I18n.t('errors.agent_response_reports.foreign_ids', field: name) unless relation.where(id: ids).count == ids.size

    ids
  end

  def id_list(values, name)
    valid = values.is_a?(Array) && values.any? && values.all? { |id| id.is_a?(String) && id.match?(ID_FORMAT) }
    raise Invalid, I18n.t('errors.agent_response_reports.invalid_ids', field: name) unless valid

    values.map(&:to_i).uniq
  end

  def store_codes_param(values)
    return if values.nil?

    valid = values.is_a?(Array) && values.any? && values.all?(String)
    raise Invalid, I18n.t('errors.agent_response_reports.invalid_ids', field: 'store_codes') unless valid
    raise Invalid, I18n.t('errors.agent_response_reports.foreign_ids', field: 'store_codes') unless (values - stores.keys).empty?

    values.uniq
  end

  # How far the sorted periods cover the period without a gap from its start.
  def covered_until(periods)
    periods.reduce(range.begin) do |cursor, period|
      period.started_at <= cursor ? [cursor, period.ended_at || now].max : cursor
    end
  end

  def with_store(scope, column)
    store_codes ? scope.where(format(STORE_SQL, column: column), store_codes) : scope
  end

  def with_agents(scope, column)
    agent_ids.nil? ? scope : scope.where(column => agent_ids)
  end
end
