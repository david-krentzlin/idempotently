# frozen_string_literal: true

require 'singleton'

module Idempotently
  # The ExecutorRegistry class is responsible for managing the registration and retrieval of [Idempotently::Executor].
  class ExecutorRegistry
    include Singleton

    class << self
      def register(context, storage:, window: Time, logger: Executor::NullLogger)
        instance.add(context, Executor.new(storage: storage, window: window, logger: logger))
      end

      def for(context)
        instance.get(context)
      end
    end

    def initialize
      @executors = {}
    end

    def add(context, executor)
      raise ArgumentError, "Executor already registered for context: #{context}" if @executors.key?(context)

      @executors[context] = executor
    end

    def get(context)
      @executors[context] || raise(ArgumentError, "No executor registered for context: #{context}")
    end
  end
end
