class Whatsapp::Triage::RouterService
  AREA_LABELS = {
    'sales' => 'triage-vendas',
    'finance' => 'triage-financeiro',
    'after_sales' => 'triage-pos-venda',
    'complaints' => 'triage-reclamacao',
    'general' => 'triage-geral'
  }.freeze

  def initialize(conversation:, configuration: Whatsapp::Triage::Configuration.new)
    @conversation = conversation
    @configuration = configuration
  end

  def perform!(classification, cycle_id)
    area = classification.fetch('area')
    return :invalid_area unless AREA_LABELS.key?(area)

    conversation.with_lock do
      attributes = conversation.custom_attributes
      next :stale_cycle if attributes['triage_cycle_id'] != cycle_id
      next :complaint_locked if attributes['triage_status'] == 'complaint_owned' && area != 'complaints'
      next upgrade_complaint!(classification, attributes) if attributes['triage_status'] == 'complaint_owned'

      route!(classification, area, attributes)
      :routed
    end
  end

  private

  attr_reader :conversation, :configuration

  def route!(classification, area, attributes)
    team = conversation.account.teams.find(configuration.team_id(area))
    previous_area = attributes['triage_area']
    complaint = area == 'complaints'
    severity = complaint ? classification.fetch('severity') : 'normal'

    conversation.assign_attributes(
      team: team,
      assignee: nil,
      status: :open,
      priority: priority_for(severity),
      custom_attributes: routed_attributes(attributes, classification, previous_area),
      label_list: routed_labels(area, severity)
    )
    add_sla_if_available if complaint
    conversation.save!
    assign_fallback_if_needed(area)
  end

  def upgrade_complaint!(classification, attributes)
    return :already_owned unless classification['severity'] == 'critical' && attributes['complaint_severity'] != 'critical'

    conversation.update!(
      priority: :urgent,
      label_list: (conversation.label_list + ['triage-reclamacao-critica']).uniq,
      custom_attributes: attributes.merge(
        'complaint_severity' => 'critical',
        'complaint_reason' => classification['reason'],
        'triage_source' => classification['source'],
        'triage_confidence' => classification['confidence']
      )
    )
    :upgraded
  end

  def routed_attributes(attributes, classification, previous_area)
    complaint = classification['area'] == 'complaints'
    routed = attributes.merge(
      'triage_status' => complaint ? 'complaint_owned' : 'routed',
      'triage_area' => classification['area'],
      'triage_source' => classification['source'],
      'triage_confidence' => classification['confidence'],
      'triage_routed_at' => Time.current.iso8601
    )

    return routed unless complaint

    routed.merge(
      'complaint_severity' => classification['severity'],
      'complaint_reason' => classification['reason'],
      'complaint_previous_area' => previous_area
    )
  end

  def routed_labels(area, severity)
    labels = conversation.label_list - AREA_LABELS.values - ['triage-reclamacao-critica']
    labels << AREA_LABELS.fetch(area)
    labels << 'triage-reclamacao-critica' if severity == 'critical'
    labels.uniq
  end

  def priority_for(severity)
    return :urgent if severity == 'critical'
    return :high if severity == 'complaint'

    nil
  end

  def add_sla_if_available
    return if conversation.sla_policy_id.present? || configuration.sla_policy_id.blank?

    conversation.sla_policy_id = configuration.sla_policy_id
  end

  def assign_fallback_if_needed(area)
    conversation.reload
    return if conversation.assignee_id.present?

    conversation.update!(assignee_id: configuration.fallback_user_id(area))
  end
end
