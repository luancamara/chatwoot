class Whatsapp::Triage::EscalationScheduler
  def initialize(conversation:, configuration: Whatsapp::Triage::Configuration.new)
    @conversation = conversation
    @configuration = configuration
  end

  def schedule_initial!(cycle_id)
    schedule(:first_response, configuration.first_response_delay, cycle_id)
    schedule(:first_response_fallback, configuration.first_response_delay * 2, cycle_id)
    schedule(:resolution, configuration.resolution_delay, cycle_id)
  end

  def schedule_next_response!(cycle_id, message)
    schedule(:next_response, configuration.next_response_delay, cycle_id, message.id)
  end

  private

  attr_reader :conversation, :configuration

  def schedule(kind, delay, cycle_id, reference_id = nil)
    Whatsapp::Triage::EscalationJob.set(wait: delay).perform_later(
      conversation.id,
      cycle_id,
      kind.to_s,
      reference_id,
      business_time_started: conversation.inbox.working_now?
    )
  end
end
