require 'googleauth'

class AdAttribution::GoogleDataManagerService
  API_URL = 'https://datamanager.googleapis.com/v1/events:ingest'.freeze
  TOKEN_SCOPES = ['https://www.googleapis.com/auth/datamanager'].freeze

  def initialize(delivery:)
    @delivery = delivery
    @conversion = delivery.ad_conversion
  end

  def perform(validate_only: false)
    validate_configuration!
    response = submit(validate_only)
    return response.parsed_response if validate_only

    delivery.record_attempt!
    return fail_request!(response) unless response.success?

    persist_submission(response.parsed_response)
    response.parsed_response
  rescue StandardError => e
    record_exception(e, validate_only)
    raise
  end

  private

  attr_reader :conversion, :delivery

  def submit(validate_only)
    HTTParty.post(API_URL, headers: headers, body: request_body(validate_only).to_json, timeout: 30)
  end

  def persist_submission(result)
    delivery.update!(
      status: :submitted,
      external_event_id: conversion.erp_order_ref,
      external_request_id: result['requestId'],
      submitted_at: Time.current,
      next_attempt_at: 30.minutes.from_now,
      error_code: nil,
      error_message: nil,
      diagnostic_data: { 'field_warnings' => sanitize_field_warnings(result['fieldWarnings']) }
    )
  end

  def sanitize_field_warnings(warnings)
    Array(warnings).map { |warning| warning.to_h.slice('fieldPath', 'warningCode') }
  end

  def record_exception(error, validate_only)
    delivery.mark_failed!(error.class.name, 'Google Data Manager request failed') unless validate_only || delivery.failed?
  end

  def request_body(validate_only)
    {
      destinations: [destination],
      encoding: 'HEX',
      events: [event],
      validateOnly: validate_only
    }.tap do |payload|
      payload[:consent] = config['consent'] if config['consent'].present?
    end
  end

  def destination
    {
      operatingAccount: { accountType: 'GOOGLE_ADS', accountId: account_id(config['customer_id']) },
      loginAccount: { accountType: 'GOOGLE_ADS', accountId: account_id(config['login_customer_id']) },
      productDestinationId: config['conversion_action_id']
    }
  end

  def event
    base_event.tap { |payload| add_optional_event_fields(payload) }
  end

  def base_event
    {
      conversionValue: conversion.value.to_f,
      currency: 'BRL',
      eventTimestamp: conversion.ordered_at.iso8601,
      transactionId: conversion.erp_order_ref,
      eventSource: event_source,
      additionalEventParameters: origin_parameters
    }
  end

  def add_optional_event_fields(payload)
    payload[:userData] = { userIdentifiers: user_identifiers } if user_identifiers.present?
    payload[:adIdentifiers] = ad_identifiers if ad_identifiers.present?
    return unless conversion.physical_store? && conversion.origin_data['store_ref'].present?

    payload[:eventLocation] = { storeId: conversion.origin_data['store_ref'] }
  end

  def origin_parameters
    {
      'erp_origin' => conversion.origin_classification,
      'erp_source' => conversion.origin_data['source'],
      'erp_store' => conversion.origin_data['store_ref'],
      'erp_terminal' => conversion.origin_data['terminal_ref'],
      'erp_media' => conversion.origin_data['media_ref']
    }.filter_map do |name, value|
      { parameterName: name, value: value } if value.present?
    end
  end

  def user_identifiers
    @user_identifiers ||= Array(conversion.user_data.dig('google', 'user_identifiers')).filter_map do |identifier|
      identifier = identifier.deep_stringify_keys
      if identifier['email_address'].present?
        { emailAddress: identifier['email_address'].upcase }
      elsif identifier['phone_number'].present?
        { phoneNumber: identifier['phone_number'].upcase }
      end
    end.compact
  end

  def ad_identifiers
    @ad_identifiers ||= conversion.user_data.dig('google', 'ad_identifiers').to_h.symbolize_keys
  end

  def event_source
    return 'IN_STORE' if conversion.physical_store?
    return 'WEB' if conversion.ecommerce?

    'OTHER'
  end

  def headers
    { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' }
  end

  def access_token
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(config.fetch('service_account_credentials').to_json),
      scope: TOKEN_SCOPES
    )
    credentials.fetch_access_token!['access_token']
  end

  def validate_configuration!
    required = %w[customer_id login_customer_id conversion_action_id service_account_credentials]
    missing = required.select { |key| config[key].blank? }
    raise "Google Data Manager configuration is incomplete: #{missing.join(', ')}" if missing.any?
    raise 'Google conversion identifiers are missing' if user_identifiers.blank? && ad_identifiers.blank?
  end

  def fail_request!(response)
    delivery.mark_failed!("http_#{response.code}", 'Google Data Manager request failed')
    nil
  end

  def account_id(value)
    value.to_s.delete('-')
  end

  def config
    @config ||= AdAttribution::Config.json('GOOGLE_AD_CONVERSION_CONFIG')
  end
end
