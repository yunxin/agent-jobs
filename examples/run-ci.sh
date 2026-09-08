#!/usr/bin/env bash
# examples/run-ci.sh — run the project's CI command as a self-reporting job.
#
# A worked example of the stanza in use. The run's output goes to a log,
# one verdict line goes to stdout, the exit code mirrors the verdict, and
# AGENT_JOB_MSG is set at every exit path through one emit(), so the report
# the agent gets names the outcome and where to read the details. The verb
# doc beside this file, run-ci.md, is what the agent follows to launch it.
#
# Usage: run-ci.sh [command...]
#   The command to run: the arguments, else $CI_COMMAND (run through bash),
#   else `npm test`.
#   CI_LOG   where the run's output goes (default: a file under $TMPDIR)
#
# Verdict  exit  meaning
#   PASS     0   the command exited 0
#   FAIL    10   it exited non-zero; the log has the details
#   (usage 2)
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Report to the terminal host that launched this, if one did. Sourced with
# no arguments, so it sees this script's own. Inert without a host, and
# silent under bin/agent-job, which then reports for it.
# shellcheck source=/dev/null
. "$here/../scripts/job-events.sh"

if [ $# -gt 0 ]; then
  cmd=("$@")
elif [ -n "${CI_COMMAND:-}" ]; then
  cmd=(bash -c "$CI_COMMAND")
else
  cmd=(npm test)
fi
CI_LOG="${CI_LOG:-$(mktemp "${TMPDIR:-/tmp}/run-ci.XXXXXX")}"

# The one exit: the verdict line for a caller, the same words for the agent.
emit() {
  local verdict="$1" code="$2" detail="${3:-}"
  printf 'VERDICT=%s LOG=%s\n' "$verdict" "$CI_LOG"
  # shellcheck disable=SC2034  # read by job-events.sh's EXIT trap
  AGENT_JOB_MSG="run-ci: $verdict${detail:+ $detail} log=$CI_LOG"
  exit "$code"
}

{ printf '[%s] run-ci: %s\n' "$(date -u +%FT%TZ)" "${cmd[*]}"; } | tee "$CI_LOG" >&2
"${cmd[@]}" >> "$CI_LOG" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then emit PASS 0; else emit FAIL 10 "rc=$rc"; fi
