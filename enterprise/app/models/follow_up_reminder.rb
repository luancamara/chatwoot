# == Schema Information
#
# Table name: follow_up_reminders
#
#  id              :bigint           not null, primary key
#  notes           :text
#  remind_at       :datetime         not null
#  reminder_type   :integer          default("manual"), not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_follow_up_reminders_on_account_id            (account_id)
#  index_follow_up_reminders_on_conversation_id       (conversation_id)
#  index_follow_up_reminders_on_remind_at_and_status  (remind_at,status)
#  index_follow_up_reminders_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#
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
