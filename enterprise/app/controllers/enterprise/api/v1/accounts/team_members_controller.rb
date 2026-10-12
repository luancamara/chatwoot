module Enterprise::Api::V1::Accounts::TeamMembersController
  private

  def validate_member_id_params
    super
    return if performed? || action_name == 'destroy'

    settings = Current.account.internal_attributes['store_routing']
    return if settings.blank?

    inbox = Current.account.inboxes.find(settings.fetch('inbox_ids').first)
    configuration = SalesRouting::Configuration.new(inbox: inbox)
    return unless conflicting_store_members?(configuration)

    render json: { error: I18n.t('errors.store_routing.exclusive_team') }, status: :unprocessable_entity
  end

  def conflicting_store_members?(configuration)
    team_ids = configuration.stores.values.map { |store| store.fetch('team_id') }
    return false unless team_ids.include?(@team.id)

    TeamMember.exists?(team_id: team_ids - [@team.id], user_id: members_to_be_added_ids & configuration.seller_ids)
  end
end
