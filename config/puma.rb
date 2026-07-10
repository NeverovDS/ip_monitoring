# frozen_string_literal: true

require_relative 'application'

workers Integer(ENV['WEB_CONCURRENCY'] || 2)

threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup "./config.ru"

bind "tcp://#{ENV['BIND'] || '0.0.0.0'}:#{ENV['PORT'] || 9292}"

environment ENV['RACK_ENV'] || 'development'

worker_timeout 60


before_fork do
  if defined?(DB)
    DB.disconnect
  end
end

on_worker_boot do
  if defined?(DB)
    DB.connect(DB.config)
  end
end
