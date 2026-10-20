class ConversationResponseTimer < ApplicationRecord
  TIMEOUT = 10.minutes

  belongs_to :conversation
  belongs_to :inbox
  validates :waiting_since, presence: true
  validates :response_kind, inclusion: { in: %w[first_response next_response] }

  scope :due, -> { where(due_at: ..Time.current) }
  after_save_commit :enqueue_deadline, if: -> { saved_change_to_due_at? && due_at.present? }
  # Explicit endings close the attempt first; any other removal (invalid window, conversation deletion) has no verdict.
  after_destroy -> { open_attempt&.finish!('ineligible') }

  def arm!(start_time: Time.current)
    update!(assignee_id: conversation.assignee_id, attempted_agent_ids: attempted_agent_ids | [conversation.assignee_id],
            due_at: Sla::BusinessHoursService.new(inbox: inbox, start_time: start_time, threshold_seconds: TIMEOUT).deadline)
    ConversationResponseAttempt.start!(self, started_at: start_time, due_at: due_at)
  end

  def open_attempt
    ConversationResponseAttempt.open.find_by(conversation_id: conversation_id)
  end

  def finish!(reason, message: nil)
    open_attempt&.finish!(reason, message: message)
    destroy!
  end

  private

  def enqueue_deadline
    SalesRouting::ReassignResponseJob.set(wait_until: due_at).perform_later(id)
  end
end
