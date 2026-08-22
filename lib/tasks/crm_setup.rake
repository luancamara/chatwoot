# CRM Setup - Create custom attributes for CRM workflow
#
# This task creates the CRM custom attribute definitions and configures
# required attributes with conditional logic for an account.
#
# Usage Examples:
#   # Using arguments
#   bundle exec rake "crm:setup[1]"
#
#   # Using environment variables (recommended)
#   ACCOUNT_ID=1 bundle exec rake crm:setup
#
# Parameters:
#   ACCOUNT_ID: ID of the account to configure (required)
#
# Notes:
#   - Only runs in development environment
#   - Safe to run multiple times (uses find_or_create_by!)
#   - Creates 3 custom attribute definitions: crm_disposition_result, crm_loss_reason, crm_funnel_stage
#   - Configures crm_disposition_result as required on resolve
#   - Configures crm_loss_reason as conditionally required when disposition = "Perda"
#
# rubocop:disable Metrics/BlockLength
namespace :crm do
  desc 'Set up CRM custom attributes for an account'
  task :setup, [:account_id] => :environment do |_t, args|
    unless Rails.env.development?
      puts 'This task can only be run in the development environment.'
      puts "Current environment: #{Rails.env}"
      exit(1)
    end

    account_id = args[:account_id] || ENV.fetch('ACCOUNT_ID', nil)

    if account_id.blank?
      puts 'Error: ACCOUNT_ID is required'
      puts 'Usage: bundle exec rake "crm:setup[account_id]"'
      puts 'Or: ACCOUNT_ID=1 bundle exec rake crm:setup'
      exit(1)
    end

    account = Account.find_by(id: account_id)
    unless account
      puts "Error: Account with ID #{account_id} not found"
      exit(1)
    end

    puts "Setting up CRM attributes for Account #{account_id} (#{account.name})"
    puts "Started at: #{Time.current}"

    # Define the CRM custom attributes
    attributes = [
      {
        attribute_display_name: 'Resultado do Atendimento',
        attribute_key: 'crm_disposition_result',
        attribute_display_type: :list,
        attribute_model: :conversation_attribute,
        attribute_values: ['Venda', 'Perda', 'Indecisão', 'Sem Resposta']
      },
      {
        attribute_display_name: 'Motivo da Perda',
        attribute_key: 'crm_loss_reason',
        attribute_display_type: :list,
        attribute_model: :conversation_attribute,
        attribute_values: ['Preço', 'Prazo de Entrega', 'Falta de Estoque', 'Atendimento', 'Outro']
      },
      {
        attribute_display_name: 'Etapa do Funil',
        attribute_key: 'crm_funnel_stage',
        attribute_display_type: :list,
        attribute_model: :conversation_attribute,
        attribute_values: %w[Lead Qualificado Orçamento Negociação Venda Perda]
      }
    ]

    # Create or update custom attribute definitions
    attributes.each do |attrs|
      definition = account.custom_attribute_definitions.find_or_initialize_by(
        attribute_key: attrs[:attribute_key],
        attribute_model: attrs[:attribute_model]
      )
      definition.assign_attributes(
        attribute_display_name: attrs[:attribute_display_name],
        attribute_display_type: attrs[:attribute_display_type],
        attribute_values: attrs[:attribute_values]
      )
      definition.save!
      puts "  [OK] #{definition.attribute_key} (#{definition.attribute_display_name})"
    end

    # Configure required attributes
    account.conversation_required_attributes = ['crm_disposition_result']
    puts "\n  [OK] conversation_required_attributes = #{account.conversation_required_attributes}"

    # Configure conditional attributes
    account.conversation_required_attribute_conditions = {
      'crm_loss_reason' => { 'depends_on' => 'crm_disposition_result', 'when_value' => 'Perda' }
    }
    puts "  [OK] conversation_required_attribute_conditions = #{account.conversation_required_attribute_conditions}"

    account.save!

    puts "\nCRM setup completed for Account #{account_id}."
  end
end
# rubocop:enable Metrics/BlockLength
