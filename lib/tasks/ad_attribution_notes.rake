namespace :ad_attribution do
  desc 'Create the ad origin note on conversations attributed before the note existed'
  task backfill_notes: :environment do
    body_limit = (ENV['BODY_LIMIT'] || 220).to_i
    created = 0

    scope = ConversationAdReferral.includes(:conversation)
    scope = scope.joins(:conversation).where(conversations: { display_id: ENV['DISPLAY_ID'] }) if ENV['DISPLAY_ID'].present?

    scope.find_each(batch_size: 200) do |referral|
      created += 1 if AdAttribution::BackfillNoteService.new(referral: referral, body_limit: body_limit).perform
      print '.' if (created % 50).zero? && created.positive?
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] note #{referral.conversation_id}: #{e.message}"
    end

    puts "\nNotas criadas: #{created}"
  end
end
