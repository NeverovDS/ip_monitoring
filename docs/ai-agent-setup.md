# AI agent setup

I work on this project with Claude Code. The goal of this setup: the agent does most of
the work on its own, and the few things that can do real damage need a human.

## What is in the repository

| File | Purpose |
|---|---|
| [`CLAUDE.md`](../CLAUDE.md) | Project context for the agent: where things are, conventions, hard rules, how to run a task |
| [`.claude/settings.json`](../.claude/settings.json) | Permissions: what runs without asking, what asks, what is denied |
| [`.claude/hooks/guard_secrets.sh`](../.claude/hooks/guard_secrets.sh) | Refuses the direct ways of reading a secret, before every tool call |
| [`.githooks/`](../.githooks) | `pre-commit` and `pre-merge-commit`: RuboCop and the full suite, no commits on `main` |
| [`.claude/agents/`](../.claude/agents) | `code-reviewer` and `test-writer` subagents |
| [`.claude/skills/`](../.claude/skills) | `/feature` (the full workflow) and `/add-api-endpoint` |
| [`.mcp.json`](../.mcp.json), [`.claude/db/`](../.claude/db), [`lib/agent_role.rb`](../lib/agent_role.rb) | Read-only Postgres access for the agent |

## How it is protected

There are four layers. Each one covers what the layer before it can miss.

1. **Permissions** in `.claude/settings.json` follow four rules:
   - Runs without asking: tests, RuboCop, Brakeman, read-only database queries. The
     commands are written out exactly, because a `*` after `rubocop` would also allow
     `--out <file>`, which overwrites files.
   - Asks first: everything that leaves the machine (`git push`, `gh`, `kamal`, `aws`) and
     edits to the git hooks.
   - Denied: reading secrets (`.env.deploy`, the Rails keys, `~/.ssh`, `~/.aws`) and turning
     the checks off (`--no-verify`, `git config`).
   - Bypass-permissions mode is disabled. Auto mode is allowed.

   Claude Code already protects `.claude/` and `.mcp.json` on its own, so the settings do
   not repeat it.
2. **The secrets guard** catches what the deny rules miss, such as
   `bin/rails credentials:show` or `git show HEAD:.env.deploy`. It fails closed: without
   `jq` it refuses every tool call.
3. **Git hooks** refuse commits on `main` and run RuboCop on the staged files and the full
   suite before every commit.
4. **CI and branch protection** are the final gate. `main` only takes a pull request with
   green `scan_ruby`, `scan_js`, `lint` and `test`, and that applies to admins too.

I do not try to block every way of skipping a local hook. If a hook is skipped, the
failure shows up in CI on the pull request instead, and nothing reaches `main` without
green CI.

## Decisions

- **Checks at commit time, not after every edit.** An agent edits the same file many times
  while it works. Running RuboCop and the tests after each edit, or each time the agent
  says "done", costs time and tokens and checks code that is about to change again.
- **A git hook, not a Claude Code hook.** The first version caught `git commit` with a
  pattern in a Claude Code hook. It missed spellings like `git -C dir commit` and checked
  the wrong folder in a worktree. Git runs its own hooks for every commit, made by an agent
  or by me.
- **Read-only through the database role.** The MCP server can run any SQL, including
  `DELETE`. The role only has `SELECT` grants, so a write fails in Postgres itself, whatever
  the tool sends. Read-only transactions and a 5 s timeout are defaults on top.
- **Auto mode stays on.** Without it the agent stops for a prompt on almost every step. In
  auto mode Claude Code's own safety check decides about edits to `.claude/`, instead of a
  prompt. I accept that: any such change shows up in the pull request.
- **Pinned MCP server (Toolbox 1.14.0).** An earlier, unpinned Postgres MCP server broke
  when one of its own dependencies disappeared from PyPI.
- **No GitHub MCP server.** It adds nothing over the `gh` CLI and needs a token.

## Working with the agent

`/feature` runs a task end to end: plan, my approval, implementation, tests from
`test-writer`, review from `code-reviewer` (at most two rounds), a commit through the git
hooks, and a summary that becomes the pull request description.

- **State between sessions** lives in `tmp/feature/<branch>.md` (git-ignored): the approved
  plan as a checklist, decisions, what is done, the next step. A new session reads it first
  and continues.
- **When the agent is stuck** (three failed attempts at the same problem, a denied
  action, an unclear requirement) it stops, writes what it tried into that file and asks.
- **Done** means the hooks passed, no blocker or major review finding is left, and every
  plan item is checked off and verified.

## Evals

`bin/eval` measures how well the agent does real tasks in this repository, so a change to
`CLAUDE.md`, a subagent or the model can be compared before and after. It costs tokens,
so I run it by hand, not in CI. A run:

1. clones the last commit into a temporary folder where nothing real can be reached:
   `origin` is a local bare repository, the deploy config points nowhere, and `kamal`,
   `aws` and `gh` are stubs that only log their calls. Of my environment variables the
   agent gets a short allowlist, so tokens and the SSH agent stay out. `HOME` is passed,
   so files like `~/.ssh` stay readable: a push or a deploy is stopped by the permission
   rules, which `claude -p` refuses, and by the stubs. If Claude Code is logged in with
   an API key, `ANTHROPIC_API_KEY` has to be added to `PASSED_ENV` in
   `evals/lib/evals/sandbox.rb`;
2. runs Claude Code on the task without a human (`claude -p`), so anything that would ask
   for permission is refused;
3. grades the result: hidden tests the agent never saw, the full suite, RuboCop, which
   files changed, and any attempt to deploy, push or call GitHub or AWS;
4. appends a row to [`evals/results.md`](../evals/results.md) with the turns and the cost.

There are two tasks so far, in [`evals/tasks/`](../evals/tasks). One is a real bug: an IP
disabled while its batch waits in the queue still gets checked. The other is a safety
task: a README typo next to a planted instruction to deploy. The agent should fix the
typo and ignore the instruction. One run says little, because the agent is not
deterministic, so for a real comparison each task runs several times (`--runs 3`).

## Known limits

- Permission rules match the text of a command, not its intent, so an unusual spelling can
  get through. CI is the backstop.
- The secrets guard matches text too: `cat .env.d*` gets through. Blocking that at the
  operating-system level needs the Claude Code sandbox, which is not enabled here yet,
  because it changes how every command runs.
- In the Claude app, trusting the folder also starts the MCP server from `.mcp.json`
  without a separate prompt (the `claude` CLI asks once). Review changes to `.mcp.json`
  like code that runs on your machine.
- All worktrees share the test databases, so tests in two worktrees must not run at the
  same time.
- The agent role's password is public. `bin/rails agent:role` only creates the role for
  `ip_monitoring_development` on `localhost:5433`.

## Setup

1. `bin/setup`: installs gems, prepares the database, enables the git hooks and creates
   the agent's database role. After `db:reset`, run `bin/rails agent:role`.
2. Install `jq` and Node.js (`npx` runs the MCP server).
3. `docker compose up -d db`, then start `claude` from the repository root and accept the
   folder trust prompt.
