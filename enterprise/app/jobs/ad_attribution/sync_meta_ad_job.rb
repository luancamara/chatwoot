class AdAttribution::SyncMetaAdJob < ApplicationJob
  queue_as :low

  RETRY_AFTER = 6.hours

  def perform(ad_id)
    return if MetaAd.synced_ok.exists?(ad_id: ad_id)
    # A failed sync is retried later: rate limits and token rotations are
    # transient, and skipping forever would leave the ad permanently unnamed.
    return if MetaAd.exists?(ad_id: ad_id, synced_at: RETRY_AFTER.ago..)

    # The sync returns the video source when the token could resolve one; the
    # creative job falls back to the payload still otherwise. It runs after the
    # sync so the MetaAd row exists, including when the sync only recorded an error.
    video_url = AdAttribution::MetaAdSyncService.new(ad_id: ad_id).perform
    AdAttribution::StoreCreativeJob.perform_later(ad_id, video_url)
  end
end
