module Whatsapp::Triage::ConversationGuard
  extend ActiveSupport::Concern

  included do
    validate :keep_complaint_with_responsible_team
    validate :keep_complaint_with_responsible_agent
  end

  private

  def keep_complaint_with_responsible_team
    return unless protected_triage_complaint? && will_save_change_to_team_id?
    return if team_id == triage_configuration.team_id('complaints')

    errors.add(:team_id, I18n.t('errors.whatsapp_triage.complaint_team_locked'))
  end

  def keep_complaint_with_responsible_agent
    return unless protected_triage_complaint? && will_save_change_to_assignee_id?
    return if will_save_change_to_team_id? && assignee_id.blank?
    return if valid_complaint_agent?

    errors.add(:assignee_id, I18n.t('errors.whatsapp_triage.complaint_assignee_locked'))
  end

  def protected_triage_complaint?
    return false if resolved? || custom_attributes['triage_status'] != 'complaint_owned'

    triage_configuration.configured_for?(inbox) && complaint_team_exists?
  end

  def complaint_team_exists?
    account.teams.exists?(id: triage_configuration.team_id('complaints'))
  end

  def valid_complaint_agent?
    return false if assignee_id.blank?

    complaint_team = account.teams.find_by(id: triage_configuration.team_id('complaints'))
    complaint_team&.members&.exists?(id: assignee_id)
  end

  def triage_configuration
    @triage_configuration ||= Whatsapp::Triage::Configuration.new
  end
end
