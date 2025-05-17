# frozen_string_literal: true

require_relative 'once/version'
require_relative 'once/storage'
require_relative 'once/executor'
require_relative 'once/executor_registry'

# The Once module provides a simple API for executing operations at most once.
# The `run_once` method allows you to execute a block of code identified by a supplied execution key.
# Users of the code can decide to extend or include this module to use the API.
#
# Example usage:
#
# ```ruby
# Once.run_once(unique_key, profile: :messaging) do
#   deliver_email
# end
# ```
module Once
  # Executes a block of code at most once using the provided execution key and profile.
  #
  # @param execution_key [String] The unique key for the operation.
  #
  # @param profile [Symbol] The profile in which the operation is executed. This must be a symbol that matches a registered profile.
  # See also [Once::ExecutorRegistry] for more details on how the profile is registered.
  #
  # @param &operation [Proc] The block of code to execute idempotently.
  # See also [Once::Executor] for more details on how the idempotency is managed.
  #
  # @return [Once::Executor::Result] The result of the operation.

  module_function

  def run_once(execution_key, profile:, &operation)
    Once::ExecutorRegistry.instance.for(profile).execute(execution_key, &operation)
  end

  def self.configure
    configurator = Configurator.new
    yield(configurator)
  end

  # Little DSL to configure the Idempotently gem.
  class Configurator
    def initialize(registry = Once::ExecutorRegistry.instance)
      @registry = registry
    end

    def profile(name, storage:, window:, logger: Executor::NullLogger, clock: Time)
      @registry.register(
        name,
        Executor.new(storage: storage, window: window, logger: logger, clock: clock)
      )
    end
  end
end
