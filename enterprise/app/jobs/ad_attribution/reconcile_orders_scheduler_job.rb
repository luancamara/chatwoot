class AdAttribution::ReconcileOrdersSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(since: 2.hours.ago, until_time: Time.current)
    return unless AdAttribution::Config.sync_enabled?

    eligible_accounts.find_each(batch_size: 50) do |account|
      AdAttribution::ReconcileOrdersJob.perform_later(account, since: since, until_time: until_time)
    end
  end

  private

  def eligible_accounts
    Account.where(id: AdAttribution::Config.account_id)
  end
end
