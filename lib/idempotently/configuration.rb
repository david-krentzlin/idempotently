# Idempotently.register_executor(:messaging, Idempotently::Storage::RedisAdapter.new(ENV['REDIS_URL'], window: 30.minutes))

module Idempotently
  def configure(context_key)
  end
end
