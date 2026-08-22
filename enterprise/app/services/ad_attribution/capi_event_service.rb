class AdAttribution::CapiEventService
  BASE_URI = 'https://graph.facebook.com'.freeze

  def initialize(delivery:, erp_client: AdAttribution::ErpClient.new)
    @delivery = delivery
    @conversion = delivery.ad_conversion
    @erp_client = erp_client
  end

  def perform(test_event_code: nil)
    @test_only = test_event_code.present?
    reason = ineligible_reason
    return handle_ineligible(reason) if reason

    validate_configuration!
    delivery.record_attempt! unless test_only?
    response = submit(test_event_code)
    return fail_request!(response) unless response.success?

    handle_success(response.parsed_response)
  rescue StandardError => e
    record_exception(e)
    raise
  end

  private

  attr_reader :conversion, :delivery, :erp_client

  def submit(test_event_code)
    HTTParty.post(
      "#{BASE_URI}/#{api_version}/#{dataset_id}/events",
      body: request_body(test_event_code).to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 30
    )
  end

  def handle_success(result)
    return result if test_only?

    delivery.update!(
      status: :accepted,
      external_event_id: conversion.erp_order_ref,
      error_code: nil,
      error_message: nil,
      diagnostic_data: { 'events_received' => result['events_received'], 'messages' => Array(result['messages']) },
      submitted_at: Time.current,
      accepted_at: Time.current,
      next_attempt_at: nil
    )
    result
  end

  def ineligible_reason
    return 'conversion_not_sold' unless conversion.sold?
    return 'conversion_not_ready' if conversion.ordered_at > 48.hours.ago
    return 'native_ecommerce_purchase' if conversion.ecommerce?
    return 'unknown_origin' if conversion.unknown?
    return unless confirmed_erp_status != 4

    confirmed_erp_status == 6 ? 'cancelled_before_submission' : 'erp_status_not_confirmed'
  end

  def handle_ineligible(reason)
    return if test_only?
    return retry_confirmation_later! if reason == 'erp_status_not_confirmed'

    skip!(reason)
  end

  def record_exception(error)
    delivery.mark_failed!(error.class.name, 'Meta CAPI request failed') unless test_only? || delivery.failed?
  end

  def request_body(test_event_code)
    { data: [event], access_token: access_token }.tap do |payload|
      payload[:test_event_code] = test_event_code if test_event_code.present?
    end
  end

  def event
    {
      event_name: 'Purchase',
      event_time: conversion.ordered_at.to_i,
      event_id: conversion.erp_order_ref,
      action_source: ctwa? ? 'business_messaging' : 'physical_store',
      user_data: ctwa? ? ctwa_user_data : conversion.user_data.fetch('meta'),
      custom_data: { value: conversion.value.to_f, currency: 'BRL', order_id: conversion.erp_order_ref }
    }.tap do |payload|
      payload[:messaging_channel] = 'whatsapp' if ctwa?
    end
  end

  def ctwa?
    referral&.ctwa_clid.present?
  end

  def ctwa_user_data
    {
      ctwa_clid: referral.ctwa_clid,
      whatsapp_business_account_id: waba_id
    }
  end

  def referral
    conversion.conversation_ad_referral
  end

  def waba_id
    @waba_id ||= referral&.inbox&.channel.try(:provider_config)&.dig('business_account_id')
  end

  def validate_configuration!
    raise 'META_CAPI_DATASET_ID is not configured' if dataset_id.blank?
    raise 'META_CAPI_ACCESS_TOKEN is not configured' if access_token.blank?
    raise 'WhatsApp Business Account ID is missing' if ctwa? && waba_id.blank?
    raise 'Meta user identifiers are missing' if !ctwa? && conversion.user_data.fetch('meta', {}).blank?
  end

  def fail_request!(response)
    return nil if test_only?

    delivery.mark_failed!("http_#{response.code}", 'Meta CAPI request failed')
    nil
  end

  def skip!(reason)
    delivery.update!(status: :skipped, error_code: reason, next_attempt_at: nil)
    nil
  end

  def retry_confirmation_later!
    delivery.update!(status: :pending, error_code: 'erp_status_not_confirmed', next_attempt_at: 1.hour.from_now)
    nil
  end

  def confirmed_erp_status
    return 4 if test_only?
    return @confirmed_erp_status if defined?(@confirmed_erp_status)

    sale = erp_client.find_sale(order_ref: conversion.erp_order_ref, ordered_at: conversion.ordered_at)
    @confirmed_erp_status = sale&.fetch('erp_status', nil)&.to_i
    return @confirmed_erp_status unless @confirmed_erp_status == 6

    conversion.update!(status: :cancelled, erp_status: 6, last_observed_at: Time.current)
    @confirmed_erp_status
  end

  def test_only?
    @test_only
  end

  def dataset_id
    @dataset_id ||= GlobalConfigService.load('META_CAPI_DATASET_ID', '')
  end

  def access_token
    @access_token ||= GlobalConfigService.load('META_CAPI_ACCESS_TOKEN', '').presence ||
                      GlobalConfigService.load('META_ADS_ACCESS_TOKEN', '')
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end
end
