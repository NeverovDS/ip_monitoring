#!/usr/bin/env bash
# PreToolUse hook (Bash|Read|Edit|Write|Grep|Glob): a tripwire for the direct ways of reading
# or printing a real secret. The Read deny rules in settings.json already stop the built-in
# file tools and Bash file commands such as `cat .env.deploy`; this hook adds what they miss,
# like `bin/rails credentials:show`, `git show HEAD:.env.deploy` or a Grep/Glob aimed at the
# key files. It matches text, so a glob (`cat .env.d*`) or a command that never names the
# file (`grep -r PASSWORD .`) gets through: blocking those needs the Claude Code sandbox.
# .env.deploy.example and .kamal/secrets are fine: they hold names and references only.
set -uo pipefail

# Fail closed: exit 2 blocks the tool call, any other non-zero exit would let it run.
command -v jq >/dev/null 2>&1 || { echo "guard_secrets.sh: jq is not installed, refusing every tool call." >&2; exit 2; }

input=$(cat)
# Only the arguments that decide WHAT is touched: the shell command and the target paths
# (for Glob that is its pattern). File contents (Edit new_string, Write content) are
# ignored, so docs that merely mention master.key, like CLAUDE.md or ci.yml, can be edited.
if ! args=$(jq -r '.tool_name as $tool | .tool_input
    | [.command, .file_path, .path, .glob, (if $tool == "Glob" then .pattern else null end)]
    | map(select(. != null)) | join("\n")' <<<"$input" 2>&1); then
  echo "guard_secrets.sh: could not read the tool input ($args), refusing the tool call." >&2
  exit 2
fi
# The disk is case-insensitive, so .ENV.deploy is the same file. Then mask the harmless
# template so it cannot trigger the .env.deploy rule.
haystack=$(tr '[:upper:]' '[:lower:]' <<<"$args")
haystack=${haystack//.env.deploy.example/}

reason=""
case "$haystack" in
  *.env.deploy*) reason=".env.deploy holds the production passwords" ;;
  *master.key*) reason="config/master.key decrypts the Rails credentials" ;;
  *credentials/*.key*) reason="per-environment credential keys are secrets" ;;
  *credentials:show* | *credentials:edit*) reason="decrypting Rails credentials prints secrets" ;;
  */.ssh* | */.aws*) reason="~/.ssh and ~/.aws hold the deploy key and the AWS credentials" ;;
esac

[[ -n "$reason" ]] || exit 0

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("Blocked by .claude/hooks/guard_secrets.sh: \($r). Ask the human if this is really needed.")
  }
}'
