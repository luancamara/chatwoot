class AdAttribution::StoreCreativeJob < ApplicationJob
  queue_as :low

  def perform(ad_id)
    AdAttribution::StoreCreativeService.new(ad_id: ad_id).perform
  end
end
