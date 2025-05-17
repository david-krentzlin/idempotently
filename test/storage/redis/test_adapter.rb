require 'test_helper'

require 'once'
require 'once/storage/redis'
require 'securerandom'

class TestRedisAdapter < Minitest::Test
  REDIS_URL = 'redis://localhost:6379/1'

  def teardown
    redis.flushall
  end

  def redis
    Redis.new(url: REDIS_URL)
  end

  def test_fetch_or_create_creates_new_state_in_started
    adapter = Once::Storage::Redis::Adapter.new(connector: -> { redis })
    key = execution_key

    state, existed = adapter.fetch_or_create(execution_key: key, window: 10.seconds)

    refute existed
    assert_equal Once::Storage::Status::STARTED, state.status
  end

  def test_fetch_or_create_creates_existing_state
    adapter = Once::Storage::Redis::Adapter.new(connector: -> { redis })
    key = execution_key

    state, existed = adapter.fetch_or_create(execution_key: key, window: 10.seconds)
    refute existed

    existing_state, existed = adapter.fetch_or_create(execution_key: key, window: 10.seconds)
    assert existed
    assert_equal state, existing_state
  end

  def test_update_changes_state_status
    adapter = Once::Storage::Redis::Adapter.new(connector: -> { redis })
    key = execution_key

    created_state, existed = adapter.fetch_or_create(execution_key: key, window: 10.seconds)
    refute existed

    updated_state = adapter.update(execution_key: key,
                                   status: Once::Storage::Status::SUCCEEDED,
                                   window: 10.seconds)

    assert_equal Once::Storage::Status::SUCCEEDED, updated_state.status
    assert_equal updated_state.key, created_state.key
    assert_equal created_state.timestamp, updated_state.timestamp
  end

  def test_upate_updates_the_timestamp
    clock = TestClock.new
    adapter = Once::Storage::Redis::Adapter.new(connector: -> { redis }, clock: clock)
    key = execution_key

    created_state, existed = adapter.fetch_or_create(execution_key: key, window: 10.seconds)
    refute existed

    clock.increment(3)

    updated_state = adapter.update(execution_key: key,
                                   status: Once::Storage::Status::SUCCEEDED,
                                   window: 10.seconds)

    assert_equal Once::Storage::Status::SUCCEEDED, updated_state.status
    assert_equal updated_state.key, created_state.key

    assert created_state.timestamp.to_i < updated_state.timestamp.to_i
  end

  def test_update_raises_error_for_nonexistent_key
    adapter = Once::Storage::Redis::Adapter.new(connector: -> { redis })

    assert_raises(Once::Storage::Adapter::NoSuchKeyError) do
      adapter.update(execution_key: 'nonexistent_key',
                     status: Once::Storage::Status::SUCCEEDED,
                     window: 10.seconds)
    end
  end

  def test_packs_and_unpacks_state_correctly
    clock = TestClock.new
    adapter = Once::Storage::Redis::Adapter.new(connector: -> { redis }, clock: clock)
    key = execution_key

    clock.set(1234) # fix timestamp

    state, = adapter.fetch_or_create(execution_key: key, window: 10.seconds)

    assert_equal Once::Storage::Status::STARTED, state.status
    assert_equal 1234, state.timestamp

    updated_state, = adapter.update(execution_key: key,
                                    status: Once::Storage::Status::FAILED,
                                    window: 10.seconds)

    assert_equal Once::Storage::Status::FAILED, updated_state.status
    assert_equal 1234, updated_state.timestamp
  end

  def test_namespacecodec_works_correctly
    clock = TestClock.new
    adapter = Once::Storage::Redis::Adapter.new(
      key_codec: Once::Storage::Redis::Codec::NamespacedKey.new('test'),
      connector: -> { redis },
      clock: clock
    )
    key = execution_key

    state, = adapter.fetch_or_create(execution_key: key, window: 10.seconds)

    assert_equal Once::Storage::Status::STARTED, state.status

    raw_value = redis.get("test:#{key}")
    assert raw_value
  end
end
