# Puts the ad creative on the referral note so the agent sees what the customer
# just clicked without leaving the conversation.
#
# Always an image: notes render attachments as images, and shipping the video
# itself would push several megabytes into every conversation. The blob stored
# on the MetaAd is reused, so one file backs every note for the same ad.
class AdAttribution::AttachCreativeService
  pattr_initialize [:message!, :ad_id]

  def perform
    return if ad_id.blank? || blob.blank?
    return if message.attachments.any? { |a| a.file.attached? && a.file.blob_id == blob.id }

    message.attachments.destroy_all
    attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
    attachment.file.attach(blob)
    attachment.save!
  end

  private

  # The poster for a video ad, the creative itself for an image ad.
  def blob
    return @blob if defined?(@blob)

    meta_ad = MetaAd.find_by(ad_id: ad_id)
    @blob = if meta_ad.blank?
              nil
            elsif meta_ad.poster.attached?
              meta_ad.poster.blob
            elsif meta_ad.creative.attached? && meta_ad.creative.content_type.to_s.start_with?('image/')
              meta_ad.creative.blob
            end
  end
end
