require_relative 'test_helper'
require 'idempotently/storage/redis_adapter'

class TestIdempotently < Minitest::Test
  REDIS_URL = 'redis://localhost:6379/2'

  def setup
    @clock = TestClock.new
    @storage = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL })

    Idempotently::ExecutorRegistry.register(:redis_integration,
                                            storage: @storage,
                                            window: 600,
                                            logger: Logger.new($stdout))
  end

  def teardown
    Idempotently::ExecutorRegistry.instance.clear
    redis = Redis.new(url: REDIS_URL)
    redis.flushall
  end

  def test_executes_successfully_only_once
    executed = 0
    existing_state = nil
    key = idempotency_key

    result = Idempotently.idempotently(key, context: :redis_integration) do |previous_state|
      executed += 1
      existing_state = previous_state
    end

    assert_equal 1, executed
    assert result.operation_executed?
    assert result.success?
    assert 1, result.return_value
    assert_nil existing_state

    existing_state = nil
    result = Idempotently.idempotently(key, context: :redis_integration) do |previous_state|
      executed += 1
      existing_state = previous_state
    end
    assert_equal 1, executed
    refute result.operation_executed?
    assert result.success?
    assert_nil existing_state
  end
end
