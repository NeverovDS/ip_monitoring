require "test_helper"
require Rails.root.join("evals/lib/evals").to_s

# Runs on the test database's server: the Postgres from docker-compose.yml locally, the
# service container in CI.
class EvalsDatabaseTest < ActiveSupport::TestCase
  setup do
    @name = "evals_test_#{SecureRandom.hex(4)}"
    @unrelated = "evals_test_#{SecureRandom.hex(4)}"
    on_server { |server| databases.each { |database| server.exec("CREATE DATABASE #{database}") } }
  end

  teardown do
    on_server { |server| databases.each { |database| server.exec("DROP DATABASE IF EXISTS #{database}") } }
  end

  test "drop removes the database and the ones the parallel test workers added, nothing else" do
    Evals::Database.new(@name, server: server).drop

    assert_equal [ @unrelated ], existing(databases)
  end

  private

  def databases
    [ @name, "#{@name}_0", "#{@name}_1", @unrelated ]
  end

  def existing(names)
    on_server { |server| server.exec("SELECT datname FROM pg_database").column_values(0) } & names
  end

  def on_server
    connection = PG.connect(**server, dbname: "postgres")
    yield connection
  ensure
    connection&.close
  end

  def server
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    { host: config[:host], port: config[:port], user: config[:username], password: config[:password] }
  end
end
