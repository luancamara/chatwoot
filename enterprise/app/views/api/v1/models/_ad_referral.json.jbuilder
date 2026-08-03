json.source_type resource.source_type
json.ad_id resource.ad_id
json.source_url resource.source_url
json.headline resource.headline
json.body resource.body
json.ctwa_clid resource.ctwa_clid
json.referred_at resource.referred_at.to_i
json.thumbnail_url resource.meta_ad&.thumbnail_url.presence || resource.payload_thumbnail_url

if resource.meta_ad.present?
  json.ad_name resource.meta_ad.name
  json.adset_name resource.meta_ad.adset_name
  json.campaign_name resource.meta_ad.campaign_name
  json.effective_status resource.meta_ad.effective_status
  json.sync_error resource.meta_ad.sync_error
end
