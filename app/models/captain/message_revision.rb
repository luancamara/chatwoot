class Captain::MessageRevision < ApplicationRecord
  self.table_name = 'captain_message_revisions'

  RETENTION = 30.days

  belongs_to :account, class_name: '::Account'
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :user, class_name: '::User', optional: true

  validates :request_id, :original_content, presence: true
  validates :outcome, inclusion: { in: %w[pending accepted unchanged rejected skipped error] }

  def self.validate_message!(message, user)
    revision_id = message.content_attributes['grammar_revision_id']
    return if revision_id.blank?

    raise ArgumentError, 'Grammar revisions require an outgoing agent reply' unless message.outgoing? && !message.private? && user.is_a?(::User)

    where(account_id: message.account_id, conversation_id: message.conversation_id, user: user).find(revision_id)
  end
end
