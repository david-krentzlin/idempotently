require_relative '../adapter'
require_relative '../state'
require_relative 'codec'
require 'redis'

module Idempotently
  module Storage
    module Redis
      # Redis storage adapter
      class Adapter < Idempotently::Storage::Adapter
        DEFAULT_REDIS_CONNECTOR = lambda {
          Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
                    reconnect_attempts: [0, 0.25, 0.5])
        }

        # @param clock [Time] The clock to use for timestamps
        # @param connector [Proc] A proc that must return a redis-rb [::Redis] connection. Defaults to DEFAULT_REDIS_CONNECTOR
        # @param key_codec [Codec] The codec to use for encoding keys. Defaults to Codec::IdentityKey
        # @param value_codec [Codec] The codec to use for encoding values. Defaults to Codec::BinaryValue
        def initialize(
          clock: Time,
          connector: DEFAULT_REDIS_CONNECTOR,
          key_codec: Codec::IdentityKey.new,
          value_codec: Codec::BinaryValue.new
        )
          super()
          raise ArgumentError, 'connector must be a proc' unless connector.respond_to?(:call)
          raise ArgumentError, 'key_codec must be a Codec::Key' unless key_codec.is_a?(Codec::Key)
          raise ArgumentError, 'value_codec must be a Codec::Value' unless value_codec.is_a?(Codec::Value)
          raise ArgumentError, 'clock must respond to now' unless clock.respond_to?(:now)

          @connector = connector
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
          @connection ||= @connector.call
        end
      end
    end
  end
end
