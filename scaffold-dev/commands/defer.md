---
description: Defer a non-blocking gap — file a project-repo GitHub issue + add a lean [TD] index line. Usage: /defer <what to defer>
argument-hint: "<short description of the deferred item>"
allowed-tools: Bash(bash:*), Bash(sd:*), Read, Write, Edit, Glob, Grep
---

# /defer

Wraps the `deferring-work-item` skill — files a templated GitHub issue in the
project (canonical) repo and appends a `[TD] …→#N` line to the memory-bank
`tech-debt.md`. Bridge `$ARGUMENTS` into an env var the skill body reads (per
`feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "defer: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:deferring-work-item)`** — pass the deferral description
parsed from `$SCAFFOLD_DEV_ARGS`. The skill body owns the remote/gh pre-flight,
issue composition, de-dup, filing, and index append.
