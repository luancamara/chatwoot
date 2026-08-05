# Histórico de compras do contato, vindo do ERP.
#
# O vendedor abre a conversa e vê na hora se aquele cliente já comprou, o que
# comprou e quando — sem sair do Chatwoot nem pedir para alguém consultar o ERP.
class AdAttribution::ErpHistoryService
  CACHE_TTL = 10.minutes

  pattr_initialize [:contact!]

  def perform
    return empty if contact.phone_number.blank? || base_url.blank?

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch }
  end

  private

  def fetch
    response = HTTParty.get(
      "#{base_url}/api/v1/vendas/historico-cliente",
      query: { telefone: contact.phone_number },
      headers: headers,
      timeout: 20
    )

    unless response.success?
      Rails.logger.error "[ad_attribution] histórico ERP #{response.code}: #{response.body.to_s.truncate(150)}"
      return empty
    end

    response.parsed_response
  end

  def empty
    { 'pedidos' => [], 'total_pedidos' => 0, 'total_gasto' => 0 }
  end

  def cache_key
    "erp_history/#{contact.id}/#{contact.phone_number}"
  end

  def headers
    token = GlobalConfigService.load('ERP_BFF_TOKEN', '')
    token.present? ? { 'Authorization' => "Bearer #{token}" } : {}
  end

  def base_url
    @base_url ||= GlobalConfigService.load('ERP_BFF_URL', '').to_s.chomp('/')
  end
end
