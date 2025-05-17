module Idempotently
  module Storage
    module Redis
    end
  end
end

require_relative 'redis/codec'
require_relative 'redis/adapter'
