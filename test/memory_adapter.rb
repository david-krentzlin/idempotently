# frozen_string_literal: true

require 'idempotently/storage'

# Simple in-memory storage adapter for testing purposes.
class MemoryAdapter < Idempotently::Storage::Adapter
  attr_accessor :fail_on_create, :fail_on_update

  def initialize(clock: Time)
    super()
    @storage = {}
    @mutex = Mutex.new
    @clock = clock
    @fail_on_update = false
    @fail_on_create = false
  end

  def get(key)
    @storage[key]
  end

  def clear
    @mutex.synchronize do
      @storage = {}
    end
  end

  def fetch_or_create(idempotency_key:, window:)
    raise Idempotently::Storage::Adapter::WriteError, 'forced error on create' if fail_on_create

    existing_state = @storage[idempotency_key]
    return [existing_state, true] if existing_state

    state = Idempotently::Storage::State.create(idempotency_key, Idempotently::Storage::Status::STARTED, @clock.now)

    @mutex.synchronize do
      @storage[idempotency_key] = state
    end

    [state, false]
  end

  def update(idempotency_key:, status:)
    if fail_on_update && status == fail_on_update
      raise Idempotently::Storage::Adapter::WriteError,
            'forced error on update'
    end

    existing_state = @storage[idempotency_key]
    raise Idempotently::Storage::Adapter::NoSuchKeyError, "No such key: #{idempotency_key}" unless existing_state

    updated_state = existing_state.with(status: status, timestamp: @clock.now.to_i)

    @mutex.synchronize do
      @storage[idempotency_key] = updated_state
    end

    updated_state
  end
end
