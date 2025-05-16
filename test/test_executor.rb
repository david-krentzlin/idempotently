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

      it 'passes nil to the block' do
        executed = 0
        existing_state = nil

        @executor.execute(key) do |previous_state|
          executed += 1
          existing_state = previous_state
        end

        assert_equal 1, executed
        assert_nil existing_state
      end
    end

    describe 'when operation is still in progress' do
      it 'does not execute the operation again' do
        executed = 0
        inner_result = nil
        test_key = key

        @executor.execute(test_key) do
          executed += 1

          # now we'll simulate that the operation is still in progress
          inner_result = @executor.execute(test_key) do
            executed += 1
          end
        end

        assert_equal 1, executed
        assert inner_result.in_progress?
        assert_nil inner_result.return_value
      end

      describe 'but the idempotency window has expired' do
        it 'does execute and timestamp is updated' do
          executed = 0
          test_key = key
          inner_result = nil

          @executor.execute(test_key) do
            executed += 1
            @clock.increment(11.second)

            inner_result = @executor.execute(test_key) do
              executed += 1
            end
          end

          assert_equal 2, executed
          assert_equal @clock.value.to_i, inner_result.state.timestamp.to_i # updated timestamp
        end

        it 'calls block with previous_state' do
          executed = 0
          test_key = key
          existing_state = nil

          @executor.execute(test_key) do
            executed += 1
            @clock.increment(11.second)

            @executor.execute(test_key) do |previous_state|
              executed += 1
              existing_state = previous_state
            end
          end

          assert existing_state.present?
        end
      end
    end

    describe 'when operation is marked as succeeded' do
      it 'does not execute the operation again' do
        executed = 0
        test_key = key

        result = @executor.execute(test_key) do
          executed += 1
        end

        assert result.success?

        result = @executor.execute(test_key) do
          executed += 1
        end

        assert_equal 1, executed
        assert result.success?
        assert_nil result.return_value
      end

      describe 'but the idempotency window has expired' do
        it 'does execute and timestamp is updated' do
          executed = 0
          test_key = key

          @executor.execute(test_key) do
            executed += 1
          end

          @clock.increment(20)

          result = @executor.execute(test_key) do
            executed += 1
          end

          assert_equal 2, executed
          assert_equal @clock.value.to_i, result.state.timestamp.to_i # updated timestamp
        end

        it 'calls block with previous_state' do
          executed = 0
          test_key = key
          previous_state = nil

          @executor.execute(test_key) do |existing_state|
            executed += 1
            previous_state = existing_state
          end

          @clock.increment(20)
          assert_nil previous_state

          previous_state = nil
          @executor.execute(test_key) do |existing_state|
            executed += 1
            previous_state = existing_state
          end

          assert_equal previous_state.key, test_key
          assert_equal previous_state.status, Idempotently::Storage::Status::SUCCEEDED
        end
      end
    end

    describe 'when operation is marked as failed' do
      it 'does not execute the operation again' do
        executed = 0
        test_key = key

        assert_raises(ArgumentError) do
          @executor.execute(test_key) do
            raise ArgumentError, 'Simulated failure'
          end
        end

        result = @executor.execute(test_key) do
          executed += 1
        end

        assert_equal 0, executed
        assert result.failure?
        assert_nil result.return_value
      end

      describe 'but the idempotency window has expired' do
        it 'executes again and updates state' do
          executed = 0
          test_key = key

          assert_raises(ArgumentError) do
            @executor.execute(test_key) do
              executed += 1
              raise ArgumentError, 'Simulated failure'
            end
          end

          @clock.increment(11.second)

          result = @executor.execute(test_key) do
            executed += 1
          end

          assert_equal 2, executed
          assert result.success?
          assert_equal @clock.value.to_i, result.state.timestamp.to_i # updated timestamp
        end

        it 'calls block with previous_state' do
          executed = 0
          test_key = key

          assert_raises(ArgumentError) do
            @executor.execute(test_key) do
              executed += 1
              raise ArgumentError, 'Simulated failure'
            end
          end

          @clock.increment(11.second)

          existing_state = nil

          @executor.execute(test_key) do |previous_state|
            executed += 1
            existing_state = previous_state
          end

          assert_equal 2, executed
          assert_equal existing_state.key, test_key
          assert_equal existing_state.status, Idempotently::Storage::Status::FAILED
        end
      end
    end
  end
end
