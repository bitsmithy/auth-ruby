# frozen_string_literal: true

require_relative "errors"

module Bitsmithy
  module Auth
    class Config
      attr_accessor :envelope_key, :magic_link_delivery, :magic_link_ttl, :clock,
                    :magic_link_redirect_uri, :claim_magic_link, :on_authenticated,
                    :after_authentication_path, :allow_email_request,
                    :magic_link_sender, :google_client_id, :google_client_secret,
                    :google_redirect_uri, :apple_client_id, :apple_redirect_uri,
                    :apple_team_id, :apple_key_id, :apple_private_key,
                    :passkey_origin, :passkey_relying_party_id,
                    :passkey_relying_party_name, :passkey_registration_context,
                    :store_passkey_credential, :find_passkey_credential,
                    :update_passkey_credential
      attr_writer :apple_client_secret, :apple_provider_client, :google_provider_client,
                  :passkey_relying_party

      def initialize
        @magic_link_ttl = 600
        @clock = -> { Time.now.utc }
        @after_authentication_path = "/"
        @allow_email_request = ->(_email, _request) { true }
        @magic_link_delivery = ->(message) { deliver_magic_link(message) }
      end

      def apple_client_secret
        @apple_client_secret || Apple::ClientSecret.issue(self)
      end

      def apple_provider_client
        @apple_provider_client ||= Apple::HttpClient.new
      end

      def google_provider_client
        @google_provider_client ||= Google::HttpClient.new
      end

      def passkey_relying_party
        @passkey_relying_party ||= WebAuthn::RelyingParty.new(
          allowed_origins: [passkey_origin],
          id: passkey_relying_party_id,
          name: passkey_relying_party_name,
          verify_attestation_statement: false,
          acceptable_attestation_types: ["None"]
        )
      end

      def validate!
        missing = required_settings.select { |setting| public_send(setting).nil? }
        return true if missing.empty?

        raise ConfigurationError, "missing required config: #{missing.join(", ")}"
      end

      private

      def deliver_magic_link(message)
        MagicLinkMailer.with(
          to: message.to,
          url: message.url,
          expires_at: message.expires_at
        ).entry.deliver_later
      end

      def required_settings
        required = %i[envelope_key on_authenticated]
        required.push(:magic_link_redirect_uri, :magic_link_sender, :claim_magic_link) if magic_link_redirect_uri
        required.push(:google_client_secret, :google_redirect_uri) if google_client_id
        required.push(:apple_team_id, :apple_key_id, :apple_private_key, :apple_redirect_uri) if apple_client_id
        required.push(*passkey_settings) if passkey_origin
        required
      end

      def passkey_settings
        %i[
          passkey_relying_party_id passkey_relying_party_name
          passkey_registration_context store_passkey_credential
          find_passkey_credential update_passkey_credential
        ]
      end
    end
  end
end
