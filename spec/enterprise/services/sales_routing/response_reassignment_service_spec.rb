require 'rails_helper'

RSpec.describe SalesRouting::ResponseReassignmentService do
  let(:account) { create(:account) }
  let(:role) { create(:custom_role, account: account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true, timezone: 'America/Sao_Paulo', working_hours_enabled: true) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:replacement) { create(:user, account: account, role: :agent) }
  let(:other_store_seller) { create(:user, account: account, role: :agent) }
  let(:manager) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:policy) do
    create(:assignment_policy, account: account, eligible_custom_role: role, assignment_order: :balanced,
                               business_hours_only: true, fair_distribution_limit: 10, fair_distribution_window: 3600)
  end
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, assignee: seller, team: team,
                          additional_attributes: { store_routing: { store: 'psd', rule: 'codigo' } })
  end
  let(:message) { create(:message, account: account, conversation: conversation, content: '[PSD]') }
  let(:watch) { ConversationResponseTimer.find_by!(conversation_id: conversation.id) }
  let(:timeout) { ConversationResponseTimer::TIMEOUT }

  before do
    travel_to Time.utc(2026, 10, 12, 15)
    account.enable_features!('assignment_v2', 'advanced_assignment')
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    [seller, replacement, other_store_seller].each do |user|
      create(:inbox_member, inbox: inbox, user: user)
      user.account_users.find_by!(account: account).update!(custom_role: role)
    end
    create(:team_member, team: team, user: seller)
    create(:team_member, team: team, user: replacement)
    create(:team_member, team: other_team, user: other_store_seller)
    account.update!(internal_attributes: { store_routing: { inbox_ids: [inbox.id], stores: {
                      psd: { team_id: team.id, label: 'loja-psd' }, lap: { team_id: other_team.id, label: 'loja-lap' }
                    } }, assignment_ledger: { inbox_ids: [inbox.id] } })
    inbox.update!(response_reassignment_mode: 'first_response', response_reassignment_notify_user: manager)
    online = [seller, replacement, other_store_seller].index_with { 'online' }.transform_keys { |user| user.id.to_s }
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(online)
  end

  it 'gives the first assigned seller the full deadline and records the transfer in Hermes with automatic provenance' do
    message
    timer_id = watch.id
    travel timeout - 1.second
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(seller)
    travel 1.second
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(replacement)
    event = conversation.conversation_assignment_events.last
    expect(event).to have_attributes(source: 'automatic', event_kind: 'reassignment')
    expect(event.routing['assignment_rule']).to eq('response-timeout')
    expect(Notification.where(user: manager, notification_type: :sla_missed_first_response).count).to eq(1)
    expect(AutoAssignment::RateLimiter.new(inbox: inbox, agent: replacement).current_count).to eq(1)
  end

  it 'starts the deadline at assignment when the customer waited unassigned' do
    conversation.update!(assignee: nil)
    message
    expect(watch.due_at).to be_nil
    travel 2.minutes
    AutoAssignment::AssignmentService.new(inbox: inbox).perform_bulk_assignment
    expect(watch.reload.due_at).to eq(timeout.from_now)
  end

  it 'supplies the policy context expected by notification payloads and email templates' do
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    notification = Notification.find_by!(user: manager, notification_type: :sla_missed_first_response)
    expect(notification.secondary_actor).to eq(policy)
    expect(notification.push_event_data[:secondary_actor]).to include(name: policy.name)
    template = Liquid::Template.parse('{{ sla_policy.name }}')
    expect(template.render('sla_policy' => notification.secondary_actor.to_drop)).to eq(policy.name)
  end

  it 'ignores views, private notes and automated replies, without restarting for additional customer messages' do
    message
    original_due = watch.due_at
    conversation.update!(agent_last_seen_at: Time.current)
    create(:message, account: account, conversation: conversation, sender: seller, message_type: :outgoing, private: true)
    create(:message, account: account, conversation: conversation, sender: seller, message_type: :outgoing,
                     content_attributes: { automation_rule_id: 1 })
    travel timeout - 1.minute
    create(:message, account: account, conversation: conversation)
    expect(watch.reload.due_at).to eq(original_due)
    travel 1.minute
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(replacement)
  end

  it 'cancels a stale job after a human reply and never rearms first-response mode for later interactions' do
    message
    timer_id = watch.id
    create(:message, account: account, conversation: conversation, sender: seller, message_type: :outgoing)
    # Native reporting metadata may lag or have been backfilled independently; use actual human replies too.
    conversation.update!(first_reply_created_at: nil)
    create(:message, account: account, conversation: conversation)
    travel timeout + 1.minute
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(seller)
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
    conversation.update!(assignee: nil)
    AutoAssignment::AssignmentService.new(inbox: inbox).perform_bulk_assignment
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
  end

  it 'starts and closes a new cycle for later interactions when all responses are enabled' do
    inbox.update!(response_reassignment_mode: 'all_responses')
    message
    create(:message, account: account, conversation: conversation, sender: seller, message_type: :outgoing)
    create(:message, account: account, conversation: conversation)
    expect(watch.response_kind).to eq('next_response')
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(replacement)
    expect(Notification.where(user: manager, notification_type: :sla_missed_next_response).count).to eq(1)
    create(:message, account: account, conversation: conversation, sender: replacement, message_type: :outgoing)
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
  end

  it 'keeps the current owner and alerts once when nobody else in that team is online' do
    message
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id)
                                                               .and_return(seller.id.to_s => 'online', other_store_seller.id.to_s => 'online')
    travel timeout
    2.times { SalesRouting::ReassignResponseJob.perform_now(watch.id) }
    expect(conversation.reload.assignee).to eq(seller)
    expect(Notification.where(user: manager, notification_type: :sla_missed_first_response).count).to eq(1)
  end

  it 'returns a lead that fell back to another store to its own store at the deadline' do
    # The automatic fallback keeps the lead's store; only a manual team change rewrites it.
    Current.executed_by = policy
    fallback = create(:conversation, account: account, inbox: inbox, assignee: other_store_seller, team: other_team,
                                     additional_attributes: { store_routing: { store: 'psd', rule: 'campanha-meta', assignment_rule: 'fallback-geral' } })
    Current.reset
    create(:message, account: account, conversation: fallback)
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(fallback.conversation_response_timer.id)
    fallback.reload
    expect(fallback.team).to eq(team)
    expect(team.members).to include(fallback.assignee)
    expect(fallback.additional_attributes['store_routing']).to include('store' => 'psd', 'assignment_rule' => 'response-timeout')
  end

  it 'does not bounce back to a seller who already missed the same response' do
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(replacement)
    expect(watch.reload.attempted_agent_ids).to contain_exactly(seller.id, replacement.id)
    expect(Notification.where(user: manager, notification_type: :sla_missed_first_response).count).to eq(2)
  end

  it 'cancels the current cycle after a manual transfer' do
    message
    timer_id = watch.id
    conversation.update!(assignee: replacement)
    travel timeout + 1.minute
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(replacement)
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
  end

  it 'cancels the current cycle when the conversation is resolved' do
    message
    timer_id = watch.id
    conversation.update!(status: :resolved)
    travel timeout + 1.minute
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(seller)
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
  end

  it 'respects the rolling hourly limit and resumes when capacity becomes available' do
    message
    limiter = AutoAssignment::RateLimiter.new(inbox: inbox, agent: replacement)
    10.times { limiter.track_assignment(conversation) }
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(seller)
    expect(limiter.current_count).to eq(10)
    travel 1.hour + 1.minute - timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(replacement)
  end

  it 'respects the target seller capacity' do
    capacity = create(:agent_capacity_policy, account: account)
    create(:inbox_capacity_limit, inbox: inbox, agent_capacity_policy: capacity, conversation_limit: 1)
    replacement.account_users.find_by!(account: account).update!(agent_capacity_policy: capacity)
    full = create(:conversation, account: account, inbox: inbox, assignee: replacement)
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(seller)
    full.update!(status: :resolved)
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(replacement)
  end

  it 'carries Sunday minutes into Monday opening instead of reassigning outside business hours' do
    inbox.working_hours.find_by!(day_of_week: 0).update!(closed_all_day: false, open_hour: 10, open_minutes: 0, close_hour: 18, close_minutes: 0)
    travel_to Time.utc(2026, 10, 11, 20, 58)
    message
    expect(watch.due_at).to eq(Time.utc(2026, 10, 12, 12, 8))
    travel_to Time.utc(2026, 10, 12, 11, 59)
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(seller)
    travel_to Time.utc(2026, 10, 12, 12, 8)
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(conversation.reload.assignee).to eq(replacement)
  end

  it 'clears pending windows when disabled and leaves stale jobs harmless' do
    message
    timer_id = watch.id
    inbox.update!(response_reassignment_mode: 'disabled')
    travel timeout + 1.minute
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(seller)
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
  end
end
