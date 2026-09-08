# agent-jobs

A long-running job an AI coding agent launched, reporting its own completion
back to the terminal host. The agent can end its turn and hand the terminal
back to you; while the job runs the host shows that background work is live,
and when it finishes and the agent has been idle since, the host prompts the
agent to pick the result up. An agent its CLI already woke, or that is busy
with something else, gets no second report.

This is the script side of AgentTerm's
[`job-events.md`](https://github.com/albertwujj/agent-term/blob/main/docs/dev/job-events.md)
contract. It is inert when no participating host is present, and
host-agnostic: any host that watches the spool can consume it.

## The wrapper

`bin/agent-job` runs one command as a self-reporting job:

```bash
agent-job npm run test:slow
agent-job scripts/watch-build.sh --url https://ci.example.com/job/912/
```

The default report is the command line and its exit code. A command says
something richer by writing one line to `$AGENT_JOB_MSG_FILE`, which the
wrapper exports and reads at exit:

```bash
agent-job bash -c 'make check && v=PASS || v=FAIL; echo "make check: $v log=/tmp/ci.log" > "$AGENT_JOB_MSG_FILE"'
```

Write that line for the agent that launched the job: what ran, how it came
out, one key link. Domain vocabulary lives in that line and nowhere else;
the host relays it without parsing it.

## What to tell the agent

An agent runs a long job under the wrapper. Three things, in the project's
guide file or a verb doc of your own, so no prompt has to carry them:

- Run a long job under `agent-job`, detached, so the command returns at
  once: `nohup agent-job <command> > /dev/null 2>&1 &`, or the shell
  tool's own background option where it ends every process on return.
  Whether the command is composed for the run or a script the project
  keeps is a question of reuse: a one-off stays a one-liner, and a command
  the project runs every time becomes a script under its `scripts/`.
- Then end the turn. No polling, sleeping, or tailing: the report arrives
  once the job finishes and the agent has been idle since.
- Act on the report: the wrapped command and its exit code, or the line
  the command wrote.

A first try that shows the loop in any window: `agent-job sleep 180`. The
host's runner icon appears within a minute, and the report follows the
finish once the agent has been idle for two minutes.

## A script that reports on its own

A bash script that must report even when someone runs it bare, without the
wrapper, sources `scripts/job-events.sh` early, with no arguments:

```bash
#!/usr/bin/env bash
set -euo pipefail
. /path/to/agent-jobs/scripts/job-events.sh

# ... the long-running work ...

AGENT_JOB_MSG="staging deploy: OK https://ci.example.com/build/912"
```

Source it with **no arguments**, so it sees the script's own positional
parameters. `AGENT_JOB_MSG` can be set any time before exit, and the last
value set is what the agent reads, verbatim; unset, the event records the
script name and exit code. Under the wrapper such a script needs nothing
extra: its message is forwarded, and exactly one event is reported.

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
