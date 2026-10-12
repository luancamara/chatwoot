class SalesRouting::ReassignResponseJob < ApplicationJob
  queue_as :default

  def perform(timer_id)
    timer = ConversationResponseTimer.find_by(id: timer_id)
    return unless timer

    SalesRouting::ResponseReassignmentService.new(inbox: timer.inbox).perform_timeout(timer_id)
  end
end
