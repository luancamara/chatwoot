# == Schema Information
#
# Table name: scheduled_messages
#
#  id                 :bigint           not null, primary key
#  content            :text             not null
#  content_attributes :jsonb
#  scheduled_at       :datetime         not null
#  status             :integer          default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  conversation_id    :bigint           not null
#  inbox_id           :bigint           not null
#  sender_id          :bigint           not null
#
# Indexes
#
#  index_scheduled_messages_on_account_id                  (account_id)
#  index_scheduled_messages_on_conversation_id             (conversation_id)
#  index_scheduled_messages_on_conversation_id_and_status  (conversation_id,status)
#  index_scheduled_messages_on_inbox_id                    (inbox_id)
#  index_scheduled_messages_on_scheduled_at_and_status     (scheduled_at,status)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (sender_id => users.id)
#
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
