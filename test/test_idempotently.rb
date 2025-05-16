# frozen_string_literal: true

require 'test_helper'
require 'idempotently/storage/memory_adapter'

class TestClock
  def initialize(value = Time.now)
    @value = value
  end

  def set(value)
    @value = value
  end

  def increment(new_value)
    @value += new_value
  end

  def now
    @value
  end
end

Idempotently::ExecutorRegistry.register(:messaging,
                                        storage: Idempotently::Storage::MemoryAdapter.new(clock: TestClock.new),
                                        window: 10.seconds)

class TestIdempotently < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Idempotently::VERSION
  end

  def test_executes_successfully_only_once
    counter = 0

    result = Idempotently.idempotently('1234', context: :messaging) do
      counter += 1
    end
    assert result.operation_executed?
    assert result.success?
    assert 1, result.return_value

    result = Idempotently.idempotently('1234', context: :messaging) do
      counter += 1
    end
    refute result.operation_executed?
    assert result.success?

    assert_equal 1, counter
  end
end
