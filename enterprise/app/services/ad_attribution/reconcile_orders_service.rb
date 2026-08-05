# Descobre quais leads de anúncio viraram pedido, cruzando telefone contra o ERP.
#
# Sem isso a atribuição para na metade: sabemos qual anúncio trouxe o lead, mas
# não qual trouxe receita. A venda é fechada na loja e nunca volta para a
# conversa, então o CRM registra quase nenhuma venda enquanto o ERP registra
# centenas.
class AdAttribution::ReconcileOrdersService
  # Móvel planejado tem ciclo longo: o cliente visita a loja, compara, volta.
  # 90 dias captura a maior parte sem creditar ao anúncio uma compra que veio
  # de outra coisa.
  DEFAULT_WINDOW_DAYS = 90

  pattr_initialize [:account!, { since: nil, window_days: DEFAULT_WINDOW_DAYS }]

  def perform
    referrals = pending_referrals.to_a
    return 0 if referrals.empty?

    leads = referrals.filter_map { |referral| lead_for(referral) }
    return 0 if leads.empty?

    conversions = client.reconcile(leads, window_days)
    persist(referrals, conversions)
  end

  private

  def persist(referrals, conversions)
    created = 0

    referrals.each do |referral|
      phone = phone_for(referral)
      orders = phone.present? ? Array(conversions[phone]) : []
      orders.each { |order| created += 1 if record(referral, order) }
      # update_column porque isto é só um carimbo de progresso: não deve tocar
      # updated_at nem disparar validação sobre uma linha que não mudou.
      referral.update_column(:reconciled_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    created
  end

  def record(referral, order)
    conversion = AdConversion.find_or_initialize_by(
      conversation_ad_referral_id: referral.id,
      erp_order_ref: order['pedido']
    )
    conversion.assign_attributes(
      account_id: referral.account_id,
      erp_client_id: order['cliente_id'],
      value: order['valor'],
      ordered_at: order['data'],
      status: order['status'] == 'vendido' ? :sold : :cancelled,
      erp_midia: order['midia']
    )
    was_new = conversion.new_record?
    conversion.save!
    # Só venda volta para a Meta; cancelamento não é sinal de compra.
    AdAttribution::SendCapiEventJob.perform_later(conversion) if was_new && conversion.sold?
    was_new
  end

  def lead_for(referral)
    phone = phone_for(referral)
    return if phone.blank?

    { telefone: phone, desde: referral.referred_at.to_date.iso8601 }
  end

  # O BFF devolve as conversões indexadas exatamente pelo telefone que enviamos,
  # então o mesmo valor precisa servir de ida e de volta.
  def phone_for(referral)
    referral.conversation&.contact&.phone_number.presence
  end

  # Só o que ainda pode mudar: nunca reconciliado, ou reconciliado mas ainda
  # dentro da janela em que uma venda nova pode aparecer. Sem esse recorte o job
  # diário reprocessaria a base inteira toda noite.
  def pending_referrals
    scope = ConversationAdReferral.from_ads
                                  .where(account_id: account.id)
                                  .where('reconciled_at IS NULL OR referred_at > ?', window_days.days.ago)
                                  .includes(conversation: :contact)
    scope = scope.where(referred_at: since..) if since.present?
    scope
  end

  def client
    @client ||= AdAttribution::ErpClient.new
  end
end
