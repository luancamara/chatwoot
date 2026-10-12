require 'rails_helper'

RSpec.describe 'Response reassignment settings', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:other_admin) { create(:user, account: create(:account), role: :administrator) }
  let(:inbox) { create(:inbox, account: account, working_hours_enabled: true) }
  let(:url) { "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}" }

  before do
    account.update!(internal_attributes: { store_routing: { inbox_ids: [inbox.id], stores: {} } })
  end

  it 'persists the selected mode and administrator through the existing inbox API' do
    patch url, params: { response_reassignment_mode: 'first_response', response_reassignment_notify_user_id: admin.id },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('response_reassignment_mode' => 'first_response', 'response_reassignment_notify_user_id' => admin.id)
    expect(inbox.reload).to be_response_reassignment_first_response
  end

  it 'rejects malformed modes before the enum setter raises' do
    patch url, params: { response_reassignment_mode: 1 }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(inbox.reload).to be_response_reassignment_disabled
  end

  it 'rejects recipients from another account' do
    patch url, params: { response_reassignment_mode: 'all_responses', response_reassignment_notify_user_id: other_admin.id },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(inbox.reload).to be_response_reassignment_disabled
  end

  it 'does not let sellers change response rules' do
    patch url, params: { response_reassignment_mode: 'first_response', response_reassignment_notify_user_id: admin.id },
               headers: seller.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(inbox.reload).to be_response_reassignment_disabled
  end

  it 'rejects activation outside the configured store-routing inboxes' do
    account.update!(internal_attributes: {})
    patch url, params: { response_reassignment_mode: 'first_response', response_reassignment_notify_user_id: admin.id },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
