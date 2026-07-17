class ConversationRiskMonitor::ProcessMessageJob < ApplicationJob
  queue_as :medium

  DEBOUNCE_KEY = 'CONVERSATION_RISK_MONITOR::CONVERSATION::%<conversation_id>d'.freeze
  DEBOUNCE_DELAY = 4.seconds
  SIGNAL_DELAY = 1.second
  AUDIO_RETRY_LIMIT = 3
  AUDIO_RETRY_DELAY = 3.seconds

  def self.schedule(message)
    token = SecureRandom.uuid
    Redis::Alfred.setex(format(DEBOUNCE_KEY, conversation_id: message.conversation_id), token, 5.minutes.to_i)
    signal = ConversationRiskMonitor::SignalDetector.new(message.content).perform
    set(wait: signal.present? ? SIGNAL_DELAY : DEBOUNCE_DELAY).perform_later(message.id, token)
  end

  def perform(message_id, token, audio_attempt = 0)
    message = Message.find_by(id: message_id)
    process_message(message, token, audio_attempt) if message.present?
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message&.account).capture_exception
  ensure
    Redis::Alfred.delete_if_equals(debounce_key(message), token) if message.present?
  end

  private

  def process_message(message, token, audio_attempt)
    return if stale?(message, token)

    config = message.inbox.conversation_risk_monitor_config
    return unless config&.operational?
    return retry_audio(message, token, audio_attempt) if should_retry_audio?(message, audio_attempt)

    ConversationRiskMonitor::EvaluatorService.new(message: message, config: config).perform
  end

  def should_retry_audio?(message, audio_attempt)
    audio_attempt < AUDIO_RETRY_LIMIT && audio_transcription_pending?(message)
  end

  def retry_audio(message, token, audio_attempt)
    self.class.set(wait: AUDIO_RETRY_DELAY).perform_later(message.id, token, audio_attempt + 1)
  end

  def stale?(message, token)
    Redis::Alfred.get(debounce_key(message)) != token
  end

  def debounce_key(message)
    format(DEBOUNCE_KEY, conversation_id: message.conversation_id)
  end

  def audio_transcription_pending?(message)
    audio_attachments = message.attachments.select(&:audio?)
    audio_attachments.any? && audio_attachments.none? { |attachment| attachment.meta&.dig('transcribed_text').present? }
  end
end
