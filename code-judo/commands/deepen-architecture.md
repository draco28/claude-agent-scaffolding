---
description: Scan the codebase for deepening opportunities — shallow modules that should become deep ones — present them as a visual HTML report opened in the browser, then grill through whichever candidate you pick.
argument-hint: "[module, subsystem, or pain point to focus on]"
allowed-tools: Bash(bash:*), Bash(git:*), Read, Write, Glob, Grep
disable-model-invocation: true
---

Parse the direction from `$ARGUMENTS` via the env-var bridge below — no positional `$1` /
`$2` / `$N`, which this harness substitutes at render time.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  DIRECTION="${ARGS_FROM_CLAUDE:-}"
  echo "deepen-architecture: direction=${DIRECTION:-<none, infer from git history>}"
'
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/deepen-architecture/SKILL.md` end to end and follow
it** — scoped to the direction parsed above if one was given, otherwise inferring hot spots
from commit history. `references/html-report.md` carries the report format;
`references/grilling.md` carries the grilling agenda and its resolution order.

Do **not** propose interfaces in the report. Write it, open it, then ask which candidate to
explore.
