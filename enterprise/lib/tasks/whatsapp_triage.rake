namespace :whatsapp_triage do
  desc 'Validate WhatsApp triage configuration and create its account resources'
  task setup: :environment do
    inbox = WhatsappTriageTasks.setup!
    puts "WhatsApp triage resources are ready for inbox #{inbox.id} (#{inbox.name})."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    abort "WhatsApp triage setup failed: #{e.message}"
  end

  desc 'Set up and enable WhatsApp triage'
  task enable: :environment do
    inbox = WhatsappTriageTasks.setup!
    WhatsappTriageTasks.update_enabled!(true)
    puts "WhatsApp triage is enabled for inbox #{inbox.id} (#{inbox.name})."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    abort "WhatsApp triage enable failed: #{e.message}"
  end

  desc 'Disable WhatsApp triage while keeping normal inbox assignment available'
  task disable: :environment do
    WhatsappTriageTasks.update_enabled!(false)
    puts 'WhatsApp triage is disabled. New conversations will bypass the triage bot.'
  end

  desc 'Show WhatsApp triage configuration status'
  task status: :environment do
    WhatsappTriageTasks.print_status
  end
end

module WhatsappTriageTasks
  module_function

  def setup!
    ConfigLoader.new.process
    Whatsapp::Triage::SetupService.new.perform!
  end

  def update_enabled!(enabled)
    ConfigLoader.new.process
    configuration = Whatsapp::Triage::Configuration.new
    config_record = InstallationConfig.find_by!(name: Whatsapp::Triage::Configuration::CONFIG_KEY)
    config_record.update!(value: configuration.to_h.merge('enabled' => enabled).to_json)
  end

  def print_status
    configuration = Whatsapp::Triage::Configuration.new
    inbox = configuration.inbox
    print_configuration_status(configuration, inbox)
    print_area_status(configuration)
    puts "SLA policy: #{identifier(configuration.sla_policy_id)}"
    puts "Triage bot active: #{inbox&.agent_bot_inbox&.active? || false}"
  end

  def print_configuration_status(configuration, inbox)
    puts "Enabled: #{configuration.enabled?}"
    puts "Operational: #{inbox.present? && configuration.operational_for?(inbox)}"
    puts "Inbox: #{inbox_description(inbox)}"
  end

  def print_area_status(configuration)
    Whatsapp::Triage::Configuration::AREAS.each do |area|
      puts "#{area}: team=#{identifier(configuration.team_id(area))} fallback_user=#{identifier(configuration.fallback_user_id(area))}"
    end
  end

  def inbox_description(inbox)
    inbox.present? ? "#{inbox.id} (#{inbox.name})" : 'not configured'
  end

  def identifier(value)
    value || '-'
  end
end
