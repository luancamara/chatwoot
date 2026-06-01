class SamlUserBuilder
  class AuthenticationFailed < StandardError; end

  def initialize(auth_hash, account_id)
    @auth_hash = auth_hash
    @account_id = account_id
    @saml_settings = AccountSamlSettings.find_by(account_id: account_id)
  end

  def perform
    @user = find_or_create_user
    add_user_to_account if @user.persisted?
    @user
  end

  private

  def find_or_create_user
    user = User.from_email(auth_attribute('email'))

    # SSO is restricted to pre-provisioned users: a person who does not already
    # exist in Chatwoot cannot self-provision through SAML.
    raise AuthenticationFailed, I18n.t('auth.saml.authentication_failed') unless user

    existing_user_for_account(user)
  end

  def existing_user_for_account(user)
    confirm_user_if_required(user)
    convert_existing_user_to_saml(user)
    user
  end

  def confirm_user_if_required(user)
    return if user.confirmed?

    user.skip_confirmation!
    user.save!
  end

  def convert_existing_user_to_saml(user)
    return if user.provider == 'saml'

    user.update!(provider: 'saml')
  end

  # The user is pre-provisioned, so we never create a membership here. The
  # account used to bootstrap SSO is auto-detected and may not be one the user
  # belongs to; we only sync role mappings when they are already a member.
  def add_user_to_account
    account = Account.find_by(id: @account_id)
    return unless account

    account_user = @user.account_users.find_by(account_id: account.id)
    return unless account_user

    apply_role_mappings(account_user, account)
  end

  def apply_role_mappings(account_user, account)
    matching_mapping = find_matching_role_mapping(account)
    return unless matching_mapping

    if matching_mapping['role']
      account_user.update(role: matching_mapping['role'])
    elsif matching_mapping['custom_role_id']
      account_user.update(custom_role_id: matching_mapping['custom_role_id'])
    end
  end

  def find_matching_role_mapping(_account)
    return if @saml_settings&.role_mappings.blank?

    saml_groups.each do |group|
      mapping = @saml_settings.role_mappings[group]
      return mapping if mapping.present?
    end
    nil
  end

  def auth_attribute(key, fallback = nil)
    @auth_hash.dig('info', key) || fallback
  end

  def saml_groups
    # Groups can come from different attributes depending on IdP
    @auth_hash.dig('extra', 'raw_info', 'groups') ||
      @auth_hash.dig('extra', 'raw_info', 'Group') ||
      @auth_hash.dig('extra', 'raw_info', 'memberOf') ||
      []
  end
end
