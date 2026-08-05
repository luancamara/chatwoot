# Fala com o BFF, que é quem tem acesso ao ERP Firebird.
#
# O Chatwoot não fala com o Firebird direto: o BFF já tem pool de conexão,
# cache e a lógica de casamento por telefone. Chamamos pelo DNS interno do
# Swarm, então nada disso trafega pela internet.
class AdAttribution::ErpClient
  # Um lote grande demais deixa a resposta pesada e a query de pedidos longa;
  # o BFF aceita até 1000 por requisição.
  BATCH_SIZE = 500

  def reconcile(leads, window_days)
    return {} if leads.blank? || base_url.blank?

    leads.each_slice(BATCH_SIZE).reduce({}) do |result, batch|
      result.merge(post_batch(batch, window_days))
    end
  end

  private

  def post_batch(batch, window_days)
    response = HTTParty.post(
      "#{base_url}/api/v1/vendas/conversao-leads",
      headers: headers,
      body: { leads: batch, janela_dias: window_days }.to_json,
      timeout: 120
    )

    unless response.success?
      Rails.logger.error "[ad_attribution] ERP respondeu #{response.code}: #{response.body.to_s.truncate(200)}"
      return {}
    end

    response.parsed_response['conversoes'] || {}
  end

  def headers
    base = { 'Content-Type' => 'application/json' }
    token = GlobalConfigService.load('ERP_BFF_TOKEN', '')
    token.present? ? base.merge('Authorization' => "Bearer #{token}") : base
  end

  def base_url
    @base_url ||= GlobalConfigService.load('ERP_BFF_URL', '').to_s.chomp('/')
  end
end
