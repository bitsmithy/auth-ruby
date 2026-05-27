# frozen_string_literal: true

require "phonelib"

module Bitsmithy
  module Auth
    module Phone
      def self.normalized(input, country: nil)
        parse(input, country: country).e164
      end

      def self.redact(input)
        parsed = parse(input)
        national_redacted = parsed.national(false).gsub(/.(?=.{4})/, "*")

        "+#{parsed.country_code}#{national_redacted}"
      end

      def self.parse(input, country: nil)
        parsed = country ? Phonelib.parse(input, country) : Phonelib.parse(input)
        raise InvalidPhoneNumber, "could not parse: #{input}" unless parsed.valid?

        parsed
      end
    end
  end
end
