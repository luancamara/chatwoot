class Whatsapp::Triage::EscalationJob < ApplicationJob
  queue_as :medium

  def perform(conversation_id, cycle_id, kind, reference_id = nil, business_time_started: true)
    conversation = Conversation.find_by(id: conversation_id)
    return unless active_complaint?(conversation, cycle_id)

    configuration = Whatsapp::Triage::Configuration.new
    return unless configuration.operational_for?(conversation.inbox)

    return reschedule(conversation, cycle_id, kind, reference_id, business_time_started) if conversation.inbox.out_of_office?
    return restart_in_business_hours(conversation, cycle_id, kind, reference_id) unless business_time_started
    return unless escalation_due?(conversation, kind, reference_id)

    assign_fallback!(conversation, configuration) if kind == 'first_response_fallback'
    Whatsapp::Triage::NotificationService.new(
      conversation: conversation,
      configuration: configuration
    ).notify_escalation!(cycle_id, kind, reference_id)
  end

  private

  def active_complaint?(conversation, cycle_id)
    return false if conversation.blank? || conversation.resolved?

    attributes = conversation.custom_attributes
    attributes['triage_cycle_id'] == cycle_id && attributes['triage_status'] == 'complaint_owned'
  end

  def escalation_due?(conversation, kind, reference_id)
    case kind
    when 'first_response', 'first_response_fallback'
      no_human_response_since?(conversation, routed_at(conversation))
    when 'next_response'
      message = conversation.messages.incoming.find_by(id: reference_id)
      message.present? &&
        human_response_exists_before?(conversation, message.created_at) &&
        no_human_response_since?(conversation, message.created_at)
    when 'resolution'
      !conversation.resolved?
    else
      false
    end
  end

  def no_human_response_since?(conversation, timestamp)
    return false if timestamp.blank?

    !human_responses(conversation).exists?(['created_at > ?', timestamp])
  end

  def human_response_exists_before?(conversation, timestamp)
    human_responses(conversation).exists?(['created_at <= ?', timestamp])
  end

  def human_responses(conversation)
    conversation.messages.outgoing.where(private: false, sender_type: 'User')
  end

  def routed_at(conversation)
    Time.iso8601(conversation.custom_attributes['triage_routed_at'])
  rescue ArgumentError, TypeError
    nil
  end

  def assign_fallback!(conversation, configuration)
    fallback_user_id = configuration.fallback_user_id('complaints')
    conversation.update!(assignee_id: fallback_user_id) if conversation.assignee_id != fallback_user_id
  end

  def reschedule(conversation, cycle_id, kind, reference_id, business_time_started)
    self.class.set(wait: 30.minutes).perform_later(
      conversation.id, cycle_id, kind, reference_id, business_time_started: business_time_started
    )
  end

  def restart_in_business_hours(conversation, cycle_id, kind, reference_id)
    configuration = Whatsapp::Triage::Configuration.new
    delay = delay_for(configuration, kind)
    self.class.set(wait: delay).perform_later(conversation.id, cycle_id, kind, reference_id, business_time_started: true)
  end

  def delay_for(configuration, kind)
    case kind
    when 'first_response'
      configuration.first_response_delay
    when 'first_response_fallback'
      configuration.first_response_delay * 2
    when 'next_response'
      configuration.next_response_delay
    else
      configuration.resolution_delay
    end
  end
end
