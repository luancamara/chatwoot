module Crm::Constants
  # Canonical funnel stages stored in `conversation.custom_attributes['crm_funnel_stage']`.
  STAGES = %w[Lead Qualificado Orcamento Negociacao Ganho Perdido].freeze
  ACTIVE_STAGES = %w[Lead Qualificado Orcamento Negociacao].freeze
  QUOTE_STAGE = 'Orcamento'.freeze
  WON_STAGE = 'Ganho'.freeze
  LOST_STAGE = 'Perdido'.freeze
  CLOSED_STAGES = [WON_STAGE, LOST_STAGE].freeze

  # Closing outcome stored in `crm_disposition_result`.
  DISPOSITIONS = ['Venda', 'Perda', 'Indecisao', 'Sem Resposta'].freeze
  WON_DISPOSITION = 'Venda'.freeze
  LOST_DISPOSITION = 'Perda'.freeze
  LOST_DISPOSITIONS = ['Perda', 'Sem Resposta'].freeze

  LOSS_REASONS = %w[Preco Prazo Estoque Atendimento Outro].freeze
end
