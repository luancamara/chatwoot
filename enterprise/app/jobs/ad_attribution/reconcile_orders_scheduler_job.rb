class AdAttribution::ReconcileOrdersSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  # Só contas que têm atribuição de anúncio; as demais não têm o que reconciliar.
  def perform
    Account.where(id: ConversationAdReferral.select(:account_id).distinct).find_each(batch_size: 50) do |account|
      AdAttribution::ReconcileOrdersJob.perform_later(account)
    end
  end
end
