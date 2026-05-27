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

      def self.failure(error:, channel: :sms, phone: nil)
        new(success: false, error: error, phone: phone, channel: channel, token: nil)
      end
    end
  end
end
