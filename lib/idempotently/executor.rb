# frozen_string_literal: true

module Idempotently
  # The Executor class is responsible for executing operations idempotently.
  class Executor
    # The result of an operation, can have more than one state
    Result = Data.define(:executed, :status, :return_value) do
      # @return [Result] a result indicating that the operation has been executed
      def self.in_progress(executed)
        new(executed, Storage::State::STARTED, nil)
      end

      def self.completed_before(status)
        new(false, status, nil)
      end

      def self.completed_now(status, result)
        new(true, status, result)
      end

      # @return [Boolean] true if the operation was executed
      def completed?
        %i[success failure].include?(status)
      end

      def success?
        status == Storage::State::SUCCEEDED
      end

      def failure?
        status == Storage::State::FAILED
      end

      # @return [Boolean] true if the operation is in progress
      def in_progress?
        status == Storage::State::STARTED
      end

      def executed?
        !!executed
      end
    end

    class << self
      def register(context, storage)
        @executors ||= {}
        @executors[context] = new(storage)
      end

      def for(context)
        @executors[context] || raise(ArgumentError, "No executor registered for context: #{context}")
      end
    end

    # @param storage [Idempotently::Storage::Adapter] storage object to use for storing state
    def initialize(storage)
      @storage = storage
    end

    # Executes the operation with the given idempotency key.
    def execute(idempotency_key)
      raise ArgumentError, 'idempotency_key is required' if idempotency_key.nil? || idempotency_key.empty?
      raise ArgumentError, 'no block given' unless block_given?

      begin
        existed, state = @storage.fetch_or_create(idempotency_key)

        if existed
          return Result.in_progress if state.in_progress?
          return Result.completed_before(state.status) if state.completed?
        end

        result = yield
        updated_state = @storage.update(state, Storage::State::SUCCEEDED)
        Result.completed_now(updated_state.status, result)
      rescue StandardError => e
        binding.pry
        @storage.update(state, Storage::State::FAILED) # TODO: this can fail now
        raise e
      end
    end
  end
end
