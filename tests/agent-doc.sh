#!/usr/bin/env bash
# tests/agent-doc.sh — the script template in long-jobs.md works under the
# wrapper: extracted from the doc's fenced block and run. No arguments.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
wrapper="$here/../bin/agent-job"
doc="$here/../long-jobs.md"

work=$(mktemp -d)
export TMPDIR="$work/tmp"; mkdir -p "$TMPDIR"
spool="$TMPDIR/agent-events"
trap 'rm -rf "$work"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s: %s\n' "$1" "$2"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want [$3], got [$2]"; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "[$2] lacks [$3]";; esac; }
reset() { rm -rf "$spool"; }
count() { ls -1 "$spool"/*.event 2>/dev/null | wc -l | tr -d ' '; }
field() { sed -n "s/^$1=//p" "$(ls -1 "$spool"/*.event 2>/dev/null | head -1)"; }

# The template: the bash block that starts with the shebang.
awk '/^```bash$/{inb=1; next} /^```$/{if (inb && got) exit; inb=0; next} inb && /^#!\/usr\/bin\/env bash/{got=1} inb && got {print}' "$doc" > "$work/run-ci.sh"
chmod +x "$work/run-ci.sh"
has "the template was extracted" "$(head -1 "$work/run-ci.sh")" "#!/usr/bin/env bash"
bash -n "$work/run-ci.sh" && ok "and it parses" || bad "and it parses" "syntax error"

# 1. Bare: verdict line and exit code, no event.
reset; out=$( unset AGENT_SESSION_ID; "$work/run-ci.sh" true 2>/dev/null ); rc=$?
has "bare: PASS verdict" "$out" "VERDICT=PASS LOG="
is  "bare: exit 0"        "$rc" "0"
is  "bare: no event"      "$(count)" "0"

# 2. Under the wrapper, failing: exit 10, one event with rc and the log, output in the log.
reset; out=$( AGENT_SESSION_ID=a1b2c3 "$wrapper" "$work/run-ci.sh" bash -c 'echo boom; exit 3' 2>/dev/null ); rc=$?
is  "wrapped fail: exit 10"           "$rc" "10"
is  "wrapped fail: one event"         "$(count)" "1"
has "wrapped fail: report names rc"   "$(field msg)" "run-ci: FAIL rc=3 log="
log=$(printf '%s' "$out" | sed -n 's/^VERDICT=FAIL LOG=//p')
has "wrapped fail: the log has the output" "$(cat "$log")" "boom"

# 3. Under the wrapper, passing, with a chosen log.
reset; AGENT_SESSION_ID=a1b2c3 CI_LOG="$work/ci.log" "$wrapper" "$work/run-ci.sh" bash -c 'echo fine' >/dev/null 2>&1; rc=$?
is  "wrapped pass: exit 0"           "$rc" "0"
has "wrapped pass: the report"       "$(field msg)" "run-ci: PASS log=$work/ci.log"
has "wrapped pass: the log"          "$(cat "$work/ci.log")" "fine"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
