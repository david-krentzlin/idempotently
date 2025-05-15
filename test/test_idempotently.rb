# frozen_string_literal: true

require "test_helper"

Idempotently::Executor.register(:messaging, Idempotently::Storage::MemoryAdapter.new(window: 10.minutes))
Idempotently::Executor.register(:api, Idempotently::Storage::MemoryAdapter.new(window: 2.minutes))

class TestIdempotently < Minitest::Test
  def setup
  end

  def test_that_it_has_a_version_number
    refute_nil ::Idempotently::VERSION
  end

  def smoke_test
    counter = 0

    Idempotently.idempotently("1234", executor: :messaging) do
      counter += 1
    end

    Idempotently.idempotently("1234", executor: :messaging) do
      counter += 1
    end

    Idempotently.idempotently("1234", executor: :messaging) do
      counter += 1
    end

    assert_equal 1, counter
  end
end
