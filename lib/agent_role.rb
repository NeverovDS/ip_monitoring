# The read-only Postgres role that the coding agent's MCP server logs in as
# (.claude/db/agent_readonly_role.sql). Its password is public, it is in the repository, so the
# role is only ever created for ip_monitoring_development on localhost:5433, the database
# .mcp.json connects to, and never on another server or on a local Postgres that other projects share.
module AgentRole
  SQL_PATH = Rails.root.join(".claude/db/agent_readonly_role.sql")
  LOCAL_HOSTS = [ nil, "", "localhost", "127.0.0.1", "::1" ].freeze
  PORT = 5433
  DATABASE = "ip_monitoring_development"

  def self.applicable?(env: Rails.env, db_config: ActiveRecord::Base.connection_db_config)
    env.development? && db_config.database == DATABASE &&
      LOCAL_HOSTS.include?(db_config.host) && db_config.configuration_hash[:port].to_i == PORT
  end

  # Idempotent: the SQL creates the role only if it is missing and resets its password and grants.
  def self.apply!(connection = ActiveRecord::Base.connection)
    connection.execute(SQL_PATH.read)
  end
end
