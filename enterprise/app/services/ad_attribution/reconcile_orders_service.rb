class AdAttribution::ReconcileOrdersService
  DEFAULT_WINDOW_DAYS = 90

  def initialize(account:, since: nil, window_days: DEFAULT_WINDOW_DAYS, dry_run: false)
    @service = AdAttribution::SyncSalesService.new(
      account: account,
      since: since || window_days.days.ago,
      until_time: Time.current,
      dry_run: dry_run
    )
  end

  def perform
    @service.perform[:created]
  end
end
