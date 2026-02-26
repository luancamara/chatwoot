class ConversationInsight < ApplicationRecord
  VALID_SENTIMENTS = %w[positive neutral negative].freeze
  VALID_CLASSIFICATIONS = %w[complete_consultation quick_consultation return_client non_commercial].freeze
  VALID_ABANDONMENT_SEVERITIES = %w[light severe].freeze

  belongs_to :conversation
  belongs_to :account

  validates :quality_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
  validates :final_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
  validates :customer_sentiment, inclusion: { in: VALID_SENTIMENTS }, allow_nil: true
  validates :conversation_classification, inclusion: { in: VALID_CLASSIFICATIONS }, allow_nil: true
  validates :abandonment_severity, inclusion: { in: VALID_ABANDONMENT_SEVERITIES }, allow_nil: true

  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :with_quality_score, -> { where.not(quality_score: nil) }
  scope :with_final_score, -> { where.not(final_score: nil) }
  scope :no_response, -> { where(no_response: true) }
  scope :with_abandonment, -> { where.not(abandonment_severity: nil) }
  scope :by_classification, ->(classification) { where(conversation_classification: classification) }
  scope :in_period, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  scope :by_agent, lambda { |user_id|
    joins(:conversation).where(conversations: { assignee_id: user_id })
  }

  def tpr_seconds
    automatic_metrics&.dig('tpr_seconds')
  end

  def tpr_score
    automatic_metrics&.dig('tpr_score')
  end

  def tmer_seconds
    automatic_metrics&.dig('tmer_seconds')
  end
end
