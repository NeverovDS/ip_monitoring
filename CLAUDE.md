# ip_monitoring — guide for coding agents

IPv4 availability monitor. A Sidekiq-cron job pings every enabled host once a minute,
stores the round-trip time, and pushes the result to a live Hotwire dashboard. Same data
is exposed as a JSON API. Production runs on AWS (EC2 + RDS + ECR) and is deployed by
GitHub Actions on every push to `main`.

## Commands

```sh
docker compose up -d db       # Postgres on :5433, all the tests need
docker compose up -d redis    # Redis for development and Sidekiq, unless one already runs on 6379
bin/setup --skip-server       # gems, database, agent DB role, git hooks; warns if jq is missing
bin/rails db:test:prepare test # full suite, a few seconds
bin/rubocop                   # rubocop-rails-omakase; `bin/rubocop -a` autocorrects
bin/brakeman --no-pager       # security scan, also runs in CI
```

## Where things are

| Concern | Location |
|---|---|
| Domain models | `app/models/ip.rb`, `ip_check.rb`, `ip_status_change.rb`, `time_range.rb` |
| Ping logic (thread pool, no Rails deps) | `app/services/ping_checker_service.rb` |
| Stats orchestration | `app/services/ip_stats_service.rb`; the SQL lives in `IpCheck.rtt_stats` |
| Background work | `app/sidekiq/ip_check_worker.rb` (cron, batches) → `ip_check_job.rb` (ping, bulk insert, broadcast) |
| JSON API | `app/controllers/api/v1/*`, serializers in `app/serializers/` |
| HTML UI | `app/controllers/ips_controller.rb`, `app/views/ips/*`, Stimulus in `app/javascript/controllers/` |
| Schema | `db/structure.sql` (NOT `schema.rb`) |
| Deploy | `config/deploy.yml` (Kamal), `.github/workflows/ci.yml` |

## Conventions

- **API contract is frozen.** It was carried over from the original Roda app. Params are
  top-level (`params.permit(:ip_address, :enabled)`), not nested under `:ip`. Responses go
  through a `BaseSerializer` subclass; errors go through `render_error` in
  `Api::V1::BaseController`, which wraps `ErrorSerializer`. Never render ad-hoc hashes for errors.
- **Business logic stays out of controllers.** Queries belong in model scopes or class
  methods (`IpCheck.in_window`, `IpCheck.rtt_stats`); orchestration belongs in `app/services`.
- **Schema changes are SQL-aware.** A trigger (`ip_status_change_trigger`) writes
  `ip_status_changes`, so the schema is dumped as `db/structure.sql`. After a migration,
  commit the regenerated `structure.sql`. `ip_status_changes` is append-only history.
- **IPv4 only.** `Ip` validates the RAW input (`ip_address_before_type_cast`) because the
  `inet` column silently casts garbage to nil. Forbidden ranges (RFC1918, loopback,
  link-local incl. the cloud metadata endpoint) must stay rejected.
- **Background jobs are bulk and idempotent-friendly.** `IpCheckJob` inserts with
  `insert_all`; do not introduce per-row `create` calls in the hot path.
- **Broadcasts run inside Sidekiq**, so Action Cable must use the Redis adapter.
- Style is rubocop-rails-omakase (`[ a, b ]` with spaces inside array brackets).
- Comments explain WHY a non-obvious choice was made, as in the existing code.

## Tests

Minitest with fixtures (`test/fixtures/*.yml`). Models in `test/models`, the API in
`test/integration/api_v1_ips_test.rb`, the HTML UI in `test/integration/ips_web_test.rb`,
jobs in `test/sidekiq`. The agent setup has tests too: the database role in `test/db` (its
SQL) and `test/lib` (when it is created), the secrets guard and the git hooks in `test/hooks`
(the guard tests need `jq`). Every behaviour change needs a test. Fix the code, not the
test, when a test fails for a real reason.

While working, run only the test files you touched (`bin/rails test test/models/ip_test.rb`).
RuboCop and the full suite run once, when you commit (the git pre-commit hook).

## Hard constraints

- **`main` deploys to production on push.** Work on a feature branch; changes reach `main`
  only through a pull request with green CI. The git hooks refuse commits on `main`.
- **Push, open PRs, deploy or touch AWS only when the human asks for it.** These commands
  always show the human a permission prompt.
- **Never skip the git hooks or change git settings** (`--no-verify`, `git config`,
  `git -c`). CI runs the same checks on every pull request anyway.
- **Never read or print secrets:** `.env.deploy`, `config/master.key`, decrypted
  credentials, `~/.ssh`, `~/.aws`. Do not look for ways around the protections, unless the
  human asks for a security review; then use probes that print nothing secret even if a
  protection fails.
- Commit messages: short imperative or `feat:`/`fix:` prefix, as in `git log`. No tool
  attribution lines.

## Working on a task

Use `/feature` for anything bigger than a one-line fix. It plans, waits for the human's
approval, implements, gets tests from `test-writer`, a review from `code-reviewer`, and
commits through the git hooks.

- **Keep state in `tmp/feature/<branch>.md`** (git-ignored): the approved plan, decisions,
  what is done, the next step. Update it after every phase. In a new session, read it first
  and continue from the next step.
- **When you are stuck, stop.** Stuck means: three attempts at the same problem failed, a
  tool call was denied, or the requirement is unclear. Write what you tried into the state
  file and ask the human. Never work around a denied action.
- **Done means:** the commit passed the hooks, `code-reviewer` has no blocker or major
  finding left, every item of the plan is checked off, and the summary says how each part
  was verified.

How the agent setup works and why: [docs/ai-agent-setup.md](docs/ai-agent-setup.md).
