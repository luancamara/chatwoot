require 'googleauth'

class AdAttribution::GoogleDiagnosticsService
  API_URL = 'https://datamanager.googleapis.com/v1/requestStatus:retrieve'.freeze
  TOKEN_SCOPES = ['https://www.googleapis.com/auth/datamanager'].freeze
  TERMINAL_STATUSES = %w[SUCCESS FAILED FAILURE PARTIAL_SUCCESS].freeze

  def initialize(delivery:)
    @delivery = delivery
  end

  def perform
    delivery.record_attempt!
    response = fetch_status
    return fail_request!(response) unless response.success?

    handle_diagnostic(sanitize(Array(response.parsed_response['requestStatusPerDestination'])))
  rescue StandardError => e
    delivery.mark_failed!(e.class.name, 'Google diagnostics request failed') unless delivery.failed?
    raise
  end

  private

  attr_reader :delivery

  def fetch_status
    HTTParty.get(
      API_URL,
      headers: { 'Authorization' => "Bearer #{access_token}" },
      query: { requestId: delivery.external_request_id },
      timeout: 30
    )
  end

  def handle_diagnostic(diagnostic)
    values = diagnostic.pluck('request_status')
    return accept!(diagnostic) if values.present? && values.all?('SUCCESS')
    return fail_diagnostic!(diagnostic) if values.intersect?(TERMINAL_STATUSES - ['SUCCESS'])
    return fail_diagnostic!(diagnostic, 'diagnostics_timeout') if delivery.submitted_at < 24.hours.ago

    schedule_next_check(diagnostic)
  end

  def schedule_next_check(diagnostic)
    checks = delivery.diagnostic_data.fetch('checks', 0).to_i + 1
    delay = [30 * (1.3**checks), 60].min.minutes
    delivery.update!(diagnostic_data: { 'checks' => checks, 'statuses' => diagnostic }, next_attempt_at: delay.from_now)
  end

  def sanitize(statuses)
    statuses.map do |item|
      {
        'request_status' => item['requestStatus'],
        'error_info' => item['errorInfo'],
        'warning_info' => item['warningInfo'],
        'events_ingestion_status' => item['eventsIngestionStatus']
      }.compact
    end
  end

  def accept!(diagnostic)
    delivery.update!(status: :accepted, diagnostic_data: { 'statuses' => diagnostic }, accepted_at: Time.current, next_attempt_at: nil)
  end

  def fail_diagnostic!(diagnostic, code = 'diagnostics_failed')
    delivery.update!(
      status: :failed,
      error_code: code,
      error_message: 'Google Data Manager diagnostics reported a failure',
      diagnostic_data: { 'statuses' => diagnostic },
      next_attempt_at: nil
    )
  end

  def fail_request!(response)
    delivery.mark_failed!("http_#{response.code}", 'Google diagnostics request failed')
  end

  def access_token
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(config.fetch('service_account_credentials').to_json),
      scope: TOKEN_SCOPES
    )
    credentials.fetch_access_token!['access_token']
  end

  def config
    @config ||= AdAttribution::Config.json('GOOGLE_AD_CONVERSION_CONFIG')
  end
end
