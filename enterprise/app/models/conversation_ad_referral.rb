# == Schema Information
#
# Table name: conversation_ad_referrals
#
#  id              :bigint           not null, primary key
#  body            :text
#  ctwa_clid       :string
#  headline        :string
#  raw             :jsonb            not null
#  referred_at     :datetime         not null
#  source_type     :string
#  source_url      :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  ad_id           :string
#  contact_id      :bigint
#  conversation_id :bigint           not null
#  inbox_id        :bigint           not null
#  source_id       :string
#
# Indexes
#
#  idx_on_account_id_ad_id_referred_at_3ea94c2fcc      (account_id,ad_id,referred_at)
#  index_conversation_ad_referrals_on_account_id       (account_id)
#  index_conversation_ad_referrals_on_contact_id       (contact_id)
#  index_conversation_ad_referrals_on_conversation_id  (conversation_id) UNIQUE
#  index_conversation_ad_referrals_on_inbox_id         (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class ConversationAdReferral < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox
  belongs_to :contact, optional: true
  belongs_to :meta_ad, primary_key: :ad_id, foreign_key: :ad_id, optional: true, inverse_of: :conversation_ad_referrals

  validates :conversation_id, uniqueness: true
  validates :source_url, length: { maximum: Limits::URL_LENGTH_LIMIT }

  scope :from_ads, -> { where(source_type: 'ad') }

  # The creative preview Meta ships inside the webhook payload. Available even
  # when the ad has not been enriched from the Graph API yet.
  def payload_thumbnail_url
    raw['thumbnail_url'].presence || raw['image_url'].presence
  end

  def push_event_data
    {
      source_type: source_type,
      ad_id: ad_id,
      source_url: source_url,
      headline: headline,
      body: body,
      ctwa_clid: ctwa_clid,
      referred_at: referred_at.to_i,
      thumbnail_url: meta_ad&.thumbnail_url.presence || payload_thumbnail_url
    }.merge(meta_ad_event_data)
  end

  private

  def meta_ad_event_data
    return {} if meta_ad.blank?

    {
      ad_name: meta_ad.name,
      adset_name: meta_ad.adset_name,
      campaign_name: meta_ad.campaign_name,
      effective_status: meta_ad.effective_status,
      sync_error: meta_ad.sync_error
    }
  end
end
