class Crm::WeeklyEvaluationReportJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    period_end = Date.current.beginning_of_week - 1.day # Last Sunday
    period_start = period_end - 6.days                  # Last Monday

    Account.find_each do |account|
      next unless account_eligible?(account)

      Crm::EvaluationReportGenerationJob.perform_later(account, 'agent_weekly', period_start, period_end)
      Crm::EvaluationReportGenerationJob.perform_later(account, 'management_weekly', period_start, period_end)
    end
  end

  private

  def account_eligible?(account)
    account.account_users.any? && ConversationInsight.by_account(account.id).any?
  end
end
