class ConversationEvaluationReport < ApplicationRecord
  VALID_REPORT_TYPES = %w[agent_weekly management_weekly management_monthly].freeze

  belongs_to :account
  belongs_to :user, optional: true

  validates :report_type, presence: true, inclusion: { in: VALID_REPORT_TYPES }
  validates :period_start, presence: true
  validates :period_end, presence: true

  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_type, ->(report_type) { where(report_type: report_type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :in_period, ->(start_date, end_date) { where(period_start: start_date..end_date) }
end
