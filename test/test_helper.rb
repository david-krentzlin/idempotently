# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'once'
require 'active_support'
require 'active_support/core_ext'

require 'pry'
require 'minitest/autorun'
require 'securerandom'

def execution_key
  SecureRandom.uuid
end

class TestClock
  attr_reader :value

  def initialize(value = Time.now)
    @value = value
  end

  def set(value)
    @value = value
  end

  def increment(new_value)
    @value += new_value
  end

  def now
    @value
  end
end
