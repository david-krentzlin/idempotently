# frozen_string_literal: true

module Idempotently
  # The Idempotently module provides a simple API for executing operations idempotently.
  # The `idempotently` method allows you to execute a block of code with an idempotency key.
  # Users of the code can decide to extend or include this module to use the API.
  #
  # Example usage:
  #
  # ```ruby
  # Idempotently.idempotently(unique_key) do
  #   deliver_email
  # end
  # ```

  module_function

  def idempotently(idempotency_key, context:, &operation)
    Idempotently::Configuration.executors[context].execute(idempotency_key, &operation)
  end
end
