# Resolves a Meta ad id into human readable campaign/adset/ad names plus the
# creative thumbnail, and caches it locally so reports can group by campaign
# without hitting the Graph API.
#
# Ads are fetched by id rather than by listing an ad account, so ads that live
# in closed or archived ad accounts still resolve.
class AdAttribution::MetaAdSyncService
  BASE_URI = 'https://graph.facebook.com'.freeze
  FIELDS = 'name,effective_status,adset{id,name},campaign{id,name},creative{thumbnail_url}'.freeze

  pattr_initialize [:ad_id!]

  def perform
    response = HTTParty.get(
      "#{BASE_URI}/#{api_version}/#{ad_id}",
      query: { fields: FIELDS, access_token: access_token }
    )

    response.success? ? store(response.parsed_response) : store_error(response)
  end

  private

  def store(body)
    meta_ad.update!(
      name: body['name'],
      effective_status: body['effective_status'],
      adset_id: body.dig('adset', 'id'),
      adset_name: body.dig('adset', 'name'),
      campaign_id: body.dig('campaign', 'id'),
      campaign_name: body.dig('campaign', 'name'),
      thumbnail_url: body.dig('creative', 'thumbnail_url'),
      synced_at: Time.current,
      sync_error: nil
    )
  end

  # Ads in ad accounts the token cannot reach are expected here. Record why so
  # the dashboard can explain the missing name instead of retrying forever.
  def store_error(response)
    meta_ad.update!(
      synced_at: Time.current,
      sync_error: response.parsed_response.dig('error', 'message').to_s.truncate(255)
    )
  end

  def meta_ad
    @meta_ad ||= MetaAd.find_or_create_by!(ad_id: ad_id)
  end

  def access_token
    GlobalConfigService.load('META_ADS_ACCESS_TOKEN', '').presence ||
      raise('META_ADS_ACCESS_TOKEN is not configured')
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end
end
