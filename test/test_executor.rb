# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/mock'
require 'securerandom'
require_relative 'memory_adapter'

describe Once::Executor do
  describe 'at most once semantics' do
    before do
      @clock = TestClock.new
      @storage = MemoryAdapter.new(clock: @clock)
      @executor = Once::Executor.new(storage: @storage,
                                     window: 10.seconds,
                                     clock: @clock,
                                     logger: Once::Executor::NullLogger)
    end

    describe "when operation hasn't been executed" do
      it 'executes the operation' do
        executed = 0

        @executor.execute(execution_key) do
          executed += 1
        end

        assert_equal 1, executed
      end

      it 'returns the result of the operation' do
        executed = 0
        result = @executor.execute(execution_key) do
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
        test_key = execution_key

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

      describe 'but the execution window has expired' do
        it 'does execute and timestamp is updated' do
          executed = 0
          test_key = execution_key
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
      end
    end

    describe 'when operation is marked as succeeded' do
      it 'does not execute the operation again' do
        executed = 0
        test_key = execution_key

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

      describe 'but the window has expired' do
        it 'does execute and timestamp is updated' do
          executed = 0
          test_key = execution_key

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
      end
    end

    describe 'when operation is marked as failed' do
      it 'does not execute the operation again' do
        executed = 0
        test_key = execution_key

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

      describe 'but the window has expired' do
        it 'executes again and updates state' do
          executed = 0
          test_key = execution_key

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
      end
    end

    describe 'when errors occur' do
      describe 'during inital creation of state' do
        it 'does not execute, propagates the error and doesnt create any record' do
          test_key = execution_key
          executed = 0

          @storage.fail_on_create = true

          assert_raises(Once::Storage::Adapter::WriteError) do
            @executor.execute(test_key) do
              executed += 1
            end
          end

          assert_equal 0, executed
          assert_nil @storage.get(test_key)
        end
      end

      describe 'on update after creation' do
        it 'does execute, status is still in progress, and propagates error' do
          test_key = execution_key
          executed = 0

          assert_raises(Once::Storage::Adapter::WriteError) do
            @storage.fail_on_create = false
            @storage.fail_on_update = Once::Storage::Status::SUCCEEDED
            @executor.execute(test_key) do
              executed += 1
            end
          end

          @storage.fail_on_update = false
          @storage.fail_on_create = false

          @executor.execute(test_key) do
            executed += 1
          end

          assert_equal 1, executed
          state = @storage.get(test_key)
          assert_equal Once::Storage::Status::STARTED, state.status
        end
      end
    end
  end
end
