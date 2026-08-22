# Promotes the raw referral Meta ships on an inbound message into a queryable
# row on the conversation, so ad performance can be reported on.
#
# Attribution is first touch: a later ad click into an already attributed
# conversation does not overwrite the conversation's origin, so a lead is never
# counted twice. The agent still sees every click, through the private note.
class AdAttribution::RecordReferralService
  pattr_initialize [:message!, { note: true }]

  def perform
    return if payload.source_type.blank?

    # Queried rather than read off the association, which the caller may already
    # have loaded as nil before the first referral was written.
    referral = ConversationAdReferral.find_by(conversation_id: conversation.id) || build_referral
    AdAttribution::SyncMetaAdJob.perform_later(payload.ad_id) if payload.ad_id.present?
    post_note
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

  # Placed right before the message that carried the referral, so a returning
  # lead's origin reads in timeline order rather than at the top of the thread.
  def post_note
    return unless note

    note_message = conversation.messages.create!(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      message_type: :outgoing,
      private: true,
      content: AdAttribution::ReferralNoteBuilder.new(payload: payload).content,
      created_at: message.created_at - 1.second
    )
    AdAttribution::AttachCreativeService.new(message: note_message, ad_id: payload.ad_id).perform
  end

  def payload
    @payload ||= AdAttribution::ReferralPayload.new(message.content_attributes['referral'])
  end

  def conversation
    @conversation ||= message.conversation
  end
end
