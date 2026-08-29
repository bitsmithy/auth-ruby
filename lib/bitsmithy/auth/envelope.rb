# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "securerandom"

module Bitsmithy
  module Auth
    module Envelope
      ALGORITHM = "aes-256-gcm"
      IV_BYTES = 12
      KEY_BYTES = 32
      TAG_BYTES = 16
      VERSION = "v1"

      module_function

      def seal(payload, key:)
        cipher, iv = encryption_context(key)
        ciphertext = cipher.update(JSON.generate(payload)) + cipher.final
        encoded = Base64.urlsafe_encode64(iv + cipher.auth_tag(TAG_BYTES) + ciphertext, padding: false)
        "#{VERSION}.#{encoded}"
      end

      def open(token, key:)
        iv, tag, ciphertext = encoded_parts(token)
        cipher = decryption_context(key, iv, tag)
        JSON.parse(cipher.update(ciphertext) + cipher.final)
      rescue ArgumentError, JSON::ParserError, OpenSSL::Cipher::CipherError
        raise InvalidEnvelope
      end

      def encryption_context(key)
        cipher = configured_cipher(:encrypt, key)
        initialization_vector = SecureRandom.random_bytes(IV_BYTES)
        cipher.iv = initialization_vector
        cipher.auth_data = VERSION
        [cipher, initialization_vector]
      end
      private_class_method :encryption_context

      def decryption_context(key, initialization_vector, tag)
        configured_cipher(:decrypt, key).tap do |cipher|
          cipher.iv = initialization_vector
          cipher.auth_tag = tag
          cipher.auth_data = VERSION
        end
      end
      private_class_method :decryption_context

      def configured_cipher(direction, key)
        validate_key!(key)
        OpenSSL::Cipher.new(ALGORITHM).public_send(direction).tap do |cipher|
          cipher.key = key.byteslice(0, KEY_BYTES)
        end
      end
      private_class_method :configured_cipher

      def encoded_parts(token)
        version, encoded = token.to_s.split(".", 2)
        raise InvalidEnvelope unless version == VERSION && encoded

        split_payload(Base64.urlsafe_decode64(encoded))
      end
      private_class_method :encoded_parts

      def split_payload(decoded)
        iv = decoded.byteslice(0, IV_BYTES)
        tag = decoded.byteslice(IV_BYTES, TAG_BYTES)
        ciphertext = decoded.byteslice((IV_BYTES + TAG_BYTES)..)
        raise InvalidEnvelope unless iv&.bytesize == IV_BYTES && tag&.bytesize == TAG_BYTES && ciphertext

        [iv, tag, ciphertext]
      end
      private_class_method :split_payload

      def validate_key!(key)
        return if key.is_a?(String) && key.bytesize >= KEY_BYTES

        raise ConfigurationError, "envelope_key must contain at least #{KEY_BYTES} bytes"
      end
      private_class_method :validate_key!
    end
  end
end
