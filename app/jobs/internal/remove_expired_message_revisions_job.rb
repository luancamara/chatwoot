class Internal::RemoveExpiredMessageRevisionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Captain::MessageRevision.where(created_at: ...Captain::MessageRevision::RETENTION.ago).in_batches.delete_all
  end
end
