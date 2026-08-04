# == Schema Information
#
# Table name: meta_ads
#
#  id               :bigint           not null, primary key
#  adset_name       :string
#  campaign_name    :string
#  effective_status :string
#  name             :string
#  sync_error       :string
#  synced_at        :datetime
#  thumbnail_url    :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  ad_id            :string           not null
#  adset_id         :string
#  campaign_id      :string
#
# Indexes
#
#  index_meta_ads_on_ad_id  (ad_id) UNIQUE
#
class MetaAd < ApplicationRecord
  has_many :conversation_ad_referrals, primary_key: :ad_id, foreign_key: :ad_id, dependent: :nullify, inverse_of: :meta_ad
  has_one_attached :creative
  has_one_attached :poster

  validates :ad_id, presence: true, uniqueness: true
  # Graph API creative thumbnails carry long signed query strings, past the 255
  # ApplicationRecord applies to string columns without an explicit validator.
  validates :thumbnail_url, length: { maximum: Limits::URL_LENGTH_LIMIT }

  scope :synced_ok, -> { where.not(synced_at: nil).where(sync_error: nil) }
end
