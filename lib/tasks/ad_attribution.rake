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
      # No note on historical conversations: most are long resolved, and adding
      # one now would surface as unread activity across the whole inbox.
      referral = AdAttribution::RecordReferralService.new(message: message, note: false).perform
      referral&.previously_new_record? ? created += 1 : skipped += 1
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] message #{message.id}: #{e.message}"
    end

    puts "Created #{created} ad referrals, skipped #{skipped} already attributed or non-ad messages."
  end

  desc 'Download and store the creative for every known Meta ad'
  task store_creatives: :environment do
    MetaAd.find_each do |meta_ad|
      next if meta_ad.creative.attached?

      AdAttribution::StoreCreativeService.new(ad_id: meta_ad.ad_id).perform
      print '.'
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] creative #{meta_ad.ad_id}: #{e.message}"
      print 'x'
    end

    puts "\n#{MetaAd.joins(:creative_attachment).count}/#{MetaAd.count} ads with a stored creative."
  end
end
