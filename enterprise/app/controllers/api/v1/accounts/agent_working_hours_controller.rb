class Api::V1::Accounts::AgentWorkingHoursController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :check_admin_authorization?
  before_action :set_user

  def index
    @working_hours = AgentWorkingHour.where(account_id: Current.account.id, user_id: @user.id).order(:day_of_week)
    render json: @working_hours.map { |working_hour| working_hour_payload(working_hour) }
  end

  def update
    working_hours_params[:working_hours].each do |wh_params|
      record = AgentWorkingHour.find_or_initialize_by(
        account_id: Current.account.id,
        user_id: @user.id,
        day_of_week: wh_params[:day_of_week]
      )
      record.update!(wh_params.permit(:open_hour, :open_minutes, :close_hour, :close_minutes, :closed_all_day))
    end

    @working_hours = AgentWorkingHour.where(account_id: Current.account.id, user_id: @user.id).order(:day_of_week)
    render json: @working_hours.map { |working_hour| working_hour_payload(working_hour) }
  end

  private

  def set_user
    @user = Current.account.users.find(params[:user_id])
  end

  def working_hours_params
    params.permit(working_hours: [:day_of_week, :open_hour, :open_minutes, :close_hour, :close_minutes, :closed_all_day])
  end

  def working_hour_payload(working_hour)
    {
      id: working_hour.id,
      day_of_week: working_hour.day_of_week,
      open_hour: working_hour.open_hour,
      open_minutes: working_hour.open_minutes,
      close_hour: working_hour.close_hour,
      close_minutes: working_hour.close_minutes,
      closed_all_day: working_hour.closed_all_day
    }
  end
end
