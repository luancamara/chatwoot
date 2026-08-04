# Resolves a Meta ad id into human readable campaign/adset/ad names plus the
# creative thumbnail, and caches it locally so reports can group by campaign
# without hitting the Graph API.
#
# Ads are fetched by id rather than by listing an ad account, so ads that live
# in closed or archived ad accounts still resolve.
class AdAttribution::MetaAdSyncService
  BASE_URI = 'https://graph.facebook.com'.freeze
  FIELDS = 'name,effective_status,adset{id,name},campaign{id,name},creative{thumbnail_url,video_id}'.freeze

  pattr_initialize [:ad_id!]

  # Returns the ad's video source url when one could be resolved, so the caller
  # can store the real creative instead of the still.
  def perform
    # Recorded rather than raised: without a row the job has nothing to back off
    # on and would re-raise for every ad-attributed conversation forever. The
    # message surfaces in the sidebar and report, which is the visible signal.
    if access_token.blank?
      record_error('META_ADS_ACCESS_TOKEN is not configured')
      return
    end

    response = HTTParty.get(
      "#{BASE_URI}/#{api_version}/#{ad_id}",
      query: { fields: FIELDS, access_token: access_token }
    )

    unless response.success?
      record_error(response.parsed_response.dig('error', 'message'))
      return
    end

    store(response.parsed_response)
    video_source_url(response.parsed_response.dig('creative', 'video_id'))
  end

  private

  # The only way to reach the actual video file: the webhook's video_url is a
  # reel page, and the creative only carries the video's id.
  def video_source_url(video_id)
    return if video_id.blank?

    response = HTTParty.get(
      "#{BASE_URI}/#{api_version}/#{video_id}",
      query: { fields: 'source', access_token: access_token }
    )
    response.success? ? response.parsed_response['source'] : nil
  end

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
  # the dashboard can explain the missing name.
  def record_error(message)
    meta_ad.update!(synced_at: Time.current, sync_error: message.to_s.truncate(255))
  end

  def meta_ad
    @meta_ad ||= MetaAd.find_or_create_by!(ad_id: ad_id)
  end

  def access_token
    @access_token ||= GlobalConfigService.load('META_ADS_ACCESS_TOKEN', '')
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end
end
