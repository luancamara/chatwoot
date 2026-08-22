# == Schema Information
#
# Table name: ad_conversions
#
#  id                          :bigint           not null, primary key
#  erp_status                  :integer
#  erp_order_ref               :string           not null
#  last_observed_at            :datetime         not null
#  ordered_at                  :datetime         not null
#  origin_classification       :string           default("unknown"), not null
#  origin_data                 :jsonb            not null
#  status                      :string           not null
#  user_data                   :jsonb            not null
#  value                       :decimal(12, 2)   default(0.0), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  conversation_ad_referral_id :bigint
#
# Indexes
#
#  index_ad_conversions_on_account_id                 (account_id)
#  index_ad_conversions_on_account_id_and_ordered_at  (account_id,ordered_at)
#  index_ad_conversions_on_referral                   (conversation_ad_referral_id)
#  index_ad_conversions_on_account_and_order           (account_id,erp_order_ref) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_ad_referral_id => conversation_ad_referrals.id)
#
class AdConversion < ApplicationRecord
  belongs_to :account
  belongs_to :conversation_ad_referral, optional: true
  has_many :deliveries, class_name: 'AdConversionDelivery', dependent: :destroy

  # Cancelamentos são guardados, não descartados: 5% dos pedidos são cancelados
  # e precisam sair da receita em vez de nunca terem existido.
  enum status: { sold: 'sold', cancelled: 'cancelled' }
  enum origin_classification: { unknown: 'unknown', physical_store: 'physical_store', ecommerce: 'ecommerce' }

  validates :erp_order_ref, presence: true, uniqueness: { scope: :account_id }
  validates :last_observed_at, presence: true

  scope :revenue, -> { sold }

  def delivery_for(provider)
    deliveries.find_or_create_by!(provider: provider)
  end
end
