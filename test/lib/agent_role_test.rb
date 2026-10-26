require "test_helper"
require "minitest/mock"
require "rake"

# The role's password is public, so AgentRole.applicable? is what keeps it off every database
# but the local development one that .mcp.json connects to.
class AgentRoleTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("agent:role")
  end

  test "applies to the local development database, over TCP or a socket" do
    assert applicable?
    assert applicable?(host: "127.0.0.1")
    assert applicable?(host: nil)
  end

  test "never applies to another host, port, database or environment" do
    assert_not applicable?(host: "db.example.com")
    assert_not applicable?(port: 5432), "a local Postgres that other projects share"
    assert_not applicable?(port: nil), "the default port, 5432"
    assert_not applicable?(database: "other_project_development")
    assert_not applicable?(env: "test")
    assert_not applicable?(env: "production")
  end

  test "agent:role creates the role when it applies" do
    applied = role_applications(applicable: true) do
      assert_output(/ipmon_agent_ro is ready/) { Rake::Task["agent:role"].execute }
    end

    assert_equal 1, applied
  end

  test "agent:role skips every other database" do
    applied = role_applications(applicable: false) do
      assert_output(/Skipped: .*ip_monitoring_development on localhost:5433/) { Rake::Task["agent:role"].execute }
    end

    assert_equal 0, applied
  end

  private

  # The local development database, except where the test changes it.
  def applicable?(env: "development", host: "localhost", port: 5433, database: "ip_monitoring_development")
    settings = { host: host, port: port, database: database }.compact
    db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(env, "primary", settings)
    AgentRole.applicable?(env: ActiveSupport::EnvironmentInquirer.new(env), db_config: db_config)
  end

  # Counts how often the task calls AgentRole.apply! while applicable? returns the given value.
  def role_applications(applicable:)
    count = 0
    AgentRole.stub(:applicable?, applicable) do
      AgentRole.stub(:apply!, -> { count += 1 }) { yield }
    end
    count
  end
end
