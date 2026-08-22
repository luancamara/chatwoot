class AdAttribution::ReconcileOrdersDailySchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AdAttribution::ReconcileOrdersSchedulerJob.perform_later(since: 90.days.ago, until_time: Time.current)
  end
end
