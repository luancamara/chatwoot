class Enterprise::Api::V2::Accounts::CrmReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def funnel
    builder = V2::CrmReports::FunnelBuilder.new(account: Current.account, params: report_params)
    render json: builder.build
  end

  def pipeline_summary
    builder = V2::CrmReports::FunnelBuilder.new(account: Current.account, params: report_params)
    render json: builder.pipeline_summary
  end

  def agent_performance
    builder = V2::CrmReports::AgentPerformanceBuilder.new(account: Current.account, params: report_params)
    render json: builder.build
  end

  def disposition_breakdown
    builder = V2::CrmReports::DispositionBuilder.new(account: Current.account, params: report_params)
    render json: builder.build
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_params
    params.permit(:since, :until, :agent_id, :team_id, :inbox_id)
  end
end
