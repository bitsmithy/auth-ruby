# frozen_string_literal: true

module Bitsmithy
  module Auth
    Result = Data.define(:success, :error, :token, :channel, :phone) do
      def success?
        success
      end

      def self.success(token: nil, channel: :sms, phone: nil)
        new(success: true, error: nil, token: token, channel: channel, phone: phone)
      end
    end
  end
end
