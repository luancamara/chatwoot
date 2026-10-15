class AddResponseAttemptsTrackedSinceToInboxes < ActiveRecord::Migration[7.2]
  # The column starts empty on purpose: deadline history is activated per inbox only after every web and worker process
  # runs the code that closes the windows it opens (see ConversationResponseAttempt.start!).
  def change
    add_column :inboxes, :response_attempts_tracked_since, :datetime
  end
end
