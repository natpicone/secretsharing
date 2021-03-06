# -*- encoding: utf-8 -*-

# Copyright 2011-2014 Glenn Rempe

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module SecretSharing
  module Shamir
    # A SecretSharing::Shamir::Secret object represents a Secret in the
    # Shamir secret sharing scheme. Secrets can be passed in as an input
    # argument when creating a new SecretSharing::Shamir::Container or
    # can be the output from a Container that has successfully decoded shares.
    # A new Secret take 0 or 1 args. Zero args means the Secret will be initialized
    # with a random OpenSSL::BN object with the Secret::DEFAULT_BITLENGTH. If a
    # single argument is passed it can be one of two object types, String or
    # OpenSSL::BN.  If a String it is expected to be a specially encoded String
    # that was generated as the output of calling #to_s on another Secret object.
    # If the object type is OpenSSL::BN it can represent a number up to 4096 num_bits
    # in length as reported by OpenSSL::BN#num_bits.
    #
    # All secrets are internally represented as an OpenSSL::BN which can be retrieved
    # in its raw form using #secret.
    #
    class Secret
      include SecretSharing::Shamir

      MAX_BITLENGTH = 4096

      attr_accessor :secret, :bitlength, :hmac

      def initialize(opts = {})
        opts = {
          :secret => get_random_number(256)
        }.merge!(opts)

        # override with options
        opts.each_key do |k|
          if self.respond_to?("#{k}=")
            send("#{k}=", opts[k])
          else
            fail ArgumentError, "Argument '#{k}' is not allowed"
          end
        end

        if opts[:secret].is_a?(String)
          # Decode a Base64.urlsafe_encode64 String which contains a Base 36 encoded Bignum back into an OpenSSL::BN
          # See : Secret#to_s for forward encoding method.
          decoded_secret = usafe_decode64(opts[:secret])
          fail ArgumentError, 'invalid base64 (returned nil or empty String)' if decoded_secret.empty?
          @secret = OpenSSL::BN.new(decoded_secret.to_i(36).to_s)
        end

        @secret = opts[:secret] if @secret.nil?
        fail ArgumentError, "Secret must be an OpenSSL::BN, not a '#{@secret.class}'" unless @secret.is_a?(OpenSSL::BN)
        @bitlength = @secret.num_bits
        fail ArgumentError, "Secret must have a bitlength less than or equal to #{MAX_BITLENGTH}" if @bitlength > MAX_BITLENGTH

        generate_hmac
      end

      # Secrets are equal if the OpenSSL::BN in @secret is the same.
      def ==(other)
        other == @secret
      end

      # Set a new secret forces regeneration of the HMAC
      def secret=(secret)
        @secret = secret
        generate_hmac
      end

      def secret?
        @secret.is_a?(OpenSSL::BN)
      end

      def to_s
        # Convert the OpenSSL::BN secret to an Bignum which has a #to_s(36) method
        # Convert the Bignum to a Base 36 encoded String
        # Wrap the Base 36 encoded String as a URL safe Base 64 encoded String
        # Combined this should result in a relatively compact and portable String
        usafe_encode64(@secret.to_i.to_s(36))
      end

      def valid_hmac?
        return false if !@secret.is_a?(OpenSSL::BN) || @hmac.to_s.empty? || @secret.to_s.empty?

        hmac_key  = @secret.to_s
        hmac_data = OpenSSL::Digest::SHA256.new(@secret.to_s).hexdigest

        @hmac == OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, hmac_key, hmac_data)
      end

      private

        # The HMAC uses the raw secret itself as the HMAC key, and the SHA256 of the secret as the data.
        # This allows later regeneration of the HMAC to confirm that the restored secret is in fact
        # identical to what was originally split into shares.
        def generate_hmac
          return false if @secret.to_s.empty?
          hmac_key  = @secret.to_s
          hmac_data = OpenSSL::Digest::SHA256.new(@secret.to_s).hexdigest
          @hmac     = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, hmac_key, hmac_data)
        end
    end # class Secret
  end # module Shamir
end # module SecretSharing
