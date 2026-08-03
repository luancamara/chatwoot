class AdAttribution::SyncMetaAdJob < ApplicationJob
  queue_as :low

  def perform(ad_id)
    return if MetaAd.where(ad_id: ad_id).where.not(synced_at: nil).exists?

    AdAttribution::MetaAdSyncService.new(ad_id: ad_id).perform
  end
end
