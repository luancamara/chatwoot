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

  desc 'Point every ad origin note at the current ad poster'
  task repair_note_images: :environment do
    # Notes share the blob stored on the ad, so re-syncing creatives leaves them
    # pointing at a purged file. Run this after any creative re-sync.
    fixed = 0
    Message.where(private: true).where('content LIKE ?', '%veio de anúncio%').find_each(batch_size: 200) do |note|
      referral = ConversationAdReferral.find_by(conversation_id: note.conversation_id)
      next if referral.blank?

      AdAttribution::AttachCreativeService.new(message: note, ad_id: referral.ad_id).perform
      fixed += 1 if note.reload.attachments.any?
      print '.' if (fixed % 100).zero? && fixed.positive?
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] repair #{note.id}: #{e.message}"
    end

    puts "\nNotas com imagem: #{fixed}"
  end
end
