if conversation.conversation_ad_referral.present?
  json.ad_referral do
    json.partial! 'api/v1/models/ad_referral', formats: [:json], resource: conversation.conversation_ad_referral
  end
end

if conversation.account.feature_enabled?('sla')
  if conversation.sla_applicable?
    json.applied_sla do
      json.partial! 'api/v1/models/applied_sla', formats: [:json], resource: conversation.applied_sla if conversation.applied_sla.present?
    end
    json.sla_events do
      json.array! conversation.sla_events do |sla_event|
        json.partial! 'api/v1/models/sla_event', formats: [:json], sla_event: sla_event
      end
    end
  else
    json.applied_sla nil
    json.sla_events []
  end
end
