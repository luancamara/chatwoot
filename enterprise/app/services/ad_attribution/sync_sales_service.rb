class AdAttribution::SyncSalesService
  SaleContext = Data.define(:sale, :ordered_at, :order_ref, :identifiers, :origin, :existing, :referral)
  HASH_PATTERN = /\A[0-9a-f]{64}\z/i
  META_HASH_FIELDS = %w[em ph fn ln ge db ct st zp country].freeze
  GOOGLE_AD_FIELDS = %w[gclid gbraid wbraid].freeze
  ORIGIN_FIELDS = %w[source store_ref terminal_ref media_ref].freeze

  def initialize(account:, since:, until_time: Time.current, dry_run: false)
    @account = account
    @since = since
    @until_time = until_time
    @dry_run = dry_run
    @stats = Hash.new(0)
    @seen_orders = Set.new
  end

  def perform
    client.each_sale(since: since, until_time: until_time) { |sale| process(sale.deep_stringify_keys) }
    stats
  end

  private

  attr_reader :account, :since, :until_time, :dry_run, :stats, :seen_orders

  def process(sale)
    context = build_context(sale)
    record_stats(context)
    persist(context) unless dry_run
  end

  def build_context(sale)
    ordered_at = Time.zone.parse(sale.fetch('ordered_at'))
    order_ref = sale.fetch('erp_order_ref')
    identifiers = sanitize_identifiers(sale.fetch('identifiers', {}))
    origin = sale.fetch('origin', {})
    existing = AdConversion.find_by(account_id: account.id, erp_order_ref: order_ref)
    referral = matcher.match(identifiers, ordered_at)
    SaleContext.new(sale: sale, ordered_at: ordered_at, order_ref: order_ref, identifiers: identifiers, origin: origin, existing: existing,
                    referral: referral)
  end

  def record_stats(context)
    stats[:fetched] += 1
    stats[status_for(context.sale)] += 1
    stats[context.existing ? :observed : :created] += 1
    record_quality_stats(context)
    record_ledger_stats(context)
  end

  def record_quality_stats(context)
    increment_stat(:duplicates) unless seen_orders.add?(context.order_ref)
    increment_stat(:missing_identifiers) if match_keys(context.identifiers).blank?
    increment_stat(:unknown_origins) if origin_classification(context.origin) == 'unknown'
    stats[:value] += context.sale['value'].to_d if context.sale['erp_status'].to_i == 4
  end

  def record_ledger_stats(context)
    increment_stat(:changed) if context.existing && conversion_changed?(context)
    increment_stat(:attributed) if context.referral || context.existing&.conversation_ad_referral_id
  end

  def persist(context)
    conversion = context.existing || AdConversion.new(account: account, erp_order_ref: context.order_ref)
    conversion.assign_attributes(conversion_attributes(context, conversion))
    conversion.save!
    reconcile_deliveries(conversion)
  end

  def conversion_attributes(context, conversion)
    {
      conversation_ad_referral: context.referral || conversion.conversation_ad_referral,
      ordered_at: context.ordered_at,
      value: context.sale.fetch('value'),
      status: status_for(context.sale),
      erp_status: context.sale['erp_status'],
      origin_classification: origin_classification(context.origin),
      origin_data: context.origin.slice(*ORIGIN_FIELDS),
      user_data: context.identifiers,
      last_observed_at: Time.current
    }
  end

  def conversion_changed?(context)
    context.existing.value != context.sale.fetch('value').to_d ||
      context.existing.ordered_at != context.ordered_at ||
      context.existing.erp_status != context.sale['erp_status'].to_i ||
      context.existing.origin_classification != origin_classification(context.origin)
  end

  def status_for(sale)
    sale['erp_status'].to_i == 6 ? :cancelled : :sold
  end

  def increment_stat(key)
    stats[key] += 1
  end

  def reconcile_deliveries(conversion)
    reconcile_meta_delivery(conversion, conversion.delivery_for(:meta))
    reconcile_google_delivery(conversion, conversion.delivery_for(:google))
  end

  def reconcile_meta_delivery(conversion, delivery)
    return if delivery.legacy_unknown? || delivery.retracted?

    return record_meta_cancellation(conversion, delivery) if delivery.accepted?

    set_pending_or_skipped(delivery, meta_skip_reason(conversion))
  end

  def reconcile_google_delivery(conversion, delivery)
    return if delivery.status.in?(%w[submitted accepted retracted failed])

    set_pending_or_skipped(delivery, google_skip_reason(conversion))
  end

  def record_meta_cancellation(conversion, delivery)
    return unless conversion.cancelled?

    delivery.update!(diagnostic_data: delivery.diagnostic_data.merge('cancelled_after_submission' => true))
  end

  def meta_skip_reason(conversion)
    return 'cancelled_before_submission' if conversion.cancelled?
    return 'native_ecommerce_purchase' if conversion.ecommerce?
    return 'unknown_origin' if conversion.unknown?
    return 'missing_identifiers' if meta_identifiers(conversion).blank? && conversion.conversation_ad_referral&.ctwa_clid.blank?
  end

  def google_skip_reason(conversion)
    return 'cancelled_before_submission' if conversion.cancelled?
    return 'missing_identifiers' if google_identifiers(conversion).blank? && google_ad_identifiers(conversion).blank?
  end

  def set_pending_or_skipped(delivery, reason)
    if reason
      delivery.update!(status: :skipped, error_code: reason, error_message: nil, next_attempt_at: nil)
    else
      delivery.update!(status: :pending, error_code: nil, error_message: nil, next_attempt_at: nil)
    end
  end

  def sanitize_identifiers(raw)
    raw = raw.deep_stringify_keys
    {
      'match' => {
        'email_sha256' => hashes(raw.dig('match', 'email_sha256')),
        'phone_sha256' => hashes(raw.dig('match', 'phone_sha256'))
      },
      'meta' => META_HASH_FIELDS.index_with { |field| hashes(raw.dig('meta', field)) }.compact_blank,
      'google' => {
        'user_identifiers' => sanitize_google_users(raw.dig('google', 'user_identifiers')),
        'ad_identifiers' => raw.fetch('google', {}).fetch('ad_identifiers', {}).slice(*GOOGLE_AD_FIELDS).compact_blank
      }
    }
  end

  def origin_classification(origin)
    value = origin['classification'].to_s
    AdConversion.origin_classifications.key?(value) ? value : 'unknown'
  end

  def sanitize_google_users(values)
    Array(values).filter_map do |identifier|
      identifier = identifier.deep_stringify_keys
      key = (identifier.keys & %w[email_address phone_number]).first
      value = identifier[key]
      { key => value } if key && value.to_s.match?(HASH_PATTERN)
    end
  end

  def hashes(values)
    Array(values).select { |value| value.to_s.match?(HASH_PATTERN) }.map(&:downcase).uniq
  end

  def match_keys(identifiers)
    identifiers.dig('match', 'email_sha256') + identifiers.dig('match', 'phone_sha256')
  end

  def meta_identifiers(conversion)
    conversion.user_data.fetch('meta', {}).values.flatten.compact
  end

  def google_identifiers(conversion)
    conversion.user_data.dig('google', 'user_identifiers')
  end

  def google_ad_identifiers(conversion)
    conversion.user_data.dig('google', 'ad_identifiers')
  end

  def matcher
    @matcher ||= AdAttribution::IdentityMatcher.new(account: account, since: since, until_time: until_time)
  end

  def client
    @client ||= AdAttribution::ErpClient.new
  end
end
