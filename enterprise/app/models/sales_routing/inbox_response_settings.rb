module SalesRouting::InboxResponseSettings
  extend ActiveSupport::Concern

  included do
    enum :response_reassignment_mode, { disabled: 0, first_response: 1, all_responses: 2 }, prefix: :response_reassignment
    belongs_to :response_reassignment_notify_user, class_name: 'User', optional: true
    has_many :conversation_response_timers, dependent: :delete_all
    validate :validate_response_reassignment_settings
    before_save :track_response_attempts_coverage,
                if: -> { will_save_change_to_response_reassignment_mode? || will_save_change_to_enable_auto_assignment? }
    after_update :clear_response_timers, if: :saved_change_to_response_reassignment_mode?
    after_save :track_response_attempts_period, if: :saved_change_to_response_attempts_tracked_since?
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
                 I18n.t('errors.response_reassignment.requires_store_routing_and_business_hours'))
    end
    return if account.account_users.administrator.exists?(user_id: response_reassignment_notify_user_id)

    errors.add(:response_reassignment_notify_user, I18n.t('errors.response_reassignment.administrator_required'))
  end

  # Gate for collecting deadline history (start of the current tracking period). Turning monitoring off ends it and
  # turning it back on restarts it; the first activation after deploy is set explicitly once every process runs this code.
  def track_response_attempts_coverage
    monitored = !response_reassignment_disabled? && enable_auto_assignment?
    self.response_attempts_tracked_since = (response_attempts_tracked_since || Time.current if monitored)
  end

  # Opening coverage starts a tracking period; ending it closes the period and settles open windows right away, so a
  # deadline job running later cannot charge a breach for time in which monitoring was already off.
  def track_response_attempts_period
    open_period = ResponseTrackingPeriod.open.find_by(inbox_id: id)
    if response_attempts_tracked_since
      ResponseTrackingPeriod.create!(account_id: account_id, inbox_id: id, started_at: response_attempts_tracked_since) unless open_period
    else
      ConversationResponseAttempt.open.where(inbox_id: id).find_each { |attempt| attempt.finish!('settings_changed') }
      open_period&.update!(ended_at: Time.current)
    end
  end

  def clear_response_timers
    ConversationResponseAttempt.open.where(inbox_id: id).find_each { |attempt| attempt.finish!('settings_changed') }
    conversation_response_timers.delete_all
  end
end
