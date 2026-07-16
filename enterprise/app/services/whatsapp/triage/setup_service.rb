class Whatsapp::Triage::SetupService
  BOT_NAME = 'Triagem WhatsApp'.freeze

  ATTRIBUTE_DEFINITIONS = [
    {
      attribute_key: 'triage_status',
      attribute_display_name: 'Status da triagem',
      attribute_display_type: 'list',
      attribute_values: %w[awaiting_classification awaiting_selection routed complaint_owned]
    },
    {
      attribute_key: 'triage_area',
      attribute_display_name: 'Área do atendimento',
      attribute_display_type: 'list',
      attribute_values: Whatsapp::Triage::Configuration::AREAS
    },
    {
      attribute_key: 'triage_source',
      attribute_display_name: 'Origem da triagem',
      attribute_display_type: 'list',
      attribute_values: %w[menu keyword ai fallback manual]
    },
    {
      attribute_key: 'triage_confidence',
      attribute_display_name: 'Confiança da triagem',
      attribute_display_type: 'number'
    },
    {
      attribute_key: 'complaint_severity',
      attribute_display_name: 'Gravidade da reclamação',
      attribute_display_type: 'list',
      attribute_values: %w[normal complaint critical]
    },
    {
      attribute_key: 'complaint_reason',
      attribute_display_name: 'Motivo da reclamação',
      attribute_display_type: 'text'
    },
    {
      attribute_key: 'complaint_previous_area',
      attribute_display_name: 'Área anterior à reclamação',
      attribute_display_type: 'list',
      attribute_values: Whatsapp::Triage::Configuration::AREAS
    }
  ].freeze

  LABELS = {
    'triage-vendas' => '#1f93ff',
    'triage-financeiro' => '#8b5cf6',
    'triage-pos-venda' => '#14b8a6',
    'triage-reclamacao' => '#f97316',
    'triage-reclamacao-critica' => '#dc2626',
    'triage-geral' => '#64748b'
  }.freeze

  def initialize(configuration: Whatsapp::Triage::Configuration.new)
    @configuration = configuration
  end

  def perform!
    configuration.validate!

    ActiveRecord::Base.transaction do
      create_attribute_definitions
      create_labels
      attach_triage_bot
      enable_audio_transcriptions
      configure_inbox_messages
    end

    configuration.inbox
  end

  private

  attr_reader :configuration

  delegate :account, to: :inbox

  def inbox
    configuration.inbox
  end

  def create_attribute_definitions
    ATTRIBUTE_DEFINITIONS.each do |attributes|
      definition = account.custom_attribute_definitions.find_or_initialize_by(
        attribute_key: attributes[:attribute_key],
        attribute_model: 'conversation_attribute'
      )
      definition.assign_attributes(attributes.merge(attribute_description: 'Preenchido automaticamente pela triagem do WhatsApp.'))
      definition.save!
    end
  end

  def create_labels
    LABELS.each do |title, color|
      label = account.labels.find_or_initialize_by(title: title)
      label.assign_attributes(color: color, description: 'Gerenciada pela triagem do WhatsApp.')
      label.save!
    end
  end

  def attach_triage_bot
    existing_bot = inbox.agent_bot
    validate_existing_bot!(existing_bot)
    bot = prepare_triage_bot(existing_bot)
    activate_bot_inbox(bot)
  end

  def validate_existing_bot!(bot)
    raise ArgumentError, "Inbox already has agent bot #{bot.name}" if bot.present? && bot.name != BOT_NAME
  end

  def prepare_triage_bot(existing_bot)
    bot = existing_bot || account.agent_bots.find_or_create_by!(name: BOT_NAME)
    raise ArgumentError, 'Triage bot cannot have an outgoing webhook' if bot.outgoing_url.present?
    raise ArgumentError, 'Triage bot is already attached to another inbox' if bot.agent_bot_inboxes.where.not(inbox_id: inbox.id).exists?

    bot.update!(outgoing_url: nil, description: 'Mantém conversas em triagem até o encaminhamento interno.')
    bot
  end

  def activate_bot_inbox(bot)
    agent_bot_inbox = inbox.agent_bot_inbox || AgentBotInbox.new(inbox: inbox)
    agent_bot_inbox.assign_attributes(agent_bot: bot, status: :active)
    agent_bot_inbox.save!
  end

  def enable_audio_transcriptions
    return if ActiveModel::Type::Boolean.new.cast(account.audio_transcriptions)

    account.update!(audio_transcriptions: true)
  end

  def configure_inbox_messages
    inbox.update!(greeting_enabled: false, out_of_office_message: configuration.out_of_office_message)
  end
end
