#!/bin/bash

echo "Running database setup..."

echo "Setting up the development database..."
  bundle exec rake db:migrate && echo "Database ready" || { echo "Failed to prepare database"; exit 1; }
exec "$@"
