# frozen_string_literal: true

module Bitsmithy
  module Auth
    EMPTY_AUTHENTICATION_VALUES = {
      provider: nil,
      subject: nil,
      credential_id: nil,
      user_handle: nil,
      signature_count: nil
    }.freeze

    AuthenticationEvidence = Data.define(
      :sign_in_method,
      :authenticated_at,
      :email,
      :provider,
      :subject,
      :credential_id,
      :user_handle,
      :signature_count,
      :replay_id
    ) do
      def self.email(email:, authenticated_at:, replay_id:)
        new(
          **EMPTY_AUTHENTICATION_VALUES,
          sign_in_method: :email,
          authenticated_at: authenticated_at,
          email: email,
          replay_id: replay_id
        )
      end

      def self.federated(provider:, subject:, email:, authenticated_at:)
        new(
          **EMPTY_AUTHENTICATION_VALUES,
          sign_in_method: provider,
          authenticated_at: authenticated_at,
          email: email,
          provider: provider,
          subject: subject,
          replay_id: nil
        )
      end

      def self.passkey(credential_id:, user_handle:, signature_count:, authenticated_at:)
        new(
          **EMPTY_AUTHENTICATION_VALUES,
          sign_in_method: :passkey,
          authenticated_at: authenticated_at,
          email: nil,
          credential_id: credential_id,
          user_handle: user_handle,
          signature_count: signature_count,
          replay_id: nil
        )
      end
    end
  end
end
