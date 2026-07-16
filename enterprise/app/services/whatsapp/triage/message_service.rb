class Whatsapp::Triage::MessageService
  MENU_ITEMS = [
    { title: 'Comprar ou pedir orçamento', value: 'sales' },
    { title: 'Pagamentos, boletos ou notas', value: 'finance' },
    { title: 'Entrega, montagem ou pós-venda', value: 'after_sales' },
    { title: 'Tenho um problema ou reclamação', value: 'complaints' },
    { title: 'Outro assunto', value: 'general' }
  ].freeze

  def initialize(conversation:, configuration: Whatsapp::Triage::Configuration.new)
    @conversation = conversation
    @configuration = configuration
  end

  def area_from(message)
    item = MENU_ITEMS.find { |menu_item| normalize(menu_item[:title]) == normalize(message.content) }
    item&.fetch(:value)
  end

  def send_menu!(cycle_id)
    create_once!(cycle_id, timestamp_key: 'triage_menu_sent_at') do
      create_message!(
        configuration.menu_message,
        content_type: 'input_select',
        content_attributes: triage_content_attributes('menu', cycle_id).merge(items: MENU_ITEMS)
      )
      update_status!('awaiting_selection')
    end
  end

  def send_routing_acknowledgement!(cycle_id, area)
    content = configuration.routing_acknowledgement(area)
    return if content.blank?

    create_once!(cycle_id, timestamp_key: 'triage_acknowledged_at') do
      unless recent_out_of_office_message?
        create_message!(content, content_attributes: triage_content_attributes('routing_acknowledgement', cycle_id))
      end
    end
  end

  def send_complaint_acknowledgement!(cycle_id)
    content = configuration.complaint_acknowledgement(out_of_office: conversation.inbox.out_of_office?)
    return if content.blank?

    create_once!(cycle_id, timestamp_key: 'complaint_acknowledged_at') do
      unless recent_out_of_office_message?
        create_message!(content, content_attributes: triage_content_attributes('complaint_acknowledgement', cycle_id))
      end
    end
  end

  private

  attr_reader :conversation, :configuration

  def create_once!(cycle_id, timestamp_key:)
    conversation.with_lock do
      attributes = conversation.custom_attributes
      next if attributes['triage_cycle_id'] != cycle_id || attributes[timestamp_key].present?

      yield
      conversation.update!(custom_attributes: conversation.custom_attributes.merge(timestamp_key => Time.current.iso8601))
    end
  end

  def create_message!(content, content_type: 'text', content_attributes: {})
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content_type: content_type,
      content: content,
      content_attributes: content_attributes
    )
  end

  def update_status!(status)
    conversation.update!(custom_attributes: conversation.custom_attributes.merge('triage_status' => status))
  end

  def triage_content_attributes(kind, cycle_id)
    { 'whatsapp_triage' => { 'kind' => kind, 'cycle_id' => cycle_id } }
  end

  def recent_out_of_office_message?
    return false unless conversation.inbox.out_of_office?

    started_at = conversation.custom_attributes['triage_started_at']
    conversation.messages.template.exists?(['created_at >= ?', started_at])
  end

  def normalize(value)
    I18n.transliterate(value.to_s).downcase.squish
  end
end
