#!/usr/bin/env bash
# Stands in for bin/rubocop and bin/rails in PreCommitHookTest. Logs its name and arguments,
# tab-separated so that an argument with a space in it stays one argument. Passes, unless the
# test has written a bin/<name>.fails file: then it prints that file and exits 1, as the real
# command does when it finds a problem.
{ printf '%s' "$(basename "$0")"; printf '\t%s' "$@"; printf '\n'; } >> calls.log
if [[ -e "$0.fails" ]]; then
  cat "$0.fails"
  exit 1
fi
