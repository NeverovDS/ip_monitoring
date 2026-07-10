# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] || 'development')

require 'dotenv'
Dotenv.load

require_relative 'database'

IS_SIDEKIQ = defined?(Sidekiq) && Sidekiq.server?

Dir["#{__dir__}/../app/models/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/services/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/workers/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/contracts/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/serializers/*.rb"].each { |file| require file }

require_relative '../app/api'
require_relative 'zeitwerk'
require_relative 'sidekiq'
