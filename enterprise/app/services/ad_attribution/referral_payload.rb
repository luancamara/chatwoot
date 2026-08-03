# Normalizes the two shapes Meta uses for ad attribution into one set of keys.
#
# WhatsApp (Cloud and Twilio) sends `source_id` / `source_type` / `headline`,
# while Messenger and Instagram send `ad_id` / `source` / `ads_context_data`.
class AdAttribution::ReferralPayload
  def initialize(referral)
    @referral = referral.to_h.with_indifferent_access
  end

  def ad?
    source_type == 'ad'
  end

  def ad_id
    @referral[:ad_id].presence || (ad? ? @referral[:source_id] : nil)
  end

  def source_type
    return @referral[:source_type] if @referral[:source_type].present?

    @referral[:source].to_s.casecmp('ads').zero? ? 'ad' : @referral[:source].presence
  end

  def source_id
    @referral[:source_id].presence || @referral[:ad_id]
  end

  def headline
    @referral[:headline].presence || @referral.dig(:ads_context_data, :ad_title)
  end

  def body
    @referral[:body]
  end

  def source_url
    @referral[:source_url]
  end

  def ctwa_clid
    @referral[:ctwa_clid]
  end

  def raw
    @referral
  end

  def to_attributes
    {
      source_type: source_type,
      source_id: source_id,
      ad_id: ad_id,
      ctwa_clid: ctwa_clid,
      source_url: source_url,
      headline: headline,
      body: body,
      raw: raw
    }
  end
end
