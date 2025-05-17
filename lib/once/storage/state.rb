# frozen_string_literal: true

module Once
  module Storage
    module Status
      STARTED = 0
      SUCCEEDED = 1
      FAILED = 2
    end

    State = Data.define(:key, :timestamp, :status) do
      def self.create(key, status, timestamp)
        raise ArgumentError, 'Invalid status' unless [Status::STARTED,
                                                      Status::SUCCEEDED,
                                                      Status::FAILED].include?(status)
        raise ArgumentError, 'Key cannot be empty' if key.to_s.empty?

        new(key, timestamp.to_i, status)
      end
    end
  end
end
