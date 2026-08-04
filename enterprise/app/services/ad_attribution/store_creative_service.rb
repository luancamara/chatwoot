# Stores the ad creative locally, once per ad.
#
# The video and image URLs come from the webhook payload rather than the Graph
# API, so creatives are available without an ads token. They point at Meta's CDN
# and are downloaded so the gallery keeps working after Meta expires them or the
# ad is deleted.
class AdAttribution::StoreCreativeService
  pattr_initialize [:ad_id!]

  def perform
    return if meta_ad.blank? || meta_ad.creative.attached?

    url = source_url
    return if url.blank?

    file = Down.download(url, max_size: 100 * 1024 * 1024)
    # content_type has to be carried over or the browser will not play the video.
    meta_ad.creative.attach(
      io: file,
      filename: file.original_filename.presence || "ad_#{ad_id}",
      content_type: file.content_type
    )
  end

  private

  def source_url
    referral = ConversationAdReferral.where(ad_id: ad_id)
                                     .where("raw->>'video_url' IS NOT NULL OR raw->>'image_url' IS NOT NULL")
                                     .order(referred_at: :desc)
                                     .first
    referral&.raw&.values_at('video_url', 'image_url')&.compact&.first
  end

  def meta_ad
    @meta_ad ||= MetaAd.find_by(ad_id: ad_id)
  end
end
