class Whatsapp::Triage::Coordinator
  def initialize(message:, configuration: Whatsapp::Triage::Configuration.new)
    @message = message
    @conversation = message.conversation
    @configuration = configuration
  end

  def perform
    cycle_id = cycle_service.prepare!(message)
    conversation.reload

    selection = message_service.area_from(message)
    return route!(menu_classification(selection), cycle_id) if selection.present?

    classification = Whatsapp::Triage::SignalDetector.new(message_content).perform
    classification ||= classifier.perform

    handle_classification(classification, cycle_id)
  end

  private

  attr_reader :message, :conversation, :configuration

  def cycle_service
    @cycle_service ||= Whatsapp::Triage::CycleService.new(conversation: conversation, configuration: configuration)
  end

  def message_service
    @message_service ||= Whatsapp::Triage::MessageService.new(conversation: conversation, configuration: configuration)
  end

  def classifier
    @classifier ||= Whatsapp::Triage::ClassifierService.new(conversation: conversation)
  end

  def router
    @router ||= Whatsapp::Triage::RouterService.new(conversation: conversation, configuration: configuration)
  end

  def notification_service
    @notification_service ||= Whatsapp::Triage::NotificationService.new(
      conversation: conversation,
      configuration: configuration
    )
  end

  def escalation_scheduler
    @escalation_scheduler ||= Whatsapp::Triage::EscalationScheduler.new(
      conversation: conversation,
      configuration: configuration
    )
  end

  def handle_classification(classification, cycle_id)
    status = conversation.custom_attributes['triage_status']

    return route!(classification, cycle_id) if classification.present? && complaint_classification?(classification)

    if status == 'complaint_owned'
      open_existing_conversation!
      escalation_scheduler.schedule_next_response!(cycle_id, message)
    elsif status == 'routed'
      open_existing_conversation!
    elsif routable_area?(classification)
      route!(classification, cycle_id)
    elsif status == 'awaiting_selection'
      route!(fallback_classification, cycle_id)
    else
      message_service.send_menu!(cycle_id)
    end
  end

  def route!(classification, cycle_id)
    result = router.perform!(classification, cycle_id)

    case result
    when :routed
      handle_new_route!(classification, cycle_id)
    when :upgraded
      notification_service.notify_routing!(classification, cycle_id)
    when :already_owned
      open_existing_conversation!
      escalation_scheduler.schedule_next_response!(cycle_id, message)
    end

    result
  end

  def handle_new_route!(classification, cycle_id)
    if classification['area'] == 'complaints'
      message_service.send_complaint_acknowledgement!(cycle_id)
      notification_service.notify_routing!(classification, cycle_id)
      escalation_scheduler.schedule_initial!(cycle_id)
    else
      message_service.send_routing_acknowledgement!(cycle_id, classification['area'])
    end
  end

  def menu_classification(area)
    {
      'area' => area,
      'severity' => area == 'complaints' ? 'complaint' : 'normal',
      'confidence' => 1.0,
      'reason' => 'Cliente escolheu uma opção do menu de triagem',
      'source' => 'menu'
    }
  end

  def fallback_classification
    {
      'area' => 'general',
      'severity' => 'normal',
      'confidence' => 0.0,
      'reason' => 'Classificação inconclusiva após o menu de triagem',
      'source' => 'fallback'
    }
  end

  def complaint_classification?(classification)
    return false unless classification['area'] == 'complaints'

    classification['confidence'].to_f >= configuration.complaint_threshold
  end

  def routable_area?(classification)
    return false if classification.blank? || classification['area'].in?(%w[unknown complaints])

    classification['confidence'].to_f >= configuration.area_threshold
  end

  def open_existing_conversation!
    conversation.open! if conversation.pending?
  end

  def message_content
    return message.content if message.content.present?

    message.attachments.filter_map { |attachment| attachment.meta&.dig('transcribed_text') }.join(' ')
  end
end
