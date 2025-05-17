# frozen_string_literal: true

module Idempotently
  module Storage
    # This is the abstract base class for a storage adapter.
    # Concrete adapters must adhere to this interface and implement a persistence mechanism.
    class Adapter
      WriteError = Class.new(StandardError)
      NoSuchKeyError = Class.new(StandardError)

      # Fetch the state of the idempotency key if it already exists or create a new state.
      #
      # @abstract
      # @param idempotency_key [String] The idempotency key. Must be non-empty.
      # @param window [Integer] The time idempotency window in seconds.
      # @return [Array] A two value array, where the first value is the state, the second indicates existence.
      #
      # Must raise [Idempotently::Storage::Adapter::WriteError] if it can not persist the state.
      def fetch_or_create(idempotency_key:, window:)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end

      # Update the state of the idempotency key.
      #
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

      # Entry point for garbage collection of storage.
      # Most storage system will need to implement this, to make sure that memory is eventually freed.
      #
      # @abstract
      # @param now [Time] The current time. This might not be the same as current wallclock time, to allow
      # simulating time travel for early cleanup, but also for windowed cleanup.
      #
      # @param window [Integer] The time idempotency window in seconds.
      def garbage_collect!(now:, window:)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end
    end
  end
end
