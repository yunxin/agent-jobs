# shellcheck shell=bash
#
# job-events.sh — background-job observability for long-running scripts.
#
# Implements agent-term's job-events.md contract:
# https://github.com/albertwujj/agent-term/blob/main/job-events.md
#
# Source it early in a bash script, with no arguments, BEFORE any `cd`: the
# relabel re-exec resolves $0 against the original working directory, and a
# sourced file with no arguments of its own sees the script's positional
# parameters.
#
#     . /path/to/agent-jobs/scripts/job-events.sh
#
# Inert without a host (AGENT_SESSION_ID unset). Nested invocations inherit
# _AGENT_JOB_TOP and stay silent, so the outermost process reports exactly
# once: a wrapper reports, the inner script it runs each cycle does not.
#
# Set AGENT_JOB_MSG any time before exiting for a self-describing completion
# event; the default records script name and exit code. Graceful signals
# funnel into the EXIT trap. Only SIGKILL-class deaths skip it, which is what
# the host's label watching covers.

if [ -n "${AGENT_SESSION_ID:-}" ] && [ -z "${_AGENT_JOB_TOP:-}" ]; then
  _aj_sess=$(printf '%s' "$AGENT_SESSION_ID" | tr -cd 'A-Za-z0-9')
  if [ -z "${_AGENT_JOB_RELABEL:-}" ]; then
    # Opt into liveness watching: surface the session token in argv[0].
    _AGENT_JOB_RELABEL=1 exec -a "$(basename "$0")[sess:$_aj_sess]" bash "$0" "$@"
  fi
  export _AGENT_JOB_TOP=$$
  _aj_started=$(date -u +%FT%TZ)
  AGENT_JOB_MSG=""
  _aj_event() {
    _aj_rc=$?
    _aj_dir="${TMPDIR:-/tmp}/agent-events"
    mkdir -p "$_aj_dir" 2>/dev/null || return 0
    printf 'session=%s\nts=%s\nstarted=%s\nmsg=%s\n' \
      "$_aj_sess" "$(date -u +%FT%TZ)" "$_aj_started" \
      "${AGENT_JOB_MSG:-$(basename "$0") exited rc=$_aj_rc}" \
      > "$_aj_dir/$(date +%s).$$.event" 2>/dev/null || true
  }
  trap 'exit' HUP INT TERM   # funnel graceful signals into the EXIT trap
  trap _aj_event EXIT
fi
