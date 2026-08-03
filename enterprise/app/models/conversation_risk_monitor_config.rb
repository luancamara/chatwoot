# == Schema Information
#
# Table name: conversation_risk_monitor_configs
#
#  id                 :bigint           not null, primary key
#  enabled            :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  complaint_label_id :bigint
#  critical_label_id  :bigint
#  inbox_id           :bigint           not null
#  management_team_id :bigint
#
# Indexes
#
#  index_conversation_risk_monitor_configs_on_account_id          (account_id)
#  index_conversation_risk_monitor_configs_on_complaint_label_id  (complaint_label_id)
#  index_conversation_risk_monitor_configs_on_critical_label_id   (critical_label_id)
#  index_conversation_risk_monitor_configs_on_inbox_id            (inbox_id) UNIQUE
#  index_conversation_risk_monitor_configs_on_management_team_id  (management_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (complaint_label_id => labels.id)
#  fk_rails_...  (critical_label_id => labels.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (management_team_id => teams.id)
#
class ConversationRiskMonitorConfig < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :management_team, class_name: 'Team', optional: true
  belongs_to :complaint_label, class_name: 'Label', optional: true
  belongs_to :critical_label, class_name: 'Label', optional: true

  validates :inbox_id, uniqueness: true
  validates :management_team, :complaint_label, :critical_label, presence: true, if: :enabled?
  validate :inbox_must_be_whatsapp
  validate :resources_must_belong_to_account

  def operational?
    account_enabled = ActiveModel::Type::Boolean.new.cast(account.conversation_risk_monitor_enabled)
    enabled? && account_enabled && valid?
  end

  private

  def inbox_must_be_whatsapp
    errors.add(:inbox, 'must be a WhatsApp inbox') if inbox.present? && !inbox.whatsapp?
  end

  def resources_must_belong_to_account
    validate_account(:inbox, inbox)
    validate_account(:management_team, management_team)
    validate_account(:complaint_label, complaint_label)
    validate_account(:critical_label, critical_label)
  end

  def validate_account(attribute, resource)
    return if resource.blank? || resource.account_id == account_id

    errors.add(attribute, 'must belong to the same account')
  end
end
