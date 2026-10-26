---
name: feature
description: Orchestrate a feature end to end in ip_monitoring - plan, human approval, implementation, tests, review, commit through the pre-commit hook. Invoke manually with /feature.
argument-hint: "[feature description]"
disable-model-invocation: true
---

Feature request: $ARGUMENTS

Run this as an orchestrated workflow. Each phase has an exit condition; do not skip ahead.

## 0. State
Keep the state of this feature in `tmp/feature/<branch>.md` (git-ignored): the approved
plan as a checklist, decisions and why, what is done, the next step. Update it at the end
of every phase. If the file already exists, read it first and continue from the next step
instead of starting over.

## 1. Branch
Never work on `main` (it deploys to production). If the current branch is `main`, create
`feature/<short-slug>` from it. For work that runs in parallel with other work, use a
Claude Code worktree (`claude --worktree <slug>`, or ask to work in a worktree): it lives
under `.claude/worktrees/` and starts from the current commit. Do not use
`git worktree add ../…`: outside the repository the project's permission rules do not
reach it. Worktrees share the test databases, so never run tests or commit in two of them
at the same time.

## 2. Plan, then stop for approval
Read the relevant code and CLAUDE.md. Write a plan with: files to change, the approach,
tests to add, schema or API contract impact, and risks. Then **stop and ask the human to
approve or adjust the plan.** Make no edits before the approval.

## 3. Implement
Implement the approved plan in small steps. Run only the test files you touch while you
work; RuboCop and the full suite run once, at the commit in step 6. For a new `/api/v1`
endpoint, follow `/add-api-endpoint`.

## 4. Tests (subagent)
Delegate to the `test-writer` subagent with a precise description of the behaviour that
changed. If it reports a bug in the application code, fix the code (not the test) and
re-run it.

## 5. Review loop (subagent)
Ask the `code-reviewer` subagent to review the diff. Fix every blocker and major finding,
then review again. **At most two review rounds.** Anything still open after the second
round goes into the summary instead of a third round.

## 6. Commit (git hooks)
Commit on the feature branch with a message in the style of `git log`. The pre-commit
hook runs RuboCop on the staged files and the full suite; if it refuses the commit, fix
the cause and commit again. Never skip the hook.

## When stuck
Three failed attempts at the same problem, a denied tool call, or an unclear requirement:
stop, write what you tried and what you need into the state file, and ask the human.
Never work around a denied action.

## 7. Done and hand-off
Done means: the commit passed the hooks, no blocker or major finding is left, every plan
item is checked off. Report what changed and why, the tests added, the open reviewer
findings, how each part was verified, and the commit hash; the same text is the pull
request description. **Push or open a PR only when the human asks for it.**
