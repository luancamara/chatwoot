module Enterprise::Conversations::EventDataPresenter
  def push_data
    # Merged outside the SLA guard so a lead that arrives over the websocket
    # carries its ad origin without waiting for a refetch.
    data = super
    data = data.merge(ad_referral: conversation_ad_referral.push_event_data) if conversation_ad_referral.present?
    return data unless account.feature_enabled?('sla')

    data.merge(sla_push_data)
  end

  private

  def sla_push_data
    sla_applicable = sla_applicable?

    {
      applied_sla: sla_applicable ? applied_sla&.push_event_data : nil,
      sla_events: sla_applicable ? sla_events.map(&:push_event_data) : [],
      sla_policy_id: sla_applicable ? sla_policy_id : nil
    }
  end
end
