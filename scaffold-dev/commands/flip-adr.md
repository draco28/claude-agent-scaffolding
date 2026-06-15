---
description: Flip an ADR's Status from Proposed to Accepted + append an Empirical validation section. Usage: /flip-adr <adr-number-or-path>
argument-hint: "<adr-number-or-path>"
allowed-tools: Bash(bash:*), Bash(sd:*), Read, Write, Edit, Glob, Grep
---

# /flip-adr

Wraps the `flipping-adr-status` skill — resolves a `proposed-then-flip` ADR (by
number across the manifest-routed product/process dirs, or by absolute path),
verifies it is currently `Status: Proposed`, flips it to `Accepted`, and appends
an `## Empirical validation` section with the operator's signal + date. Bridge
`$ARGUMENTS` into an env var the skill body reads (per
`feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "flip-adr: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:flipping-adr-status)`** — pass the ADR number-or-path
parsed from `$SCAFFOLD_DEV_ARGS`. The skill body owns manifest discovery, ADR
resolution + disambiguation, the `Status: Proposed` gate, the empirical-signal
prompt, and the targeted Status flip + validation-section append.
