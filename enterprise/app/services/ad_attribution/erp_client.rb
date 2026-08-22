# Fala com o BFF, que é quem tem acesso ao ERP Firebird.
#
# O Chatwoot não fala com o Firebird direto: o BFF já tem pool de conexão,
# cache e a normalização de identificadores. Chamamos pelo DNS interno do Swarm,
# então nenhum dado cru de cliente precisa entrar no Chatwoot.
class AdAttribution::ErpClient
  # Um lote grande demais deixa a resposta pesada e a query de pedidos longa;
  # o BFF limita cada requisição a 500 itens.
  BATCH_SIZE = 500

  def each_sale(since:, until_time:, statuses: [4, 6], order_ref: nil, &)
    return enum_for(__method__, since: since, until_time: until_time, statuses: statuses, order_ref: order_ref) unless block_given?
    raise 'ERP_BFF_URL is not configured' if base_url.blank?

    page = 1
    loop do
      payload = fetch_page(since: since, until_time: until_time, statuses: statuses, order_ref: order_ref, page: page)
      items = Array(payload['items'])
      items.each(&)
      break unless payload.dig('pagination', 'has_next') || items.length == BATCH_SIZE

      page += 1
    end
  end

  def find_sale(order_ref:, ordered_at:)
    each_sale(since: ordered_at.beginning_of_day, until_time: ordered_at.end_of_day, order_ref: order_ref).first
  end

  private

  def fetch_page(since:, until_time:, statuses:, order_ref:, page:)
    response = HTTParty.get(
      "#{base_url}/api/v1/vendas/conversoes-offline",
      headers: headers,
      query: {
        desde: since.iso8601,
        ate: until_time.iso8601,
        status: statuses.join(','),
        pagina: page,
        por_pagina: BATCH_SIZE,
        erp_order_ref: order_ref
      }.compact,
      timeout: 120
    )

    raise "ERP conversion export failed with HTTP #{response.code}" unless response.success?

    response.parsed_response
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
