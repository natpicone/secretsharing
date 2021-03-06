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
  # Module for common methods shared across Container, Secret, or Share
  module Shamir
    # Creates a random number of a certain bitlength, optionally ensuring
    # the bitlength by setting the highest bit to 1.
    def get_random_number(bitlength)
      byte_length = (bitlength / 8.0).ceil
      rand_hex    = OpenSSL::Random.random_bytes(byte_length).each_byte.to_a.map { |a| sprintf('%02x', a) }.join('')
      rand        = OpenSSL::BN.new(rand_hex, 16)

      begin
        rand.mask_bits!(bitlength)
      rescue OpenSSL::BNError
        # never mind if there was an error, this just means
        # rand was already smaller than 2^bitlength - 1
      end

      rand.set_bit!(bitlength)
      rand
    end

    # Computes the smallest prime of a given bitlength. Uses prime_fasttest
    # from the OpenSSL library with 20 attempts to be compatible to openssl
    # prime, which is used in the OpenXPKI::Crypto::Secret::Split library.
    def smallest_prime_of_bitlength(bitlength)
      # start with 2^bit_length + 1
      test_prime = OpenSSL::BN.new((2**bitlength + 1).to_s)
      prime_found = false

      until prime_found
        # prime_fasttest? 20 do be compatible to
        # openssl prime, which is used in
        # OpenXPKI::Crypto::Secret::Split
        prime_found = test_prime.prime_fasttest?(20)
        test_prime += 2
      end

      test_prime
    end

    # Evaluate the polynomial at x.
    def evaluate_polynomial_at(x, coefficients, prime)
      result = OpenSSL::BN.new('0')

      coefficients.each_with_index do |c, i|
        result += c * OpenSSL::BN.new(x.to_s)**i
        result %= prime
      end

      result
    end

    # Part of the Lagrange interpolation.
    # This is l_j(0), i.e.
    # \prod_{x_j \neq x_i} \frac{-x_i}{x_j - x_i}
    # for more information compare Wikipedia:
    # http://en.wikipedia.org/wiki/Lagrange_form
    def l(x, shares)
      result = shares.select { |s| s.x != x }

      result = result.map do |s|
        minus_xi = OpenSSL::BN.new((-s.x).to_s)
        one_over_xj_minus_xi = OpenSSL::BN.new((x - s.x).to_s).mod_inverse(shares[0].prime)
        minus_xi.mod_mul(one_over_xj_minus_xi, shares[0].prime)
      end

      (result.reduce { |a, e| a.mod_mul(e, shares[0].prime) })
    end

    # Backported for Ruby 1.8.7, REE, JRuby, Rubinious
    def usafe_decode64(str)
      return Base64.urlsafe_decode64(str) if Base64.respond_to?(:urlsafe_decode64)

      if str.include?('\n')
        fail(ArgumentError, 'invalid base64')
      else
        Base64.decode64(str)
      end
    end

    # Backported for Ruby 1.8.7, REE, JRuby, Rubinious
    def usafe_encode64(bin)
      return Base64.urlsafe_encode64(bin) if Base64.respond_to?(:urlsafe_encode64)
      Base64.encode64(bin).tr("\n", '')
    end
  end # module Shamir
end # module SecretSharing
