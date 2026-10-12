module SalesRouting::ResponseTracking
  extend ActiveSupport::Concern

  included do
    has_one :conversation_response_timer, dependent: :destroy
    after_save :track_response_ownership, if: -> { saved_change_to_assignee_id? || saved_change_to_team_id? || saved_change_to_status? }
  end

  private

  def track_response_ownership
    return unless inbox.response_reassignment_active?

    SalesRouting::ResponseTracker.new(conversation: self).conversation_changed
  end
end
