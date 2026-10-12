module SalesRouting::InboxResponseSettings
  extend ActiveSupport::Concern

  included do
    enum :response_reassignment_mode, { disabled: 0, first_response: 1, all_responses: 2 }, prefix: true
    belongs_to :response_reassignment_notify_user, class_name: 'User', optional: true
    has_many :conversation_response_timers, dependent: :delete_all
    validate :validate_response_reassignment_settings
    after_update :clear_response_timers, if: :saved_change_to_response_reassignment_mode?
  end

  def response_reassignment_available?
    SalesRouting::Configuration.new(inbox: self).enabled?
  end

  def response_reassignment_active?
    !response_reassignment_disabled? && response_reassignment_available? && auto_assignment_v2_enabled? && enable_auto_assignment?
  end

  private

  def validate_response_reassignment_settings
    return if response_reassignment_disabled?

    unless response_reassignment_available? && working_hours_enabled?
      errors.add(:response_reassignment_mode,
                 'requires store routing and business hours')
    end
    return if account.account_users.administrator.exists?(user_id: response_reassignment_notify_user_id)

    errors.add(:response_reassignment_notify_user, 'must be an administrator of this account')
  end

  def clear_response_timers
    conversation_response_timers.delete_all
  end
end
