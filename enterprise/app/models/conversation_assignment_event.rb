class ConversationAssignmentEvent < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :conversation, optional: true

  validates :account_id, :conversation_id, :agent_id, :inbox_id, :conversation_display_id, :agent_name, :assigned_at, :source, presence: true
  validates :event_kind, inclusion: { in: %w[initial reassignment] }

  scope :pending, -> { where(synced_at: nil) }

  after_create_commit :enqueue_sync

  private

  def enqueue_sync
    SalesRouting::SyncAssignmentsJob.perform_later
  end
end
