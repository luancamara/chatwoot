class AdAttribution::ReconcileOrdersJob < ApplicationJob
  queue_as :low

  def perform(account, since: 2.hours.ago, until_time: Time.current)
    stats = AdAttribution::SyncSalesService.new(account: account, since: since, until_time: until_time).perform
    Rails.logger.info "[ad_attribution] account=#{account.id} fetched=#{stats[:fetched]} created=#{stats[:created]}"
  end
end
