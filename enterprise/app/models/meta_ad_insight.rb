# == Schema Information
#
# Table name: meta_ad_insights
#
#  id          :bigint           not null, primary key
#  clicks      :integer          default(0), not null
#  date        :date             not null
#  impressions :integer          default(0), not null
#  reach       :integer          default(0), not null
#  spend       :decimal(12, 2)   default(0.0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  ad_id       :string           not null
#
# Indexes
#
#  index_meta_ad_insights_on_ad_id_and_date  (ad_id,date) UNIQUE
#  index_meta_ad_insights_on_date            (date)
#
class MetaAdInsight < ApplicationRecord
  belongs_to :meta_ad, primary_key: :ad_id, foreign_key: :ad_id, optional: true, inverse_of: :insights

  validates :ad_id, presence: true
  validates :date, uniqueness: { scope: :ad_id }

  scope :in_period, ->(range) { where(date: range) }
end
