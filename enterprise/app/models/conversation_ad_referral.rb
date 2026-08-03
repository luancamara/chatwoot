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

  scope :from_ads, -> { where(source_type: 'ad') }

  # The creative preview Meta ships inside the webhook payload. Available even
  # when the ad has not been enriched from the Graph API yet.
  def payload_thumbnail_url
    raw['thumbnail_url'].presence || raw['image_url'].presence
  end
end
