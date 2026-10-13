module Enterprise::Concerns::AssignmentPolicy
  extend ActiveSupport::Concern

  included do
    enum assignment_order: { round_robin: 0, balanced: 1 } if ChatwootApp.enterprise?
    belongs_to :eligible_custom_role, class_name: 'CustomRole', optional: true
    validate :eligible_role_belongs_to_account
  end

  def push_event_data
    { id: id, name: name }
  end

  def to_drop
    BaseDrop.new(self)
  end

  private

  def eligible_role_belongs_to_account
    return if eligible_custom_role_id.nil? || eligible_custom_role&.account_id == account_id

    errors.add(:eligible_custom_role, I18n.t('errors.assignment_policy.eligible_role_account'))
  end
end
