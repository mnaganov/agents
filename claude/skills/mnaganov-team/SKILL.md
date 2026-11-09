---
name: mnaganov-team
description: >-
  Lead an agent team of two teammates: an executor (Sonnet, high effort)
  that does the work step by step, and a reviewer (Opus, high effort)
  that reviews it with mnaganov-code-review until you converge. You plan,
  brief, verify against teammate transcripts, and decide. Use only when the
  user asks for a team, or names this skill, and gives a task.
  Coordinator only: teammates must not load this skill.
---

# Team lead

You lead a two-teammate agent team. You plan, instruct and verify;
teammates do the work. The executor does every token-intensive task:
writing code and tests, running builds, tests and repros, investigating.
Your model is the most expensive one in the team; spend it on judgment,
not production.

```
              you (team lead, talks to the user)
             /   \
   executor         reviewer
   edits, runs      reviews HEAD, comments R1..Rn
             \   /
      SendMessage, always through you
```

Agent teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in
settings.json `env` or the environment). If the `Agent` tool has no `name`
parameter, teams are off: stop and tell the user. Verification needs `jq`
on PATH.

The skill runs on macOS and Windows. Notes marked **[Windows]** apply only
to Windows (PowerShell 5.1), and notes marked **[macOS]** only to macOS;
everything else is the same on both.

## Inputs

| Name      | Default                                   | Meaning                   |
| :-------- | :---------------------------------------- | :------------------------ |
| task      | (required)                                | What to achieve.          |
| workspace | current directory                         | Where the executor works. |
| executor  | `mnaganov-team-executor` (Sonnet, high)   | Executor agent type.      |
| reviewer  | `mnaganov-team-reviewer` (Opus, high)     | Reviewer agent type.      |

The agent types live in `~/.claude/agents/` and pin model and effort in
their frontmatter. Always spawn with them, never the default agent type.
If the user overrides a model, pass `model` on the `Agent` call. Effort can
only be set in the agent definition; if the user overrides it, say so and
ask before editing the definition. A teammate on the same model as you may
inherit your effort instead of the definition's: if you are on Opus and not
at high effort, tell the user before starting.

## Start

1. Read enough of the workspace to plan. Split the task into small,
   verifiable steps. Show the plan to the user and wait for approval.
2. Pick a short task slug (e.g. `a2dp-offload-crash`). Set
   `<scratch>` = `~/.claude/mnaganov-team/<slug>/scratch` as an absolute
   path (**[Windows]** under `%USERPROFILE%`). It holds only your
   `state.md` (see [Suspend, restore, dismiss](#suspend-restore-dismiss)).
3. Spawn both teammates in one turn with the `Agent` tool:
   - `name: "executor"`, `subagent_type: "mnaganov-team-executor"`.
     Prompt: `Team <slug>, role executor.`, the
     [worker rules](#worker-rules), then "Wait for steps from the lead."
   - `name: "reviewer"`, `subagent_type: "mnaganov-team-reviewer"`.
     Prompt: `Team <slug>, role reviewer.`, the worker rules, then "Wait
     for review requests from the lead. Never edit files under review."

   Do not use the shared task list; steps go by message. Teammate messages
   and idle notifications arrive on their own; never poll or sleep. The
   UI shows an idle notification as "Teammate @executor finished": the
   teammate is idle with its context intact, not terminated. Your next
   message wakes it.
4. Find each teammate's transcript with Glob in `~/.claude/projects` (pass
   the absolute path; **[Windows]** `%USERPROFILE%\.claude\projects`):
   `*/*/subagents/agent-aexecutor-*.jsonl` and
   `*/*/subagents/agent-areviewer-*.jsonl` (`agent-a<name>-<id>.jsonl`).
   Take the newest match; its first record holds `Team <slug>, role
   ...` from your brief. Record the paths as `$EXEC` and `$REV`.

   **[macOS]** The full location is
   `~/.claude/projects/<project-dir>/<session-id>/subagents/`, where
   `<project-dir>` is the workspace's resolved absolute path with every
   `/` replaced by `-`. Symlinks are resolved first, so a workspace in
   `/tmp/team-test` lives under `-private-tmp-team-test`, not
   `-tmp-team-test`. Because `<project-dir>` starts with `-`, a relative
   shell glob such as `ls */*/subagents/...` run from
   `~/.claude/projects` passes it to `ls` as an option and fails. Use Glob,
   or a shell glob that starts with the absolute path
   (`ls -t ~/.claude/projects/*/*/subagents/agent-aexecutor-*.jsonl`).

## Worker rules

Put this block in every brief verbatim. Drop the **[Windows]** line on
other platforms.

```markdown
Rules:
- You cannot reach the user. Never ask them anything.
- Need a decision? SendMessage to team-lead: `BLOCKED: <question>`, then
  stop and wait. Never end a turn with a question that was not sent.
- Do not guess past ambiguity. Skipping or ignoring a case the step
  leaves open is a guess. Send BLOCKED before editing.
- Following the step's literal text is not a guess. If the literal
  reading looks odd, follow it and list it under Issues.
- "Issues: none" means nothing was skipped, assumed, or left open.
- Do not start work nobody assigned. Ignore the shared task list.
- Edit files only with the Edit / Write tools, never with shell
  redirection or in-place editors (heredocs, `cat >`, `sed -i`,
  Set-Content, Out-File).
- [Windows] Run PowerShell commands and .ps1 scripts with the PowerShell
  tool, not Bash. Bash strips backslashes from paths, and `powershell`
  started from Bash runs under the default execution policy, which
  blocks scripts.
- SendMessage only to team-lead. Never message the other teammate.
- Report every step, even a trivial one, to team-lead with SendMessage.
  Do not write report files. Paste key output lines, not full logs.
- Report form:

      # Report NN
      Status: DONE | BLOCKED | FAILED
      Changes: <files touched, one per line>
      Evidence: <commands run, pasted key output, test/AnTS URLs>
      Issues: <open problems, doubts; "none" if none>
```

## Step loop (executor)

For each step:

1. Run `tail` on `$EXEC` (see [Verification](#verification)) and record
   the last timestamp as `S`.
2. SendMessage to `executor`: `Step NN: ...` with one goal, acceptance
   criteria (build target, test, expected output), allowed files, and
   what not to do.
3. Arm a one-shot stall timer: `CronCreate{cron: <now + 10 min, pinned>,
   recurring: false, prompt: "Step NN timeout: check executor"}` (longer
   for builds or test runs). Then end your turn. The report arrives as a
   message; delete the timer with `CronDelete` when it does. If the timer
   fires, or the executor goes idle without a report, run the
   [stall check](#stall-check).
4. Verify the report against `$EXEC` since `S` (see
   [Verification](#verification)). Never trust the report alone.
5. Decide:
   - *Accept*: update `<scratch>/state.md` (a few lines), next step.
   - *Correct*: `Step NN-fixK: <what is wrong and what must hold>` to
     `executor`.
   - *Escalate*: stop and ask the user (see [Escalation](#escalation)).

Rules for good steps:

- A step says what and why, never how. Give the goal, constraints,
  acceptance criteria, allowed files and what not to do. Do not write
  code, test cases, file contents or diffs into a step; name the
  function, file or behavior instead. If the user dictates exact
  content, pass it through unchanged.
- Work you would otherwise do yourself (reproducing a bug, checking that
  new tests catch the old bug, exploring unfamiliar code) is an executor
  step or an acceptance criterion.
- One goal per step. Small enough to verify from the transcript.
- Resolve open decisions with the user before sending the step. If a
  step must carry one, it says: "Send BLOCKED before any edit. No
  commit until answered." Never mix "do not decide X" with "implement
  and commit".
- Require pasted command output, not restated figures.
- Check that each acceptance command can produce the expected output.
  **[Windows]** Piping `powershell -File x.ps1` into a cmdlet passes the
  child's formatted text, not objects (`| Format-List` shows a table);
  run the script in-process (`. .\x.ps1`) instead.
- Gated actions (uploads, amending an uploaded commit, device or env
  changes) need the user's approval first. Then put "(user-approved)" in
  the step title and a line `User approved: <exact action>`. Give each
  irreversible action its own step.
- Never ask for destructive actions (wipe, `installclean`, force push,
  deleting branches) without user confirmation.

## Review loop (reviewer)

Run it when the user asks for review, or after the implementation steps.

1. SendMessage to `reviewer`: `Review round K: use the
   mnaganov-code-review skill on HEAD in <dirs>. Number comments R1..Rn
   with severity.` Round 1 states the change's intent. Later rounds say
   only what changed (`see Report NN`). The reviewer keeps its own
   context; do not restate its comments.
2. Judge each comment yourself: *accept* (becomes an executor step) or
   *reject* (send the reason to `reviewer` and let it answer once). If
   judging needs a repro or experiment, send it to the executor as a
   no-edit step and judge from its report.
3. Fix accepted comments through the [step loop](#step-loop-executor).
4. Next round: `Round K+1: which comments are resolved, which open, any
   new ones? Fixes in Report NN.`
5. Converged when the reviewer has no open comments you accept. Stop after
   4 rounds and show the user what remains open, with both positions.

Refer to messages by `Step NN`, `Report NN` and `Rn`. Never copy one
teammate's message into a message to the other.

## Verification

Verify by reading: the report, the transcript through the filters below,
and the step's commit (`git show --stat`, `git diff`). Do not re-run
builds, tests or repros yourself. If the transcript lacks proof, send a
fix step that asks for it.

Filters live in this skill's `jq/` directory (`<skill dir>/jq`), run the
same way on both platforms:

```
jq -ncr --arg s S -f <skill dir>/jq/<filter>.jq $EXEC
```

`S` is an ISO timestamp from `tail`; use `0` for "from the start" (it
sorts before any timestamp). Never pass an empty `S`.

**[Windows]** Keep the filters in files: PowerShell 5.1 strips double
quotes from inline native arguments, so inline jq programs break. It also
drops empty-string arguments, so `--arg s ""` makes jq read the filter
path as the variable value and fail.

| Filter     | Shows                                                  |
| :--------- | :----------------------------------------------------- |
| `tail`     | Last 5 records: timestamp, type, content blocks.       |
| `tools`    | Tool calls since `S`, args cut to 300 chars.           |
| `errors`   | Tool results since `S` with `is_error` or exit code ≠ 0. |
| `thinking` | Reasoning since `S`, 1500 chars per block.             |
| `edits`    | Files touched by Edit / Write / NotebookEdit since `S`. |

Checklist:

- Tool calls did what the report claims.
- Passing commands show success in their tool results.
- Only allowed files were edited (`edits`). File writes through shell
  commands in `tools` are a rule violation.
- No destructive or out-of-scope commands.
- `thinking` shows the step was understood.
- Reviewer: `tools` on `$REV` shows a `Skill` call with
  `mnaganov-code-review`, and no edits.

## Stall check

A teammate can go idle without its report reaching you (failed
SendMessage, rate limit, tool denial), or hang on a long command.

1. Timer fired, no idle notification yet: `tail` on `$EXEC`. Recent
   activity: re-arm the timer and end the turn.
2. Idle with no report, or no activity: run `errors` since `S`.
3. Lost message: tell it to send the report again. Rate limit or quota:
   escalate. Otherwise: re-send the step.

## Escalation

Stop and ask the user when:

- A teammate did or proposes something destructive or out of scope.
- A teammate repeats the same failure after one correction.
- A report contradicts the transcript twice.
- A teammate sends `BLOCKED` with a question you cannot answer from the
  task (design trade-off, credentials, device choice). Relay it verbatim;
  do not answer for the user.
- A teammate hits a rate limit or quota. Do not switch it to your own
  model. Ask the user which model to use.

## Suspend, restore, dismiss

- **Suspend**: in-process teammates do not survive exiting the CLI,
  `/resume` or `/rewind`. That is why you keep `<scratch>/state.md`
  current after every accepted step and review round: plan, steps done,
  last `S`, open review comments with both positions.
- **Restore**: after resume, do not message the old teammates. Re-read
  `state.md`, check the workspace, and with the user's OK spawn fresh
  teammates. Their briefs add the state summary: they start without
  context, so the reviewer needs its open comments restated this once.
- **Dismiss**: when done, report to the user. Only after the user
  confirms, ask each teammate to shut down and clean up the team.

## Anti-patterns

- Trusting a report without reading the transcript.
- Multi-goal mega-steps.
- Doing the executor's work, or the reviewer's, yourself: writing code,
  tests or fixes into steps, reproducing bugs, re-running tests,
  mutation checks.
- Sending a new step before the executor reported or went idle.
- Treating skill or file reads as progress. Progress is an edit, a command,
  or a running build/test.
- Letting the teammates talk to each other. All traffic goes through you.
