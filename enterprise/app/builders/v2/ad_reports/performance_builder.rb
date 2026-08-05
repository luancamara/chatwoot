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
    rows.map { |row| present(row) }
  end

  private

  def present(row)
    {
      ad_id: row.ad_id,
      source_type: row.source_type,
      ad_name: row.ad_name || row.headline,
      campaign_name: row.campaign_name,
      adset_name: row.adset_name,
      thumbnail_url: row.thumbnail_url,
      leads: row.leads,
      resolved: row.resolved,
      contacts: row.contacts,
      quality_score: quality_by_ad.dig(row.ad_id, :quality),
      first_response_seconds: quality_by_ad.dig(row.ad_id, :tpr)
    }.merge(economics(row))
  end

  def economics(row)
    orders, revenue = conversions_by_ad.fetch(row.ad_id, [0, 0])
    spend = spend_by_ad[row.ad_id].to_f

    {
      orders: orders,
      revenue: revenue.to_f,
      spend: spend,
      cost_per_lead: divide(spend, row.leads),
      cost_per_order: divide(spend, orders),
      roas: divide(revenue.to_f, spend)
    }
  end

  def divide(numerator, denominator)
    return if denominator.to_f.zero?

    (numerator / denominator.to_f).round(2)
  end

  # Calculados em consultas separadas de propósito: pedidos e gasto são 1:N por
  # anúncio, então juntá-los na agregação principal multiplicaria as linhas e
  # inflaria a contagem de leads.
  def conversions_by_ad
    @conversions_by_ad ||= AdConversion.sold
                                       .joins(:conversation_ad_referral)
                                       .where(conversation_ad_referrals: { account_id: account.id, referred_at: range })
                                       .group('conversation_ad_referrals.ad_id')
                                       .pluck(Arel.sql('conversation_ad_referrals.ad_id, COUNT(*), COALESCE(SUM(ad_conversions.value), 0)'))
                                       .to_h { |ad_id, count, sum| [ad_id, [count, sum]] }
  end

  def spend_by_ad
    @spend_by_ad ||= MetaAdInsight.in_period(range.first.to_date..range.last.to_date)
                                  .group(:ad_id)
                                  .sum(:spend)
  end

  # Separa "anúncio ruim" de "anúncio entregando às 23h, quando ninguém atende".
  def quality_by_ad
    @quality_by_ad ||= ConversationInsight
                       .joins(conversation: :conversation_ad_referral)
                       .where(conversation_ad_referrals: { account_id: account.id, referred_at: range })
                       .group('conversation_ad_referrals.ad_id')
                       .pluck(Arel.sql("conversation_ad_referrals.ad_id, AVG(quality_score), AVG((automatic_metrics->>'tpr_seconds')::numeric)"))
                       .to_h { |ad_id, quality, tpr| [ad_id, { quality: quality&.to_f&.round(2), tpr: tpr&.to_i }] }
  end

  def rows
    scope.select(SELECT)
         .group('conversation_ad_referrals.ad_id, conversation_ad_referrals.source_type')
         .order(Arel.sql('COUNT(*) DESC'))
  end

  def scope
    relation = ConversationAdReferral.from_ads
                                     .where(account_id: account.id)
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
