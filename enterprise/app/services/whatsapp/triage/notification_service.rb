class Whatsapp::Triage::NotificationService
  def initialize(conversation:, configuration: Whatsapp::Triage::Configuration.new)
    @conversation = conversation
    @configuration = configuration
  end

  def notify_routing!(classification, cycle_id)
    severity = classification.fetch('severity')
    event_key = severity == 'critical' ? 'routed-critical' : 'routed'
    title = severity == 'critical' ? 'Reclamação crítica encaminhada automaticamente' : 'Reclamação encaminhada automaticamente'

    content = <<~CONTENT.squish
      #{title}. Motivo: #{classification.fetch('reason')}.
      Antes de resolver, registre em nota privada o tipo, a causa, a providência, o resultado e o responsável pela decisão.
    CONTENT
    notify_once!(cycle_id, event_key, content)
  end

  def notify_escalation!(cycle_id, kind, reference_id = nil)
    event_key = [kind, reference_id].compact.join(':')
    content = escalation_message(kind)
    notify_once!(cycle_id, event_key, content)
  end

  private

  attr_reader :conversation, :configuration

  def notify_once!(cycle_id, event_key, content)
    conversation.with_lock do
      attributes = conversation.custom_attributes
      next if attributes['triage_cycle_id'] != cycle_id

      escalations = attributes['complaint_escalations'].is_a?(Hash) ? attributes['complaint_escalations'] : {}
      next if escalations[event_key].present?

      team = conversation.account.teams.find(configuration.team_id('complaints'))
      create_private_note!(team, content, cycle_id, event_key)
      conversation.update!(
        custom_attributes: conversation.custom_attributes.merge(
          'complaint_escalations' => escalations.merge(event_key => Time.current.iso8601)
        )
      )
    end
  end

  def create_private_note!(team, content, cycle_id, event_key)
    mention = "[@#{team.name}](mention://team/#{team.id}/#{ERB::Util.url_encode(team.name)})"
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      content: "#{mention} #{content}",
      content_attributes: {
        'whatsapp_triage' => { 'kind' => 'internal_notification', 'cycle_id' => cycle_id, 'event' => event_key }
      }
    )
  end

  def escalation_message(kind)
    case kind.to_s
    when 'first_response'
      'O prazo de primeira resposta humana desta reclamação foi atingido.'
    when 'first_response_fallback'
      'A reclamação continua sem primeira resposta e foi encaminhada ao responsável de contingência.'
    when 'next_response'
      'O cliente está aguardando uma nova resposta além do prazo definido.'
    when 'resolution'
      'A reclamação permanece aberta além do prazo de posicionamento conclusivo.'
    else
      'A reclamação exige atenção da equipe responsável.'
    end
  end
end
