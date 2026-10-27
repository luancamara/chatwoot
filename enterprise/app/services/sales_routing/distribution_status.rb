# Live state of a store-routing inbox for the manager panel: who is waiting and why each seller is or is not getting new
# leads. Statuses follow the assignment filters in order: store team, team auto-assign, online, capacity, hourly limit.
class SalesRouting::DistributionStatus
  pattr_initialize [:inbox!]

  def build
    { id: inbox.id, name: inbox.name, working_now: inbox.working_now?,
      assignment_limit: policy.fair_distribution_limit, assignment_window_seconds: policy.fair_distribution_window,
      queue: queue, in_progress: open.where.not(assignee_id: nil).count, agents: agents }
  end

  private

  def queue
    oldest = Arel.sql('MIN(COALESCE(conversations.waiting_since, conversations.created_at))')
    by_store = open.unassigned.group(:team_id).pluck(:team_id, Arel.sql('COUNT(*)'), oldest)
                   .group_by { |team_id, _count, _oldest| configuration.store_for_team(team_id) }
                   .map do |store, rows|
                     { store: store, name: store && configuration.team_for(store).name, count: rows.sum(&:second),
                       oldest_waiting_since: rows.map(&:third).min.iso8601 }
                   end
    { total: by_store.sum { |row| row[:count] }, oldest_waiting_since: by_store.pluck(:oldest_waiting_since).min, by_store: by_store }
  end

  def agents
    User.where(id: seller_ids).map { |user| agent(user) }.sort_by { |row| -row[:open] }
  end

  def agent(user)
    id = user.id
    team = store_teams[id]
    row = { id: id, name: user.name, store: team && configuration.store_for_team(team.id), store_name: team&.name,
            availability: availability.fetch(id.to_s, 'offline'), open: open_counts.fetch(id, 0), capacity_limit: capacity_limits[id],
            awaiting_reply: awaiting_counts.fetch(id, 0),
            recent_assignments: AutoAssignment::RateLimiter.new(inbox: inbox, agent: user).current_count }
    row.merge(status: status(row, team, online_ids.include?(id)))
  end

  def status(row, team, online)
    return 'no_store' unless team
    return 'store_paused' unless team.allow_auto_assign?
    return 'offline' unless online
    return 'at_capacity' if row[:capacity_limit] && row[:open] >= row[:capacity_limit]
    return 'hourly_limit' if row[:recent_assignments] >= policy.fair_distribution_limit

    'receiving'
  end

  def configuration
    @configuration ||= SalesRouting::Configuration.new(inbox: inbox)
  end

  def policy
    inbox.assignment_policy
  end

  def open
    inbox.conversations.open
  end

  def store_teams
    @store_teams ||= configuration.teams.values.flat_map { |team| team.members.map { |member| [member.id, team] } }.to_h
  end

  def seller_ids
    @seller_ids ||= configuration.seller_ids
  end

  def open_counts
    @open_counts ||= open.where(assignee_id: seller_ids).group(:assignee_id).count
  end

  def awaiting_counts
    @awaiting_counts ||= open.where(assignee_id: seller_ids).where.not(waiting_since: nil).group(:assignee_id).count
  end

  def online_ids
    @online_ids ||= inbox.available_agents.pluck(:user_id)
  end

  def availability
    @availability ||= OnlineStatusTracker.get_available_users(inbox.account_id)
  end

  # Capacity is only enforced with advanced assignment (Enterprise::AutoAssignment::CapacityService).
  def capacity_limits
    @capacity_limits ||= if inbox.account.feature_enabled?('advanced_assignment')
                           InboxCapacityLimit.where(inbox: inbox).joins(agent_capacity_policy: :account_users)
                                             .where(account_users: { account_id: inbox.account_id, user_id: seller_ids })
                                             .pluck('account_users.user_id', :conversation_limit).to_h
                         else
                           {}
                         end
  end
end
