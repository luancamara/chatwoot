class Whatsapp::Triage::SignalDetector
  CRITICAL_SIGNALS = {
    'Risco jurídico ou órgão de defesa do consumidor' => [
      /\bprocon\b/,
      /\b(?:meu|minha|um|uma)?\s*advogad[oa]\b/,
      /\b(?:acao|processo) judicial\b/,
      /\b(?:vou|irei) processar\b/,
      /\bdenuncia(?:r)?\b/
    ],
    'Cobrança indevida' => [
      /\bcobranca indevida\b/,
      /\bcobraram? (?:duas vezes|duplicado|novamente)\b/
    ],
    'Cancelamento por problema não resolvido' => [
      /\b(?:quero|vou|preciso) cancelar (?:o |a |meu |minha )?(?:pedido|compra|contrato|servico)\b/,
      /\bcancelamento (?:do |da |de )?(?:pedido|compra|contrato|servico)\b/
    ],
    'Falha reiterada de atendimento' => [
      /\bninguem (?:me )?(?:responde|resolve|retorna|atende)\b/,
      /\bja (?:falei|liguei|chamei|reclamei).*(?:nao|sem) (?:resolver|solucao|retorno)\b/
    ]
  }.freeze

  COMPLAINT_SIGNALS = {
    'Cliente declarou uma reclamação' => [
      /\b(?:reclamacao|reclamar|insatisfeit[oa])\b/
    ],
    'Produto com problema' => [
      /\b(?:produto|movel|pedido).*(?:quebrado|danificado|defeito|errado|avariado)\b/,
      /\b(?:quebrado|danificado|com defeito|nao funciona)\b/
    ],
    'Problema de entrega ou montagem' => [
      /\b(?:entrega|montagem).*(?:atrasada|atraso|problema|errada|nao chegou)\b/,
      /\bnao (?:entregaram|montaram|chegou)\b/
    ],
    'Problema sem solução' => [
      /\b(?:problema|erro).*(?:sem solucao|nao resolvido|continua)\b/,
      /\bnao (?:resolveram|solucionaram)\b/
    ]
  }.freeze

  def initialize(content)
    @content = normalize(content)
  end

  def perform
    match = find_match(CRITICAL_SIGNALS)
    return classification('critical', match) if match

    match = find_match(COMPLAINT_SIGNALS)
    return classification('complaint', match) if match

    nil
  end

  private

  attr_reader :content

  def find_match(signals)
    signals.find { |_reason, patterns| patterns.any? { |pattern| content.match?(pattern) } }&.first
  end

  def classification(severity, reason)
    {
      'area' => 'complaints',
      'severity' => severity,
      'confidence' => 1.0,
      'reason' => reason,
      'source' => 'keyword'
    }
  end

  def normalize(value)
    I18n.transliterate(value.to_s).downcase.squish
  end
end
