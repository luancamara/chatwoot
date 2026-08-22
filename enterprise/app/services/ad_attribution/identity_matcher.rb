class AdAttribution::IdentityMatcher
  ATTRIBUTION_WINDOW = 90.days

  def initialize(account:, since:, until_time:)
    @account = account
    @since = since
    @until_time = until_time
  end

  def match(identifiers, ordered_at)
    candidates = match_keys(identifiers).flat_map { |key| referral_index[key] }.uniq
    candidates.select { |referral| referral.referred_at <= ordered_at }.max_by(&:referred_at)
  end

  private

  attr_reader :account, :since, :until_time

  def match_keys(identifiers)
    match_data = identifiers.fetch('match', {})
    Array(match_data['email_sha256']) + Array(match_data['phone_sha256'])
  end

  def referral_index
    @referral_index ||= Hash.new { |hash, key| hash[key] = [] }.tap do |index|
      referrals.find_each do |referral|
        contact = referral.contact || referral.conversation&.contact
        next if contact.blank?

        keys = [AdAttribution::IdentityHasher.email(contact.email), AdAttribution::IdentityHasher.phone(contact.phone_number)].compact
        keys.each { |key| index[key] << referral }
      end
    end
  end

  def referrals
    ConversationAdReferral.where(account_id: account.id, referred_at: (since - ATTRIBUTION_WINDOW)..until_time)
                          .includes(:contact, :inbox, conversation: :contact)
  end
end
