// Single source of truth for CRM funnel stages, dispositions and loss reasons.
// Canonical values are stored in `conversation.custom_attributes`; labels are
// what we render in the UI. Keep this in sync with the backend constants in
// `enterprise/app/services/crm/constants.rb`.

export const FUNNEL_STAGES = [
  { value: 'Lead', label: 'Lead' },
  { value: 'Qualificado', label: 'Qualificado' },
  { value: 'Orcamento', label: 'Orçamento' },
  { value: 'Negociacao', label: 'Negociação' },
  { value: 'Ganho', label: 'Ganho' },
  { value: 'Perdido', label: 'Perdido' },
];

// Stages that represent a closed deal (terminal columns).
export const WON_STAGE = 'Ganho';
export const LOST_STAGE = 'Perdido';
export const CLOSED_STAGES = [WON_STAGE, LOST_STAGE];

export const DISPOSITIONS = [
  { value: 'Venda', label: 'Venda' },
  { value: 'Perda', label: 'Perda' },
  { value: 'Indecisao', label: 'Indecisão' },
  { value: 'Sem Resposta', label: 'Sem Resposta' },
];

export const LOSS_REASONS = [
  { value: 'Preco', label: 'Preço' },
  { value: 'Prazo', label: 'Prazo' },
  { value: 'Estoque', label: 'Estoque' },
  { value: 'Atendimento', label: 'Atendimento' },
  { value: 'Outro', label: 'Outro' },
];

const toLabelMap = list =>
  list.reduce((acc, { value, label }) => {
    acc[value] = label;
    return acc;
  }, {});

export const STAGE_LABELS = toLabelMap(FUNNEL_STAGES);
export const DISPOSITION_LABELS = toLabelMap(DISPOSITIONS);
export const LOSS_REASON_LABELS = toLabelMap(LOSS_REASONS);

export const stageLabel = value => STAGE_LABELS[value] || value || '';
export const dispositionLabel = value => DISPOSITION_LABELS[value] || value || '';
export const lossReasonLabel = value => LOSS_REASON_LABELS[value] || value || '';
