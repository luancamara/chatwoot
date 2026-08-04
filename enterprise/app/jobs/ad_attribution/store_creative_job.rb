class AdAttribution::StoreCreativeJob < ApplicationJob
  queue_as :low

  def perform(ad_id, url = nil)
    AdAttribution::StoreCreativeService.new(ad_id: ad_id, url: url).perform
  rescue Down::Error => e
    # Expected for ads whose creative Meta has already expired or removed.
    Rails.logger.warn "[ad_attribution] creative #{ad_id}: #{e.message}"
  end
end
