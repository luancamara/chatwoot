namespace :ad_attribution do
  desc 'Send already reconciled sales to Meta as conversions'
  task backfill_capi: :environment do
    # A Meta recusa eventos muito antigos; o padrão cobre a janela que ela aceita.
    since = (ENV['SINCE'] || 7.days.ago.to_date.iso8601).to_date
    sent = 0

    AdConversion.sold.where(ordered_at: since..).find_each(batch_size: 100) do |conversion|
      next if conversion.conversation_ad_referral.ctwa_clid.blank?

      AdAttribution::CapiEventService.new(conversion: conversion).perform
      sent += 1
      print '.' if (sent % 50).zero?
    rescue StandardError => e
      Rails.logger.error "[ad_attribution] capi #{conversion.id}: #{e.message}"
    end

    puts "\nConversões enviadas: #{sent}"
  end
end
