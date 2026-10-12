class SalesRouting::ResponseTracker
  pattr_initialize [:conversation!]

  def customer_message(message)
    return unless response_kind
    return if timer

    watch = ConversationResponseTimer.create!(conversation: conversation, inbox: conversation.inbox,
                                              waiting_since: message.created_at, customer_message_id: message.id, response_kind: response_kind)
    watch.arm!(start_time: message.created_at) if human_owner?
  end

  def human_reply
    timer&.destroy!
  end

  def conversation_changed
    return human_reply unless conversation.open?
    return human_reply if manual_transfer?

    watch = timer || first_response_watch
    watch&.arm! if human_owner?
  end

  def unanswered?(watch)
    replies = conversation.messages.outgoing.where(private: false)
    replies = replies.where('id > ?', watch.customer_message_id) unless watch.response_kind == 'first_response'
    replies.includes(:sender).none?(&:response_reassignment_human_reply?)
  end

  private

  def timer
    ConversationResponseTimer.find_by(conversation_id: conversation.id)
  end

  def response_kind
    replied = conversation.first_reply_created_at.present? ||
              conversation.messages.outgoing.where(private: false).includes(:sender).any?(&:response_reassignment_human_reply?)
    return 'first_response' unless replied
    return 'next_response' if conversation.inbox.response_reassignment_all_responses?
  end

  def human_owner?
    SalesRouting::Configuration.new(inbox: conversation.inbox).response_owner?(conversation)
  end

  def manual_transfer?
    return false if Current.executed_by.is_a?(AssignmentPolicy)

    conversation.assignee_id_before_last_save.present? && (conversation.saved_change_to_assignee_id? || conversation.saved_change_to_team_id?)
  end

  def first_response_watch
    return unless response_kind == 'first_response'
    return unless Current.executed_by.is_a?(AssignmentPolicy)

    first_message = conversation.messages.incoming.where(private: false).order(:created_at, :id).first
    return if first_message.nil?

    ConversationResponseTimer.create!(conversation: conversation, inbox: conversation.inbox,
                                      waiting_since: first_message.created_at, customer_message_id: first_message.id, response_kind: 'first_response')
  end
end
