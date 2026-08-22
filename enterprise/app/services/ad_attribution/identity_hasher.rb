require 'digest'

class AdAttribution::IdentityHasher
  class << self
    def email(value)
      digest(value.to_s.strip.downcase)
    end

    def phone(value)
      digits = value.to_s.gsub(/\D/, '').sub(/^0+/, '')
      digits = "55#{digits}" if digits.length.in?([10, 11])
      digest("+#{digits}")
    end

    private

    def digest(value)
      return if value.blank?

      Digest::SHA256.hexdigest(value)
    end
  end
end
