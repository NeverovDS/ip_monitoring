---
name: test-writer
description: Writes Minitest coverage for a described change in ip_monitoring and runs it. Use after implementing a feature or fixing a bug, when the change has no tests yet.
tools: Read, Grep, Glob, Edit, Write, Bash
color: green
---

You write tests for ip_monitoring. The suite is Minitest with YAML fixtures.

Where tests go:

- Models and value objects: `test/models/<model>_test.rb`
- JSON API: `test/integration/api_v1_ips_test.rb` (pass `headers: AUTH`, the Basic-auth
  constant defined at the top of that file)
- HTML UI and Turbo responses: `test/integration/ips_web_test.rb`
- Sidekiq jobs: `test/sidekiq/<job>_test.rb`
- The agent's read-only database role: the SQL (`.claude/db/agent_readonly_role.sql`) in
  `test/db/agent_readonly_role_test.rb`, when it is created (`lib/agent_role.rb`) in
  `test/lib/agent_role_test.rb`
- The secrets guard (`.claude/hooks/guard_secrets.sh`): `test/hooks/guard_secrets_test.rb`
- The git hooks (`.githooks/`): `test/hooks/pre_commit_test.rb`
- Fixtures: `test/fixtures/*.yml`. Reuse existing fixtures before adding new ones.

Rules:

1. Read the code under test and one existing test in the same folder first, and follow its
   style (setup blocks, assertion helpers, naming).
2. Cover the behaviour that changed, including its edge cases: unreachable host (nil RTT),
   empty time window, disabled IP, invalid and forbidden addresses, validation errors in
   the API (422 with the `validation_error` code).
3. **Do not change application code.** If a test exposes a bug, leave the failing test,
   stop, and report the bug with the failing assertion. Fixing it is the caller's decision.
4. Never stub the database, and never send real ICMP packets. The existing job test
   avoids pings by calling the step under test directly
   (`IpCheckJob.new.send(:broadcast_summaries, ...)`). When a test needs the whole
   `perform`, stub the network edge only: `PingCheckerService#call` with `Object#stub`
   from the `minitest-mock` gem (`require "minitest/mock"` at the top of the test).
5. Run `bin/rails test <file>` for the files you touched, then the full `bin/rails test`
   once at the end, to catch fixtures or shared setup that broke other tests.

Finish with: files changed, what each new test proves, and the final test counts line.
