class Whatsapp::Triage::ProcessMessageJob < ApplicationJob
  queue_as :medium

  DEBOUNCE_KEY = 'WHATSAPP_TRIAGE::CONVERSATION::%<conversation_id>d'.freeze
  AUDIO_RETRY_LIMIT = 3
  AUDIO_RETRY_DELAY = 3.seconds
  SIGNAL_DELAY = 1.second

  def self.schedule(message, configuration: Whatsapp::Triage::Configuration.new)
    token = SecureRandom.uuid
    key = format(DEBOUNCE_KEY, conversation_id: message.conversation_id)
    Redis::Alfred.setex(key, token, 5.minutes.to_i)
    signal = Whatsapp::Triage::SignalDetector.new(message.content).perform
    selection = Whatsapp::Triage::MessageService.new(conversation: message.conversation).area_from(message)
    delay = processing_delay(signal, selection, configuration)
    set(wait: delay).perform_later(message.id, token)
  end

  def self.processing_delay(signal, selection, configuration)
    return 0.seconds if selection.present?
    return SIGNAL_DELAY if signal.present?

    configuration.debounce_seconds.seconds
  end

  def perform(message_id, token, audio_attempt = 0)
    message = Message.find_by(id: message_id)
    return if message.blank? || stale?(message, token)

    configuration = Whatsapp::Triage::Configuration.new
    return bypass_triage(message) unless configuration.operational_for?(message.inbox)

    if audio_transcription_pending?(message) && audio_attempt < AUDIO_RETRY_LIMIT
      return self.class.set(wait: AUDIO_RETRY_DELAY).perform_later(message.id, token, audio_attempt + 1)
    end

    Whatsapp::Triage::Coordinator.new(message: message, configuration: configuration).perform
    Redis::Alfred.delete_if_equals(debounce_key(message), token)
  end

  private

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

  def bypass_triage(message)
    bot = message.inbox.agent_bot
    message.conversation.open! if bot&.name == Whatsapp::Triage::SetupService::BOT_NAME && message.conversation.pending?
  end
end
