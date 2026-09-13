# agent-jobs

A piece of [agent-term](https://github.com/albertwujj/agent-term): the wrapper that lets the agent start a long job (CI, a heavy test suite, a deploy), end its turn, and get the result reported back when the job is done. How it is used from the terminal is in [long jobs](https://github.com/albertwujj/agent-term/blob/main/docs/jobs.md).

## Adding it

Ask your agent:

```text
Clone https://github.com/yunxin/agent-jobs into ai/ in this project,
and leave ai/ out of .gitignore.
```

A clone beside the project, or under your home directory, works too ([placement](https://github.com/albertwujj/agent-term/blob/main/docs/conventions.md#placement)).

## The mechanics

For another host, or for working on this repo. agent-jobs is the job's side: the wrapper, and the records it writes as the job starts and ends. A terminal builds the rest on top, showing the running jobs and handing the report to the agent.

- [long-jobs.md](long-jobs.md): what the agent follows. Launch the job under the wrapper, detached, end the turn without polling, and act on the report; and what a verb doc and a script for a job must contain.
- [scripts/README.md](scripts/README.md): how the reporting works underneath, and how a script that is run on its own reports.
- agent-term's [job-events.md](https://github.com/albertwujj/agent-term/blob/main/docs/dev/job-events.md): the contract the terminal reads.

## Tests

```bash
tests/job-events.sh
tests/agent-doc.sh
```

## License

MIT.
