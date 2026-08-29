# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Testing
      ALLOWED_ENVIRONMENTS = %i[development test].freeze
      DEFAULT_TIME = Time.utc(2000, 1, 1)

      module_function

      def authentication_evidence(sign_in_method, environment:, authenticated_at: DEFAULT_TIME, **values)
        ensure_allowed!(environment)
        factory = "#{sign_in_method}_evidence"
        raise ArgumentError, "unsupported test Sign-in Method: #{sign_in_method}" unless respond_to?(factory, true)

        send(factory, authenticated_at, values)
      end

      def apple_evidence(authenticated_at, values)
        federated_evidence(:apple, authenticated_at, values)
      end
      private_class_method :apple_evidence

      def email_evidence(authenticated_at, values)
        AuthenticationEvidence.email(
          email: Email.normalize(values.fetch(:email)),
          authenticated_at: authenticated_at,
          replay_id: values.fetch(:replay_id, "test-replay-id")
        )
      end
      private_class_method :email_evidence

      def federated_evidence(provider, authenticated_at, values)
        AuthenticationEvidence.federated(
          provider: provider,
          subject: values.fetch(:subject, "test-provider-subject"),
          email: values[:email] && Email.normalize(values[:email]),
          authenticated_at: authenticated_at
        )
      end
      private_class_method :federated_evidence

      def google_evidence(authenticated_at, values)
        federated_evidence(:google, authenticated_at, values)
      end
      private_class_method :google_evidence

      def passkey_evidence(authenticated_at, values)
        AuthenticationEvidence.passkey(
          credential_id: values.fetch(:credential_id, "test-credential"),
          user_handle: values.fetch(:user_handle, "test-user-handle"),
          signature_count: values.fetch(:signature_count, 0),
          authenticated_at: authenticated_at
        )
      end
      private_class_method :passkey_evidence

      def ensure_allowed!(environment)
        return if ALLOWED_ENVIRONMENTS.include?(environment.to_sym)

        raise ConfigurationError, "RubyAuth test support is unavailable in production"
      end
      private_class_method :ensure_allowed!
    end
  end
end
