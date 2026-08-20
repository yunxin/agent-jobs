# agent-jobs

A long-running job an AI coding agent launched, reporting its own completion
back to the terminal host. The agent can end its turn and hand the terminal
back to you; when the job finishes, the host prompts the agent to pick the
result up. Mainly for CLIs that don't wake themselves.

This is the script side of AgentTerm's
[`job-events.md`](https://github.com/albertwujj/agent-term/blob/main/job-events.md)
contract. Source one file in a bash script and it labels its own process,
drops a completion event on exit, and stays inert when no participating host
is present.

The script side is host-agnostic: any host that watches the event spool and
the session's process list can consume it.

## Setup

Source it early, before any `cd`:

```bash
#!/usr/bin/env bash
set -euo pipefail
. /path/to/agent-jobs/scripts/job-events.sh

# ... the long-running work ...

AGENT_JOB_MSG="staging deploy: OK https://ci.example.com/build/912"
```

Position matters twice. Source it **before any `cd`**, because the relabel
re-exec resolves `$0` against the original working directory. Source it with
**no arguments**, so it sees the script's own positional parameters.

`AGENT_JOB_MSG` can be set any time before exit, and the last value set is
what the agent reads, verbatim. Leave it unset and the event records the
script name and exit code.

Write the message for the agent that launched the job: what ran, how it came
out, one key link. Domain vocabulary lives in that line and nowhere else. The
host relays it without parsing it.

## What it does

| Mechanism | Effect |
|---|---|
| Relabels `argv[0]` to `script.sh[sess:<token>]` | Opts into liveness watching. A labeled process that dies with no event earns the agent a "gone without a completion report" notice, covering the SIGKILL and OOM case where a result is never coming. |
| Writes one event file to `${TMPDIR:-/tmp}/agent-events/` on exit | The primary signal. The host delivers `msg` to the agent verbatim, exactly once, then deletes the file. |
| Reads `AGENT_SESSION_ID` from the environment | The routing key, set by the host on the shell it spawns, and inherited by every process in that window. Unset means nothing is listening and the whole block is a no-op. |
| Exports `_AGENT_JOB_TOP` | Nested invocations stay silent, so a wrapper that reuses an inner script reports exactly once, from the outermost process. |

`HUP`, `INT`, and `TERM` funnel into the `EXIT` trap, so an interrupted job
still reports. Only SIGKILL-class deaths skip it, which is what the label
covers.

## Opting out

Clear the token for a single invocation:

```bash
AGENT_SESSION_ID= ./long-job.sh
```

## Guarantees

None, deliberately. This is insurance underneath whatever re-engagement duty
an agent's runbook already imposes, and nothing may depend on it for
correctness. The contract covers the host's half: delivery timing, the
"no completion report" notice, and how events age out.

## Tests

```bash
tests/job-events.sh
```

Covers the inert path, the event drop and its fields, session-token
sanitization, a custom message, a non-zero exit, and nesting silence.

## License

MIT.
