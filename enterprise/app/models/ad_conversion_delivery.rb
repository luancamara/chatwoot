class AdConversionDelivery < ApplicationRecord
  belongs_to :ad_conversion

  enum provider: { meta: 'meta', google: 'google' }
  enum status: {
    pending: 'pending',
    submitted: 'submitted',
    accepted: 'accepted',
    failed: 'failed',
    skipped: 'skipped',
    legacy_unknown: 'legacy_unknown',
    retracted: 'retracted'
  }

  validates :provider, uniqueness: { scope: :ad_conversion_id }

  scope :ready, -> { where('next_attempt_at IS NULL OR next_attempt_at <= ?', Time.current) }

  delegate :account, to: :ad_conversion

  def record_attempt!
    update!(attempts: attempts + 1, last_attempted_at: Time.current)
  end

  def mark_failed!(code, message)
    update!(status: :failed, error_code: code, error_message: message.to_s.truncate(500), next_attempt_at: nil)
  end
end
