# frozen_string_literal: true

require 'logger'

module Once
  # The Executor implements the core logic to run operations at most once within a configured execution window window.
  # It uses an instance of [Once::Storage::Adapter] to manage the state of operations.
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

    # @param storage [Once::Storage::Adapter] storage object to use for storing state
    # @param window [Integer] The execution window in seconds. Must respont to `#to_i` and return a positive integer.
    # @param clock [Time] The clock to use for time operations
    # @param logger [Logger] The logger to use for logging
    def initialize(storage:, window:, clock:, logger:)
      raise ArgumentError, 'storage is required' if storage.nil?
      raise ArgumentError, 'window is required' if window.nil? || window.to_i <= 0

      @storage = storage
      @window = window.to_i
      @clock = clock
      @logger = logger
    end

    # Executes the operation with the given execution key.
    # TODO: add parameter for OtelSpan
    #
    # Semantics:
    # Executes the operation associated with the key, at most once within the configured window.
    # If an execution is recorded but is not within the execution window, it will be run again.
    #
    # @param execution_key [String] The unique key identifying the operation.
    # @param &operation [Proc] The block of code to execute.
    #
    # @return [Once::Executor::Result] The result of the operation.
    def execute(execution_key, &operation)
      raise ArgumentError, 'execution_key is required' if execution_key.nil? || execution_key.to_s.empty?
      raise ArgumentError, 'no block given' unless block_given?

      @logger.debug("Operation with execution key: #{execution_key}, window: #{@window}")

      state, existed = @storage.fetch_or_create(execution_key: execution_key.to_s, window: @window)

      begin
        if existed
          return Result.skip(state) if within_window?(state)

          @logger.debug("Execution key #{execution_key} already exists with status #{state.status} but it is outside the execution window.")
          @storage.update(execution_key: execution_key.to_s, status: Storage::Status::STARTED, window: @window)
        end

        value = operation.call

        # This might still fail.
        # It will leave the status in started, hence prevening another run later, but the state will not match reality.
        updated_state = @storage.update(execution_key: execution_key.to_s, status: Storage::Status::SUCCEEDED,
                                        window: @window)

        Result.complete(updated_state, value)
      rescue Storage::Adapter::WriteError => e
        @logger.error("Status update for key #{execution_key} failed with error: #{e.message}")
        raise e
      rescue StandardError => e
        @logger.error("Execution for key #{execution_key} failed with error: #{e.message}")
        @storage.update(execution_key: execution_key.to_s, status: Storage::Status::FAILED, window: @window)
        raise e
      end
    end

    private

    def within_window?(state)
      elapsed_time = @clock.now.to_i - state.timestamp
      elapsed_time <= @window
    end
  end
end
