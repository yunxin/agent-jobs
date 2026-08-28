# agent-jobs

A long-running job an AI coding agent launched, reporting its own completion
back to the terminal host. The agent can end its turn and hand the terminal
back to you; while the job runs the host shows that background work is live,
and when it finishes and the agent has been idle since, the host prompts the
agent to pick the result up. An agent its CLI already woke, or that is busy
with something else, gets no second report.

This is the script side of AgentTerm's
[`job-events.md`](https://github.com/albertwujj/agent-term/blob/main/job-events.md)
contract. Two ways in:

- **Wrap any command**: `bin/agent-job <command> [args...]` reports the
  command's completion with no changes to the command itself.
- **Source one file**: a bash script that sources `scripts/job-events.sh`
  reports its own completion and can author its report message.

Both are inert when no participating host is present. The script side is
host-agnostic: any host that watches the spool can consume it.

## Wrapping a command

```bash
agent-job npm run test:slow
agent-job scripts/watch-build.sh --url https://ci.example.com/job/912/
```

The default report is the command line and its exit code. A wrapped process
can say something richer by writing one line to `$AGENT_JOB_MSG_FILE`, which
the wrapper exports and reads at exit. A wrapped script that sources
`job-events.sh` needs nothing extra: its `AGENT_JOB_MSG` is forwarded to the
wrapper automatically, and exactly one event is reported.

This is the launch convention to give an agent: run long jobs under
`agent-job`, then end the turn. The agent knows a report will arrive once
the job finishes and it has been idle since.

## Sourcing the stanza

Source it early, with no arguments:

```bash
#!/usr/bin/env bash
set -euo pipefail
. /path/to/agent-jobs/scripts/job-events.sh

# ... the long-running work ...

AGENT_JOB_MSG="staging deploy: OK https://ci.example.com/build/912"
```

Source it with **no arguments**, so it sees the script's own positional
parameters.

`AGENT_JOB_MSG` can be set any time before exit, and the last value set is
what the agent reads, verbatim. Leave it unset and the event records the
script name and exit code.

Write the message for the agent that launched the job: what ran, how it came
out, one key link. Domain vocabulary lives in that line and nowhere else. The
host relays it without parsing it.

## What it does

| Mechanism | Effect |
|---|---|
| Writes a start record to `${TMPDIR:-/tmp}/agent-events/` at launch, removed on exit | Tells the host a job is live (it can show a background-jobs indicator, surviving a session resume). A record whose process died with no completion event earns the agent a "gone without a completion report" notice, covering the SIGKILL and OOM case where a result is never coming. |
| Writes one completion event file to the same spool on exit | The primary signal. The host delivers `msg` to the agent verbatim, at most once, and only to an agent that has been idle since the job finished; otherwise it consumes the event silently. The file is deleted either way. |
| Reads `AGENT_SESSION_ID` from the environment | The routing key, set by the host on the shell it spawns and inherited by every process in that window. A resumed session keeps its token, so a job started before the resume still reports to it. Unset means nothing is listening and the whole block is a no-op. |
| Exports `_AGENT_JOB_TOP` | Nested invocations stay silent, so a wrapper that reuses an inner script reports exactly once, from the outermost process. |

`HUP`, `INT`, `TERM`, `PIPE`, and `QUIT` funnel into the `EXIT` trap, so an
interrupted job still reports. Only SIGKILL-class deaths skip it, which is
what the start record covers.

## Opting out

Clear the token for a single invocation:

```bash
AGENT_SESSION_ID= ./long-job.sh
```

## Guarantees

None, deliberately. This is insurance underneath whatever re-engagement duty
an agent's runbook already imposes, and nothing may depend on it for
correctness. The contract covers the host's half: when a report is
delivered and when it is withheld, the "no completion report" notice, and
how events age out.

## Tests

```bash
tests/job-events.sh
```

Covers the inert path, the event drop and its fields, the start record's
lifecycle (present mid-run, removed on exit, left behind by SIGKILL),
session-token sanitization, a custom message, a non-zero exit, the signal
funnel, nesting silence, and the wrapper (default report, message file,
forwarding from a sourced script, nesting).

## License

MIT.
