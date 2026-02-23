module Enterprise::Conversations::ResolutionJob
  private

  # Auto-fill CRM disposition for auto-resolved conversations so they appear
  # correctly in CRM reports. Auto-resolved conversations are treated as
  # "Sem Resposta" since the customer never got a meaningful response.
  def auto_fill_crm_disposition(conversation, account)
    return unless account.conversation_required_attributes&.include?('crm_disposition_result')

    current_attrs = conversation.custom_attributes || {}
    return if current_attrs['crm_disposition_result'].present?

    conversation.update!(
      custom_attributes: current_attrs.merge('crm_disposition_result' => 'Sem Resposta')
    )
  end
end
