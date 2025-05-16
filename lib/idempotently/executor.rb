# frozen_string_literal: true

require 'logger'

module Idempotently
  # The Executor implements the core logic to run operations at most once within a configured idempotency window.
  # It uses an instance of [Idempotently::Storage::Adapter] to manage the state of operations.
  class Executor
    NullLogger = Logger.new(IO::NULL)

    Result = Data.define(:state, :executed, :return_value) do
      def self.skip(state)
        new(state, false, nil)
      end

      def self.complete(state, return_value)
        new(state, true, return_value)
      end

      def operation_executed?
        !!executed
      end

      def completed?
        success? || failure?
      end

      def in_progress?
        state.status == Storage::Status::STARTED
      end

      def success?
        state.status == Storage::Status::SUCCEEDED
      end

      def failure?
        state.status == Storage::Status::FAILED
      end
    end

    # @param storage [Idempotently::Storage::Adapter] storage object to use for storing state
    # @param window [Integer] The idempotency window in seconds
    # @param clock [Time] The clock to use for time operations (default: Time)
    # @param logger [Logger] The logger to use for logging (default: NullLogger)
    def initialize(storage:, window:, clock: Time, logger: NullLogger)
      raise ArgumentError, 'storage is required' if storage.nil?
      raise ArgumentError, 'window is required' if window.nil? || window.to_i <= 0

      @storage = storage
      @window = window.to_i
      @clock = clock
      @logger = logger
    end

    # Executes the operation with the given idempotency key.
    # TODO: add parameter for OtelSpan
    #
    # Semantics:
    # Executes the operation associated with the idempotency key, at most once within the configured idempotency window.
    # If an execution is recorded but is not within the idempotency window, it will be run again.
    #
    # @param idempotency_key [String] The idempotency key for the operation.
    # @param &operation [Proc] The block of code to execute idempotently.
    # The proc receives one argument which is the state of the previous execution or nil if the key is new.
    # If you the block is executed and the previous state is non nil, it means that the idempotency window has expired.
    # In this case it's up to the caller to decide if the operation should be executed normally.
    #
    # @return [Idempotently::Executor::Result] The result of the operation.
    def execute(idempotency_key, &operation)
      raise ArgumentError, 'idempotency_key is required' if idempotency_key.nil? || idempotency_key.to_s.empty?
      raise ArgumentError, 'no block given' unless block_given?

      @logger.debug("Operation with idempotency key: #{idempotency_key}, window: #{@window}")

      state, existed = @storage.fetch_or_create(idempotency_key: idempotency_key.to_s, window: @window)

      begin
        if existed
          return Result.skip(state) if within_window?(state)

          @logger.debug("Idempotency key #{idempotency_key} already exists with status #{state.status} but it is outside the idempotency window.")
          @storage.update(idempotency_key: idempotency_key.to_s, status: Storage::Status::STARTED)
        end

        value = operation.call(existed ? state : nil)

        updated_state = @storage.update(idempotency_key: idempotency_key.to_s, status: Storage::Status::SUCCEEDED)
        @logger.debug("Idempotency key #{idempotency_key} executed successfully.")

        Result.complete(updated_state, value)
      rescue StandardError => e
        @logger.error("Execution for key #{idempotency_key} failed with error: #{e.message}")
        @storage.update(idempotency_key: idempotency_key.to_s, status: Storage::Status::FAILED)
        raise e
      end
    end

    private

    def within_window?(state)
      # Check if the operation is within the idempotency window
      elapsed_time = @clock.now.to_i - state.timestamp
      elapsed_time <= @window
    end
  end
end
