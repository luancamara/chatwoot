module Enterprise::Concerns::AccountUser
  extend ActiveSupport::Concern

  included do
    belongs_to :custom_role, optional: true
    belongs_to :agent_capacity_policy, optional: true

    after_create :seed_agent_working_hours, if: -> { defined?(AgentWorkingHour) }
  end

  private

  def seed_agent_working_hours
    (0..6).each do |day|
      closed = day.in?([0, 6]) # Sunday=0, Saturday=6
      AgentWorkingHour.create!(
        account_id: account_id,
        user_id: user_id,
        day_of_week: day,
        closed_all_day: closed,
        open_hour: closed ? nil : 8,
        open_minutes: closed ? nil : 0,
        close_hour: closed ? nil : 18,
        close_minutes: closed ? nil : 0
      )
    end
  rescue ActiveRecord::RecordNotUnique
    # Already seeded, skip
  end
end
