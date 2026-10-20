require 'rails_helper'

RSpec.describe ConversationResponseAttempt do
  let(:account) { create(:account) }
  let(:role) { create(:custom_role, account: account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true, timezone: 'America/Sao_Paulo', working_hours_enabled: true) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:replacement) { create(:user, account: account, role: :agent) }
  let(:manager) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
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
  let(:attempts) { described_class.where(conversation_id: conversation.id).order(:id) }
  let(:timeout) { ConversationResponseTimer::TIMEOUT }

  before do
    travel_to Time.utc(2026, 10, 12, 15)
    account.enable_features!('assignment_v2', 'advanced_assignment')
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    [seller, replacement].each do |user|
      create(:inbox_member, inbox: inbox, user: user)
      user.account_users.find_by!(account: account).update!(custom_role: role)
      create(:team_member, team: team, user: user)
    end
    account.update!(internal_attributes: { store_routing: { inbox_ids: [inbox.id], stores: { psd: { team_id: team.id, label: 'loja-psd' } } },
                                           assignment_ledger: { inbox_ids: [inbox.id] } })
    inbox.update!(response_reassignment_mode: 'first_response', response_reassignment_notify_user: manager)
    online = [seller, replacement].index_with { 'online' }.transform_keys { |user| user.id.to_s }
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(online)
  end

  def reply(sender)
    create(:message, account: account, conversation: conversation, sender: sender, message_type: :outgoing)
  end

  it 'saves the human reply and records it as met for the owner, with business-time speed and the drilldown snapshot' do
    message
    travel 3.minutes
    # Regression: the business_hours column once collided with ReportingEventHelper#business_hours and rolled back replies.
    expect { reply(seller) }.to change(conversation.messages.outgoing, :count).by(1)
    expect(attempts.sole).to have_attributes(
      assignee_id: seller.id, responder_id: seller.id, outcome: 'met', end_reason: 'replied', response_seconds: 180, wait_seconds: 180,
      conversation_display_id: conversation.display_id, team_id: team.id, threshold_seconds: timeout.to_i, business_hours: true,
      started_at: message.created_at, due_at: message.created_at + timeout
    )
    expect(ConversationResponseTimer.where(conversation: conversation)).to be_empty
  end

  it 'gives the owner no credit when another person replies before the deadline' do
    message
    travel 1.minute
    reply(manager)
    expect(attempts.sole).to have_attributes(assignee_id: seller.id, responder_id: manager.id, outcome: 'answered_by_other', response_seconds: 60)
  end

  it 'does not credit the replacement when the previous owner answers inside the new window' do
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    travel 1.minute
    reply(seller)
    expect(attempts.pluck(:assignee_id, :outcome)).to eq([[seller.id, 'breached'], [replacement.id, 'answered_by_other']])
  end

  it 'treats a reply after the deadline as a breach even when the deadline job has not run yet' do
    message
    travel timeout + 1.minute
    reply(seller)
    expect(attempts.sole).to have_attributes(outcome: 'breached', end_reason: 'replied', responder_id: seller.id,
                                             response_seconds: (timeout + 1.minute).to_i)
  end

  it 'charges the missed deadline to the previous owner and gives the replacement a fresh window measured from the transfer' do
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    travel 2.minutes
    reply(replacement)
    expect(attempts.map { |attempt| attempt.slice(:assignee_id, :outcome, :end_reason) }).to eq(
      [{ 'assignee_id' => seller.id, 'outcome' => 'breached', 'end_reason' => 'reassigned' },
       { 'assignee_id' => replacement.id, 'outcome' => 'met', 'end_reason' => 'replied' }]
    )
    expect(attempts.last).to have_attributes(started_at: Time.utc(2026, 10, 12, 15) + timeout, response_seconds: 120,
                                             wait_seconds: (timeout + 2.minutes).to_i)
  end

  it 'does not charge the same customer wait twice when the same owner is re-armed after a breach' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(seller.id.to_s => 'online')
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    travel 1.minute
    watch.arm!
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(attempts.sole).to have_attributes(assignee_id: seller.id, outcome: 'breached', ended_at: nil)
  end

  it 'records a breach once when no substitute exists, however often the deadline is retried' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(seller.id.to_s => 'online')
    message
    travel timeout
    3.times do
      SalesRouting::ReassignResponseJob.perform_now(watch.id)
      travel 1.minute
    end
    expect(attempts.sole).to have_attributes(assignee_id: seller.id, outcome: 'breached', ended_at: nil)
    reply(seller)
    expect(attempts.sole).to have_attributes(outcome: 'breached', end_reason: 'replied', responder_id: seller.id)
  end

  it 'does not breach or reassign when the reply wins the race against a due job' do
    message
    timer_id = watch.id
    travel timeout - 1.second
    reply(seller)
    travel 1.second
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(conversation.reload.assignee).to eq(seller)
    expect(attempts.sole).to have_attributes(outcome: 'met', end_reason: 'replied')
  end

  it 'cancels windows that end before the deadline without counting them as fulfilled' do
    message
    travel 2.minutes
    conversation.update!(assignee: replacement)
    expect(attempts.sole).to have_attributes(outcome: 'canceled', end_reason: 'manual_transfer', replied_at: nil)
  end

  it 'keeps the breach when the conversation is resolved after the deadline' do
    message
    travel timeout + 2.minutes
    conversation.update!(status: :resolved)
    expect(attempts.sole).to have_attributes(outcome: 'breached', end_reason: 'closed')
  end

  it 'closes open windows and coverage when the reassignment mode is disabled' do
    message
    travel 1.minute
    inbox.update!(response_reassignment_mode: 'disabled')
    expect(attempts.sole).to have_attributes(outcome: 'canceled', end_reason: 'settings_changed')
    expect(inbox.reload.response_attempts_tracked_since).to be_nil
    travel 1.minute
    inbox.update!(response_reassignment_mode: 'first_response')
    expect(inbox.reload.response_attempts_tracked_since).to eq(Time.current)
  end

  it 'settles open windows when auto-assignment stops, so a stale deadline job cannot charge a later breach' do
    message
    expect(ResponseTrackingPeriod.open.find_by!(inbox_id: inbox.id).started_at).to eq(Time.utc(2026, 10, 12, 15))
    timer_id = watch.id
    travel 1.minute
    inbox.update!(enable_auto_assignment: false)
    expect(attempts.sole).to have_attributes(outcome: 'canceled', end_reason: 'settings_changed')
    expect(ResponseTrackingPeriod.where(inbox_id: inbox.id).pluck(:ended_at)).to eq([Time.current])
    travel 10.minutes
    SalesRouting::ReassignResponseJob.perform_now(timer_id)
    expect(attempts.sole.outcome).to eq('canceled')
    inbox.update!(enable_auto_assignment: true)
    expect(ResponseTrackingPeriod.where(inbox_id: inbox.id).order(:started_at).pluck(:ended_at)).to eq([10.minutes.ago, nil])
  end

  it 'snapshots the origin store of the conversation on each window' do
    message
    expect(attempts.sole.store_code).to eq('psd')
  end

  it 'starts the window when the seller receives the conversation, not while it waited unassigned' do
    conversation.update!(assignee: nil)
    message
    expect(attempts).to be_empty
    travel 2.minutes
    AutoAssignment::AssignmentService.new(inbox: inbox).perform_bulk_assignment
    assignee = conversation.reload.assignee
    travel 1.minute
    reply(assignee)
    expect(attempts.sole).to have_attributes(assignee_id: assignee.id, started_at: message.created_at + 2.minutes,
                                             response_seconds: 60, wait_seconds: 180, outcome: 'met')
  end

  it 'counts response speed in business time across the evening close' do
    travel_to Time.utc(2026, 10, 12, 19, 58)
    message
    expect(attempts.sole.due_at).to eq(Time.utc(2026, 10, 13, 12, 8))
    travel_to Time.utc(2026, 10, 13, 12, 1)
    reply(seller)
    expect(attempts.sole).to have_attributes(outcome: 'met', response_seconds: 180, wait_seconds: 180)
  end

  it 'carries weekend time into the next opening' do
    inbox.working_hours.find_by!(day_of_week: 0).update!(closed_all_day: false, open_hour: 10, open_minutes: 0, close_hour: 18, close_minutes: 0)
    travel_to Time.utc(2026, 10, 11, 20, 58)
    message
    expect(attempts.sole.due_at).to eq(Time.utc(2026, 10, 12, 12, 8))
    travel_to Time.utc(2026, 10, 12, 12, 1)
    reply(seller)
    expect(attempts.sole).to have_attributes(outcome: 'met', response_seconds: 180)
  end

  it 'gives no verdict when the deadline job finds the window ineligible, since it cannot tell when that happened' do
    message
    travel 1.minute
    conversation.contact.update!(blocked: true)
    travel timeout - 1.minute
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(attempts.sole).to have_attributes(outcome: 'canceled', end_reason: 'ineligible')
  end

  it 'keeps a breach already recorded at the deadline when the window turns ineligible afterwards' do
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return(seller.id.to_s => 'online')
    message
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    conversation.contact.update!(blocked: true)
    travel 1.minute
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(attempts.sole).to have_attributes(outcome: 'breached', end_reason: 'ineligible')
  end

  it 'gives no verdict to a window removed before its deadline and keeps history after the conversation is deleted' do
    message
    travel 1.minute
    conversation.destroy!
    expect(described_class.where(conversation_id: conversation.id).sole).to have_attributes(outcome: 'canceled', end_reason: 'ineligible')
  end

  it 'collects nothing before activation and never invents the start of a window armed before it' do
    inbox.update!(response_attempts_tracked_since: nil)
    message
    expect(attempts).to be_empty
    inbox.update!(response_attempts_tracked_since: Time.current)
    travel timeout
    SalesRouting::ReassignResponseJob.perform_now(watch.id)
    expect(attempts.sole).to have_attributes(assignee_id: replacement.id, outcome: 'pending', started_at: Time.current)
  end
end
