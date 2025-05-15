# frozen_string_literal: true

module Idempotently
  VERSION = "0.1.0"
end

# class Processor < Xing::AMQP::Processor
#   include Idempotently
#
#   def process
#     idempotently(message.id, executor: :messaging) do
#       deliver_email
#     end
#   end
# end

# class MailController < ApplicationController
#   def send_email
#     result = idempotently(request.headers[:idempotency_key], executor: :mail) do
#       deliver_email(params[:email])
#     end
#   end
# end
#
# Idempotently.configure do |config|
#   config.executor(:messaging) do |msg_config|
#     msg_config.storage = Idempotently::Storage::RedisAdapter.new(ENV['REDIS_URL'])
#     msh_config.window = 30.minutes
#   end
# end
