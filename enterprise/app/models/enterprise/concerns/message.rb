module Enterprise::Concerns::Message
  extend ActiveSupport::Concern
  include SalesRouting::ResponseMessageTracking

  # Marks a fixed bot message, written in the account language, for translation into the contact language.
  TRANSLATE_FOR_CONTACT_ATTRIBUTE = 'translate_for_contact'.freeze

  included do
    include ConversationMonitors::MessageTracking
    has_one :call, dependent: :nullify
    has_many :message_reports, class_name: 'Captain::MessageReport', dependent: :destroy_async
    # A deleted message keeps its row with placeholder text.
    scope :not_deleted, -> { where("((messages.content_attributes #>> '{}')::jsonb ->> 'deleted') IS DISTINCT FROM 'true'") }

    before_create :mark_for_translation, if: :translation_enabled?

    after_create_commit :record_ad_referral
    after_create_commit :classify_sales_store
  end

  private

  def classify_sales_store
    return unless incoming? && !private?
    return unless SalesRouting::Configuration.new(inbox: inbox).enabled?
    return if conversation.additional_attributes[SalesRouting::Classifier::ATTRIBUTES_KEY].present?

    SalesRouting::ClassifyJob.set(wait: SalesRouting::Classifier::ENRICHMENT_WAIT).perform_later(conversation_id)
  end

  # Every channel that carries Meta ad attribution stores it under the same
  # `referral` key, so one hook covers WhatsApp, Messenger and Instagram.
  def record_ad_referral
    return unless incoming?
    return if content_attributes['referral'].blank?

    AdAttribution::RecordReferralService.new(message: self).perform
  end

  def mark_for_translation
    content_attributes['translation_pending'] = true
  end

  # Bots and automations already write in the contact language, except for the fixed texts they flag.
  def translation_enabled?
    conversation.auto_translate_enabled? && content.present? && !private? &&
      (template? || translatable_agent_reply? || content_attributes[TRANSLATE_FOR_CONTACT_ATTRIBUTE] == true)
  end

  # Forwarded messages and WhatsApp templates must go out exactly as they are.
  def translatable_agent_reply?
    outgoing? && sender.is_a?(User) && text? && content_attributes['forwarded_message_id'].blank? &&
      additional_attributes.to_h['template_params'].blank?
  end
end
