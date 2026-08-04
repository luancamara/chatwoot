# Stores the ad creative locally, once per ad, so the gallery keeps working
# after Meta expires the CDN links or the ad is deleted.
#
# Without an ads token only the still is available: the webhook's `video_url` is
# a Facebook reel *page*, not a media file. The Graph API resolves the real
# video source and passes it in through `url`.
class AdAttribution::StoreCreativeService
  pattr_initialize [:ad_id!, { url: nil }]

  def perform
    return if meta_ad.blank? || meta_ad.creative.attached?

    source = url.presence || payload_image_url
    return if source.blank?

    file = Down.download(source, max_size: 100 * 1024 * 1024)
    # content_type has to be carried over or the browser will not play the video.
    meta_ad.creative.attach(
      io: file,
      filename: file.original_filename.presence || "ad_#{ad_id}",
      content_type: file.content_type
    )
  end

  private

  def payload_image_url
    referral = ConversationAdReferral.where(ad_id: ad_id)
                                     .where("raw->>'image_url' IS NOT NULL OR raw->>'thumbnail_url' IS NOT NULL")
                                     .order(referred_at: :desc)
                                     .first
    referral&.raw&.values_at('image_url', 'thumbnail_url')&.compact&.first
  end

  def meta_ad
    @meta_ad ||= MetaAd.find_by(ad_id: ad_id)
  end
end
