class SalesRouting::ResponseReassignmentService < AutoAssignment::AssignmentService
  def perform_timeout(timer_id)
    Current.executed_by = inbox.assignment_policy
    inbox.with_lock do
      watch = ConversationResponseTimer.find_by(id: timer_id)
      next unless watch

      conversation = inbox.conversations.lock.find_by(id: watch.conversation_id)
      watch = ConversationResponseTimer.find_by(id: timer_id)
      next unless conversation && watch

      process_watch(watch, conversation)
    end
  ensure
    Current.executed_by = nil
  end

  private

  def process_watch(watch, conversation)
    return watch.destroy! unless valid_window?(watch, conversation)
    return unless watch.due_at && watch.due_at <= Time.current && inbox.working_now?

    expire_response(watch, conversation)
  end

  def valid_window?(watch, conversation)
    return false unless inbox.response_reassignment_active? && store_routing.response_owner?(conversation)
    return false unless watch.assignee_id == conversation.assignee_id
    return false unless response_kind_allowed?(watch, conversation) && conversation.sla_applicable?

    SalesRouting::ResponseTracker.new(conversation: conversation).unanswered?(watch)
  end

  def response_kind_allowed?(watch, conversation)
    return conversation.first_reply_created_at.nil? if watch.response_kind == 'first_response'

    inbox.response_reassignment_all_responses?
  end

  def expire_response(watch, conversation)
    notify_manager(watch, conversation)
    agents = filter_agents_by_role(inbox.available_agents).where.not(user_id: watch.attempted_agent_ids | [conversation.assignee_id])
    agents = filter_agents_by_team(agents, conversation)
    eligible = policy_eligible_agents(agents)
    agent = SalesRouting::AgentSelector.new(conversation: conversation, configuration: store_routing, round: []).select(eligible)
    return unless agent

    route = conversation.additional_attributes.fetch(SalesRouting::Classifier::ATTRIBUTES_KEY)
    attributes = conversation.additional_attributes.merge(SalesRouting::Classifier::ATTRIBUTES_KEY => route.merge(
      'assignment_rule' => 'response-timeout', 'response_kind' => watch.response_kind
    ))
    conversation.update!(assignee: agent, additional_attributes: attributes)
    build_rate_limiter(agent).track_assignment(conversation)
  end

  def notify_manager(watch, conversation)
    return if watch.notified_assignee_id == conversation.assignee_id

    type = watch.response_kind == 'first_response' ? 'sla_missed_first_response' : 'sla_missed_next_response'
    NotificationBuilder.new(notification_type: type, user: inbox.response_reassignment_notify_user,
                            account: inbox.account, primary_actor: conversation, secondary_actor: inbox.assignment_policy).perform
    watch.update!(notified_assignee_id: conversation.assignee_id)
  end
end
