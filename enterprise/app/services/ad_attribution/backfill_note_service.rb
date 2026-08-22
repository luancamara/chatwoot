# Writes the ad origin note onto a conversation that was attributed before the
# note existed.
#
# Unlike the live path this inserts without callbacks: a normal create would
# broadcast to open dashboards, bump last_activity_at and reorder the inbox, and
# reopen conversations that were already resolved. Replaying that across
# thousands of closed threads would read as a flood of new activity.
class AdAttribution::BackfillNoteService
  pattr_initialize [:referral!, { body_limit: 220 }]

  def perform
    return if conversation.blank? || note_exists?

    note = insert_note
    AdAttribution::AttachCreativeService.new(message: note, ad_id: referral.ad_id).perform
    note
  end

  private

  def insert_note
    row = Message.insert_all!( # rubocop:disable Rails/SkipsModelValidations
      [{
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        conversation_id: conversation.id,
        message_type: Message.message_types[:outgoing],
        private: true,
        content: content,
        created_at: referral.referred_at - 1.second,
        updated_at: Time.current
      }]
    ).first

    Message.find(row['id'])
  end

  def content
    payload = AdAttribution::ReferralPayload.new(referral.raw)
    AdAttribution::ReferralNoteBuilder.new(payload: payload, body_limit: body_limit).content
  end

  def note_exists?
    conversation.messages.where(private: true).exists?(['content LIKE ?', '%veio de anúncio%'])
  end

  def conversation
    @conversation ||= referral.conversation
  end
end
