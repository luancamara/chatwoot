class ConversationRiskMonitor::AlertService
  STATE_KEY = 'conversation_risk_monitor'.freeze
  SEVERITY_RANK = { 'complaint' => 1, 'critical' => 2 }.freeze

  def initialize(conversation:, config:)
    @conversation = conversation
    @config = config
  end

  def perform(classification, message_id)
    severity = classification.fetch('severity')
    return unless SEVERITY_RANK.key?(severity)

    conversation.with_lock do
      alert!(classification, severity, message_id)
    end
  end

  private

  attr_reader :conversation, :config

  def alert!(classification, severity, message_id)
    state = active_incident_state
    return if alerted_at_same_or_higher_severity?(state, severity)

    apply_labels!(severity)
    store_alert_state!(state, severity, message_id)
    create_private_note!(classification, severity)
  end

  def active_incident_state
    state = current_state
    return state if state.present? && state['resolved_at'].blank?

    new_incident_state
  end

  def alerted_at_same_or_higher_severity?(state, severity)
    SEVERITY_RANK.fetch(state['severity'], 0) >= SEVERITY_RANK.fetch(severity)
  end

  def apply_labels!(severity)
    labels = [config.complaint_label]
    labels << config.critical_label if severity == 'critical'
    conversation.label_list = (conversation.label_list.to_a + labels.map(&:title)).uniq
  end

  def store_alert_state!(state, severity, message_id)
    state = state.merge(
      'severity' => severity,
      'last_evaluated_message_id' => message_id,
      'alerts' => state.fetch('alerts', {}).merge(severity => Time.current.iso8601)
    )
    conversation.additional_attributes = conversation.additional_attributes.merge(STATE_KEY => state)
    conversation.save!
  end

  def current_state
    conversation.additional_attributes[STATE_KEY].presence&.deep_dup
  end

  def new_incident_state
    { 'incident_id' => SecureRandom.uuid, 'started_at' => Time.current.iso8601, 'alerts' => {} }
  end

  def create_private_note!(classification, severity)
    team = config.management_team
    mention = "[@#{team.name}](mention://team/#{team.id}/#{ERB::Util.url_encode(team.name)})"
    level = severity == 'critical' ? 'RISCO CRÍTICO' : 'RECLAMAÇÃO'
    content = "#{mention} Monitor silencioso sinalizou #{level}. Motivo: #{classification.fetch('reason')}."

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      content: content,
      content_attributes: {
        'conversation_risk_monitor' => {
          'severity' => severity,
          'source' => classification.fetch('source')
        }
      }
    )
  end
end
