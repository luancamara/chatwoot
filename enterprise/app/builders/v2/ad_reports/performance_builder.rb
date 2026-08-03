# Aggregates leads per Meta ad for the ad performance report.
#
# Grouping happens on the denormalized conversation_ad_referrals table rather
# than on message content_attributes, which is a `json` column holding a JSON
# string and therefore not aggregatable in SQL.
class V2::AdReports::PerformanceBuilder
  SELECT = <<~SQL.squish.freeze
    conversation_ad_referrals.ad_id,
    conversation_ad_referrals.source_type,
    MAX(meta_ads.name) AS ad_name,
    MAX(meta_ads.campaign_name) AS campaign_name,
    MAX(meta_ads.adset_name) AS adset_name,
    MAX(meta_ads.thumbnail_url) AS thumbnail_url,
    MAX(conversation_ad_referrals.headline) AS headline,
    COUNT(*) AS leads,
    COUNT(*) FILTER (WHERE conversations.status = 1) AS resolved,
    COUNT(DISTINCT conversation_ad_referrals.contact_id) AS contacts
  SQL

  pattr_initialize [:account!, :params!]

  def build
    rows.map do |row|
      {
        ad_id: row.ad_id,
        source_type: row.source_type,
        ad_name: row.ad_name || row.headline,
        campaign_name: row.campaign_name,
        adset_name: row.adset_name,
        thumbnail_url: row.thumbnail_url,
        leads: row.leads,
        resolved: row.resolved,
        contacts: row.contacts
      }
    end
  end

  private

  def rows
    scope.select(SELECT)
         .group('conversation_ad_referrals.ad_id, conversation_ad_referrals.source_type')
         .order(Arel.sql('COUNT(*) DESC'))
  end

  def scope
    relation = ConversationAdReferral.where(account_id: account.id)
                                     .joins(:conversation)
                                     .left_joins(:meta_ad)
                                     .where(referred_at: range)
    relation = relation.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    relation
  end

  def range
    parse_time(params[:since], 30.days.ago)..parse_time(params[:until], Time.current)
  end

  def parse_time(value, fallback)
    value.present? ? Time.zone.at(value.to_i) : fallback
  end
end
