# == Schema Information
#
# Table name: conversation_evaluation_reports
#
#  id           :bigint           not null, primary key
#  data         :jsonb
#  period_end   :date             not null
#  period_start :date             not null
#  report_type  :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  user_id      :bigint
#
# Indexes
#
#  idx_eval_reports_unique  (account_id,user_id,report_type,period_start) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
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
