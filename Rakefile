require 'sequel'
require_relative 'config/database'

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_t, args|
    require 'sequel/extensions/migration'

    Sequel.extension :migration

    version = args[:version] ? args[:version].to_i : nil

    Sequel::Migrator.run(DB, 'db/migrations', target: version)

    puts 'Migrations completed'
  end

  desc 'Create new migration'
  task :new_migration, [:name] do |_t, args|
    name = args[:name] || 'migration'
    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    filename = "db/migrations/#{timestamp}_#{name}.rb"

    FileUtils.mkdir_p('db/migrations')

    content = <<~RUBY
      # frozen_string_literal: true

      Sequel.migration do
        change do
        end
      end
    RUBY

    File.write(filename, content)
    puts "Created migration: #{filename}"
  end

  desc 'Rollback last migration'
  task :rollback do
    require 'sequel/extensions/migration'

    Sequel.extension :migration

    Sequel::Migrator.run(DB, 'db/migrations', target: -1)

    puts 'Rollback completed'
  end

  desc 'Check migration status'
  task :status do
    require 'sequel/extensions/migration'

    Sequel.extension :migration

    if Sequel::Migrator.is_current?(DB, 'db/migrations')
      puts 'All migrations are up to date'
    else
      puts 'Migrations are pending'
    end

    migration_files = Dir['db/migrations/*.rb'].sort
    applied = DB[:schema_migrations].select_map(:filename)

    migration_files.each do |file|
      filename = File.basename(file)
      status = applied.include?(filename) ? 'UP' : 'DOWN'
      puts "#{filename} - #{status}"
    end
  end
end
