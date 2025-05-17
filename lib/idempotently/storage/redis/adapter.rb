require_relative '../adapter'
require_relative '../state'
require_relative 'codec'
require 'redis'

module Idempotently
  module Storage
    module Redis
      # Redis storage adapter
      class Adapter < Idempotently::Storage::Adapter
        DEFAULT_REDIS_OPTS = {
          url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
          reconnect_attempts: [0, 0.25, 0.5]
        }.freeze

        def initialize(
          clock: Time,
          redis_opts: DEFAULT_REDIS_OPTS,
          key_codec: Codec::IdentityKey.new,
          value_codec: Codec::BinaryValue.new
        )
          super()
          @redis_opts = redis_opts
          @clock = clock
          @key_codec = key_codec
          @value_codec = value_codec
        end

        def fetch_or_create(idempotency_key:, window:)
          raise ArgumentError, 'idempotency_key is required' if idempotency_key.nil? || idempotency_key.to_s.empty?
          raise ArgumentError, 'window is required' if window.nil? || window.to_i <= 0

          timestamp = @clock.now.to_i
          encoded_value = @value_codec.encode(Status::STARTED, timestamp)
          encoded_key = @key_codec.encode(idempotency_key, timestamp, window)

          existing_value = connection.set(encoded_key, encoded_value, get: true, nx: true, ex: window.to_i)

          if existing_value
            status, timestamp = @value_codec.decode(existing_value)
            [State.create(idempotency_key, status, timestamp), true]
          else
            [State.create(idempotency_key, Status::STARTED, timestamp), false]
          end
        end

        def update(idempotency_key:, status:, window:)
          raise ArgumentError, 'idempotency_key is required' if idempotency_key.nil? || idempotency_key.to_s.empty?
          raise ArgumentError, 'status is required' if status.nil?

          encoded_key = @key_codec.encode(idempotency_key, @clock.now.to_i, window)

          value = connection.get(encoded_key)
          raise NoSuchKeyError, "No such key: #{idempotency_key}" unless value

          timestamp = @clock.now.to_i
          new_value = @value_codec.encode(status, timestamp)

          connection.set(encoded_key, new_value, xx: true)

          State.create(idempotency_key, status, timestamp)
        end

        private

        def connection
          @connection ||= ::Redis.new(@redis_opts)
        end
      end
    end
  end
end
