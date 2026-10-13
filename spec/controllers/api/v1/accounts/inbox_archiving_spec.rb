require 'rails_helper'

RSpec.describe 'Inbox archiving', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:url) { "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}" }

  it 'allows an administrator to deactivate without deleting history or changing assignment settings' do
    conversation = create(:conversation, account: account, inbox: inbox)
    message = create(:message, account: account, inbox: inbox, conversation: conversation)
    channel = inbox.channel

    patch url, headers: admin.create_new_auth_token, params: { archived: true }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['archived']).to be(true)
    expect(inbox.reload).to have_attributes(archived: true, enable_auto_assignment: true)
    expect(Conversation.exists?(conversation.id)).to be(true)
    expect(Message.exists?(message.id)).to be(true)
    expect(channel.class.exists?(channel.id)).to be(true)
  end

  it 'allows an administrator to reactivate an inactive inbox' do
    inbox.update!(archived: true)
    patch url, headers: admin.create_new_auth_token, params: { archived: false }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['archived']).to be(false)
    expect(inbox.reload.archived?).to be(false)
  end

  it 'keeps inactive inboxes in the authenticated listing and accessible for historical conversations' do
    inbox.update!(archived: true)
    create(:inbox_member, inbox: inbox, user: agent)

    get "/api/v1/accounts/#{account.id}/inboxes", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['payload']).to include(include('id' => inbox.id, 'archived' => true))

    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['archived']).to be(true)
  end

  it 'rejects an assigned agent trying to deactivate the inbox' do
    create(:inbox_member, inbox: inbox, user: agent)

    patch url, headers: agent.create_new_auth_token, params: { archived: true }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(inbox.reload.archived?).to be(false)
  end

  it 'does not allow changing another account inbox' do
    other_inbox = create(:inbox)

    patch "/api/v1/accounts/#{account.id}/inboxes/#{other_inbox.id}",
          headers: admin.create_new_auth_token, params: { archived: true }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(other_inbox.reload.archived?).to be(false)
  end

  it 'rejects non-boolean archive values before updating the inbox' do
    ['true', 'false', 1, nil, {}].each do |value|
      patch url, headers: admin.create_new_auth_token, params: { archived: value }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(inbox.reload.archived?).to be(false)
    end
  end
end
