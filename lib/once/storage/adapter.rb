# frozen_string_literal: true

module Once
  module Storage
    # This is the abstract base class for a storage adapter.
    # Concrete adapters must adhere to this interface and implement a persistence mechanism.
    class Adapter
      WriteError = Class.new(StandardError)
      NoSuchKeyError = Class.new(StandardError)

      # @abstract
      # @param execution_key [String] The unique execution key. Must be non-empty.
      # @param window [Integer] The time window in seconds.
      # @return [Array] A two value array, where the first value is the state, the second indicates existence.
      #
      # Must raise [Once::Storage::Adapter::WriteError] if it can not persist the state.
      def fetch_or_create(execution_key:, window:)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end

      # @abstract
      # @param execution_key [String] The unique execution key. Must be non-empty.
      # @param status [Integer] Must be one of the defined statuses in [Once::Storage::Status].
      # @param window [Integer] The time idempotency window in seconds.
      # @return [Once::Storage::State] The updated state.
      #
      # Must raise [Once::Storage::Adapter::NoSuchKeyError] if the key does not exist.
      def update(execution_key:, status:, window:)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end
    end
  end
end
