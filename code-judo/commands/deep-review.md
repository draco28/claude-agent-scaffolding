---
description: Strict maintainability review of a branch or diff — abstraction quality, giant files, spaghetti growth, boundary leaks — pushed toward restructurings that delete complexity rather than rearrange it. One report, one disposition pass, no loop.
argument-hint: "[base-ref]"
allowed-tools: Bash(bash:*), Bash(git:*), Read, Glob, Grep, Task
disable-model-invocation: true
---

Parse the argument from `$ARGUMENTS` via the env-var bridge below — no positional `$1` /
`$2` / `$N`, which this harness substitutes at render time.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  echo "deep-review: base=${ARGS_FROM_CLAUDE:-<none given, resolve per SKILL.md §1>}"
'
```

**Read `${CLAUDE_PLUGIN_ROOT}/skills/deep-review/SKILL.md` end to end and follow it**, passing
the base above if one was given. **Base resolution lives in the skill, not here** — Codex
publishes `./skills/` and never loads this file, so a resolver written here would exist on one
surface and not the other, which is how the two came to disagree in the first place.
`references/rubric.md` carries the standards, questions, flags, and remedies;
`references/disposition.md` carries the approval bar and the stopping rule.

This is a **quality** review, not a correctness or security review. It produces one report
and one disposition pass, and never re-reviews its own fixes.
