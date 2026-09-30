# agent-jobs

A wrapper for long jobs, supported by [AgentTerm](https://github.com/albertwujj/agent-term). Your agent can start CI, a heavy test suite, or a deploy and end its turn, leaving the session available for other work.

## Adding it

Ask your agent:

```text
Clone the repository below into ai/ in this project, and leave ai/ out
of .gitignore.
https://github.com/yunxin/agent-jobs
```

Other locations work too ([placement](https://github.com/albertwujj/agent-term/blob/main/docs/conventions.md#placement)).

## Using it

Ask your agent to follow [`long-jobs.md`](long-jobs.md) when starting a long job. The guide covers launching it in the background without polling and acting on the result.

AgentTerm prompts the agent with the result if it has been idle since the job finished. See [long jobs](https://github.com/albertwujj/agent-term/blob/main/docs/jobs.md) for examples and completion behavior.

## The mechanics

See [reporting mechanics](scripts/README.md) for the wrapper and scripts, and [AgentTerm's event contract](https://github.com/albertwujj/agent-term/blob/main/docs/dev/job-events.md) for integration with other hosts.

## Tests

See [test commands and coverage](scripts/README.md#tests).

## License

[MIT](LICENSE).
