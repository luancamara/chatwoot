# Traz gasto e entrega diários da Meta, por anúncio.
#
# Sem custo o relatório informa mas não decide: dá para ver qual anúncio traz
# mais lead, não qual traz lead mais barato nem qual se paga.
class AdAttribution::InsightsSyncService
  BASE_URI = 'https://graph.facebook.com'.freeze
  FIELDS = 'ad_id,spend,impressions,clicks,reach'.freeze

  pattr_initialize [{ since: nil, until_date: nil }]

  def perform
    return 0 if access_token.blank? || ad_account_id.blank?

    rows = fetch_all
    rows.each { |row| store(row) }
    rows.size
  end

  private

  def fetch_all
    url = "#{BASE_URI}/#{api_version}/act_#{ad_account_id}/insights"
    query = initial_query
    rows = []

    while url.present?
      response = HTTParty.get(url, query: query)
      unless response.success?
        Rails.logger.error "[ad_attribution] insights: #{response.parsed_response.dig('error', 'message')}"
        break
      end

      rows.concat(response.parsed_response['data'] || [])
      # O link de paginação da Meta já carrega token e filtros na própria URL.
      url = response.parsed_response.dig('paging', 'next')
      query = {}
    end
    rows
  end

  def initial_query
    {
      level: 'ad',
      fields: FIELDS,
      time_increment: 1,
      time_range: { since: period_start.iso8601, until: period_end.iso8601 }.to_json,
      limit: 500,
      access_token: access_token
    }
  end

  def store(row)
    insight = MetaAdInsight.find_or_initialize_by(ad_id: row['ad_id'], date: row['date_start'])
    insight.update!(
      spend: row['spend'].to_f,
      impressions: row['impressions'].to_i,
      clicks: row['clicks'].to_i,
      reach: row['reach'].to_i
    )
  end

  def period_start
    since || 7.days.ago.to_date
  end

  def period_end
    until_date || Date.current
  end

  # A conta de anúncios sai da própria campanha já sincronizada, para não
  # exigir mais um config que pode divergir do que os anúncios apontam.
  def ad_account_id
    return @ad_account_id if defined?(@ad_account_id)

    configured = GlobalConfigService.load('META_ADS_ACCOUNT_ID', '').presence
    return @ad_account_id = configured if configured

    campaign_id = MetaAd.where.not(campaign_id: nil).pick(:campaign_id)
    @ad_account_id = campaign_id.present? ? fetch_account_id(campaign_id) : nil
  end

  def fetch_account_id(campaign_id)
    response = HTTParty.get("#{BASE_URI}/#{api_version}/#{campaign_id}",
                            query: { fields: 'account_id', access_token: access_token })
    response.success? ? response.parsed_response['account_id'] : nil
  end

  def access_token
    @access_token ||= GlobalConfigService.load('META_ADS_ACCESS_TOKEN', '')
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end
end
