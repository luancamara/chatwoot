# rubocop:disable Metrics/BlockLength
namespace :ad_attribution do
  desc 'Dry-run ERP sales against the canonical ledger without writing to the database'
  task dry_run: :environment do
    each_conversion_account do |account|
      stats = sync_service(account, dry_run: true).perform
      puts "account=#{account.id} #{format_stats(stats)}"
    end
  end

  desc 'Synchronize ERP sales into the canonical ledger without delivering them'
  task sync_sales: :environment do
    each_conversion_account do |account|
      stats = sync_service(account, dry_run: false).perform
      puts "account=#{account.id} #{format_stats(stats)}"
    end
  end

  desc 'Show canonical ledger and provider delivery counts'
  task status: :environment do
    puts "conversions=#{AdConversion.count} sold=#{AdConversion.sold.count} cancelled=#{AdConversion.cancelled.count}"
    puts "value_brl=#{AdConversion.sold.sum(:value).round(2)} attributed=#{AdConversion.where.not(conversation_ad_referral_id: nil).count}"
    AdConversionDelivery.group(:provider, :status).count.sort.each do |(provider, status), count|
      puts "provider=#{provider} status=#{status} count=#{count}"
    end
  end

  def each_conversion_account(&)
    account_id = ENV['ACCOUNT_ID'].presence || AdAttribution::Config.account_id
    raise 'ACCOUNT_ID or AD_CONVERSION_ACCOUNT_ID is required' if account_id.blank?

    Account.where(id: account_id).find_each(&)
  end

  def sync_service(account, dry_run:)
    since = Time.zone.parse(ENV.fetch('SINCE', 90.days.ago.iso8601))
    until_time = Time.zone.parse(ENV.fetch('UNTIL', Time.current.iso8601))
    AdAttribution::SyncSalesService.new(account: account, since: since, until_time: until_time, dry_run: dry_run)
  end

  def format_stats(stats)
    %i[fetched created observed changed sold cancelled duplicates missing_identifiers unknown_origins attributed value].map do |key|
      "#{key}=#{stats[key]}"
    end.join(' ')
  end
end
# rubocop:enable Metrics/BlockLength
