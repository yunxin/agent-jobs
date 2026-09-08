# How the reporting works

`bin/agent-job` runs one command as a self-reporting job, and
`scripts/job-events.sh` does the same for a script that sources it. Both
speak the host's side of AgentTerm's
[`job-events.md`](https://github.com/albertwujj/agent-term/blob/main/docs/dev/job-events.md)
contract. Both are inert without a host, and host-agnostic: any host that
watches the spool can consume the records.

## The wrapper

```bash
agent-job npm run test:slow
agent-job bash -c 'make check && v=PASS || v=FAIL; echo "make check: $v" > "$AGENT_JOB_MSG_FILE"'
```

The default report is the command line and its exit code. A command says
something richer by writing one line to `$AGENT_JOB_MSG_FILE`, which the
wrapper exports and reads at exit. Write that line for the agent that
launched the job: what ran, how it came out, one key link. The host relays
it without parsing it.

## A script that reports on its own

A bash script that must report even when someone runs it without the
wrapper sources `job-events.sh` early, with no arguments, so it sees the
script's own positional parameters:

```bash
#!/usr/bin/env bash
set -euo pipefail
. /path/to/agent-jobs/scripts/job-events.sh

# ... the long-running work ...

AGENT_JOB_MSG="staging deploy: OK https://ci.example.com/build/912"
```

`AGENT_JOB_MSG` can be set any time before exit, and the last value set is
what the agent reads, verbatim; unset, the event records the script name
and exit code. Under the wrapper such a script needs nothing extra: its
message is forwarded, and exactly one event is reported.

## What is written where

| Mechanism | Effect |
|---|---|
| A start record in `${TMPDIR:-/tmp}/agent-events/` at launch, removed on exit | Tells the host a job is live, so it can show a running-jobs indicator that survives a session resume. A record whose process died with no completion event earns the agent a "gone without a completion report" notice, covering the SIGKILL and OOM case where a result is never coming. |
| One completion event file in the same spool on exit | The primary signal. The host delivers `msg` to the agent verbatim, at most once, and only to an agent that has been idle since the job finished; otherwise it consumes the event silently. The file is deleted either way. |
| `AGENT_SESSION_ID`, read from the environment | The routing key, set by the host on the shell it spawns and inherited by every process in that window. A resumed session keeps its token, so a job started before the resume still reports to it. Unset means nothing is listening and the whole block is a no-op. |
| `_AGENT_JOB_TOP`, exported | Nested invocations stay silent, so a wrapper that reuses an inner script reports exactly once, from the outermost process. |

`HUP`, `INT`, `TERM`, `PIPE`, and `QUIT` funnel into the `EXIT` trap, so an
interrupted job still reports. Only SIGKILL-class deaths skip it, which is
what the start record covers.

## Opting out

Clear the token for one invocation:

```bash
AGENT_SESSION_ID= ./long-job.sh
```

## Guarantees

None, deliberately. This is insurance underneath whatever re-engagement
duty an agent's runbook already imposes, and nothing may depend on it for
correctness. The contract covers the host's half: when a report is
delivered and when it is withheld, the "no completion report" notice, and
how events age out.

## Tests

`tests/job-events.sh` covers the inert path, the event drop and its fields,
the start record's lifecycle (present mid-run, removed on exit, left behind
by SIGKILL), session-token sanitization, a custom message, a non-zero exit,
the signal funnel, nesting silence, and the wrapper (default report,
message file, forwarding from a sourced script, nesting).
`tests/agent-doc.sh` runs the script template in `long-jobs.md` under the
wrapper.
