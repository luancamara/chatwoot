module Enterprise::Api::V1::AccountsSettings
  private

  def permitted_settings_attributes
    super + [:auto_fix_grammar, { conversation_required_attributes: [] }, { conversation_required_attribute_conditions: {} }]
  end
end
