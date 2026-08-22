class Enterprise::Api::V2::Accounts::AdReportsController < Api::V1::Accounts::BaseController
  # The gallery is reference material for the sales floor: it carries ad copy and
  # creatives, no customer data, so every agent may read it. Lead volume per ad
  # stays behind the report permission.
  before_action :check_authorization, only: [:performance]

  def performance
    builder = V2::AdReports::PerformanceBuilder.new(account: Current.account, params: report_params)
    render json: { payload: builder.build }
  end

  def gallery
    builder = V2::AdReports::GalleryBuilder.new(account: Current.account)
    render json: { payload: builder.build }
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_params
    params.permit(:since, :until, :inbox_id)
  end
end
