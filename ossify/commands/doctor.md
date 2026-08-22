---
description: Diagnose an ossify project — state health, spec validation, rule authoring, Claude/Codex interop, and the skill budgets
argument-hint: "[state|spec|rules|interop|budget]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then load the `ossify:doctor` skill body, which owns the diagnosis.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "doctor: ARGS=${ARGS:-<none>}"
'
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/doctor/SKILL.md` end to end and follow it** —
with the parsed surface name, if any. The skill body owns the routing (an
optional surface token; empty runs the full sweep) → state inspection
(`oss doctor`'s four gate lines, the remedy table, then the advisory reads the
skill performs itself — lock, ledger, fakes, patches, worktrees) → lean-spec
validation → machine-checkable-rule authoring → the Claude/Codex interop check
→ the budget check.

It shells out to `oss` for mechanical facts **where a verb exists**. The interop
surface no longer has one: `interop_check` was 175 lines of bash that opened
files and described them, and the skill performs that surface by reading — the
manifest walk and parse, both roots as directories, a raw `git -C` probe on
canonical, and the `AGENTS.md` scan. What stays mechanical there is path
*resolution* (`oss repo_root`, `oss state_path`), because every mutating verb
routes through it.

With no argument it runs all five surfaces and reports all five. Unlike `/close`,
nothing here halts on a failure and nothing here is a gate: `doctor` reports, and
the only thing it writes is a rule block the user asked for.

It also runs on a **broken** project by design — an uninitialised project, a
corrupt state file or a missing pairing manifest is the finding, not a reason to
refuse.
