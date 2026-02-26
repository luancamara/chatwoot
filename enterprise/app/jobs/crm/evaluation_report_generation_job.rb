class Crm::EvaluationReportGenerationJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(account, report_type, period_start, period_end)
    case report_type
    when 'agent_weekly'
      generate_agent_reports(account, period_start, period_end)
    when 'management_weekly', 'management_monthly'
      generate_management_report(account, report_type, period_start, period_end)
    end
  end

  private

  def generate_agent_reports(account, period_start, period_end)
    account.account_users.find_each do |account_user|
      data = V2::CrmReports::AgentEvaluationReportBuilder.new(
        account: account,
        user_id: account_user.user_id,
        period_start: period_start,
        period_end: period_end
      ).build

      ConversationEvaluationReport.find_or_initialize_by(
        account_id: account.id,
        user_id: account_user.user_id,
        report_type: 'agent_weekly',
        period_start: period_start
      ).update!(
        period_end: period_end,
        data: data
      )
    end
  end

  def generate_management_report(account, report_type, period_start, period_end)
    data = V2::CrmReports::ManagementEvaluationReportBuilder.new(
      account: account,
      period_start: period_start,
      period_end: period_end
    ).build

    ConversationEvaluationReport.find_or_initialize_by(
      account_id: account.id,
      user_id: nil,
      report_type: report_type,
      period_start: period_start
    ).update!(
      period_end: period_end,
      data: data
    )
  end
end
