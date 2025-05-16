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

  def idempotency_key
    SecureRandom.uuid
  end

  def test_fetch_or_create_creates_new_state_in_started
    adapter = Idempotently::Storage::RedisAdapter.new(redis_url: REDIS_URL)
    key = idempotency_key

    state, existed = adapter.fetch_or_create(idempotency_key: key, window: 10.seconds)

    refute existed
    assert_equal Idempotently::Storage::Status::STARTED, state.status
  end

  # def test_fetch_or_create_creates_new_state
  #   idempotency_key = 'test_key'
  #   window = 10.seconds
  #   state, created = @adapter.fetch_or_create(idempotency_key: idempotency_key, window: window)
  #   assert created
  #   assert_equal Idempotently::Storage::State::Status::STARTED, state.status
  #   assert_equal idempotency_key, state.idempotency_key
  # end
  #
  # def test_update_changes_state_status
  #   idempotency_key = 'test_key'
  #   window = 10.seconds
  #   _, _created = @adapter.fetch_or_create(idempotency_key: idempotency_key, window: window)
  #   updated_state = @adapter.update(idempotency_key: idempotency_key,
  #                                   status: Idempotently::Storage::State::Status::COMPLETED)
  #   assert_equal Idempotently::Storage::State::Status::COMPLETED, updated_state.status
  # end
  #
  # def test_update_raises_error_for_nonexistent_key
  #   assert_raises(Idempotently::Storage::NoSuchKeyError) do
  #     @adapter.update(idempotency_key: 'nonexistent_key', status: Idempotently::Storage::State::Status::COMPLETED)
  #   end
  # end
  #
  # def test_clear_removes_all_states
  #   idempotency_key = 'test_key'
  #   window = 10.seconds
  #   @adapter.fetch_or_create(idempotency_key: idempotency_key, window: window)
  #   assert_equal 1, @redis.keys('*').size
  #   @adapter.clear
  #   assert_equal 0, @redis.keys('*').size
  # end
end
