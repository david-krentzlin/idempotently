# frozen_string_literal: true

require 'test_helper'
require 'idempotently/storage/memory_adapter'

Idempotently::Executor.register(:messaging, Idempotently::Storage::MemoryAdapter.new(window: 10.minutes))
Idempotently::Executor.register(:api, Idempotently::Storage::MemoryAdapter.new(window: 2.minutes))

class TestIdempotently < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Idempotently::VERSION
  end

  def test_executes_successfully_only_once
    counter = 0

    result = Idempotently.idempotently('1234', context: :messaging) do
      counter += 1
    end
    assert result.executed?
    assert result.success?
    assert 1, result.return_value

    result = Idempotently.idempotently('1234', context: :messaging) do
      counter += 1
    end
    refute result.executed?
    assert result.success?

    assert_equal 1, counter
  end
end
