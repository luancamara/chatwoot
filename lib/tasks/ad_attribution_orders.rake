namespace :ad_attribution do
  desc 'Reconcile every ad-attributed conversation against ERP orders'
  task reconcile_orders: :environment do
    since = ENV['SINCE'].presence && Time.zone.parse(ENV.fetch('SINCE'))
    window = (ENV['WINDOW_DAYS'] || AdAttribution::ReconcileOrdersService::DEFAULT_WINDOW_DAYS).to_i
    total = 0

    Account.where(id: ConversationAdReferral.select(:account_id).distinct).find_each do |account|
      created = AdAttribution::ReconcileOrdersService.new(
        account: account, since: since, window_days: window
      ).perform
      total += created
      puts "conta #{account.id}: #{created} conversões"
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] conta #{account.id}: #{e.message}"
      puts "conta #{account.id}: erro — #{e.message}"
    end

    sold = AdConversion.sold
    puts "\nTotal: #{total} conversões novas."
    puts "Base: #{AdConversion.count} pedidos casados, #{sold.count} vendidos, R$ #{sold.sum(:value).round(2)} de receita."
  end
end
