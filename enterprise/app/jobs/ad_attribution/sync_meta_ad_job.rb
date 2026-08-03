class AdAttribution::SyncMetaAdJob < ApplicationJob
  queue_as :low

  RETRY_AFTER = 6.hours

  def perform(ad_id)
    return if MetaAd.synced_ok.exists?(ad_id: ad_id)
    # A failed sync is retried later: rate limits and token rotations are
    # transient, and skipping forever would leave the ad permanently unnamed.
    return if MetaAd.exists?(ad_id: ad_id, synced_at: RETRY_AFTER.ago..)

    AdAttribution::MetaAdSyncService.new(ad_id: ad_id).perform
  end
end
