# The ad gallery salespeople browse to answer "what did this ad promise?".
#
# Ad copy and creative come from the webhook payload, so the gallery is useful
# before an ads token is configured; the Graph API only adds the real ad, ad set
# and campaign names on top.
class V2::AdReports::GalleryBuilder
  pattr_initialize [:account!]

  def build
    ads = referrals_by_ad.map { |ad_id, referrals| present(ad_id, referrals) }
    ads.sort_by { |ad| -ad[:last_seen_at] }
  end

  private

  def present(ad_id, referrals)
    latest = referrals.max_by(&:referred_at)
    meta_ad = meta_ads[ad_id]

    ad_metadata(meta_ad).merge(
      ad_id: ad_id,
      headline: latest.headline,
      body: latest.body,
      source_url: latest.source_url,
      media_type: latest.raw['media_type'],
      video_page_url: latest.raw['video_url'],
      creative_url: creative_url(meta_ad),
      creative_type: meta_ad&.creative&.attached? ? meta_ad.creative.content_type : nil,
      thumbnail_url: poster_url(meta_ad) || latest.payload_thumbnail_url,
      first_seen_at: referrals.min_by(&:referred_at).referred_at.to_i,
      last_seen_at: latest.referred_at.to_i
    )
  end

  def ad_metadata(meta_ad)
    {
      ad_name: meta_ad&.name,
      campaign_name: meta_ad&.campaign_name,
      adset_name: meta_ad&.adset_name,
      effective_status: meta_ad&.effective_status
    }
  end

  def referrals_by_ad
    @referrals_by_ad ||= ConversationAdReferral.from_ads
                                               .where(account_id: account.id)
                                               .where.not(ad_id: nil)
                                               .group_by(&:ad_id)
  end

  def meta_ads
    @meta_ads ||= MetaAd.where(ad_id: referrals_by_ad.keys)
                        .includes(creative_attachment: :blob, poster_attachment: :blob)
                        .index_by(&:ad_id)
  end

  def creative_url(meta_ad)
    blob_path(meta_ad&.creative)
  end

  # Served from local storage rather than Meta's CDN, which expires its links.
  def poster_url(meta_ad)
    blob_path(meta_ad&.poster) || meta_ad&.thumbnail_url.presence
  end

  def blob_path(attachment)
    return if attachment.blank? || !attachment.attached?

    Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)
  end
end
