class ConversationRiskMonitor::LegacyCleanupService
  CONFIG_KEY = 'WHATSAPP_TRIAGE_CONFIG'.freeze
  BOT_NAME = 'Triagem WhatsApp'.freeze
  RESET_KEYS = %w[
    triage_status triage_area triage_source triage_confidence triage_started_at triage_routed_at
    triage_menu_sent_at triage_acknowledged_at triage_cycle_id triage_last_resolved_at
    complaint_severity complaint_reason complaint_previous_area complaint_acknowledged_at complaint_escalations
  ].freeze

  def initialize(inbox:)
    @inbox = inbox
  end

  def audit
    {
      inbox_id: inbox.id,
      conversations: inbox.conversations.count,
      conversations_with_legacy_metadata: conversations_with_legacy_metadata.count,
      pending_assigned_to_legacy_bot: pending_assigned_to_legacy_bot.count,
      legacy_public_messages: legacy_messages.where(private: false).count,
      legacy_private_notes: legacy_messages.where(private: true).count
    }
  end

  def perform!
    ActiveRecord::Base.transaction do
      disable_legacy_config!
      clean_conversations!
      remove_attribute_definitions!
      detach_legacy_bot!
    end
  end

  private

  attr_reader :inbox

  delegate :account, to: :inbox

  def legacy_bot
    @legacy_bot ||= account.agent_bots.find_by(name: BOT_NAME)
  end

  def legacy_messages
    inbox.messages.where("content_attributes::text LIKE '%whatsapp_triage%'")
  end

  def conversations_with_legacy_metadata
    inbox.conversations.where('custom_attributes ?| array[:keys]', keys: RESET_KEYS)
  end

  def pending_assigned_to_legacy_bot
    return inbox.conversations.none if legacy_bot.blank?

    inbox.conversations.pending.where(assignee_agent_bot_id: legacy_bot.id)
  end

  def disable_legacy_config!
    record = InstallationConfig.find_by(name: CONFIG_KEY)
    return if record.blank?

    settings = parse_config(record.value)
    record.update!(value: settings.merge('enabled' => false))
  end

  def parse_config(value)
    return value.deep_stringify_keys if value.respond_to?(:deep_stringify_keys)
    return JSON.parse(value) if value.is_a?(String)

    {}
  rescue JSON::ParserError
    {}
  end

  def clean_conversations!
    inbox.conversations.where('custom_attributes ?| array[:keys]', keys: RESET_KEYS).find_each do |conversation|
      conversation.update!(custom_attributes: conversation.custom_attributes.except(*RESET_KEYS))
    end

    pending_assigned_to_legacy_bot.find_each do |conversation|
      conversation.update!(status: :open, assignee_agent_bot: nil)
    end
  end

  def remove_attribute_definitions!
    account.custom_attribute_definitions.where(
      attribute_model: :conversation_attribute,
      attribute_key: RESET_KEYS
    ).destroy_all
  end

  def detach_legacy_bot!
    return if legacy_bot.blank?

    legacy_bot.agent_bot_inboxes.where(inbox: inbox).destroy_all
    legacy_bot.reload.destroy! if legacy_bot.agent_bot_inboxes.none? && legacy_bot.assigned_conversations.none?
  end
end
