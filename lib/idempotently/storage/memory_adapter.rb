module Idempotently
  module Storage
    # Simple in-memory storage adapter for testing purposes.
    class MemoryAdapter < Adapter
      def initialize(window:, clock: Time)
        super(window: window)
        @storage = {}
        @clock = clock
        @mutex = Mutex.new
      end

      def fetch_or_create(idempotency_key)
        existing_state = @storage[idempotency_key]

        return [true, existing_state[:value]] if existing_state # && existing_state[:timestamp] + @window <= @clock.now

        value = State.create(idempotency_key, State::STARTED)

        @mutex.synchronize do
          @storage[idempotency_key] = { value: value, timestamp: @clock.now }
        end

        [false, value]
      end

      def update(state, status)
        State.create(state.key, status).tap do |value|
          @storage[state.key] = { value: value, timestamp: @clock.now }
        end
      end
    end
  end
end
