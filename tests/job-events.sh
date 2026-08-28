#!/usr/bin/env bash
# tests/job-events.sh — behavior tests for scripts/job-events.sh and
# bin/agent-job. No arguments. Exits non-zero if any case fails.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lib="$here/../scripts/job-events.sh"
wrapper="$here/../bin/agent-job"

work=$(mktemp -d)                      # created under the real TMPDIR
export TMPDIR="$work/tmp"; mkdir -p "$TMPDIR"   # isolate the event spool
spool="$TMPDIR/agent-events"
trap 'rm -rf "$work"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s: %s\n' "$1" "$2"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want [$3], got [$2]"; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "[$2] lacks [$3]";; esac; }

# Fixture: sources the library, exits as told.
cat > "$work/job.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
[ -n "\${MSG:-}" ] && AGENT_JOB_MSG="\$MSG"
exit \${RC:-0}
EOF

# Fixture: sources the library, then runs the inner fixture.
cat > "$work/outer.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
bash "$work/job.sh"
AGENT_JOB_MSG="outer done"
EOF

# Fixture: sources the library, sets a message, then dies by SIGPIPE.
cat > "$work/pipe.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
AGENT_JOB_MSG="died mid-pipe"
kill -s PIPE \$\$
echo unreachable > "$work/pipe-survived"
EOF
chmod +x "$work/job.sh" "$work/outer.sh" "$work/pipe.sh"

reset()  { rm -rf "$spool"; }
count()  { ls -1 "$spool"/*.event 2>/dev/null | wc -l | tr -d ' '; }
starts() { ls -1 "$spool"/*.started 2>/dev/null | wc -l | tr -d ' '; }
one()    { ls -1 "$spool"/*.event 2>/dev/null | head -1; }
field()  { sed -n "s/^$1=//p" "$(one)"; }

# 1. No host: nothing written.
reset; ( unset AGENT_SESSION_ID; "$work/job.sh" )
is "inert: no event without a host" "$(count)" "0"

# 2. With a host: exactly one event, correct session, default message.
reset; AGENT_SESSION_ID=a1b2c3 "$work/job.sh"
is  "event: exactly one file"        "$(count)" "1"
is  "event: session routed"          "$(field session)" "a1b2c3"
has "event: default msg names job"   "$(field msg)" "job.sh exited rc=0"

# 3. Timestamps present and ISO 8601 UTC.
case "$(field ts)"      in ????-??-??T??:??:??Z) ok "event: ts is ISO 8601 UTC";;      *) bad "event: ts is ISO 8601 UTC" "$(field ts)";; esac
case "$(field started)" in ????-??-??T??:??:??Z) ok "event: started is ISO 8601 UTC";; *) bad "event: started is ISO 8601 UTC" "$(field started)";; esac

# 4. Custom message wins, verbatim.
reset; AGENT_SESSION_ID=a1b2c3 MSG="build 912: REAL_FAIL https://ci/912" "$work/job.sh"
is "msg: AGENT_JOB_MSG used verbatim" "$(field msg)" "build 912: REAL_FAIL https://ci/912"

# 5. Non-zero exit: reported, and the status reaches the caller.
reset; AGENT_SESSION_ID=a1b2c3 RC=7 "$work/job.sh"; rc=$?
is  "exit: status reaches the caller" "$rc" "7"
has "exit: default msg carries rc"    "$(field msg)" "rc=7"

# 6. Token sanitization: only alphanumerics reach the event.
reset; AGENT_SESSION_ID='a1/b2 c3;$x' "$work/job.sh"
is "session: sanitized to alphanumerics" "$(field session)" "a1b2c3x"

# 7. Nesting: the outermost process reports, once.
reset; AGENT_SESSION_ID=a1b2c3 "$work/outer.sh"
is "nesting: exactly one event"    "$(count)" "1"
is "nesting: outer authored it"    "$(field msg)" "outer done"

# 8. Start record: present while the job runs, removed on exit.
cat > "$work/live.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
ls -1 "$spool"/*.started > "$work/during" 2>/dev/null || true
EOF
chmod +x "$work/live.sh"
reset; AGENT_SESSION_ID=a1b2c3 "$work/live.sh"
is "start record: present mid-run"   "$(wc -l < "$work/during" | tr -d ' ')" "1"
is "start record: removed on exit"   "$(starts)" "0"
is "start record: event still written" "$(count)" "1"

# 9. Start record fields, including the command line.
cat > "$work/fields.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
cp "\$(ls -1 "$spool"/*.started | head -1)" "$work/started-copy"
EOF
chmod +x "$work/fields.sh"
reset; AGENT_SESSION_ID=a1b2c3 "$work/fields.sh" --flag value
has "start record: session field" "$(cat "$work/started-copy")" "session=a1b2c3"
has "start record: cmd carries script and args" "$(cat "$work/started-copy")" "cmd=fields.sh --flag value"

# 10. SIGKILL: the start record survives and no event is written.
cat > "$work/kill9.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
sleep 5
EOF
chmod +x "$work/kill9.sh"
reset; AGENT_SESSION_ID=a1b2c3 "$work/kill9.sh" & k9=$!
sleep 0.5
kill -9 "$k9" 2>/dev/null; wait "$k9" 2>/dev/null
is "SIGKILL: no completion event"      "$(count)" "0"
is "SIGKILL: start record left behind" "$(starts)" "1"

# 11. Signal funnel: SIGPIPE death still reports, and the script stops there.
reset; AGENT_SESSION_ID=a1b2c3 "$work/pipe.sh"
is "funnel: SIGPIPE writes the event"  "$(count)" "1"
is "funnel: message set before death"  "$(field msg)" "died mid-pipe"
[ ! -e "$work/pipe-survived" ] && ok "funnel: script stopped at the signal" \
  || bad "funnel: script stopped at the signal" "ran past the kill"

# 12. Wrapper, no host: transparent, no event.
reset; ( unset AGENT_SESSION_ID; "$wrapper" bash -c 'exit 3' ); rc=$?
is "wrapper inert: status passes through" "$rc" "3"
is "wrapper inert: no event"              "$(count)" "0"

# 13. Wrapper: default report is the command line and rc; status propagates.
reset; AGENT_SESSION_ID=a1b2c3 "$wrapper" bash -c 'exit 3'; rc=$?
is  "wrapper: status reaches the caller" "$rc" "3"
is  "wrapper: exactly one event"         "$(count)" "1"
has "wrapper: default msg carries command and rc" "$(field msg)" "bash -c exit 3 exited rc=3"
is  "wrapper: start record removed"      "$(starts)" "0"

# 14. Wrapper: a plain command reports richly via $AGENT_JOB_MSG_FILE.
reset; AGENT_SESSION_ID=a1b2c3 "$wrapper" bash -c 'echo "deploy: OK https://x" > "$AGENT_JOB_MSG_FILE"'
is "wrapper: msg-file report used verbatim" "$(field msg)" "deploy: OK https://x"

# 15. Wrapper around a sourced script: one event, the script's message forwarded.
reset; AGENT_SESSION_ID=a1b2c3 MSG="verdict: SUCCESS" "$wrapper" "$work/job.sh"
is "wrapper+stanza: exactly one event"   "$(count)" "1"
is "wrapper+stanza: AGENT_JOB_MSG forwarded" "$(field msg)" "verdict: SUCCESS"

# 16. Wrapper nested under a participating script: transparent.
cat > "$work/top.sh" <<EOF
#!/usr/bin/env bash
. "$lib"
"$wrapper" bash "$work/job.sh"
AGENT_JOB_MSG="top done"
EOF
chmod +x "$work/top.sh"
reset; AGENT_SESSION_ID=a1b2c3 "$work/top.sh"
is "nested wrapper: exactly one event" "$(count)" "1"
is "nested wrapper: top authored it"   "$(field msg)" "top done"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
