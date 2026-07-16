class Whatsapp::Triage::CycleService
  RESET_KEYS = %w[
    triage_status
    triage_area
    triage_source
    triage_confidence
    triage_started_at
    triage_routed_at
    triage_menu_sent_at
    triage_acknowledged_at
    complaint_severity
    complaint_reason
    complaint_previous_area
    complaint_acknowledged_at
    complaint_escalations
  ].freeze

  def initialize(conversation:, configuration: Whatsapp::Triage::Configuration.new)
    @conversation = conversation
    @configuration = configuration
  end

  def prepare!(message)
    conversation.with_lock do
      next current_cycle_id unless new_cycle?(message)

      attributes = conversation.custom_attributes.except(*RESET_KEYS).merge(
        'triage_cycle_id' => SecureRandom.uuid,
        'triage_status' => 'awaiting_classification',
        'triage_started_at' => message.created_at.iso8601
      )
      conversation.update!(
        assignee: nil,
        team: nil,
        status: :pending,
        priority: nil,
        label_list: conversation.label_list.reject { |label| label.start_with?('triage-') },
        custom_attributes: attributes
      )
      attributes['triage_cycle_id']
    end
  end

  def mark_resolved!
    conversation.with_lock do
      conversation.update!(
        custom_attributes: conversation.custom_attributes.merge('triage_last_resolved_at' => Time.current.iso8601)
      )
    end
  end

  private

  attr_reader :conversation, :configuration

  def current_cycle_id
    conversation.custom_attributes['triage_cycle_id']
  end

  def new_cycle?(message)
    return true if current_cycle_id.blank?

    last_resolved_at = parse_time(conversation.custom_attributes['triage_last_resolved_at'])
    last_resolved_at.present? && message.created_at > last_resolved_at + configuration.reopen_window
  end

  def parse_time(value)
    Time.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end
end
