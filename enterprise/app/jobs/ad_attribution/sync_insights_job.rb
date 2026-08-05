class AdAttribution::SyncInsightsJob < ApplicationJob
  queue_as :scheduled_jobs

  # Sete dias em vez de um: a Meta reprocessa atribuição por alguns dias, então
  # o gasto de ontem ainda muda depois.
  def perform
    rows = AdAttribution::InsightsSyncService.new.perform
    Rails.logger.info "[ad_attribution] insights: #{rows} linhas de gasto sincronizadas"
  end
end
