require_relative './config/application'
require './app/api'
require 'sidekiq/web'
require 'rack/session/cookie'

use Rack::Session::Cookie,
  secret: ENV['SESSION_SECRET'] || SecureRandom.hex(32),
  same_site: true,
  max_age: 86_400

use Rack::Auth::Basic, 'Protected Area' do |username, password|
  username == ENV['ADMIN_USERNAME'] && password == ENV['ADMIN_PASSWORD']
end

map '/' do
  run API
end

map '/sidekiq' do
  run Sidekiq::Web
end
