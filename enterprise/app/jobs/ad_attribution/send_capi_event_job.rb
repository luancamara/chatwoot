class AdAttribution::SendCapiEventJob < ApplicationJob
  queue_as :low

  def perform(conversion)
    return unless AdAttribution::Config.meta_live?

    delivery = conversion.delivery_for(:meta)
    AdAttribution::CapiEventService.new(delivery: delivery).perform
  end
end
