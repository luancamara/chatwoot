class ConversationRiskMonitor::IncidentService
  STATE_KEY = ConversationRiskMonitor::AlertService::STATE_KEY

  def initialize(conversation:)
    @conversation = conversation
  end

  def resolve!
    conversation.with_lock do
      state = conversation.additional_attributes[STATE_KEY]
      next if state.blank? || state['resolved_at'].present?

      conversation.update!(
        additional_attributes: conversation.additional_attributes.merge(
          STATE_KEY => state.merge('resolved_at' => Time.current.iso8601)
        )
      )
    end
  end

  private

  attr_reader :conversation
end
