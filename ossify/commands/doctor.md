---
description: Diagnose an ossify project — state health, spec validation, rule authoring, Claude/Codex interop, and the skill budgets
argument-hint: "[state|spec|rules|interop|budget]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `ossify:doctor` skill, which owns the diagnosis.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "doctor: ARGS=${ARGS:-<none>}"
'
```

Now invoke the skill in-conversation:

**`Skill(ossify:doctor)`** — pass the parsed surface name, if any. The skill body
owns the routing (an optional surface token; empty runs the full sweep) → state
inspection (`oss doctor`'s check lines, the remedy table, orphan worktrees) →
lean-spec validation → machine-checkable-rule authoring → the Claude/Codex
interop check → the budget check, and shells out to `oss` for every mechanical
fact.

With no argument it runs all five surfaces and reports all five. Unlike `/close`,
nothing here halts on a failure and nothing here is a gate: `doctor` reports, and
the only thing it writes is a rule block the user asked for.

It also runs on a **broken** project by design — an uninitialised project, a
corrupt state file or a missing pairing manifest is the finding, not a reason to
refuse.
