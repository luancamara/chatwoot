# Durable history of each monitored response window. The live ConversationResponseTimer is deleted on reply, transfer or
# cancellation; this row keeps who owned the window, its deadline and how it ended, attributed to the owner at the deadline.
class ConversationResponseAttempt < ApplicationRecord
  OUTCOMES = %w[pending met breached answered_by_other canceled].freeze
  END_REASONS = %w[replied reassigned manual_transfer closed settings_changed ineligible].freeze
  # ReportingEventHelper#business_hours(inbox, from, to) must not be mixed into this model: it would shadow the
  # `business_hours` column reader.
  BUSINESS_TIME = Object.new.extend(ReportingEventHelper)

  # No associations with dependent behavior: history must survive conversation, inbox and user deletion.
  belongs_to :inbox, optional: true
  belongs_to :assignee, class_name: 'User', optional: true

  validates :outcome, inclusion: { in: OUTCOMES }
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true

  scope :open, -> { where(ended_at: nil) }

  # History is only collected while the inbox coverage is active (response_attempts_tracked_since), so windows are
  # never recorded by a deployment that cannot also close them.
  def self.start!(timer, started_at:, due_at:)
    previous = open.find_by(conversation_id: timer.conversation_id)
    # The same owner re-armed within the same customer wait keeps the deadline already charged to them.
    return if previous&.assignee_id == timer.assignee_id && previous.customer_message_id == timer.customer_message_id

    previous&.finish!('reassigned')
    return if timer.inbox.response_attempts_tracked_since.nil?

    create_for!(timer, started_at: started_at, due_at: due_at)
  end

  def self.create_for!(timer, started_at:, due_at:)
    conversation = timer.conversation
    create!(account_id: conversation.account_id, inbox_id: timer.inbox_id, conversation_id: conversation.id,
            conversation_display_id: conversation.display_id, team_id: conversation.team_id, assignee_id: timer.assignee_id,
            store_code: SalesRouting::Classifier.origin_store(conversation.additional_attributes[SalesRouting::Classifier::ATTRIBUTES_KEY]),
            response_kind: timer.response_kind, customer_message_id: timer.customer_message_id, waiting_since: timer.waiting_since,
            started_at: started_at, due_at: due_at, threshold_seconds: ConversationResponseTimer::TIMEOUT.to_i,
            business_hours: timer.inbox.working_hours_enabled?)
  end

  def breach!
    update!(outcome: 'breached') if outcome == 'pending'
  end

  # Any ending at or after the deadline is a breach for the owner, including a reply saved before the deadline job ran.
  # Before the deadline only the owner's own reply is credited; another person's reply and other endings carry no verdict.
  # An ineligible window is only detected by the deadline job, so it never adds a breach of its own: a real miss was
  # already recorded by `breach!` when the job last found the window valid and overdue.
  def finish!(reason, message: nil)
    at = message ? message.created_at : Time.current
    attributes = { end_reason: reason, ended_at: at, outcome: final_outcome(reason, at, message) }
    attributes.merge!(reply_attributes(message)) if message
    update!(attributes)
  end

  private

  def final_outcome(reason, at, message)
    return 'breached' if outcome == 'breached'
    return 'canceled' if reason == 'ineligible'
    return 'breached' if at >= due_at
    return 'canceled' unless message

    owner_reply?(message) ? 'met' : 'answered_by_other'
  end

  def owner_reply?(message)
    message.sender_type == 'User' && message.sender_id == assignee_id
  end

  def reply_attributes(message)
    { replied_at: message.created_at, reply_message_id: message.id, responder_id: (message.sender_id if message.sender_type == 'User'),
      response_seconds: elapsed_seconds(started_at, message.created_at), wait_seconds: elapsed_seconds(waiting_since, message.created_at) }
  end

  # Business seconds when the deadline used business hours, so durations read on the same clock as the deadline.
  def elapsed_seconds(from, to)
    return (to - from).to_i unless business_hours && inbox

    BUSINESS_TIME.business_hours(inbox, from, to).to_i
  end
end
