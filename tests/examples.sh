#!/usr/bin/env bash
# tests/examples.sh — behavior tests for examples/run-ci.sh. No arguments.
# Exits non-zero if any case fails.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../examples/run-ci.sh"
wrapper="$here/../bin/agent-job"

work=$(mktemp -d)
export TMPDIR="$work/tmp"; mkdir -p "$TMPDIR"   # isolate the event spool and the logs
spool="$TMPDIR/agent-events"
trap 'rm -rf "$work"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s: %s\n' "$1" "$2"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want [$3], got [$2]"; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "[$2] lacks [$3]";; esac; }

reset() { rm -rf "$spool"; }
count() { ls -1 "$spool"/*.event 2>/dev/null | wc -l | tr -d ' '; }
one()   { ls -1 "$spool"/*.event 2>/dev/null | head -1; }
field() { sed -n "s/^$1=//p" "$(one)"; }

# 1. No host: the verdict line and exit code, no event.
reset; out=$( unset AGENT_SESSION_ID; "$script" true 2>/dev/null ); rc=$?
has "no host: verdict line"   "$out" "VERDICT=PASS LOG="
is  "no host: exit 0 on pass" "$rc" "0"
is  "no host: no event"       "$(count)" "0"

# 2. A failing command under a host: FAIL, exit 10, one event naming rc and the log.
reset; out=$( AGENT_SESSION_ID=a1b2c3 "$script" bash -c 'echo boom; exit 3' 2>/dev/null ); rc=$?
has "fail: verdict line"       "$out" "VERDICT=FAIL LOG="
is  "fail: exit 10"            "$rc" "10"
is  "fail: one event"          "$(count)" "1"
has "fail: message names rc"   "$(field msg)" "run-ci: FAIL rc=3 log="
log=$(printf '%s' "$out" | sed -n 's/^VERDICT=FAIL LOG=//p')
has "fail: the log has the output" "$(cat "$log")" "boom"

# 3. CI_COMMAND when no arguments are given.
reset; out=$( AGENT_SESSION_ID=a1b2c3 CI_COMMAND='exit 0' "$script" 2>/dev/null ); rc=$?
is  "CI_COMMAND: exit 0"      "$rc" "0"
has "CI_COMMAND: PASS report" "$(field msg)" "run-ci: PASS log="

# 4. Under the wrapper: one event, the script's message forwarded.
reset; AGENT_SESSION_ID=a1b2c3 "$wrapper" "$script" true >/dev/null 2>&1
is  "wrapped: exactly one event"     "$(count)" "1"
has "wrapped: the script's message"  "$(field msg)" "run-ci: PASS log="

# 5. A chosen log path is used.
reset; AGENT_SESSION_ID=a1b2c3 CI_LOG="$work/ci.log" "$script" bash -c 'echo hello' >/dev/null 2>&1
has "CI_LOG: output lands there" "$(cat "$work/ci.log")" "hello"
has "CI_LOG: the report names it" "$(field msg)" "log=$work/ci.log"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
