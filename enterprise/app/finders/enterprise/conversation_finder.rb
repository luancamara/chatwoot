module Enterprise::ConversationFinder
  def conversations_base_query
    # The conversation partial serializes the ad referral and its cached ad, so
    # both are preloaded to keep the list at a constant number of queries.
    scope = super.includes(conversation_ad_referral: :meta_ad)
    return scope unless current_account.feature_enabled?('sla')

    scope.includes(:applied_sla, :sla_events, inbox: :working_hours)
  end
end
