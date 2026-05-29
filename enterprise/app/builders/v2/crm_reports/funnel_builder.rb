class V2::CrmReports::FunnelBuilder
  include DateRangeHelper

  STAGES = %w[Lead Qualificado Orcamento Negociacao Venda Perda].freeze
  PIPELINE_PER_STAGE_LIMIT = 50

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  # Returns the conversation cards for each funnel stage, grouped by stage.
  # Queries the JSONB attribute directly so it doesn't depend on a registered
  # custom_attribute_definition (unlike the generic conversation filter API).
  def pipeline
    STAGES.index_with do |stage|
      stage_conversations(stage)
        .includes(:contact, :assignee)
        .order(last_activity_at: :desc)
        .limit(PIPELINE_PER_STAGE_LIMIT)
        .map { |conversation| serialize_card(conversation) }
    end
  end

  def build
    {
      stages: stage_counts,
      conversion_rates: conversion_rates
    }
  end

  def pipeline_summary
    STAGES.map do |stage|
      conversations = stage_conversations(stage)
      {
        stage: stage,
        count: conversations.count,
        estimated_value: estimated_value_for(conversations)
      }
    end
  end

  private

  def filtered_conversations
    scope = account.conversations
    scope = scope.where(created_at: range) if range.present?
    scope = scope.where(assignee_id: params[:agent_id]) if params[:agent_id].present?
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope
  end

  def stage_conversations(stage)
    filtered_conversations.where("custom_attributes->>'crm_funnel_stage' = ?", stage)
  end

  def stage_counts
    counts = filtered_conversations
             .where("custom_attributes->>'crm_funnel_stage' IS NOT NULL")
             .group("custom_attributes->>'crm_funnel_stage'")
             .count

    STAGES.map do |stage|
      { stage: stage, count: counts[stage] || 0 }
    end
  end

  def conversion_rates
    counts = stage_counts.map { |s| s[:count] }
    STAGES.each_cons(2).with_index.map do |(from_stage, to_stage), i|
      {
        from: from_stage,
        to: to_stage,
        rate: counts[i].positive? ? (counts[i + 1].to_f / counts[i] * 100).round(1) : 0
      }
    end
  end

  def estimated_value_for(conversations)
    return 0 unless defined?(ConversationInsight)

    ConversationInsight
      .where(conversation_id: conversations.select(:id))
      .sum(:estimated_value)
  rescue StandardError
    0
  end

  def serialize_card(conversation)
    {
      id: conversation.display_id,
      display_id: conversation.display_id,
      custom_attributes: conversation.custom_attributes,
      meta: {
        sender: contact_card(conversation.contact),
        assignee: agent_card(conversation.assignee)
      },
      last_non_activity_message: last_message_card(conversation)
    }
  end

  def contact_card(contact)
    return {} if contact.blank?

    { name: contact.name, thumbnail: contact.avatar_url }
  end

  def agent_card(assignee)
    return nil if assignee.blank?

    { name: assignee.name, thumbnail: assignee.avatar_url }
  end

  def last_message_card(conversation)
    message = conversation.messages.non_activity_messages.first
    return nil if message.blank?

    { content: message.content }
  end
end
