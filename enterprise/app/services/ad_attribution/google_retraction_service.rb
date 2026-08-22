require 'googleauth'

class AdAttribution::GoogleRetractionService
  ADS_SCOPE = ['https://www.googleapis.com/auth/adwords'].freeze

  def initialize(delivery:)
    @delivery = delivery
    @conversion = delivery.ad_conversion
  end

  def perform(validate_only: false)
    validate_configuration!
    response = submit(validate_only)
    return response.parsed_response if validate_only

    delivery.record_attempt!
    return fail_request!(response) unless response.success? && response.parsed_response['partialFailureError'].blank?

    persist_retraction(response.parsed_response)
    response.parsed_response
  rescue StandardError => e
    record_exception(e, validate_only)
    raise
  end

  private

  attr_reader :conversion, :delivery

  def submit(validate_only)
    HTTParty.post(api_url, headers: headers, body: request_body(validate_only).to_json, timeout: 30)
  end

  def persist_retraction(result)
    delivery.update!(
      status: :retracted,
      diagnostic_data: delivery.diagnostic_data.merge('retraction_job_id' => result['jobId']),
      retracted_at: Time.current,
      next_attempt_at: nil,
      error_code: nil,
      error_message: nil
    )
  end

  def record_exception(error, validate_only)
    delivery.mark_failed!(error.class.name, 'Google conversion retraction failed') unless validate_only || delivery.failed?
  end

  def request_body(validate_only)
    {
      customerId: customer_id,
      conversionAdjustments: [{
        conversionAction: "customers/#{customer_id}/conversionActions/#{config['conversion_action_id']}",
        adjustmentType: 'RETRACTION',
        orderId: conversion.erp_order_ref,
        adjustmentDateTime: Time.current.strftime('%Y-%m-%d %H:%M:%S%:z')
      }],
      partialFailure: true,
      validateOnly: validate_only
    }
  end

  def headers
    {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json',
      'developer-token' => config['developer_token'],
      'login-customer-id' => config['login_customer_id'].to_s.delete('-')
    }
  end

  def access_token
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: config['client_id'],
      client_secret: config['client_secret'],
      refresh_token: config['refresh_token'],
      scope: ADS_SCOPE
    )
    credentials.fetch_access_token!['access_token']
  end

  def validate_configuration!
    required = %w[customer_id login_customer_id conversion_action_id developer_token client_id client_secret refresh_token]
    missing = required.select { |key| config[key].blank? }
    raise "Google Ads adjustment configuration is incomplete: #{missing.join(', ')}" if missing.any?
  end

  def fail_request!(response)
    delivery.mark_failed!("http_#{response.code}", 'Google conversion retraction failed')
    nil
  end

  def api_url
    "https://googleads.googleapis.com/#{config.fetch('api_version', 'v25')}/customers/#{customer_id}:uploadConversionAdjustments"
  end

  def customer_id
    @customer_id ||= config['customer_id'].to_s.delete('-')
  end

  def config
    @config ||= AdAttribution::Config.json('GOOGLE_AD_ADJUSTMENT_CONFIG')
  end
end
