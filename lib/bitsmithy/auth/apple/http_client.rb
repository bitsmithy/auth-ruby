# frozen_string_literal: true

require "json"
require "net/http"

module Bitsmithy
  module Auth
    module Apple
      class HttpClient
        JWKS_URI = URI("https://appleid.apple.com/auth/keys")
        TOKEN_URI = URI("https://appleid.apple.com/auth/token")
        CACHE_SECONDS = 300

        def initialize(open_timeout: 5, read_timeout: 10, clock: -> { Time.now.utc })
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          @clock = clock
        end

        def exchange(**parameters)
          request = Net::HTTP::Post.new(TOKEN_URI)
          request.set_form_data(parameters.merge(grant_type: "authorization_code"))
          json_response(TOKEN_URI, request)
        end

        def jwks
          return @jwks if @jwks && @jwks_expires_at > @clock.call

          @jwks = json_response(JWKS_URI, Net::HTTP::Get.new(JWKS_URI))
          @jwks_expires_at = @clock.call + CACHE_SECONDS
          @jwks
        end

        private

        def json_response(uri, request)
          response = http_for(uri).request(request)
          raise ProviderUnavailable unless response.is_a?(Net::HTTPSuccess)

          JSON.parse(response.body)
        rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error
          raise ProviderUnavailable
        end

        def http_for(uri)
          Net::HTTP.new(uri.host, uri.port).tap do |http|
            http.use_ssl = true
            http.open_timeout = @open_timeout
            http.read_timeout = @read_timeout
          end
        end
      end
    end
  end
end
