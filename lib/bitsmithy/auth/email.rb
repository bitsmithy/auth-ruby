# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Email
      PATTERN = /\A[^\s@]+@[^\s@]+\z/

      module_function

      def normalize(input)
        normalized = input.to_s.strip.downcase
        raise InvalidEmail unless normalized.match?(PATTERN)

        normalized.freeze
      end
    end
  end
end
