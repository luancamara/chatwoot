class Whatsapp::Triage::Configuration
  CONFIG_KEY = 'WHATSAPP_TRIAGE_CONFIG'.freeze
  AREAS = %w[sales finance after_sales complaints general].freeze

  DEFAULTS = {
    'enabled' => false,
    'debounce_seconds' => 4,
    'reopen_window_hours' => 24,
    'complaint_threshold' => 0.7,
    'area_threshold' => 0.85,
    'first_response_minutes' => 10,
    'next_response_minutes' => 30,
    'resolution_minutes' => 480
  }.freeze

  def initialize(value: nil)
    stored_value = value || InstallationConfig.find_by(name: CONFIG_KEY)&.value || {}
    @settings = DEFAULTS.merge(normalize_settings(stored_value).deep_stringify_keys).with_indifferent_access
  end

  def enabled_for?(inbox)
    enabled? && configured_for?(inbox)
  end

  def operational_for?(inbox)
    return false unless enabled_for?(inbox)

    validate!
  rescue ArgumentError, ActiveRecord::RecordNotFound
    false
  end

  def configured_for?(inbox)
    inbox.whatsapp? && inbox.id == inbox_id
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(settings[:enabled])
  end

  def to_h
    settings.to_h.deep_dup
  end

  def inbox_id
    integer_value(settings[:inbox_id])
  end

  def fallback_user_id(area)
    return unless AREAS.include?(area.to_s)

    integer_value(settings.dig(:fallback_user_ids, area.to_s))
  end

  def sla_policy_id
    integer_value(settings[:sla_policy_id])
  end

  def team_id(area)
    return unless AREAS.include?(area.to_s)

    integer_value(settings.dig(:team_ids, area.to_s))
  end

  def debounce_seconds
    positive_integer(settings[:debounce_seconds], DEFAULTS['debounce_seconds'])
  end

  def reopen_window
    positive_integer(settings[:reopen_window_hours], DEFAULTS['reopen_window_hours']).hours
  end

  def complaint_threshold
    confidence_value(settings[:complaint_threshold], DEFAULTS['complaint_threshold'])
  end

  def area_threshold
    confidence_value(settings[:area_threshold], DEFAULTS['area_threshold'])
  end

  def first_response_delay
    positive_integer(settings[:first_response_minutes], DEFAULTS['first_response_minutes']).minutes
  end

  def next_response_delay
    positive_integer(settings[:next_response_minutes], DEFAULTS['next_response_minutes']).minutes
  end

  def resolution_delay
    positive_integer(settings[:resolution_minutes], DEFAULTS['resolution_minutes']).minutes
  end

  def menu_message
    settings[:menu_message].to_s.presence
  end

  def complaint_acknowledgement(out_of_office: false)
    key = out_of_office ? :complaint_acknowledgement_out_of_office : :complaint_acknowledgement
    settings[key].to_s.presence
  end

  def routing_acknowledgement(area)
    return if area.to_s == 'complaints'

    settings.dig(:routing_acknowledgements, area.to_s).to_s.presence
  end

  def out_of_office_message
    settings[:out_of_office_message].to_s.presence
  end

  def validate!
    validate_inbox!
    validate_teams!
    validate_fallback_users!
    validate_sla_policy!
    validate_messages!

    true
  end

  def inbox
    @inbox ||= Inbox.find_by(id: inbox_id)
  end

  private

  attr_reader :settings

  def validate_inbox!
    raise ArgumentError, 'WhatsApp triage inbox_id is missing' if inbox_id.blank?
    raise ArgumentError, 'WhatsApp triage inbox does not exist' unless inbox
    raise ArgumentError, 'WhatsApp triage inbox must use Channel::Whatsapp' unless inbox.whatsapp?
  end

  def validate_teams!
    missing_areas = AREAS.select { |area| team_id(area).blank? }
    raise ArgumentError, "WhatsApp triage team IDs are missing for: #{missing_areas.join(', ')}" if missing_areas.any?

    unknown_team_ids = AREAS.filter_map { |area| team_id(area) }.uniq - inbox.account.team_ids
    raise ArgumentError, "WhatsApp triage teams do not belong to the inbox account: #{unknown_team_ids.join(', ')}" if unknown_team_ids.any?
    raise ArgumentError, 'WhatsApp triage complaints team must be independent' if duplicated_complaints_team?
  end

  def normalize_settings(value)
    return value.to_h if value.respond_to?(:to_h)
    return JSON.parse(value) if value.is_a?(String)

    {}
  rescue JSON::ParserError
    {}
  end

  def integer_value(value)
    integer = value.to_i
    integer.positive? ? integer : nil
  end

  def positive_integer(value, fallback)
    integer_value(value) || fallback
  end

  def confidence_value(value, fallback)
    number = Float(value)
    number.between?(0, 1) ? number : fallback
  rescue ArgumentError, TypeError
    fallback
  end

  def validate_fallback_users!
    missing_areas = AREAS.select { |area| fallback_user_id(area).blank? }
    raise ArgumentError, "WhatsApp triage fallback user IDs are missing for: #{missing_areas.join(', ')}" if missing_areas.any?

    fallback_ids = AREAS.index_with { |area| fallback_user_id(area) }
    validate_fallback_inbox_members!(fallback_ids)
    validate_fallback_team_memberships!(fallback_ids)
  end

  def validate_fallback_inbox_members!(fallback_ids)
    users_outside_inbox = fallback_ids.values.uniq - inbox.member_ids
    raise ArgumentError, "WhatsApp triage fallback users must be inbox members: #{users_outside_inbox.join(', ')}" if users_outside_inbox.any?
  end

  def validate_fallback_team_memberships!(fallback_ids)
    memberships = TeamMember.where(team_id: AREAS.map { |area| team_id(area) }).pluck(:team_id, :user_id)
    invalid_areas = AREAS.reject do |area|
      memberships.include?([team_id(area), fallback_ids.fetch(area)])
    end
    return if invalid_areas.empty?

    raise ArgumentError, "WhatsApp triage fallback users must belong to their teams: #{invalid_areas.join(', ')}"
  end

  def validate_sla_policy!
    return if sla_policy_id.blank?
    return if inbox.account.sla_policies.exists?(id: sla_policy_id)

    raise ArgumentError, 'WhatsApp triage SLA policy does not belong to the inbox account'
  end

  def duplicated_complaints_team?
    (AREAS - ['complaints']).any? { |area| team_id(area) == team_id('complaints') }
  end

  def validate_messages!
    raise ArgumentError, 'WhatsApp triage menu message is missing' if menu_message.blank?
    raise ArgumentError, 'WhatsApp triage complaint acknowledgement is missing' if complaint_acknowledgement.blank?
    raise ArgumentError, 'WhatsApp triage out-of-office message is missing' if out_of_office_message.blank?
    return if complaint_acknowledgement(out_of_office: true).present?

    raise ArgumentError, 'WhatsApp triage out-of-office complaint acknowledgement is missing'
  end
end
