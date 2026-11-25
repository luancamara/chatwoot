module IndividualReadStateBroadcasting
  private

  # widget: { tokens:, data: } sends web widget sessions their payload in the same job
  def broadcast(account, tokens, event_name, data, conversation: nil, widget: {})
    widget_tokens = widget[:tokens].to_a
    return if tokens.blank? && widget_tokens.blank?

    if conversation && tokens.present? && account.feature_enabled?(Conversations::ReadStateService::FEATURE_FLAG)
      payloads = Conversations::ReadStateBroadcast.new(conversation: conversation).payloads(tokens, data, nested: data.key?(:conversation))
      payloads.each { |recipients, payload| broadcast(account, recipients, event_name, payload) }
      return broadcast(account, [], event_name, data, widget: widget)
    end

    widget_options = {}
    widget_options = { widget_members: widget_tokens.uniq, widget_data: broadcast_payload(account, widget[:data]) } if widget_tokens.present?
    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, broadcast_payload(account, data), **widget_options)
  end

  def broadcast_payload(account, data)
    payload = data.merge(account_id: account.id)
    # So the frontend knows who performed the action.
    payload[:performer] = Current.user.push_event_data if Current.user.present?
    payload
  end
end
