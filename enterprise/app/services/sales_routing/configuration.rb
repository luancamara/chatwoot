class SalesRouting::Configuration
  pattr_initialize [:inbox!]

  def enabled?
    settings.present? && settings.fetch('inbox_ids').include?(inbox.id)
  end

  def stores
    settings.fetch('stores')
  end

  def teams
    @teams ||= inbox.account.teams.where(id: stores.values.map { |store| store.fetch('team_id') }).includes(:members).index_by(&:id)
  end

  def store_for_team(team_id)
    stores.find { |_code, store| store.fetch('team_id') == team_id }&.first
  end

  def team_for(store)
    teams.fetch(stores.fetch(store).fetch('team_id'))
  end

  def member_ids
    memberships = stores.keys.flat_map { |store| team_for(store).members.map(&:id) }
    duplicates = memberships.tally.select { |_id, count| count > 1 }.keys
    raise 'A seller belongs to more than one store team' if duplicates.intersect?(seller_ids)

    memberships.uniq
  end

  def seller_ids
    inbox.account.account_users.where(custom_role_id: inbox.assignment_policy.eligible_custom_role_id).pluck(:user_id)
  end

  def response_owner?(conversation)
    return false unless conversation.open? && conversation.assignee_id && conversation.assignee_agent_bot_id.nil?
    return false unless store_for_team(conversation.team_id)

    team = teams.fetch(conversation.team_id)
    eligible_ids = team.members.map(&:id) & seller_ids
    team.allow_auto_assign? && eligible_ids.include?(conversation.assignee_id)
  end

  private

  def settings
    @settings ||= inbox.account.internal_attributes['store_routing']
  end
end
