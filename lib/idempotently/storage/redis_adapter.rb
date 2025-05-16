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
      DEFAULT_REDIS_OPTS = {
        url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
        reconnect_attempts: [0, 0.25, 0.5]
      }.freeze

      def initialize(namespace: '', clock: Time, redis_opts: DEFAULT_REDIS_OPTS)
        super()
        @redis_opts = redis_opts
        @namespace = namespace
        @clock = clock
      end

      def fetch_or_create(idempotency_key:, window:)
        raise ArgumentError, 'idempotency_key is required' if idempotency_key.nil? || idempotency_key.to_s.empty?
        raise ArgumentError, 'window is required' if window.nil? || window.to_i <= 0

        timestamp = @clock.now.to_i
        value = pack(Status::STARTED, timestamp)

        existing_value = connection.set(with_namespace(idempotency_key), value, get: true, nx: true, ex: window.to_i)

        if existing_value
          status, timestamp = unpack(existing_value)
          [State.create(idempotency_key, status, timestamp), true]
        else
          [State.create(idempotency_key, Status::STARTED, timestamp), false]
        end
      end

      def update(idempotency_key:, status:)
        raise ArgumentError, 'idempotency_key is required' if idempotency_key.nil? || idempotency_key.to_s.empty?
        raise ArgumentError, 'status is required' if status.nil?

        namespaced_key = with_namespace(idempotency_key)

        value = connection.get(namespaced_key)
        raise NoSuchKeyError, "No such key: #{idempotency_key}" unless value

        timestamp = @clock.now.to_i
        new_value = pack(status, timestamp)

        connection.set(namespaced_key, new_value, xx: true)

        State.create(idempotency_key, status, timestamp)
      end

      private

      def with_namespace(idempotency_key)
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
        @connection ||= Redis.new(@redis_opts)
      end
    end
  end
end
