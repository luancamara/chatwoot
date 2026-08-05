class AdAttribution::ReconcileOrdersJob < ApplicationJob
  queue_as :low

  def perform(account)
    created = AdAttribution::ReconcileOrdersService.new(account: account).perform
    Rails.logger.info "[ad_attribution] conta #{account.id}: #{created} conversões novas" if created.positive?
  end
end
