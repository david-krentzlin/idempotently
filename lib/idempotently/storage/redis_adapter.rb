require_relative 'adapter'
require_relative 'state'
require 'redis'

module Idempotently
  module Storage
    # Redis storage adapter for Idempotently.
    #
    # The state is modelled as a u64 bitfield which encodes both the
    # timestamp and the current status.
    #
    # The lower u8 are interepreted as the state (started, succeeded, failed).
    # The uper u56 are interpreted as the timestamp.
    # This gives us 64 bits in big endian.
    class RedisAdapter < Adapter
      def initialize(redis_url:, namespace: '', clock: Time)
        super()
        @url = redis_url
        @namespace = namespace
        @clock = clock
      end

      def fetch_or_create(idempotency_key:, window:)
        timestamp = @clock.now.to_i
        value = pack(Status::STARTED, timestamp)

        existing_value = connection.set(key(idempotency_key), value, get: true, nx: true, ex: window.to_i)

        if existing_value
          status, timestamp = unpack(existing_value)
          [State.create(idempotency_key, status, timestamp), true]
        else
          [State.create(idempotency_key, Status::STARTED, timestamp), false]
        end
      end

      def update(idempotency_key:, status:)
        value = connection.get(idempotency_key)
        raise NoSuchKeyError, "No such key: #{idempotency_key}" unless value

        timestamp = @clock.now.to_i
        new_value = pack(status, timestamp)

        connection.set(key(idempotency_key), new_value, xx: true)

        State.create(idempotency_key, status, timestamp)
      end

      private

      def key(idempotency_key)
        return idempotency_key if @namespace.empty?

        "#{@namespace}:#{idempotency_key}"
      end

      def pack(status, timestamp)
        full_value = (status << 56) | timestamp
        [full_value].pack('Q>')
      end

      def unpack(value)
        raw = value.unpack1('Q>') # 64-bit unsigned, big-endian

        status = (raw >> 56) & 0xFF
        timestamp = raw & 0x00FF_FFFF_FFFF_FFFF

        [status, timestamp]
      end

      def connection
        @connection ||= Redis.new(url: @redis_url)
      end
    end
  end
end
