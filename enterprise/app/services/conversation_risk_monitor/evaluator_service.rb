class ConversationRiskMonitor::EvaluatorService
  CONFIDENCE_THRESHOLD = 0.7

  def initialize(message:, config:)
    @message = message
    @config = config
  end

  def perform
    classification = ConversationRiskMonitor::SignalDetector.new(message_content).perform
    classification ||= ConversationRiskMonitor::ClassifierService.new(conversation: message.conversation).perform
    return if classification.blank? || classification['severity'] == 'none'
    return if classification['confidence'] < CONFIDENCE_THRESHOLD

    ConversationRiskMonitor::AlertService.new(conversation: message.conversation, config: config)
                                         .perform(classification, message.id)
  end

  private

  attr_reader :message, :config

  def message_content
    return message.content if message.content.present?

    message.attachments.filter_map { |attachment| attachment.meta&.dig('transcribed_text') }.join(' ')
  end
end
