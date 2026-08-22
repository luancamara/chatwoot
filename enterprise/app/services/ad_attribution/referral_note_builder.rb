# Builds the private note that tells the agent which ad brought the lead in.
#
# The ad body carries the commercial terms the customer just read ("Por 12x de
# R$257,00", "à pronta entrega"), which is what they will hold the agent to, so
# it leads the note. Built from the payload rather than the stored referral so a
# returning lead's note describes the ad they just clicked, not the first one.
class AdAttribution::ReferralNoteBuilder
  pattr_initialize [:payload!, { body_limit: nil }]

  def content
    [heading, ad_body, details].compact.join("\n\n")
  end

  private

  # Backfilled notes are trimmed: replaying a full ad copy across thousands of
  # closed conversations buries the history it is meant to explain.
  def ad_body
    text = payload.body.presence
    return text if text.blank? || body_limit.blank?

    text.truncate(body_limit, separator: ' ')
  end

  # The webhook headline is the call-to-action Meta renders on the ad ("Converse
  # conosco"), identical across every ad, so it is not used as a title. Only a
  # name resolved from the Graph API identifies the ad.
  def heading
    heading = "**#{I18n.t('conversations.ad_referral.heading')}**"
    meta_ad&.name.presence ? "#{heading} · #{meta_ad.name}" : heading
  end

  def details
    lines = []
    lines << "#{I18n.t('conversations.ad_referral.campaign')}: #{meta_ad.campaign_name}" if meta_ad&.campaign_name.present?
    lines << "#{I18n.t('conversations.ad_referral.adset')}: #{meta_ad.adset_name}" if meta_ad&.adset_name.present?
    lines << "[#{I18n.t('conversations.ad_referral.view_ad')}](#{payload.source_url})" if payload.source_url.present?
    lines.presence&.join("\n")
  end

  def meta_ad
    return @meta_ad if defined?(@meta_ad)

    @meta_ad = payload.ad_id.present? ? MetaAd.find_by(ad_id: payload.ad_id) : nil
  end
end
