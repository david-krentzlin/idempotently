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
# Idempotently.idempotently(unique_key, context: :messaging) do
#   deliver_email
# end
# ```
module Idempotently
  module_function

  # Executes a block of code idempotently using the provided idempotency key and context.
  #
  # @param idempotency_key [String] The unique key for the operation.
  #
  # @param context [Symbol] The context in which the operation is executed. This must be a symbol that matches a registered context.
  # See also [Idempotently::ExecutorRegistry] for more details on how the context is registered.
  #
  # @param &operation [Proc] The block of code to execute idempotently.
  # See also [Idempotently::Executor] for more details on how the idempotency is managed.
  #
  # @return [Idempotently::Executor::Result] The result of the operation.
  def idempotently(idempotency_key, context:, &operation)
    Idempotently::ExecutorRegistry.for(context).execute(idempotency_key, &operation)
  end
end
