module ConversationRiskMonitorTasks
  module_function

  def migrate_legacy!
    legacy = legacy_settings
    inbox = Inbox.find(Integer(legacy.fetch('inbox_id')))
    team_id = Integer(legacy.fetch('team_ids').fetch('complaints'))
    cleanup = ConversationRiskMonitor::LegacyCleanupService.new(inbox: inbox)

    puts "Before migration: #{cleanup.audit.to_json}"
    cleanup.perform!
    config = configure_monitor(inbox, team_id)
    puts "After migration: #{cleanup.audit.merge(configured: true, enabled: config.enabled?).to_json}"
  end

  def enable!(inbox_id)
    config = find_config(inbox_id)
    config.account.update!(conversation_risk_monitor_enabled: true)
    config.update!(enabled: true)
    puts "Silent monitor enabled: #{status(config).to_json}"
  end

  def disable!(inbox_id)
    config = find_config(inbox_id)
    config.update!(enabled: false)
    puts "Silent monitor disabled: #{status(config).to_json}"
  end

  def print_status(inbox_id)
    puts status(find_config(inbox_id)).to_json
  end

  def configure_monitor(inbox, team_id)
    config = inbox.account.conversation_risk_monitor_configs.find_or_initialize_by(inbox: inbox)
    config.update!(
      enabled: false,
      management_team: inbox.account.teams.find(team_id),
      complaint_label: inbox.account.labels.find_by!(title: 'triage-reclamacao'),
      critical_label: inbox.account.labels.find_by!(title: 'triage-reclamacao-critica')
    )
    config
  end

  def legacy_settings
    value = InstallationConfig.find_by!(name: ConversationRiskMonitor::LegacyCleanupService::CONFIG_KEY).value
    value.is_a?(String) ? JSON.parse(value) : value.deep_stringify_keys
  end

  def find_config(inbox_id)
    ConversationRiskMonitorConfig.find_by!(inbox_id: Integer(inbox_id))
  end

  def status(config)
    {
      account_id: config.account_id,
      inbox_id: config.inbox_id,
      enabled: config.enabled?,
      account_enabled: ActiveModel::Type::Boolean.new.cast(config.account.conversation_risk_monitor_enabled),
      operational: config.operational?,
      management_team_id: config.management_team_id,
      complaint_label_id: config.complaint_label_id,
      critical_label_id: config.critical_label_id
    }
  end
end

namespace :conversation_risk_monitor do
  desc 'Audit and migrate the legacy WhatsApp triage into the silent monitor'
  task migrate_legacy: :environment do
    ConversationRiskMonitorTasks.migrate_legacy!
  end

  desc 'Enable the configured silent monitor for an inbox'
  task :enable, [:inbox_id] => :environment do |_task, args|
    ConversationRiskMonitorTasks.enable!(args.fetch(:inbox_id))
  end

  desc 'Disable the configured silent monitor for an inbox'
  task :disable, [:inbox_id] => :environment do |_task, args|
    ConversationRiskMonitorTasks.disable!(args.fetch(:inbox_id))
  end

  desc 'Show silent monitor status'
  task :status, [:inbox_id] => :environment do |_task, args|
    ConversationRiskMonitorTasks.print_status(args.fetch(:inbox_id))
  end
end
