# Promotes the raw referral Meta ships on an inbound message into a queryable
# row on the conversation, so ad performance can be reported on.
#
# First touch wins: a later ad click into an already attributed conversation is
# kept on the message but does not overwrite the conversation's origin.
class AdAttribution::RecordReferralService
  pattr_initialize [:message!]

  def perform
    return if payload.source_type.blank?
    return if conversation.conversation_ad_referral.present?

    referral = build_referral
    AdAttribution::SyncMetaAdJob.perform_later(referral.ad_id) if referral.ad_id.present?
    referral
  end

  private

  def build_referral
    ConversationAdReferral.create!(
      payload.to_attributes.merge(
        account_id: message.account_id,
        conversation_id: conversation.id,
        inbox_id: message.inbox_id,
        contact_id: conversation.contact_id,
        referred_at: message.created_at
      )
    )
  end

  def payload
    @payload ||= AdAttribution::ReferralPayload.new(message.content_attributes['referral'])
  end

  def conversation
    @conversation ||= message.conversation
  end
end
