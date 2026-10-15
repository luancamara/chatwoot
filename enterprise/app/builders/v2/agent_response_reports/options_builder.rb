# Filter choices for the agent response dashboard. Stores are the routing stores (the historical store filter); each
# agent also lists the stores of their current teams, which callers may use to offer a current roster.
class V2::AgentResponseReports::OptionsBuilder
  pattr_initialize [:filters!]
  delegate :account, :stores, to: :filters

  def build
    { inboxes: inboxes, stores: store_options, agents: agents }
  end

  private

  def inboxes
    account.inboxes.order(:name).pluck(:id, :name, :response_attempts_tracked_since).map do |id, name, tracked_since|
      { id: id, name: name, monitored: tracked_since.present? }
    end
  end

  def store_options
    stores.map { |code, store| { code: code, team_id: store.fetch('team_id'), name: teams[store.fetch('team_id')]&.name } }
  end

  def agents
    account.users.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name, store_codes: current_stores[id] } }
  end

  def current_stores
    @current_stores ||= stores.each_with_object(Hash.new { |hash, id| hash[id] = [] }) do |(code, store), by_agent|
      teams[store.fetch('team_id')]&.members&.each { |member| by_agent[member.id] << code }
    end
  end

  def teams
    @teams ||= account.teams.where(id: stores.values.map { |store| store.fetch('team_id') }).includes(:members).index_by(&:id)
  end
end
