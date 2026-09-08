# Run CI

Run the project's CI as a background job, then end your turn. The terminal
reports the result to you when the run finishes.

1. Start it under `agent-job`, detached, so the command returns at once.
   Both files are in this clone of agent-jobs, the folder above this one:

   ```bash
   nohup <clone>/bin/agent-job <clone>/examples/run-ci.sh > /dev/null 2>&1 &
   ```

   If your shell tool ends every process when the command returns, use
   the tool's own background option for this line instead.

   The script runs the arguments you give it, else `$CI_COMMAND` through
   bash, else a two-minute sleep, a stand-in that shows the loop. Pass the
   project's CI command as the arguments when it has one. The run's output
   goes to a log the report names.

2. Say that CI is running, and end your turn. Do not poll, sleep, or tail
   the log: the report arrives on its own once the run ends and you have
   been idle since.

3. Act on the report. `run-ci: PASS log=<path>` needs no more than a word
   to the user. `run-ci: FAIL rc=<n> log=<path>`: read the log at that
   path, fix what it shows, and run CI again the same way.
