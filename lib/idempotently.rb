# frozen_string_literal: true

require_relative 'idempotently/version'
require_relative 'idempotently/storage'
require_relative 'idempotently/executor'
require_relative 'idempotently/executor_registry'

# The Idempotently module provides a simple API for executing operations idempotently.
# The `idempotently` method allows you to execute a block of code with an idempotency key.
# Users of the code can decide to extend or include this module to use the API.
#
# Example usage:
#
# ```ruby
# Idempotently.idempotently(unique_key, profile: :messaging) do
#   deliver_email
# end
# ```
module Idempotently
  # Executes a block of code idempotently using the provided idempotency key and profile.
  #
  # @param idempotency_key [String] The unique key for the operation.
  #
  # @param profile [Symbol] The profile in which the operation is executed. This must be a symbol that matches a registered profile.
  # See also [Idempotently::ExecutorRegistry] for more details on how the profile is registered.
  #
  # @param &operation [Proc] The block of code to execute idempotently.
  # See also [Idempotently::Executor] for more details on how the idempotency is managed.
  #
  # @return [Idempotently::Executor::Result] The result of the operation.

  module_function

  def idempotently(idempotency_key, profile:, &operation)
    Idempotently::ExecutorRegistry.for(profile).execute(idempotency_key, &operation)
  end

  def self.configure
    configurator = Configurator.new
    yield(configurator)
  end

  # Little DSL to configure the Idempotently gem.
  class Configurator
    def profile(name, storage:, window:, logger: Executor::NullLogger, clock: Time)
      ExecutorRegistry.register(
        name,
        Executor.new(storage: storage, window: window, logger: logger, clock: clock)
      )
    end
  end
end
