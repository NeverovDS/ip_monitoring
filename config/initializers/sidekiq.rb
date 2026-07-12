# Unlike the Roda version, there is no manual boot file: Rails already loads
# the environment (models, DB) for the Sidekiq process. We only point Sidekiq
# at Redis and register the cron schedule.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  schedule_file = Rails.root.join("config", "schedule.yml")
  Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file)) if File.exist?(schedule_file)
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

# Protect the /sidekiq dashboard with the same Basic Auth credentials.
require "sidekiq/web"
Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("ADMIN_USERNAME", "admin")) &
    ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("ADMIN_PASSWORD", "admin"))
end
