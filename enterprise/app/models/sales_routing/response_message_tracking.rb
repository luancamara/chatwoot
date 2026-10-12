module SalesRouting::ResponseMessageTracking
  extend ActiveSupport::Concern

  included do
    around_create :track_response_window, if: :response_window_message?
  end

  def response_reassignment_human_reply?
    !private? && human_response?
  end

  private

  def response_window_message?
    !private? && (incoming? || human_response?) && inbox.response_reassignment_active?
  end

  def track_response_window
    # Serialize committed replies with ownership changes; a stale deadline cannot overtake an already recorded reply.
    self.conversation = Conversation.lock.find(conversation_id)
    yield
    tracker = SalesRouting::ResponseTracker.new(conversation: conversation)
    incoming? ? tracker.customer_message(self) : tracker.human_reply
  end
end
