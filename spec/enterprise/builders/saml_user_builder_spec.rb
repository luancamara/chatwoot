require 'rails_helper'

RSpec.describe SamlUserBuilder do
  let(:email) { 'saml.user@example.com' }
  let(:auth_hash) do
    {
      'provider' => 'saml',
      'uid' => 'saml-uid-123',
      'info' => {
        'email' => email,
        'name' => 'SAML User',
        'first_name' => 'SAML',
        'last_name' => 'User'
      },
      'extra' => {
        'raw_info' => {
          'groups' => %w[Administrators Users]
        }
      }
    }
  end
  let(:account) { create(:account) }
  let(:builder) { described_class.new(auth_hash, account.id) }

  describe '#perform' do
    context 'when user does not exist' do
      it 'does not create a new user (SSO is restricted to pre-provisioned users)' do
        expect { builder.perform rescue nil }.not_to change(User, :count)
      end

      it 'raises an authentication failure' do
        expect { builder.perform }.to raise_error do |error|
          expect(error.class.name).to eq('SamlUserBuilder::AuthenticationFailed')
          expect(error.message).to eq(I18n.t('auth.saml.authentication_failed'))
        end
      end

      it 'does not create any account association' do
        expect do
          builder.perform
        rescue SamlUserBuilder::AuthenticationFailed
          nil
        end.not_to change(AccountUser, :count)
      end
    end

    context 'when user already exists and belongs to the account' do
      let!(:existing_user) { create(:user, email: email, account: account) }

      it 'does not create a new user' do
        expect { builder.perform }.not_to change(User, :count)
      end

      it 'returns the existing user' do
        user = builder.perform
        expect(user).to eq(existing_user)
      end

      it 'keeps the existing user in the account' do
        user = builder.perform
        expect(user.accounts).to include(account)
      end

      it 'converts existing user to SAML' do
        expect(existing_user.provider).not_to eq('saml')

        builder.perform

        expect(existing_user.reload.provider).to eq('saml')
      end

      it 'does not change provider if user is already SAML' do
        existing_user.update!(provider: 'saml')

        expect { builder.perform }.not_to(change { existing_user.reload.provider })
      end

      it 'does not duplicate account association' do
        expect { builder.perform }.not_to change(AccountUser, :count)
      end

      context 'when user is not confirmed' do
        let(:unconfirmed_email) { 'unconfirmed_saml_user@example.com' }
        let(:unconfirmed_auth_hash) do
          {
            'provider' => 'saml',
            'uid' => 'saml-uid-123',
            'info' => {
              'email' => unconfirmed_email,
              'name' => 'SAML User',
              'first_name' => 'SAML',
              'last_name' => 'User'
            }
          }
        end
        let(:unconfirmed_builder) { described_class.new(unconfirmed_auth_hash, account.id) }
        let!(:existing_user) do
          user = build(:user, email: unconfirmed_email, account: account)
          user.confirmed_at = nil
          user.save!(validate: false)
          user
        end

        it 'confirms unconfirmed user after SAML authentication' do
          expect(existing_user.confirmed?).to be false

          unconfirmed_builder.perform

          expect(existing_user.reload.confirmed?).to be true
        end
      end
    end

    context 'when user exists but does not belong to the bootstrap account' do
      let!(:other_account) { create(:account) }
      let!(:existing_user) { create(:user, email: email, account: other_account) }

      it 'returns the existing user without raising' do
        expect(builder.perform).to eq(existing_user)
      end

      it 'does not add the user to the bootstrap account' do
        expect { builder.perform }.not_to change(AccountUser, :count)
        expect(existing_user.reload.accounts).not_to include(account)
      end

      it 'still converts the user provider to saml' do
        builder.perform
        expect(existing_user.reload.provider).to eq('saml')
      end
    end

    context 'with role mappings for an existing member' do
      let!(:existing_user) { create(:user, email: email, account: account) }
      let(:saml_settings) do
        create(:account_saml_settings,
               account: account,
               role_mappings: {
                 'Administrators' => { 'role' => 'administrator' },
                 'Agents' => { 'role' => 'agent' }
               })
      end

      before { saml_settings }

      it 'applies administrator role based on SAML groups' do
        user = builder.perform
        account_user = AccountUser.find_by(user: user, account: account)
        expect(account_user.role).to eq('administrator')
      end

      context 'with custom role mapping' do
        let!(:custom_role) { create(:custom_role, account: account) }
        let(:saml_settings) do
          create(:account_saml_settings,
                 account: account,
                 role_mappings: {
                   'Administrators' => { 'custom_role_id' => custom_role.id }
                 })
        end

        before { saml_settings }

        it 'applies custom role based on SAML groups' do
          user = builder.perform
          account_user = AccountUser.find_by(user: user, account: account)
          expect(account_user.custom_role_id).to eq(custom_role.id)
        end
      end

      context 'when user is not in any mapped groups' do
        let(:auth_hash) do
          {
            'provider' => 'saml',
            'uid' => 'saml-uid-123',
            'info' => {
              'email' => email,
              'name' => 'SAML User'
            },
            'extra' => {
              'raw_info' => {
                'groups' => ['UnmappedGroup']
              }
            }
          }
        end

        it 'keeps the existing role' do
          user = builder.perform
          account_user = AccountUser.find_by(user: user, account: account)
          expect(account_user.role).to eq('agent')
        end
      end
    end
  end
end
