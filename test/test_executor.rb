# frozen_string_literal: true

require 'test_helper'
require 'idempotently/storage/memory_adapter'
require 'minitest/spec'
require 'securerandom'

describe Idempotently::Executor do
  def key
    SecureRandom.uuid
  end

  describe 'at most once semantics' do
    before do
      @clock = TestClock.new
      @storage = Idempotently::Storage::MemoryAdapter.new(clock: @clock)
      @executor = Idempotently::Executor.new(storage: @storage, window: 10.seconds, clock: @clock)
    end

    describe "when operation hasn't been executed" do
      it 'executes the operation' do
        executed = 0

        @executor.execute(key) do
          executed += 1
        end

        assert_equal 1, executed
      end

      it 'returns the result of the operation' do
        executed = 0
        result = @executor.execute(key) do
          executed += 1
          'hello world'
        end

        assert_equal 1, executed
        assert result.success?
        assert_equal 'hello world', result.return_value
      end
    end

    describe 'when operation is still in progress' do
      it 'does not execute the operation again' do
        executed = 0
        inner_result = nil
        key = 'test_key_progress'

        @executor.execute(key) do
          executed += 1

          # now we'll simulate that the operation is still in progress
          inner_result = @executor.execute(key) do
            executed += 1
          end
        end

        assert_equal 1, executed
        assert inner_result.in_progress?
        assert_nil inner_result.return_value
      end
    end

    describe 'when operation is marked as succeeded' do
      it 'does not execute the operation again' do
        executed = 0
        key = 'test_key_success'

        result = @executor.execute(key) do
          executed += 1
        end

        assert result.success?

        result = @executor.execute(key) do
          executed += 1
        end

        assert_equal 1, executed
        assert result.success?
        assert_nil result.return_value
      end
    end

    describe 'when operation is marked as failed' do
      before do
        @clock = TestClock.new
        @storage = Idempotently::Storage::MemoryAdapter.new(clock: @clock)
        @executor = Idempotently::Executor.new(storage: @storage, window: 10.seconds, clock: @clock)
        @key = 'test_key'
      end

      it 'does not execute the operation again' do
        executed = 0
        key = 'test_key_error'

        assert_raises(ArgumentError) do
          @executor.execute(key) do
            raise ArgumentError, 'Simulated failure'
          end
        end

        result = @executor.execute(key) do
          executed += 1
        end

        assert_equal 0, executed
        assert result.failure?
        assert_nil result.return_value
      end

      describe 'but is outside the idempotency window' do
      end
    end
  end
end
