# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'idempotently'
require 'active_support'
require 'active_support/core_ext'

require 'pry'
require 'minitest/autorun'
