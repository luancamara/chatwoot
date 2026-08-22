class ConversationInsight::BusinessHoursCalculator
  def initialize(user_id:, account_id:, inbox: nil)
    @user_id = user_id
    @account_id = account_id
    @inbox = inbox
    @agent_hours = load_agent_hours
  end

  # Returns business seconds between two timestamps
  def business_seconds_between(start_time, end_time)
    return 0 if start_time.nil? || end_time.nil? || start_time >= end_time

    total_seconds = 0
    current = start_time

    while current < end_time
      day_wh = working_hours_for_day(current.wday)

      if closed_day?(day_wh)
        current = next_day_start(current)
        next
      end

      day_open = current.change(hour: day_wh[:open_hour], min: day_wh[:open_minutes], sec: 0)
      day_close = current.change(hour: day_wh[:close_hour], min: day_wh[:close_minutes], sec: 0)

      # If current time is before opening, skip to opening
      effective_start = [current, day_open].max
      # If end_time is before close, use end_time
      effective_end = [end_time, day_close].min

      total_seconds += (effective_end - effective_start).to_i if effective_start < effective_end

      current = next_day_start(current)
    end

    total_seconds
  end

  private

  def closed_day?(working_hours)
    working_hours.nil? || working_hours[:closed]
  end

  def load_agent_hours
    hours = AgentWorkingHour.where(account_id: @account_id, user_id: @user_id).index_by(&:day_of_week)
    return hours if hours.present?

    # Fallback to inbox working hours
    return {} unless @inbox

    @inbox.working_hours.index_by(&:day_of_week)
  end

  def working_hours_for_day(wday)
    wh = @agent_hours[wday]
    return nil unless wh

    return unless wh.respond_to?(:closed_all_day?)
    return { closed: true } if wh.closed_all_day?

    {
      closed: false,
      open_hour: wh.open_hour,
      open_minutes: wh.open_minutes,
      close_hour: wh.close_hour,
      close_minutes: wh.close_minutes
    }
  end

  def next_day_start(time)
    (time + 1.day).beginning_of_day
  end
end
