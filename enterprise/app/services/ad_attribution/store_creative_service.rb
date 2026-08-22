# Stores the ad creative locally, once per ad, so the gallery keeps working
# after Meta expires the CDN links or the ad is deleted.
#
# Without an ads token only the still is available: the webhook's `video_url` is
# a Facebook reel *page*, not a media file. The Graph API resolves the real
# video source and passes it in through `url`.
class AdAttribution::StoreCreativeService
  pattr_initialize [:ad_id!, { url: nil }]

  def perform
    return if meta_ad.blank?

    store_creative
    store_poster
  end

  private

  def store_creative
    return if meta_ad.creative.attached?

    # Tried in order rather than picking one: Meta expires CDN links on older
    # ads, so the best available source is often already gone and the next one
    # still works. That expiry is the whole reason creatives are copied locally.
    sources.each do |source|
      file = download(source)
      next if file.blank?

      attach(meta_ad.creative, file)
      break
    end
  end

  # The video's cover, kept locally for the same reason as the video itself, and
  # only for videos since an image creative is its own poster.
  def store_poster
    return if meta_ad.poster.attached? || meta_ad.thumbnail_url.blank?
    return unless meta_ad.creative.attached? && meta_ad.creative.content_type.to_s.start_with?('video/')

    file = download(meta_ad.thumbnail_url)
    attach(meta_ad.poster, file) if file.present?
  end

  # content_type has to be carried over or the browser will not play a video.
  def attach(attachment, file)
    attachment.attach(
      io: file,
      filename: file.original_filename.presence || "ad_#{ad_id}",
      content_type: file.content_type
    )
  end

  def sources
    [url, payload_image_url, meta_ad.thumbnail_url].filter_map(&:presence)
  end

  def download(source)
    Down.download(source, max_size: 100 * 1024 * 1024)
  rescue Down::Error => e
    Rails.logger.warn "[ad_attribution] creative #{ad_id} from #{source[0, 60]}: #{e.message}"
    nil
  end

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
