# frozen_string_literal: true

module Bitsmithy
  module Auth
    class MagicLinkMailer < ActionMailer::Base
      def entry
        @magic_link_url = params.fetch(:url)
        @expires_at = params.fetch(:expires_at)
        mail(
          to: params.fetch(:to),
          from: Bitsmithy::Auth.config.magic_link_sender,
          subject: "Your secure sign-in link"
        )
      end
    end
  end
end
