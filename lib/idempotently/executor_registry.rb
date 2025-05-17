# frozen_string_literal: true

require 'singleton'

module Idempotently
  # The ExecutorRegistry class is responsible for managing the registration and retrieval of [Idempotently::Executor].
  class ExecutorRegistry
    include Singleton

    class << self
      def register(profile, executor)
        instance.add(profile, executor)
      end

      def for(profile)
        instance.get(profile)
      end
    end

    def initialize
      @executors = {}
    end

    def clear
      @executors = {}
    end

    def add(profile, executor)
      raise ArgumentError, "Executor already registered for profile: #{profile}" if @executors.key?(profile)

      @executors[profile] = executor
    end

    def get(profile)
      @executors[profile] || raise(ArgumentError, "No executor registered for profile: #{profile}")
    end
  end
end
