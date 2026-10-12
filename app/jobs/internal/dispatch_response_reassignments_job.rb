class Internal::DispatchResponseReassignmentsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless ChatwootApp.enterprise?

    ConversationResponseTimer.due.find_each { |timer| SalesRouting::ReassignResponseJob.perform_later(timer.id) }
  end
end
