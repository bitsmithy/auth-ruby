# frozen_string_literal: true

module Bitsmithy
  module Auth
    class Error < StandardError; end
    class InvalidPhoneNumber < Error; end
  end
end
