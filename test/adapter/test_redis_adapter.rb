require 'test_helper'

require 'idempotently'
require 'idempotently/storage/redis_adapter'
require 'securerandom'

class TestRedisAdapter < Minitest::Test
  REDIS_URL = 'redis://localhost:6379/1'

  def teardown
    redis = Redis.new(url: REDIS_URL)
    redis.flushall
  end

  def test_fetch_or_create_creates_new_state_in_started
    adapter = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL })
    key = idempotency_key

    state, existed = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)

    refute existed
    assert_equal Idempotently::Storage::Status::STARTED, state.status
  end

  def test_fetch_or_create_creates_existing_state
    adapter = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL })
    key = idempotency_key

    state, existed = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)
    refute existed

    existing_state, existed = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)
    assert existed
    assert_equal state, existing_state
  end

  def test_update_changes_state_status
    adapter = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL })
    key = idempotency_key

    created_state, existed = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)
    refute existed

    updated_state = adapter.update(idempotency_key: key, status: Idempotently::Storage::Status::SUCCEEDED)

    assert_equal Idempotently::Storage::Status::SUCCEEDED, updated_state.status
    assert_equal updated_state.key, created_state.key
    assert_equal created_state.timestamp, updated_state.timestamp
  end

  def test_upate_updates_the_timestamp
    clock = TestClock.new
    adapter = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL }, clock: clock)
    key = idempotency_key

    created_state, existed = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)
    refute existed

    clock.increment(3)

    updated_state = adapter.update(idempotency_key: key, status: Idempotently::Storage::Status::SUCCEEDED)

    assert_equal Idempotently::Storage::Status::SUCCEEDED, updated_state.status
    assert_equal updated_state.key, created_state.key

    assert created_state.timestamp.to_i < updated_state.timestamp.to_i
  end

  def test_update_raises_error_for_nonexistent_key
    adapter = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL })

    assert_raises(Idempotently::Storage::Adapter::NoSuchKeyError) do
      adapter.update(idempotency_key: 'nonexistent_key', status: Idempotently::Storage::Status::SUCCEEDED)
    end
  end

  def test_packs_and_unpacks_state_correctly
    clock = TestClock.new
    adapter = Idempotently::Storage::RedisAdapter.new(redis_opts: { url: REDIS_URL }, clock: clock)
    key = idempotency_key

    clock.set(1234) # fix timestamp

    state, = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)

    assert_equal Idempotently::Storage::Status::STARTED, state.status
    assert_equal 1234, state.timestamp

    updated_state, = adapter.update(idempotency_key: key, status: Idempotently::Storage::Status::FAILED)

    assert_equal Idempotently::Storage::Status::FAILED, updated_state.status
    assert_equal 1234, updated_state.timestamp
  end
end
