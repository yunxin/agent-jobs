# shellcheck shell=bash
#
# job-events.sh — background-job observability for long-running scripts.
#
# Implements agent-term's job-events.md contract:
# https://github.com/albertwujj/agent-term/blob/main/job-events.md
#
# Source it early in a bash script, with no arguments (a sourced file with
# no arguments of its own sees the script's positional parameters):
#
#     . /path/to/agent-jobs/scripts/job-events.sh
#
# Inert without a host (AGENT_SESSION_ID unset). Nested invocations inherit
# _AGENT_JOB_TOP and stay silent, so the outermost process reports exactly
# once: a wrapper reports, the inner script it runs each cycle does not.
# Under bin/agent-job the wrapper is the reporter; a nested script's
# AGENT_JOB_MSG is forwarded to it through $AGENT_JOB_MSG_FILE on exit.
#
# While the job runs, a start record in the spool tells the host a job is
# live (it shows a background-jobs indicator, and a record whose process
# died with no completion event earns a "gone without a completion report"
# notice — the SIGKILL/OOM case). The EXIT trap removes the record and
# writes the completion event.
#
# Set AGENT_JOB_MSG any time before exiting for a self-describing completion
# event; the default records script name and exit code. Graceful and
# pipeline signals (HUP INT TERM PIPE QUIT) funnel into the EXIT trap; only
# SIGKILL-class deaths skip it — which the start record covers.

if [ -n "${AGENT_SESSION_ID:-}" ]; then
  if [ -z "${_AGENT_JOB_TOP:-}" ]; then
    _aj_sess=$(printf '%s' "$AGENT_SESSION_ID" | tr -cd 'A-Za-z0-9')
    export _AGENT_JOB_TOP=$$
    _aj_started=$(date -u +%FT%TZ)
    _aj_dir="${TMPDIR:-/tmp}/agent-events"
    _aj_start="$_aj_dir/$(date +%s).$$.started"
    { mkdir -p "$_aj_dir" && printf 'session=%s\nstarted=%s\ncmd=%s\n' \
        "$_aj_sess" "$_aj_started" "$(basename "$0")${*:+ $*}" \
        > "$_aj_start"; } 2>/dev/null || true
    AGENT_JOB_MSG=""
    _aj_event() {
      _aj_rc=$?
      mkdir -p "$_aj_dir" 2>/dev/null || return 0
      printf 'session=%s\nts=%s\nstarted=%s\nmsg=%s\n' \
        "$_aj_sess" "$(date -u +%FT%TZ)" "$_aj_started" \
        "${AGENT_JOB_MSG:-$(basename "$0") exited rc=$_aj_rc}" \
        > "$_aj_dir/$(date +%s).$$.event" 2>/dev/null || true
      rm -f "$_aj_start" 2>/dev/null || true
    }
    trap 'exit' HUP INT TERM PIPE QUIT   # funnel graceful signals into the EXIT trap
    trap _aj_event EXIT
  elif [ -n "${AGENT_JOB_MSG_FILE:-}" ]; then
    # Nested under bin/agent-job: the wrapper reports; forward this script's
    # message to it. Nested scripts exit innermost-first, so the outermost
    # script that sets AGENT_JOB_MSG writes last and wins.
    AGENT_JOB_MSG=""
    _aj_forward() {
      if [ -n "${AGENT_JOB_MSG:-}" ]; then
        printf '%s\n' "$AGENT_JOB_MSG" > "$AGENT_JOB_MSG_FILE" 2>/dev/null || true
      fi
    }
    trap _aj_forward EXIT
  fi
fi
