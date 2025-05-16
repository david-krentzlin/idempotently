# Idempotently

A focused, extensible Ruby library to help teams write safe, idempotent operations around side-effecting code — especially in distributed systems, messaging pipelines, and service integrations.

It provides a simple API to wrap operations that must run **at most once**, even in the presence of multiple invocations, because of retries, or duplicate events. At most once guarantees are applied within a *configurable idempotency window*.

## 🧩 Usage

```ruby
require "idempotently"
require "idempotently/storage/redis_adapter"

# Put the following into your app's configuration
Idempotently::ExecutorRegistry
  .register(:email, 
            window: 3600, # 1 hour of idempotency window
            storage: Idempotently::Storage::RedisAdapter.new(redis_opts: { url: ENV['REDIS_URL'] }, namespace: 'myapp'),
            logger: Logger.new($stdout))


# Assuming this is used in a message processor
class EmailProcessor < MessageProcessor
  include Idempotently

  def process
    idempotently(message.message_id, context: :email) do |_previous_state|
      deliver_email(payload.email)
    end
  end
end
```

## Guidelines on finding suitable configuration options

The most obvious question is how to pick the idempotency window.
The trade-off here is safety vs. storage requirements. The bigger the idempotency window, the more data has to be stored.
Which value you want to pick thus depends on:

1. the rate of operations that you want to make idempotent
2. the maxium amount of memory you have for your storage
3. the probability of duplicate executions

From these points, the third one needs a bit more explanation.
It is not uncommon that operations are triggered by events in a distributed system, for example via a messaging system like RabbitMQ or Kafka.
In this case the probability of seeing the same messages, that act as a trigger twice, decreases with the TTL of the message, as well as system settings that control
how long transient messages are kept in flight. These can be useful indicators to pick a proper window.

If you want to play it safe, you can always react domain specific in the event of reprocessing of an operation, by examaning the previous state in
the block of the operation. Defensive implementations will not execute again and create useful logs or metrics to be informed.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
