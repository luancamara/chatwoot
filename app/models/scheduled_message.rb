class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox
  belongs_to :sender, class_name: 'User'

  enum status: { pending: 0, sent: 1, failed: 2, cancelled: 3 }

  validates :content, presence: true
  validates :scheduled_at, presence: true
  validate :scheduled_at_in_future, on: :create

  scope :ready_to_send, -> { pending.where('scheduled_at <= ?', Time.current) }

  private

  def scheduled_at_in_future
    return if scheduled_at.blank?

    errors.add(:scheduled_at, 'must be in the future') if scheduled_at <= Time.current
  end
end
