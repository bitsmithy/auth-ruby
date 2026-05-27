# frozen_string_literal: true

require "phonelib"

module Bitsmithy
  module Auth
    module Phone
      def self.normalized(input, country: nil)
        parsed = country ? Phonelib.parse(input, country) : Phonelib.parse(input)
        raise InvalidPhoneNumber unless parsed.valid?

        parsed.e164
      end

      def self.redact(phone)
        parsed = Phonelib.parse(phone)
        national_redacted = parsed.national(false).gsub(/.(?=.{4})/, "*")

        "+#{parsed.country_code}#{national_redacted}"
      end
    end
  end
end
