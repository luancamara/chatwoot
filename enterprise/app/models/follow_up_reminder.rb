class FollowUpReminder < ApplicationRecord
  belongs_to :conversation
  belongs_to :account
  belongs_to :user

  enum :reminder_type, { manual: 0, auto_d1: 1, auto_d3: 2, auto_d7: 3 }
  enum :status, { pending: 0, triggered: 1, dismissed: 2 }

  validates :remind_at, presence: true

  scope :due, -> { pending.where('remind_at <= ?', Time.current) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
end
