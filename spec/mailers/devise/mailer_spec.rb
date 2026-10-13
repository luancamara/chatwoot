require 'rails_helper'

RSpec.describe Devise::Mailer do
  it 'uses the installation locale for password reset emails without an account context' do
    user = create(:user)

    with_modified_env DEFAULT_LOCALE: 'pt_BR' do
      mail = described_class.with(account: nil).reset_password_instructions(user, 'reset-token').message

      expect(mail.subject).to eq(I18n.t('devise.mailer.reset_password_instructions.subject', locale: :pt_BR))
      expect(mail.body.decoded).to include('Alterar minha senha', 'Se você não fez esta solicitação', 'Este e-mail foi enviado por')
      expect(mail.body.decoded).to include('reset_password_token=reset-token')
      expect(mail.body.decoded).not_to include('Someone has requested', 'Change my password')
    end
  end

  it 'carries the pending Shopify install redirect in the confirmation link' do
    user = create(:user, skip_confirmation: false)
    redirect_url = "settings/integrations/shopify?shopify_pending_install=#{'a' * 32}"
    mail = described_class
           .with(redirect_url: redirect_url)
           .confirmation_instructions(user, 'confirmation-token')

    expect(CGI.unescapeHTML(mail.body.to_s)).to include(
      "route_url=settings%2Fintegrations%2Fshopify%3Fshopify_pending_install%3D#{'a' * 32}"
    )
  end

  it 'carries the requested redirect in the password edit link' do
    user = create(:user)
    redirect_url = 'settings/billing?plan_handle=growth'
    mail = described_class
           .with(redirect_url: redirect_url, sso_account_id: '42')
           .reset_password_instructions(user, 'reset-token')

    expect(CGI.unescapeHTML(mail.body.to_s)).to include(
      'route_url=settings%2Fbilling%3Fplan_handle%3Dgrowth',
      'sso_account_id=42'
    )
  end
end
