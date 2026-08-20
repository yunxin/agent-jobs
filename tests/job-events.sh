#!/usr/bin/env bash
# tests/job-events.sh — behavior tests for scripts/job-events.sh.
# No arguments. Exits non-zero if any case fails.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lib="$here/../scripts/job-events.sh"

work=$(mktemp -d)                      # created under the real TMPDIR
export TMPDIR="$work/tmp"; mkdir -p "$TMPDIR"   # isolate the event spool
spool="$TMPDIR/agent-events"
trap 'rm -rf "$work"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s: %s\n' "$1" "$2"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want [$3], got [$2]"; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "[$2] lacks [$3]";; esac; }

# Fixture: sources the library, records its own process name, exits as told.
cat > "$work/job.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
[ -n "\${MSG:-}" ] && AGENT_JOB_MSG="\$MSG"
ps -p \$\$ -o args= > "$work/argv0"
exit \${RC:-0}
EOF

# Fixture: sources the library, then runs the inner fixture.
cat > "$work/outer.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
bash "$work/job.sh"
AGENT_JOB_MSG="outer done"
EOF
chmod +x "$work/job.sh" "$work/outer.sh"

reset()  { rm -rf "$spool"; }
count()  { ls -1 "$spool"/*.event 2>/dev/null | wc -l | tr -d ' '; }
one()    { ls -1 "$spool"/*.event 2>/dev/null | head -1; }
field()  { sed -n "s/^$1=//p" "$(one)"; }

# 1. No host: nothing written, no relabel.
reset; ( unset AGENT_SESSION_ID; "$work/job.sh" )
is "inert: no event without a host" "$(count)" "0"
case "$(cat "$work/argv0")" in *'[sess:'*) bad "inert: process name untouched" "was relabeled";; *) ok "inert: process name untouched";; esac

# 2. With a host: exactly one event, correct session, default message, relabel.
reset; AGENT_SESSION_ID=a1b2c3 "$work/job.sh"
is  "event: exactly one file"        "$(count)" "1"
is  "event: session routed"          "$(field session)" "a1b2c3"
has "event: default msg names job"   "$(field msg)" "job.sh exited rc=0"
has "relabel: process name carries token" "$(cat "$work/argv0")" "[sess:a1b2c3]"

# 3. Timestamps present and ISO 8601 UTC.
case "$(field ts)"      in ????-??-??T??:??:??Z) ok "event: ts is ISO 8601 UTC";;      *) bad "event: ts is ISO 8601 UTC" "$(field ts)";; esac
case "$(field started)" in ????-??-??T??:??:??Z) ok "event: started is ISO 8601 UTC";; *) bad "event: started is ISO 8601 UTC" "$(field started)";; esac

# 4. Custom message wins, verbatim.
reset; AGENT_SESSION_ID=a1b2c3 MSG="build 912: REAL_FAIL https://ci/912" "$work/job.sh"
is "msg: AGENT_JOB_MSG used verbatim" "$(field msg)" "build 912: REAL_FAIL https://ci/912"

# 5. Non-zero exit: reported, and the status still reaches the caller.
reset; AGENT_SESSION_ID=a1b2c3 RC=7 "$work/job.sh"; rc=$?
is  "exit: status survives the re-exec" "$rc" "7"
has "exit: default msg carries rc"      "$(field msg)" "rc=7"

# 6. Token sanitization: only alphanumerics reach the event.
reset; AGENT_SESSION_ID='a1/b2 c3;$x' "$work/job.sh"
is "session: sanitized to alphanumerics" "$(field session)" "a1b2c3x"

# 7. Nesting: the outermost process reports, once.
reset; AGENT_SESSION_ID=a1b2c3 "$work/outer.sh"
is "nesting: exactly one event"    "$(count)" "1"
is "nesting: outer authored it"    "$(field msg)" "outer done"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
