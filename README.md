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
            storage: Idempotently::Storage::RedisAdapter.new(redis_opts: { url: ENV['REDIS_URL'] }),
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


## Guarantees

TODO:

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
