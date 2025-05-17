# Oncd

A focused, extensible ruby library to help teams to establish at-most once semantics for side-effecting code — especially in distributed systems, messaging pipelines, and service integrations.


## 🧩 Usage

```ruby
require "once"
require "once/storage/redis"

# Put the following into your app's configuration
Once.configure do |config|
  config.profile :email, 
                 storage: Once::Storage::Redis::Adapter.new, # takes redis url from ENV['REDIS_URL']
                 window: 1.hour, # 1 hour in seconds
                 logger: Logger.new(STDOUT) 
                  
end

# Assuming this is used in a message processor
class EmailProcessor < MessageProcessor
  include Once

  def process
    run_once(message.message_id, profile: :email) do 
      deliver_email(payload.email)
    end
  end
end

```

## API Details

The library presents itself through a configuration, and a simple invocation API.
The following gives a more details account of those two building blocks, and aims to give practical information that goes beyond the mere code documentation.

The entry point for the API is the `Once.run_once` method, which you can either invoke directly or by including the module into your classes.
It requires you to pass two arguments:

1. The operation key, which must be provided by the caller, non-empty and has to respond to `#to_s`
2. A symbol determining the execution profile to be used for this particular invocation 
3. A block that encapsulates the operation that performs the side-effect

The execution profile that is associated with the second argument, has to be setup / configured before it can be used.
It provides the storage backend that is to be used, as well as specification for the `execute once window` in seconds.

You can register arbitrary execution profiles and for some storage backends it is recommended to re-use the same
backend across different executors. This is for example true for the **redis adapter**.

```ruby
Once.run_once("my-unique-key", profile: :email) do 
  puts "Operation not yet executed. Will continue"
  perform_heavy_side_effect!
end

````

## Guidelines on finding suitable configuration options

The most obvious question is how to pick the at-most once window.
The trade-off here is safety vs. storage requirements. The bigger the window, the more data has to be stored.
Which value you want to pick thus depends on:

1. the rate of operations that you want to ensure run at most once
2. the maxium amount of memory you have for your storage
3. the probability of duplicate executions

From these points, the third one needs a bit more explanation.
It is not uncommon that operations are triggered by events in a distributed system, for example via a messaging system like RabbitMQ or Kafka.
In this case the probability of seeing the same messages, that act as a trigger twice, decreases with the TTL of the message, as well as system settings that control
how long transient messages are kept in flight. These can be useful indicators to pick a proper window.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
