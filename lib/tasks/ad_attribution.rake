namespace :ad_attribution do
  desc 'Backfill conversation ad referrals from referral data already stored on messages'
  task backfill: :environment do
    # find_each walks ascending by id, which within a conversation is
    # chronological, so the first touch is the one that gets recorded.
    # content_attributes is a `json` column written through `store ... coder: JSON`,
    # so it holds a JSON *string* and no jsonb operator applies. Filter coarsely in
    # SQL and let the service decide, since it reads the decoded hash.
    scope = Message.incoming.where('content_attributes::text LIKE ?', '%referral%')

    created = 0
    skipped = 0

    scope.find_each(batch_size: 500) do |message|
      referral = AdAttribution::RecordReferralService.new(message: message).perform
      referral ? created += 1 : skipped += 1
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] message #{message.id}: #{e.message}"
    end

    puts "Created #{created} ad referrals, skipped #{skipped} already attributed or non-ad messages."
  end
end
