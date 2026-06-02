---
description: Derive memory-bank + CLAUDE.md + .claude/settings.json from MASTER-SPEC.md
argument-hint: "[--regenerate]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse flags from `$ARGUMENTS` using the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `scaffold-onboard:scaffolding-memory-bank` skill. The skill body
owns MASTER-SPEC validation, the 14-file memory-bank derivation, CLAUDE.md
generation, and `.claude/settings.json` emission per scaffold-onboard SPEC §5.2.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  REGEN=$(printf "%s" "$ARGS" | grep -oE -- "--regenerate" | head -1 || true)

  echo "scaffold-project: ARGS=${ARGS:-<none>}"
  echo "scaffold-project: REGENERATE=${REGEN:-<unset>}"
'
```

Now invoke the skill in-conversation:

**`Skill(scaffold-onboard:scaffolding-memory-bank)`** — pass the parsed flags
above. The skill body handles `--regenerate` (overwrite live/static files
`05-active-context.md` / `06-progress.md` / `09-known-issues.md` /
`10-decisions-log.md` / `WORKFLOW.md` after confirmation) and the default
no-flag case (idempotent derivation that preserves live state files).
