# frozen_string_literal: true

require_relative 'adapter'
require_relative 'state'

module Idempotently
  module Storage
    # Simple in-memory storage adapter for testing purposes.
    class MemoryAdapter < Adapter
      def initialize(clock: Time)
        super()
        @storage = {}
        @mutex = Mutex.new
        @clock = clock
      end

      def clear
        @mutex.synchronize do
          @storage = {}
        end
      end

      def fetch_or_create(idempotency_key:, window:)
        existing_state = @storage[idempotency_key]
        return [existing_state, true] if existing_state

        state = State.create(idempotency_key, Status::STARTED, @clock.now)

        @mutex.synchronize do
          @storage[idempotency_key] = state
        end

        [state, false]
      end

      def update(idempotency_key:, status:)
        existing_state = @storage[idempotency_key]
        raise NoSuchKeyError, "No such key: #{idempotency_key}" unless existing_state

        updated_state = existing_state.with(status: status, timestamp: @clock.now.to_i)

        @mutex.synchronize do
          @storage[idempotency_key] = updated_state
        end

        updated_state
      end
    end
  end
end
