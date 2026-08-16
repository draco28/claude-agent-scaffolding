---
description: Resume from a session handoff — verify its claims against the live repo, report drift, then follow its sequence; never refuses
argument-hint: "[path]"
allowed-tools: Bash(git:*), Read, Glob, Grep
---

Handoff to resume, if one was named: $ARGUMENTS

Read `${CLAUDE_PLUGIN_ROOT}/references/handoff/resume.md` end to end and follow
it. It owns target resolution (no argument means the most recent handoff found
by the same evidence logic compose uses), the cheap claim-by-claim
verification, the drift report, and the verdict.

Two rails survive any adaptation:

- **Verify before trusting.** The handoff's State section was written as
  checkable claims precisely so this costs seconds of `git` and `test -e`, not
  a re-read of the project. Run the checks before acting on anything the
  handoff asserts.
- **Drift is information, never a refusal.** A drifted claim is reported —
  sometimes the drift *is* the expected progress. The verdict is a
  recommendation the operator can override.

This command is `/ossify:handoff-resume` rather than `/resume` deliberately:
`resume` is Claude Code's own session verb, and a command that shadows the
host's vocabulary gets reached for the wrong job — the same reason
operator-facing text writes `ossify:doctor`, never `/doctor`.
