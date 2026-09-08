# agent-jobs

When a coding agent starts a long job, such as CI, a heavy test suite or a
deploy, it has two bad choices: sit and watch it, which blocks the
terminal, or end its turn, after which nobody is there when the job
finishes. agent-jobs adds the option that was missing. The agent starts the
job under the `agent-job` wrapper, ends its turn, and the terminal reports
the result to the agent when the job is done.

agent-jobs is the job's side of this: the wrapper, and the records it
writes as the job starts and ends. A terminal builds the rest on top:
[AgentTerm](https://github.com/albertwujj/agent-term) shows the running
jobs and hands the report to the agent.

## Adding it

Clone this repo into `ai/` in your project, and leave `ai/` out of
`.gitignore` so `@` pickers can see it. Other placements are described in
AgentTerm's
[placement](https://github.com/albertwujj/agent-term/blob/main/docs/conventions.md#placement)
notes.

## Using it

A long job runs under the wrapper, detached, so the command returns at
once:

```bash
nohup ai/agent-jobs/bin/agent-job <command> > /tmp/<job>.log 2>&1 &
```

Then the agent ends its turn, without polling, sleeping, or tailing the
log. Within a minute the terminal shows a running-jobs icon at the top
right, and the agent can be given other work while the job runs.

When the job finishes, the terminal waits for the agent to be idle for two
minutes, then pastes the report into its prompt: the command and its exit
code, or a line the command wrote for it. The agent acts on the report,
reading the log at the path it chose when it launched the job.

## Two things to know

- **A busy agent gets no report.** The report is pasted only to an agent
  that was idle when the job finished. If you kept the agent busy, the
  report is dropped, since a paste would arrive late and read as a stale
  second result. The agent then checks the result itself when you ask, or
  when it next needs it.

- **A job that is killed still gets noticed.** A process killed outright
  writes no report, but the terminal sees that it is gone and tells the
  agent so, with the same idle rule. A result that is never coming does
  not leave the agent waiting.

Closing a session and resuming it does not lose a job: one started before
still reports to the session that comes back.

## The docs

- [`long-jobs.md`](long-jobs.md): what the agent follows.
- AgentTerm's [long jobs](https://github.com/albertwujj/agent-term/blob/main/docs/jobs.md) page: the loop from the terminal's side, with CI as the example.
- [`scripts/README.md`](scripts/README.md): how the reporting works
  underneath, and how a script that is run on its own reports.

## Tests

```bash
tests/job-events.sh
tests/agent-doc.sh
```

## License

MIT.
