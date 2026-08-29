# frozen_string_literal: true

require "securerandom"
require "uri"

module Bitsmithy
  module Auth
    module MagicLink
      Message = Data.define(:to, :url, :expires_at)
      PURPOSE = "email_magic_link"

      module_function

      def request(email:, redirect_uri:, config:)
        normalized_email = Email.normalize(email)
        message = issue_message(normalized_email, redirect_uri, config)
        config.magic_link_delivery.call(message)
        Result.success(metadata: { email: normalized_email })
      rescue InvalidEmail
        Result.failure(error: :invalid_email, metadata: { email: email.to_s })
      end

      def verify(credential, config:)
        payload = Envelope.open(credential, key: config.envelope_key)
        validate_payload!(payload, config.clock.call)
        Result.success(evidence: evidence_from(payload))
      rescue ExpiredEnvelope
        Result.failure(error: :expired_magic_link)
      rescue InvalidEmail, InvalidEnvelope, KeyError, TypeError
        Result.failure(error: :invalid_magic_link)
      end

      def issue_message(email, redirect_uri, config)
        issued_at = config.clock.call
        expires_at = issued_at + config.magic_link_ttl
        credential = Envelope.seal(payload(email, issued_at, expires_at), key: config.envelope_key)
        Message.new(
          to: email,
          url: "#{validated_redirect_uri(redirect_uri)}#credential=#{credential}",
          expires_at: expires_at
        )
      end
      private_class_method :issue_message

      def payload(email, issued_at, expires_at)
        {
          "purpose" => PURPOSE,
          "email" => email,
          "replay_id" => SecureRandom.uuid,
          "issued_at" => issued_at.to_i,
          "expires_at" => expires_at.to_i
        }
      end
      private_class_method :payload

      def validate_payload!(payload, now)
        raise InvalidEnvelope unless payload["purpose"] == PURPOSE
        raise ExpiredEnvelope if payload.fetch("expires_at") <= now.to_i
      end
      private_class_method :validate_payload!

      def evidence_from(payload)
        AuthenticationEvidence.email(
          email: Email.normalize(payload.fetch("email")),
          authenticated_at: Time.at(payload.fetch("issued_at")).utc,
          replay_id: payload.fetch("replay_id")
        )
      end
      private_class_method :evidence_from

      def validated_redirect_uri(input)
        uri = URI.parse(input.to_s)
        return uri.to_s if uri.is_a?(URI::HTTPS) && uri.host

        raise ConfigurationError, "magic-link redirect_uri must be an absolute HTTPS URL"
      rescue URI::InvalidURIError
        raise ConfigurationError, "magic-link redirect_uri must be an absolute HTTPS URL"
      end
      private_class_method :validated_redirect_uri
    end
  end
end
