class Enterprise::Api::V2::Accounts::DistributionStatusesController < Api::V1::Accounts::BaseController
  before_action -> { authorize :report, :view? }

  def show
    inbox_ids = Current.account.internal_attributes.dig('store_routing', 'inbox_ids') || []
    inboxes = Current.account.inboxes.where(id: inbox_ids).order(:id)
    render json: { generated_at: Time.current.iso8601, inboxes: inboxes.map { |inbox| SalesRouting::DistributionStatus.new(inbox: inbox).build } }
  end
end
