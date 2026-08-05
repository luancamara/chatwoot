# Devolve a venda para a Meta, para ela otimizar por quem compra.
#
# É o único item da atribuição que muda a entrega dos anúncios, não só o
# relatório: sem esse retorno a Meta só sabe que alguém puxou conversa, e
# otimiza para conversa. Com ele, aprende quem fecha pedido.
#
# O `ctwa_clid` é o identificador do clique que a própria Meta mandou no
# webhook, então não é preciso enviar telefone nem e-mail de ninguém.
class AdAttribution::CapiEventService
  BASE_URI = 'https://graph.facebook.com'.freeze

  pattr_initialize [:conversion!]

  def perform
    return if dataset_id.blank? || access_token.blank? || click_id.blank? || waba_id.blank?

    response = HTTParty.post(
      "#{BASE_URI}/#{api_version}/#{dataset_id}/events",
      body: { data: [event], access_token: access_token }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    return response.parsed_response if response.success?

    Rails.logger.error "[ad_attribution] CAPI #{conversion.erp_order_ref}: #{response.parsed_response.dig('error', 'message')}"
    nil
  end

  private

  def event
    {
      event_name: 'Purchase',
      event_time: conversion.ordered_at.to_i,
      action_source: 'business_messaging',
      messaging_channel: 'whatsapp',
      # Deduplicação: reenviar o mesmo pedido não conta a venda duas vezes.
      event_id: "#{conversion.conversation_ad_referral_id}-#{conversion.erp_order_ref}",
      # A conta do WhatsApp precisa ir dentro de user_data: no nível do evento a
      # Meta responde "falta a identificação da conta do WhatsApp Business".
      user_data: { ctwa_clid: click_id, whatsapp_business_account_id: waba_id },
      custom_data: { value: conversion.value.to_f, currency: 'BRL', order_id: conversion.erp_order_ref }
    }
  end

  def click_id
    @click_id ||= conversion.conversation_ad_referral.ctwa_clid
  end

  # Sai do próprio canal que recebeu o lead, para não depender de mais um config.
  def waba_id
    return @waba_id if defined?(@waba_id)

    channel = conversion.conversation_ad_referral.inbox&.channel
    @waba_id = channel.try(:provider_config)&.dig('business_account_id')
  end

  def dataset_id
    @dataset_id ||= GlobalConfigService.load('META_CAPI_DATASET_ID', '')
  end

  # Token próprio: enviar conversão exige ads_management, enquanto o token de
  # leitura de anúncios só precisa de ads_read.
  def access_token
    @access_token ||= GlobalConfigService.load('META_CAPI_ACCESS_TOKEN', '').presence ||
                      GlobalConfigService.load('META_ADS_ACCESS_TOKEN', '')
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end
end
