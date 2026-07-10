# frozen_string_literal: true

require 'dotenv'
Dotenv.load

require 'sequel'
DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres://#{ENV['DB_USER']}:#{ENV['DB_PASSWORD']}@#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_NAME']}")

require 'dry-validation'
require 'dry-types'
require 'ipaddress'

Dir["#{__dir__}/../app/models/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/services/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/workers/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/contracts/*.rb"].each { |file| require file }
Dir["#{__dir__}/../app/serializers/*.rb"].each { |file| require file }

require 'sidekiq'
require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }

  schedule_file = File.join(Dir.pwd, 'config', 'sidekiq.yml')
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)['schedule'] if File.exist?(schedule_file)
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end
