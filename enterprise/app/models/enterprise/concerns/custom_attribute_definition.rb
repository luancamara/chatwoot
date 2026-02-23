module Enterprise::Concerns::CustomAttributeDefinition
  extend ActiveSupport::Concern

  included do
    after_destroy :cleanup_conversation_required_attributes
  end

  private

  def cleanup_conversation_required_attributes
    return unless conversation_attribute?

    changed = cleanup_required_list
    changed = cleanup_required_conditions || changed
    account.save! if changed
  end

  def cleanup_required_list
    return false unless account.conversation_required_attributes&.include?(attribute_key)

    account.conversation_required_attributes = account.conversation_required_attributes - [attribute_key]
    true
  end

  def cleanup_required_conditions
    conditions = account.conversation_required_attribute_conditions
    return false if conditions.blank?

    original_size = conditions.size
    conditions.delete(attribute_key)
    conditions.reject! { |_k, v| v['depends_on'] == attribute_key }
    account.conversation_required_attribute_conditions = conditions
    conditions.size != original_size
  end
end
