class ConversationResponseTimer < ApplicationRecord
  TIMEOUT = 5.minutes

  belongs_to :conversation
  belongs_to :inbox
  validates :waiting_since, presence: true
  validates :response_kind, inclusion: { in: %w[first_response next_response] }

  scope :due, -> { where(due_at: ..Time.current) }
  after_save_commit :enqueue_deadline, if: -> { saved_change_to_due_at? && due_at.present? }

  def arm!(start_time: Time.current)
    update!(assignee_id: conversation.assignee_id, attempted_agent_ids: attempted_agent_ids | [conversation.assignee_id],
            due_at: Sla::BusinessHoursService.new(inbox: inbox, start_time: start_time, threshold_seconds: TIMEOUT).deadline)
  end

  private

  def enqueue_deadline
    SalesRouting::ReassignResponseJob.set(wait_until: due_at).perform_later(id)
  end
end
