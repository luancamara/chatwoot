# A continuous span in which deadline history was collected for an inbox. Reports use it to mark days and periods
# without collection as unavailable, while every attempt recorded inside past periods stays reportable.
class ResponseTrackingPeriod < ApplicationRecord
  scope :open, -> { where(ended_at: nil) }
  scope :overlapping, ->(range) { where('started_at < ? AND (ended_at IS NULL OR ended_at > ?)', range.end, range.begin) }
end
