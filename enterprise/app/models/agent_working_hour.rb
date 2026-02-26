class AgentWorkingHour < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :open_hour,     presence: true, unless: :closed_all_day?
  validates :open_minutes,  presence: true, unless: :closed_all_day?
  validates :close_hour,    presence: true, unless: :closed_all_day?
  validates :close_minutes, presence: true, unless: :closed_all_day?

  validates :open_hour,     inclusion: 0..23, unless: :closed_all_day?
  validates :close_hour,    inclusion: 0..23, unless: :closed_all_day?
  validates :open_minutes,  inclusion: 0..59, unless: :closed_all_day?
  validates :close_minutes, inclusion: 0..59, unless: :closed_all_day?

  validates :day_of_week, inclusion: 0..6
  validates :day_of_week, uniqueness: { scope: [:account_id, :user_id] }

  validate :close_after_open, unless: :closed_all_day?

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_day, ->(day_of_week) { where(day_of_week: day_of_week) }

  def open_at?(time)
    return false if closed_all_day?

    open_time = time.change(hour: open_hour, min: open_minutes)
    close_time = time.change(hour: close_hour, min: close_minutes)
    time.between?(open_time, close_time)
  end

  def open_seconds_on_day
    return 0 if closed_all_day?

    (close_hour * 3600 + close_minutes * 60) - (open_hour * 3600 + open_minutes * 60)
  end

  private

  def close_after_open
    return unless open_hour.hours + open_minutes.minutes >= close_hour.hours + close_minutes.minutes

    errors.add(:close_hour, 'Closing time cannot be before opening time')
  end
end
