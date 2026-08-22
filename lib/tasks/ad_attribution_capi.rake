namespace :ad_attribution do
  desc 'Queue eligible non-legacy Meta deliveries inside the accepted CAPI window'
  task backfill_capi: :environment do
    since = Time.zone.parse(ENV.fetch('SINCE', 7.days.ago.iso8601))
    scope = AdConversionDelivery.meta.pending
                                .joins(:ad_conversion)
                                .where(ad_conversions: { status: 'sold', ordered_at: since..48.hours.ago })
    puts "eligible=#{scope.count} legacy_unknown=#{AdConversionDelivery.meta.legacy_unknown.count}"
    AdAttribution::DispatchDeliveriesJob.perform_later if AdAttribution::Config.meta_live?
  end

  desc 'Send one eligible conversion to Meta Test Events'
  task test_meta: :environment do
    delivery = AdConversionDelivery.meta.pending.find_by!(ad_conversion_id: ENV.fetch('CONVERSION_ID'))
    test_code = ENV['TEST_EVENT_CODE'].presence || GlobalConfigService.load('META_CAPI_TEST_EVENT_CODE', '')
    raise 'TEST_EVENT_CODE is required' if test_code.blank?

    result = AdAttribution::CapiEventService.new(delivery: delivery).perform(test_event_code: test_code)
    puts "events_received=#{result['events_received']}"
  end

  desc 'Validate one conversion with Google Data Manager without applying it'
  task validate_google: :environment do
    delivery = AdConversionDelivery.google.pending.find_by!(ad_conversion_id: ENV.fetch('CONVERSION_ID'))
    result = AdAttribution::GoogleDataManagerService.new(delivery: delivery).perform(validate_only: true)
    puts "validated=#{result.present?}"
  end

  desc 'Validate one Google retraction without applying it'
  task validate_google_retraction: :environment do
    delivery = AdConversionDelivery.google.accepted.find_by!(ad_conversion_id: ENV.fetch('CONVERSION_ID'))
    result = AdAttribution::GoogleRetractionService.new(delivery: delivery).perform(validate_only: true)
    puts "validated=#{result.present?}"
  end
end
