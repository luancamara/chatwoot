class AdAttribution::DispatchDeliveriesJob < ApplicationJob
  queue_as :low

  def perform
    dispatch_meta if AdAttribution::Config.meta_live?
    dispatch_google if AdAttribution::Config.google_live?
  end

  private

  def dispatch_meta
    deliveries(:meta, :pending).where(ad_conversions: { status: 'sold' })
                               .where('ad_conversions.ordered_at <= ?', 48.hours.ago)
                               .find_each do |delivery|
      deliver(delivery) { AdAttribution::CapiEventService.new(delivery: delivery).perform }
    end
  end

  def dispatch_google
    deliveries(:google, :pending).where(ad_conversions: { status: 'sold' }).find_each do |delivery|
      deliver(delivery) { AdAttribution::GoogleDataManagerService.new(delivery: delivery).perform }
    end

    deliveries(:google, :submitted).find_each do |delivery|
      deliver(delivery) { AdAttribution::GoogleDiagnosticsService.new(delivery: delivery).perform }
    end

    deliveries(:google, :accepted).where(ad_conversions: { status: 'cancelled' }).find_each do |delivery|
      deliver(delivery) { AdAttribution::GoogleRetractionService.new(delivery: delivery).perform }
    end
  end

  def deliveries(provider, status)
    AdConversionDelivery.where(provider: provider, status: status)
                        .joins(:ad_conversion)
                        .where('next_attempt_at IS NULL OR next_attempt_at <= ?', Time.current)
  end

  def deliver(delivery)
    yield
  rescue StandardError => e
    delivery.mark_failed!(e.class.name, 'Conversion delivery failed') unless delivery.failed?
    Rails.logger.error "[ad_attribution] delivery=#{delivery.id} provider=#{delivery.provider} failed=#{e.class.name}"
  end
end
