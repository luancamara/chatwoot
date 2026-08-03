class Enterprise::Api::V2::Accounts::AdReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def performance
    builder = V2::AdReports::PerformanceBuilder.new(account: Current.account, params: report_params)
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
