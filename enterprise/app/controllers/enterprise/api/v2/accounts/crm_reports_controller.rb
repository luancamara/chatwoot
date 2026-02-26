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

  def evaluation_reports
    reports = ConversationEvaluationReport
                .by_account(Current.account.id)
                .by_type(report_params[:report_type] || 'management_weekly')
    reports = reports.by_user(report_params[:agent_id]) if report_params[:agent_id].present?
    reports = reports.in_period(report_params[:since], report_params[:until]) if report_params[:since].present?
    reports = reports.order(period_start: :desc)

    render json: reports.map { |r| evaluation_report_payload(r) }
  end

  def agent_evaluation
    report = ConversationEvaluationReport
               .by_account(Current.account.id)
               .by_type('agent_weekly')
               .by_user(report_params[:agent_id])
               .order(period_start: :desc)
               .first

    if report
      render json: evaluation_report_payload(report)
    else
      # Generate on the fly
      data = V2::CrmReports::AgentEvaluationReportBuilder.new(
        account: Current.account,
        user_id: report_params[:agent_id].to_i,
        period_start: parse_date(report_params[:since]) || 1.week.ago,
        period_end: parse_date(report_params[:until]) || Time.current
      ).build
      render json: { data: data }
    end
  end

  def management_evaluation
    report = ConversationEvaluationReport
               .by_account(Current.account.id)
               .by_type(report_params[:report_type] || 'management_weekly')
               .where(user_id: nil)
               .order(period_start: :desc)
               .first

    if report
      render json: evaluation_report_payload(report)
    else
      data = V2::CrmReports::ManagementEvaluationReportBuilder.new(
        account: Current.account,
        period_start: parse_date(report_params[:since]) || 1.week.ago,
        period_end: parse_date(report_params[:until]) || Time.current
      ).build
      render json: { data: data }
    end
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_params
    params.permit(:since, :until, :agent_id, :team_id, :inbox_id, :report_type)
  end

  def evaluation_report_payload(report)
    {
      id: report.id,
      report_type: report.report_type,
      user_id: report.user_id,
      period_start: report.period_start,
      period_end: report.period_end,
      data: report.data,
      created_at: report.created_at
    }
  end

  def parse_date(value)
    return nil if value.blank?

    DateTime.strptime(value, '%s')
  rescue ArgumentError
    nil
  end
end
