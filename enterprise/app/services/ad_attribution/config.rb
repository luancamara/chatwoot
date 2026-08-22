module AdAttribution::Config
  module_function

  def sync_enabled?
    enabled?('AD_CONVERSION_SYNC_ENABLED')
  end

  def meta_live?
    enabled?('META_AD_CONVERSION_LIVE_ENABLED')
  end

  def google_live?
    enabled?('GOOGLE_AD_CONVERSION_LIVE_ENABLED')
  end

  def account_id
    Integer(GlobalConfigService.load('AD_CONVERSION_ACCOUNT_ID', ''), exception: false)
  end

  def json(key)
    value = GlobalConfigService.load(key, '')
    return value.deep_stringify_keys if value.is_a?(Hash)
    return {} if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    {}
  end

  def enabled?(key)
    ActiveModel::Type::Boolean.new.cast(GlobalConfigService.load(key, false))
  end
end
