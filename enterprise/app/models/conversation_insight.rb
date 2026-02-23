class ConversationInsight < ApplicationRecord
  VALID_SENTIMENTS = %w[positive neutral negative].freeze

  belongs_to :conversation
  belongs_to :account

  validates :quality_score, numericality: { in: 1..10 }, allow_nil: true
  validates :customer_sentiment, inclusion: { in: VALID_SENTIMENTS }, allow_nil: true

  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :with_quality_score, -> { where.not(quality_score: nil) }
end
