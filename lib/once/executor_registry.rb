# frozen_string_literal: true

require 'singleton'

module Once
  # The ExecutorRegistry class is responsible for managing the registration and retrieval of [Once::Executor].
  class ExecutorRegistry
    include Singleton

    def initialize
      @executors = {}
    end

    def clear
      @executors = {}
    end

    def register(profile, executor)
      raise ArgumentError, "Executor already registered for profile: #{profile}" if @executors.key?(profile)

      @executors[profile] = executor
    end

    def for(profile)
      @executors[profile] || raise(ArgumentError, "No executor registered for profile: #{profile}")
    end
  end
end
