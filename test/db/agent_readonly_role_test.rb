require "test_helper"

# The Postgres MCP server logs in as ipmon_agent_ro, and its SELECT-only grants are the only
# thing that keeps the server's execute_sql from writing. Everything runs inside the test
# transaction, so whatever the test does to the role is rolled back afterwards.
class AgentReadonlyRoleTest < ActiveSupport::TestCase
  # The role belongs to the whole Postgres cluster, so on a developer machine bin/setup has
  # created it already. Without the cleanup, the test could pass on grants an earlier run left.
  setup do
    if role_exists?
      # Every grant in this database, default privileges included, and CONNECT on the other
      # databases, development too. The test transaction rolls all of it back.
      execute "DROP OWNED BY ipmon_agent_ro"
      execute "ALTER ROLE ipmon_agent_ro RESET ALL"
      execute "REVOKE pg_read_all_stats FROM ipmon_agent_ro"
    end
    # Twice, as bin/setup may run again and again.
    2.times { AgentRole.apply!(connection) }
  end

  test "reads every table, so a table added later is covered too" do
    tables = connection.tables
    assert_includes tables, "ips"

    as_agent do
      tables.each { |table| assert_readable table }
    end
  end

  test "cannot write" do
    as_agent do
      assert_refused "INSERT INTO ips (ip_address, enabled, created_at, updated_at) VALUES ('8.8.4.4', true, now(), now())"
      assert_refused "UPDATE ips SET enabled = enabled"
      assert_refused "DELETE FROM ip_checks"
      assert_refused "TRUNCATE ip_status_changes"
      assert_refused "CREATE TABLE agent_probe (id int)"
    end
  end

  test "reads tables and sequences that later migrations create" do
    execute "CREATE TABLE agent_probe (id bigserial PRIMARY KEY)"

    as_agent do
      assert_readable "agent_probe"
      assert value("SELECT has_sequence_privilege('agent_probe_id_seq', 'SELECT')")
    end
  end

  test "reads existing sequences and the statistics views" do
    assert value("SELECT has_sequence_privilege('ipmon_agent_ro', pg_get_serial_sequence('ips', 'id'), 'SELECT')")
    assert value("SELECT pg_has_role('ipmon_agent_ro', 'pg_read_all_stats', 'member')")
  end

  # SET ROLE does not load a role's login settings, so they are read from the catalog.
  test "every login starts read-only with a 5 second statement timeout" do
    settings = value("SELECT rolconfig FROM pg_roles WHERE rolname = 'ipmon_agent_ro'")

    assert_includes settings, "default_transaction_read_only=on"
    assert_includes settings, "statement_timeout=5s"
  end

  private

  def as_agent
    execute "SET ROLE ipmon_agent_ro"
    yield
  ensure
    execute "RESET ROLE"
  end

  def assert_readable(table)
    assert_kind_of Integer, value("SELECT count(*) FROM #{connection.quote_table_name(table)}"), table
  end

  # In a savepoint, so one refused statement does not abort the test's transaction.
  def assert_refused(sql)
    error = assert_raises(ActiveRecord::StatementInvalid, sql) do
      connection.transaction(requires_new: true) { execute(sql) }
    end
    assert_match "permission denied", error.message
  end

  def role_exists?
    value("SELECT 1 FROM pg_roles WHERE rolname = 'ipmon_agent_ro'").present?
  end

  def execute(sql)
    connection.execute(sql)
  end

  def value(sql)
    connection.select_value(sql)
  end

  def connection
    ActiveRecord::Base.connection
  end
end
