# frozen_string_literal: true

module Idempotently
  module Storage
    # This is the abstract base class for a storage adapter.
    # Concrete adapters must adhere to this interface and implement a persistence mechanism.
    class Adapter
      WriteError = Class.new(StandardError)
      NoSuchKeyError = Class.new(StandardError)

      # @abstract
      # @param idempotency_key [String] The idempotency key. Must be non-empty.
      # @param window [Integer] The time idempotency window in seconds.
      # @return [Array] A two value array, where the first value is the state, the second indicates existence.
      #
      # Must raise [Idempotently::Storage::Adapter::WriteError] if it can not persist the state.
      def fetch_or_create(idempotency_key:, window:)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end

      # @abstract
      # @param idempotency_key [String] The idempotency key. Must be non-empty.
      # @param status [Integer] Must be one of the defined statuses in Idempotently::Storage::Status.
      # @param window [Integer] The time idempotency window in seconds.
      # @return [Idempotently::Storage::State] The updated state.
      #
      # Must raise [Idempotently::Storage::Adapter::NoSuchKeyError] if the key does not exist.
      def update(idempotency_key:, status:, window:)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end
    end
  end
end
