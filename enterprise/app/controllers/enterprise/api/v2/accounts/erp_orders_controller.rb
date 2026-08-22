class Enterprise::Api::V2::Accounts::ErpOrdersController < Api::V1::Accounts::BaseController
  # Histórico de compras é informação de atendimento: todo agente que já vê a
  # conversa pode ver o que aquele cliente comprou.
  def show
    contact = Current.account.contacts.find(params[:contact_id])
    render json: AdAttribution::ErpHistoryService.new(contact: contact).perform
  end
end
