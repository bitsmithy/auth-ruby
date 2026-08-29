# frozen_string_literal: true

module Bitsmithy
  module Auth
    Result = Data.define(:success, :error, :evidence, :metadata) do
      def success?
        success
      end

      def self.success(evidence: nil, metadata: {})
        new(success: true, error: nil, evidence: evidence, metadata: metadata.freeze)
      end

      def self.failure(error:, metadata: {})
        new(success: false, error: error, evidence: nil, metadata: metadata.freeze)
      end
    end
  end
end
