-- Read-only Postgres role for the coding agent's MCP server (development database only).
--
-- Why a role and not a server flag: the MCP server exposes `execute_sql`, which would
-- happily run DELETE or DROP. The SELECT-only grants make writes to the app's tables fail
-- in Postgres itself, whatever MCP server is plugged in and whatever the model sends.
-- The two role settings below are defaults on top, not the guard: a session can SET them.
--
-- `bin/rails agent:role` applies this (bin/setup runs it), only for the local development
-- database on :5433; see lib/agent_role.rb. Idempotent. The grants live inside the database,
-- so run it again after db:reset or db:drop. To apply by hand:
--   docker compose exec -T db psql -U postgres -d ip_monitoring_development < .claude/db/agent_readonly_role.sql

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ipmon_agent_ro') THEN
    CREATE ROLE ipmon_agent_ro;
  END IF;
  -- Every run, so a password the role changed for itself is put back.
  ALTER ROLE ipmon_agent_ro LOGIN PASSWORD 'agent_ro_dev_only';
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO ipmon_agent_ro', current_database());
  -- Tables that later migrations create (as the current user) become readable automatically.
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT ON TABLES TO ipmon_agent_ro', current_user);
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT ON SEQUENCES TO ipmon_agent_ro', current_user);
END
$$;

-- Read-only transactions unless the session asks otherwise; no query runs past five seconds.
ALTER ROLE ipmon_agent_ro SET default_transaction_read_only = on;
ALTER ROLE ipmon_agent_ro SET statement_timeout = '5s';

GRANT USAGE ON SCHEMA public TO ipmon_agent_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ipmon_agent_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ipmon_agent_ro;

-- Statistics views (active queries, locks) that the MCP server's monitoring tools read.
GRANT pg_read_all_stats TO ipmon_agent_ro;
