# agent-jobs

When a coding agent starts a long job, such as CI, a heavy test suite or a
deploy, it has two bad choices: sit and watch it, which blocks the
terminal, or end its turn, after which nobody is there when the job
finishes. agent-jobs removes the choice. The agent starts the job, ends its
turn, and the terminal reports the result to the agent when the job is
done.

It works with a terminal that watches for these reports, such as
[AgentTerm](https://github.com/albertwujj/agent-term). Without one, jobs
run exactly as before and nothing else happens.

## Setting up, once per project

1. Clone this repo into `ai/` in your project, and leave `ai/` out of
   `.gitignore` so `@` pickers can see it. Other placements are described in
   AgentTerm's
   [placement](https://github.com/albertwujj/agent-term/blob/main/docs/conventions.md#placement)
   notes.

2. Make a folder of your own beside it, for example `ai/ci/`, and ask the
   agent to fill it:

   ```text
   Create ai/ci/run-ci.md and ai/ci/run-ci.sh for this project's CI,
   following ai/agent-jobs/long-jobs.md. CI runs with: make check
   ```

   The agent writes two things. `run-ci.md` is the verb doc: the steps the
   agent follows every time CI runs. `run-ci.sh` is the script for the
   usual run.

3. Read the verb doc and change what you want. From then on it is the
   guide. The agent follows it and does not edit it. The scripts cover the
   usual runs; when a run needs something they do not do, the agent may
   write another script beside them, but never another doc.

## A run

Type `@run-ci` in the prompt. It completes to `ai/ci/run-ci.md`, and the
agent follows it: it starts the script under `agent-job`, tells you CI is
running, and ends its turn.

Within a minute, the terminal shows a running-jobs icon at the top right.
You can talk to the agent about something else, or walk away.

When the job finishes, the terminal waits for the agent to be idle for two
minutes, then pastes the report into its prompt: `run-ci: PASS` or
`run-ci: FAIL`, with the path of the log. The agent reads the log, fixes
what it finds, and runs CI again the same way, until the report says pass.

The quickest first try, in any window, is `ai/agent-jobs/bin/agent-job
sleep 180`: the icon appears, and three minutes later the report does.

## Two things to know

- **A busy agent gets no report.** The report is pasted only to an agent
  that was idle when the job finished. If you kept the agent busy, the
  report is dropped, since a paste would arrive late and read as a stale
  second result. The agent then checks the log itself when you ask, or
  when it next needs the result.

- **A job that is killed still gets noticed.** A process killed outright
  writes no report, but the terminal sees that it is gone and tells the
  agent so, with the same idle rule. A result that is never coming does
  not leave the agent waiting.

Jobs outlive the session that started them: a job started before a
restart or a resume still reports to the resumed session.

## The docs

- [`long-jobs.md`](long-jobs.md): what the agent follows to write a verb doc and a
  script, and the rules for launching a job.
- [`scripts/README.md`](scripts/README.md): how the reporting works
  underneath, and how a script that is run on its own reports.

## Tests

```bash
tests/job-events.sh
tests/agent-doc.sh
```

## License

MIT.
