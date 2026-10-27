require 'rails_helper'

RSpec.describe SalesRouting::DistributionStatus do
  let(:account) { create(:account) }
  let(:role) { create(:custom_role, account: account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:team) { create(:team, account: account) }
  let(:policy) do
    create(:assignment_policy, account: account, eligible_custom_role: role, fair_distribution_limit: 2, fair_distribution_window: 3600)
  end
  let(:receiving) { create(:user, account: account, role: :agent) }
  let(:full) { create(:user, account: account, role: :agent) }
  let(:busy) { create(:user, account: account, role: :agent) }
  let(:away) { create(:user, account: account, role: :agent) }
  let(:loose) { create(:user, account: account, role: :agent) }

  before do
    account.enable_features!('assignment_v2', 'advanced_assignment')
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    capacity = create(:agent_capacity_policy, account: account)
    create(:inbox_capacity_limit, inbox: inbox, agent_capacity_policy: capacity, conversation_limit: 1)
    [receiving, full, busy, away, loose].each do |user|
      create(:inbox_member, inbox: inbox, user: user)
      user.account_users.find_by!(account: account).update!(custom_role: role, agent_capacity_policy: capacity)
    end
    [receiving, full, busy, away].each { |user| create(:team_member, team: team, user: user) }
    account.update!(internal_attributes: { store_routing: { inbox_ids: [inbox.id], stores: { psd: { team_id: team.id, label: 'loja-psd' } } } })
    online = [receiving, full, busy, loose].index_with { 'online' }.transform_keys { |user| user.id.to_s }
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(online)
  end

  it 'reports the queue per store and the first reason each seller is not receiving leads' do
    held = create(:conversation, account: account, inbox: inbox, assignee: full, team: team)
    2.times { AutoAssignment::RateLimiter.new(inbox: inbox, agent: busy).track_assignment(held) }
    create(:conversation, account: account, inbox: inbox, team: team)
    create(:conversation, account: account, inbox: inbox)

    status = described_class.new(inbox: inbox).build

    expect(status).to include(in_progress: 1, assignment_limit: 2, assignment_window_seconds: 3600)
    expect(status[:queue][:total]).to eq(2)
    expect(status[:queue][:by_store].map { |row| row.slice(:store, :name, :count) })
      .to contain_exactly({ store: 'psd', name: team.name, count: 1 }, { store: nil, name: nil, count: 1 })
    expect(status[:agents].to_h { |row| [row[:id], row[:status]] }).to eq(
      full.id => 'at_capacity', receiving.id => 'receiving', busy.id => 'hourly_limit', away.id => 'offline', loose.id => 'no_store'
    )
    expect(status[:agents].first).to include(id: full.id, open: 1, capacity_limit: 1, awaiting_reply: 1, store: 'psd')
  end
end
