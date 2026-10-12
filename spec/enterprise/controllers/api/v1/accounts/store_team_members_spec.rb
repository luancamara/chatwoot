require 'rails_helper'

RSpec.describe 'Store team membership', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:role) { create(:custom_role, account: account) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:first_team) { create(:team, account: account) }
  let(:second_team) { create(:team, account: account) }

  before do
    policy = create(:assignment_policy, account: account, eligible_custom_role: role)
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    seller.account_users.find_by!(account: account).update!(custom_role: role)
    create(:team_member, team: first_team, user: seller)
    create(:team_member, team: first_team, user: admin)
    account.update!(internal_attributes: { store_routing: { inbox_ids: [inbox.id], stores: {
                      psd: { team_id: first_team.id }, lap: { team_id: second_team.id }
                    } } })
  end

  it 'rejects a seller in two store teams without changing either membership' do
    post "/api/v1/accounts/#{account.id}/teams/#{second_team.id}/team_members",
         params: { user_ids: [seller.id] }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(second_team.members).not_to include(seller)
    expect(first_team.members).to include(seller)
  end

  it 'preserves manager access to multiple teams' do
    post "/api/v1/accounts/#{account.id}/teams/#{second_team.id}/team_members",
         params: { user_ids: [admin.id] }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(second_team.members).to include(admin)
  end
end
