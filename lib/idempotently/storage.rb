module Idempotently
  module Storage
    module State
      STARTED = 0
      SUCCEEDED = 1
      FAILED = 2

      def self.create(key, status)
        raise ArgumentError, 'Invalid status' unless [STARTED, SUCCEEDED, FAILED].include?(status)
        raise ArgumentError, 'Key cannot be empty' if key.to_s.empty?

        Entry.new(key, status)
      end

      Entry = Data.define(:key, :status) do
        def in_progress?
          status == STARTED
        end

        def completed?
          success? || failure?
        end

        def success?
          status == SUCCEEDED
        end

        def failure?
          status == FAILED
        end
      end
    end

    # Abstract class for storage adapters.
    class Adapter
      attr_reader :window

      def initialize(window:)
        raise ArgumentError, 'Window must be provided' if window.nil?
        raise ArgumentError, 'Window must be a positive number' unless window.is_a?(Numeric) && window.positive?
      end

      def fetch_or_create(idempotency_key)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end

      def update(state, status)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end
    end
  end
end
