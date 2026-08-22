class AdAttribution::StoreCreativeJob < ApplicationJob
  queue_as :low

  def perform(ad_id, url = nil)
    AdAttribution::StoreCreativeService.new(ad_id: ad_id, url: url).perform
  end
end
