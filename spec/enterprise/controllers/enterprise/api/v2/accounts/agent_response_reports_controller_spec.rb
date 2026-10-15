require 'rails_helper'

RSpec.describe 'Agent response reports API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:replacement) { create(:user, account: account, role: :agent, name: 'Bruno') }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:inbox) { create(:inbox, account: account, response_attempts_tracked_since: Time.utc(2026, 10, 1, 12)) }
  let(:other_inbox) { create(:inbox, account: account) }
  # Created before the ledger is enabled so only the explicit events below exist.
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, assignee: replacement, team: team,
                          additional_attributes: { store_routing: { store: 'psd' } })
  end
  let(:params) { { since: '2026-10-14', until: '2026-10-14', timezone: 'America/Sao_Paulo' } }
  let(:summary_url) { "/api/v2/accounts/#{account.id}/agent_response_reports/summary" }
  let(:details_url) { "/api/v2/accounts/#{account.id}/agent_response_reports/details" }
  let(:attempt) do
    { account_id: account.id, inbox_id: inbox.id, conversation_id: conversation.id, conversation_display_id: conversation.display_id,
      team_id: team.id, store_code: 'psd', response_kind: 'first_response', customer_message_id: 1, waiting_since: Time.utc(2026, 10, 14, 15),
      threshold_seconds: 300, business_hours: true }
  end

  before do
    travel_to Time.utc(2026, 10, 14, 18)
    create(:team_member, team: team, user: seller)
    stores = { psd: { team_id: team.id, label: 'loja-psd' }, lap: { team_id: other_team.id, label: 'loja-lap' } }
    account.update!(internal_attributes: { assignment_ledger: { inbox_ids: [inbox.id] }, store_routing: { inbox_ids: [inbox.id], stores: stores } })
    event = { account: account, conversation: conversation, inbox_id: inbox.id, conversation_display_id: conversation.display_id,
              source: 'automatic', routing: { store: 'psd' } }
    ConversationAssignmentEvent.create!(event.merge(agent_id: seller.id, agent_name: seller.name, event_kind: 'initial',
                                                    assigned_at: Time.utc(2026, 10, 14, 15)))
    ConversationAssignmentEvent.create!(event.merge(agent_id: replacement.id, agent_name: replacement.name, event_kind: 'reassignment',
                                                    routing: { store: 'psd', assignment_rule: 'response-timeout' },
                                                    assigned_at: Time.utc(2026, 10, 14, 15, 5)))
    ConversationResponseAttempt.create!(attempt.merge(assignee_id: seller.id, started_at: Time.utc(2026, 10, 14, 15),
                                                      due_at: Time.utc(2026, 10, 14, 15, 5), outcome: 'breached', end_reason: 'reassigned',
                                                      ended_at: Time.utc(2026, 10, 14, 15, 5)))
    ConversationResponseAttempt.create!(attempt.merge(assignee_id: replacement.id, started_at: Time.utc(2026, 10, 14, 15, 5),
                                                      due_at: Time.utc(2026, 10, 14, 15, 10), outcome: 'met', end_reason: 'replied',
                                                      ended_at: Time.utc(2026, 10, 14, 15, 7), replied_at: Time.utc(2026, 10, 14, 15, 7),
                                                      responder_id: replacement.id, response_seconds: 120, wait_seconds: 420))
    message = { account: account, inbox: inbox, conversation: conversation }
    create_list(:message, 3, message)
    create_list(:message, 2, message.merge(message_type: :outgoing, sender: seller))
    create(:message, message.merge(message_type: :outgoing, sender: replacement))
    create(:message, message.merge(message_type: :outgoing, sender: seller, private: true))
    create(:message, message.merge(message_type: :outgoing, sender: seller, content_attributes: { automation_rule_id: 1 }))
    create(:message, message.merge(message_type: :outgoing, sender: seller, additional_attributes: { campaign_id: 1 }))
    create(:reporting_event, name: 'conversation_resolved', account: account, inbox: inbox, user: replacement, conversation: conversation)
  end

  # Each call returns its own parsed body after checking it succeeded, so a failure shows the real response.
  def get_summary(user, extra = {})
    get summary_url, params: params.merge(extra), headers: user.create_new_auth_token
    expect(response).to have_http_status(:ok), response.body
    response.parsed_body
  end

  def get_details(extra)
    get details_url, params: params.merge(extra), headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok), response.body
    response.parsed_body
  end

  describe 'authorization' do
    it 'rejects agents without report permission' do
      get summary_url, params: params, headers: seller.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects administrators of another account' do
      get summary_url, params: params, headers: create(:user, account: create(:account), role: :administrator).create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows custom roles with report permission' do
      role = create(:custom_role, account: account, permissions: ['report_manage'])
      seller.account_users.find_by!(account: account).update!(custom_role: role)
      expect(get_summary(seller)['agents']).to be_an(Array)
    end
  end

  describe 'validation' do
    it 'rejects malformed dates, long ranges, foreign ids and malformed list shapes instead of widening the query' do
      [{ since: '14/10/2026' }, { since: '2026-06-01' }, { timezone: 'Mars/Base' }, { inbox_ids: [create(:inbox).id] },
       { inbox_ids: inbox.id.to_s }, { agent_ids: { first: seller.id } }, { agent_ids: [''] }, { store_codes: ['xyz'] }].each do |invalid|
        get summary_url, params: params.merge(invalid), headers: admin.create_new_auth_token
        expect(response).to have_http_status(:unprocessable_entity), invalid.inspect
      end
    end

    it 'explains validation errors in the account language' do
      account.update!(locale: 'pt_BR')
      get summary_url, params: params.merge(until: '2026-10-01'), headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('a data final não pode ser anterior à inicial')
    end
  end

  describe 'GET summary' do
    it 'counts unique conversations separately from assignment and transfer events' do
      summary = get_summary(admin)
      expect(summary['summary']['conversations']).to eq('received' => 1, 'handled' => 1, 'resolved' => 1)
      expect(summary['summary']['assignments']).to eq('initial' => 1, 'reassignments' => 1, 'timeout_reassignments' => 1)
      expect(summary['agents'].to_h { |agent| [agent['name'], agent['conversations']['received']] }).to eq('Ana' => 1, 'Bruno' => 1)
    end

    it 'counts authored human messages by sender, excluding notes, automation and campaigns, and shows customer volume' do
      summary = get_summary(admin)
      expect(summary['summary']['messages']).to eq('agent' => 3, 'customer' => 3, 'per_handled_conversation' => 3.0)
      messages = summary['agents'].to_h { |agent| [agent['name'], agent['messages']] }
      expect(messages['Ana']).to eq('agent' => 2, 'customer' => 3, 'per_handled_conversation' => 2.0)
      expect(messages['Bruno']).to eq('agent' => 1, 'customer' => 3, 'per_handled_conversation' => 1.0)
    end

    it 'charges deadlines to the owner at the deadline and measures speed from receipt' do
      summary = get_summary(admin)
      expect(summary['summary']['deadline']).to include('met' => 1, 'breached' => 1, 'eligible' => 2, 'compliance_rate' => 0.5)
      expect(summary['summary']['response_time']).to eq('count' => 1, 'mean_seconds' => 120, 'median_seconds' => 120)
      expect(summary['summary']['customer_wait']).to eq('count' => 1, 'mean_seconds' => 420, 'median_seconds' => 420)
      ana = summary['agents'].find { |agent| agent['name'] == 'Ana' }
      expect(ana['deadline']).to include('breached' => 1, 'met' => 0, 'lost_to_reassignment' => 1)
      expect(ana['response_time']).to eq('count' => 0, 'mean_seconds' => nil, 'median_seconds' => nil)
      expect(summary['heatmap']).to eq([{ 'weekday' => 3, 'hour' => 12, 'breached' => 1 }])
      expect(summary['trend']).to eq([{ 'date' => '2026-10-14', 'met' => 1, 'breached' => 1, 'received' => 1, 'handled' => 1 }])
    end

    it 'keeps replies by someone else out of the owner compliance' do
      ConversationResponseAttempt.find_by!(outcome: 'met').update!(outcome: 'answered_by_other', responder_id: admin.id)
      summary = get_summary(admin)
      expect(summary['summary']['deadline']).to include('met' => 0, 'answered_by_other' => 1, 'eligible' => 1, 'compliance_rate' => 0.0)
      expect(summary['summary']['response_time']['count']).to eq(0)
    end

    it 'counts an overdue open window as breached only while its live timer exists' do
      open_window = ConversationResponseAttempt.find_by!(outcome: 'breached')
      open_window.update!(outcome: 'pending', end_reason: nil, ended_at: nil)
      summary = get_summary(admin)
      expect(summary['summary']['deadline']).to include('breached' => 0, 'canceled' => 1)

      ConversationResponseTimer.create!(conversation: conversation, inbox: inbox, waiting_since: open_window.waiting_since,
                                        customer_message_id: 1, response_kind: 'first_response', due_at: open_window.due_at)
      summary = get_summary(admin)
      expect(summary['summary']['deadline']).to include('breached' => 1, 'canceled' => 0)
    end

    it 'reports untracked inboxes as unavailable instead of zero' do
      summary = get_summary(admin, inbox_ids: [other_inbox.id])
      expect(summary['coverage']['response_attempts']).to include('available' => false, 'complete' => false, 'periods' => [],
                                                                  'unmonitored_inbox_ids' => [other_inbox.id])
      expect(summary['coverage']['assignments']).to include('available' => false)
      expect(summary['summary']).to include('deadline' => nil, 'response_time' => nil, 'assignments' => nil)
      expect(summary['summary']['conversations']).to eq('received' => nil, 'handled' => 0, 'resolved' => 0)
      expect(summary['trend'].first).to include('met' => nil, 'breached' => nil, 'received' => nil, 'handled' => 0)
      expect(summary['heatmap']).to be_nil
    end

    it 'marks days before coverage as unavailable and the period as incomplete' do
      summary = get_summary(admin, since: '2026-09-29', until: '2026-10-01')
      expect(summary['coverage']['response_attempts']).to include('available' => true, 'complete' => false)
      expect(summary['trend'].map { |day| [day['date'], day['met']] }).to eq([['2026-09-29', nil], ['2026-09-30', nil], ['2026-10-01', 0]])
      expect(summary['summary']['deadline']).to include('eligible' => 0, 'compliance_rate' => nil)
    end

    it 'keeps windows recorded before a coverage gap and reports the gap instead of hiding them' do
      ResponseTrackingPeriod.find_by!(inbox_id: inbox.id).update!(ended_at: Time.utc(2026, 10, 14, 15, 6))
      ResponseTrackingPeriod.create!(account_id: account.id, inbox_id: inbox.id, started_at: Time.utc(2026, 10, 14, 16))
      summary = get_summary(admin, inbox_ids: [inbox.id])
      expect(summary['summary']['deadline']).to include('breached' => 1, 'met' => 1)
      expect(summary['coverage']['response_attempts']['complete']).to be(false)
      expect(summary['coverage']['response_attempts']['periods'].pluck('ended_at')).to eq(['2026-10-14T15:06:00Z', nil])
    end

    it 'calls history complete only when every selected inbox was collected through the whole period' do
      inbox.update!(response_attempts_tracked_since: nil)
      summary = get_summary(admin, inbox_ids: [inbox.id])
      expect(summary['coverage']['response_attempts']).to include('complete' => true, 'unmonitored_inbox_ids' => [])
      summary = get_summary(admin, inbox_ids: [inbox.id, other_inbox.id])
      expect(summary['coverage']['response_attempts']).to include('complete' => false, 'unmonitored_inbox_ids' => [other_inbox.id])
    end

    it 'filters by agent in every section' do
      summary = get_summary(admin, agent_ids: [seller.id])
      expect(summary['agents'].pluck('name')).to eq(['Ana'])
      expect(summary['summary']['messages']['agent']).to eq(2)
      expect(summary['summary']['deadline']).to include('breached' => 1, 'met' => 0)
      expect(summary['summary']['conversations']).to eq('received' => 1, 'handled' => 1, 'resolved' => 0)
    end

    it 'filters every section by the origin store of the conversation, not by the current team of the seller' do
      TeamMember.find_by!(team: team, user: seller).destroy!
      create(:team_member, team: other_team, user: seller)

      summary = get_summary(admin, store_codes: ['psd'], agent_ids: [seller.id])
      expect(summary['summary']['deadline']).to include('breached' => 1)
      expect(summary['summary']['conversations']).to eq('received' => 1, 'handled' => 1, 'resolved' => 0)

      summary = get_summary(admin, store_codes: ['lap'], agent_ids: [seller.id])
      expect(summary['summary']['deadline']).to include('breached' => 0, 'met' => 0)
      expect(summary['summary']['conversations']).to eq('received' => 0, 'handled' => 0, 'resolved' => 0)
      expect(summary['options']['agents'].find { |agent| agent['id'] == seller.id }['store_codes']).to eq(['lap'])
    end

    it 'keeps every section in the origin store after the conversation is moved to another store by hand' do
      conversation.update!(team: other_team)
      expect(conversation.reload.additional_attributes['store_routing']).to include('store' => 'lap', 'origin_store' => 'psd')
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: replacement)

      summary = get_summary(admin, store_codes: ['psd'])
      expect(summary['summary']['conversations']).to eq('received' => 1, 'handled' => 1, 'resolved' => 1)
      expect(summary['summary']['messages']).to include('agent' => 4, 'customer' => 3)
      expect(summary['summary']['deadline']).to include('met' => 1, 'breached' => 1)
      expect(summary['coverage']['origin_store']).to eq('unknown' => 0, 'without_store' => 0, 'deleted_unknown' => 0)

      summary = get_summary(admin, store_codes: ['lap'])
      expect(summary['summary']['conversations']).to eq('received' => 0, 'handled' => 0, 'resolved' => 0)
      details = get_details(kind: 'conversations', metric: 'handled', store_codes: ['lap'])
      expect(details['payload']).to eq([])
    end

    it 'leaves conversations with an unknown origin out of store filters and says how many' do
      conversation.update!(additional_attributes: { store_routing: { store: 'lap', rule: 'manual-team' } })
      ConversationResponseAttempt.find_each { |window| window.update!(store_code: nil) }

      summary = get_summary(admin, store_codes: ['psd'])
      expect(summary['summary']['conversations']).to eq('received' => 0, 'handled' => 0, 'resolved' => 0)
      expect(summary['coverage']['origin_store']).to eq('unknown' => 1, 'without_store' => 0, 'deleted_unknown' => 0)

      summary = get_summary(admin)
      expect(summary['summary']['conversations']).to eq('received' => 1, 'handled' => 1, 'resolved' => 1)
      expect(summary['coverage']['origin_store']).to be_nil
    end

    it 'keeps a lead that arrived without a store as "without store" after a manager moves it to a store team' do
      conversation.update!(additional_attributes: { store_routing: { store: nil, origin_store: nil, rule: 'sem-sinal' } })
      conversation.update!(team: other_team)
      expect(conversation.reload.additional_attributes['store_routing']).to include('store' => 'lap', 'origin_store' => nil,
                                                                                    'rule' => 'manual-team')

      summary = get_summary(admin, store_codes: ['lap'])
      expect(summary['summary']['conversations']).to eq('received' => 0, 'handled' => 0, 'resolved' => 0)
      expect(summary['summary']['deadline']).to include('met' => 0, 'breached' => 0)
      expect(summary['coverage']['origin_store']).to eq('unknown' => 0, 'without_store' => 1, 'deleted_unknown' => 0)
    end

    it 'keeps preserved history of a deleted conversation in its proven store' do
      conversation.destroy!

      summary = get_summary(admin, store_codes: ['psd'])
      expect(summary['summary']['conversations']['received']).to eq(1)
      expect(summary['summary']['assignments']).to eq('initial' => 1, 'reassignments' => 1, 'timeout_reassignments' => 1)
      expect(summary['summary']['deadline']).to include('met' => 1, 'breached' => 1)
      expect(summary['coverage']['origin_store']).to eq('unknown' => 0, 'without_store' => 0, 'deleted_unknown' => 0)

      details = get_details(kind: 'conversations', metric: 'received', store_codes: ['psd'])
      expect(details['payload'].pluck('conversation_display_id', 'conversation_url')).to eq([[nil, nil], [nil, nil]])
      expect(get_summary(admin, store_codes: ['lap'])['summary']['conversations']['received']).to eq(0)
    end

    it 'reports deleted history whose store cannot be proven instead of dropping it silently' do
      ConversationAssignmentEvent.find_each { |event| event.update!(routing: { store: 'lap', rule: 'manual-team' }) }
      ConversationResponseAttempt.find_each { |window| window.update!(store_code: nil) }
      conversation.destroy!

      summary = get_summary(admin, store_codes: ['psd'])
      expect(summary['summary']['conversations']['received']).to eq(0)
      expect(summary['coverage']['origin_store']).to eq('unknown' => 0, 'without_store' => 0, 'deleted_unknown' => 1)
    end

    it 'files a deadline window under the origin the conversation got after the window was armed' do
      ConversationResponseAttempt.find_each { |window| window.update!(store_code: nil) }
      summary = get_summary(admin, store_codes: ['psd'])
      expect(summary['summary']['deadline']).to include('met' => 1, 'breached' => 1)
    end

    it 'measures first-reply speed and customer wait only on first-response windows' do
      ConversationResponseAttempt.create!(attempt.merge(assignee_id: replacement.id, response_kind: 'next_response',
                                                        started_at: Time.utc(2026, 10, 14, 16), due_at: Time.utc(2026, 10, 14, 16, 5),
                                                        outcome: 'met', end_reason: 'replied', ended_at: Time.utc(2026, 10, 14, 16, 1),
                                                        replied_at: Time.utc(2026, 10, 14, 16, 1), responder_id: replacement.id,
                                                        response_seconds: 30, wait_seconds: 30))
      summary = get_summary(admin)
      expect(summary['summary']['deadline']).to include('met' => 2, 'eligible' => 3)
      expect(summary['summary']['response_time']).to eq('count' => 1, 'mean_seconds' => 120, 'median_seconds' => 120)
      expect(summary['summary']['customer_wait']).to eq('count' => 1, 'mean_seconds' => 420, 'median_seconds' => 420)
    end

    it 'counts a loss to reassignment only when the transferred window had missed its deadline' do
      ConversationResponseAttempt.create!(attempt.merge(assignee_id: seller.id, started_at: Time.utc(2026, 10, 14, 16),
                                                        due_at: Time.utc(2026, 10, 14, 16, 5), outcome: 'canceled', end_reason: 'reassigned',
                                                        ended_at: Time.utc(2026, 10, 14, 16, 2)))
      summary = get_summary(admin, agent_ids: [seller.id])
      expect(summary['summary']['deadline']).to include('lost_to_reassignment' => 1, 'canceled' => 1)
    end

    it 'treats agents outside the account as an empty selection, never as everyone' do
      summary = get_summary(admin, agent_ids: [create(:user).id])
      expect(summary['agents']).to eq([])
      expect(summary['summary']['messages']['agent']).to eq(0)
    end
  end

  describe 'GET details' do
    it 'paginates attempts in a stable order with safe conversation links' do
      pages = [1, 2].map do |page|
        get_details(kind: 'attempts', page: page, per_page: 1)
      end
      expect(pages.map { |page| page['meta']['total'] }).to eq([2, 2])
      expect(pages.map { |page| page['payload'].sole['agent']['name'] }).to eq(%w[Bruno Ana])
      expect(pages.first['payload'].sole['conversation_url']).to end_with("/app/accounts/#{account.id}/conversations/#{conversation.display_id}")
    end

    it 'filters attempts by outcome and conversations by metric with the same filters as the summary' do
      details = get_details(kind: 'attempts', outcome: 'breached')
      expect(details['payload'].pluck('outcome', 'end_reason')).to eq([%w[breached reassigned]])
      details = get_details(kind: 'conversations', metric: 'handled', agent_ids: [seller.id], store_codes: ['psd'])
      expect(details['payload'].sole).to include('agent_messages' => 2, 'customer_messages' => 3,
                                                 'conversation_display_id' => conversation.display_id)
    end

    it 'opens exactly the samples behind the first-reply speed, late replies included and later responses excluded' do
      late = ConversationResponseAttempt.find_by!(outcome: 'breached')
      late.update!(replied_at: Time.utc(2026, 10, 14, 15, 9), responder_id: seller.id, response_seconds: 540)
      ConversationResponseAttempt.create!(attempt.merge(assignee_id: replacement.id, response_kind: 'next_response',
                                                        started_at: Time.utc(2026, 10, 14, 16), due_at: Time.utc(2026, 10, 14, 16, 5),
                                                        outcome: 'met', replied_at: Time.utc(2026, 10, 14, 16, 1), responder_id: replacement.id))
      summary = get_summary(admin)
      expect(summary['summary']['response_time']['count']).to eq(2)
      details = get_details(kind: 'attempts', sample: 'first_reply')
      expect(details['meta']['total']).to eq(2)
      expect(details['payload'].pluck('outcome')).to contain_exactly('met', 'breached')
    end

    it 'rejects unknown kinds and invalid pages' do
      [{ kind: 'messages' }, { kind: 'attempts', outcome: 'late' }, { kind: 'conversations', metric: 'handled', per_page: 101 },
       { kind: 'attempts', page: '0' }, { kind: 'attempts', sample: 'all' }, { kind: 'attempts', outcome: 'met', sample: 'first_reply' },
       { kind: 'conversations', metric: 'handled', sample: 'first_reply' }].each do |invalid|
        get details_url, params: params.merge(invalid), headers: admin.create_new_auth_token
        expect(response).to have_http_status(:unprocessable_entity), invalid.inspect
      end
    end
  end
end
