# Puts the ad creative on the referral note so the agent sees what the customer
# just clicked without leaving the conversation.
#
# The blob stored on the MetaAd is reused rather than downloaded again, so one
# file backs every note for the same ad.
class AdAttribution::AttachCreativeService
  pattr_initialize [:message!, :ad_id]

  def perform
    return if ad_id.blank?

    meta_ad = MetaAd.find_by(ad_id: ad_id)
    return if meta_ad.blank? || !meta_ad.creative.attached?

    attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
    attachment.file.attach(meta_ad.creative.blob)
    attachment.save!
  end
end
