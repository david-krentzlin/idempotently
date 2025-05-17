# frozen_string_literal: true

require 'once/storage'

# Simple in-memory storage adapter for testing purposes.
class MemoryAdapter < Once::Storage::Adapter
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

  def fetch_or_create(execution_key:, window:)
    raise Once::Storage::Adapter::WriteError, 'forced error on create' if fail_on_create

    existing_state = @storage[execution_key]
    return [existing_state, true] if existing_state

    state = Once::Storage::State.create(execution_key, Once::Storage::Status::STARTED, @clock.now)

    @mutex.synchronize do
      @storage[execution_key] = state
    end

    [state, false]
  end

  def update(execution_key:, status:, window:)
    if fail_on_update && status == fail_on_update
      raise Once::Storage::Adapter::WriteError,
            'forced error on update'
    end

    existing_state = @storage[execution_key]
    raise Once::Storage::Adapter::NoSuchKeyError, "No such key: #{execution_key}" unless existing_state

    updated_state = existing_state.with(status: status, timestamp: @clock.now.to_i)

    @mutex.synchronize do
      @storage[execution_key] = updated_state
    end

    updated_state
  end
end
