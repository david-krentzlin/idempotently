require_relative 'test_helper'
require 'once/storage/redis'

class TestOnce < Minitest::Test
  REDIS_URL = 'redis://localhost:6379/2'

  def setup
    @clock = TestClock.new
    @storage = Once::Storage::Redis::Adapter.new(connector: -> { Redis.new(url: REDIS_URL) },
                                                 key_codec: Once::Storage::Redis::Codec::NamespacedKey.new('integration'))

    Once.configure do |config|
      config.profile :redis_integration, storage: @storage, window: 2
    end
  end

  def teardown
    Once::ExecutorRegistry.instance.clear
    redis = Redis.new(url: REDIS_URL)
    redis.flushall
  end

  def test_executes_successfully_only_once
    executed = 0
    existing_state = nil
    key = execution_key

    result = Once.run_once(key, profile: :redis_integration) do |previous_state|
      executed += 1
      existing_state = previous_state
    end

    assert_equal 1, executed
    assert result.operation_executed?
    assert result.success?
    assert 1, result.return_value
    assert_nil existing_state

    existing_state = nil
    result = Once.run_once(key, profile: :redis_integration) do |previous_state|
      executed += 1
      existing_state = previous_state
    end
    assert_equal 1, executed
    refute result.operation_executed?
    assert result.success?
    assert_nil existing_state
  end
end
