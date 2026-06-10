---
description: Derive governance docs (PRD/SRS/BACKLOG/PROJECT_PLAN/ADR-0001 + optional --full extensions) from MASTER-SPEC.md
argument-hint: "[--full] [--regenerate]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse flags from `$ARGUMENTS` using the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `scaffold-onboard:scaffolding-governance-docs` skill. The skill
body owns MASTER-SPEC validation, base + --full doc derivation, and ADR-0001
emission per scaffold-onboard SPEC §5.3. PROJECT_PLAN.md output is unchanged
from v0.1.0 (no rename — per SPEC §5.3 + §13.5; R1 hierarchy lives in
ROADMAP.md authored by /plan-roadmap).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  FULL=$(printf "%s" "$ARGS" | grep -oE -- "--full" | head -1 || true)
  REGEN=$(printf "%s" "$ARGS" | grep -oE -- "--regenerate" | head -1 || true)

  echo "scaffold-docs: ARGS=${ARGS:-<none>}"
  echo "scaffold-docs: FULL=${FULL:-<unset>}"
  echo "scaffold-docs: REGENERATE=${REGEN:-<unset>}"
'
```

Now invoke the skill in-conversation:

**`Skill(scaffold-onboard:scaffolding-governance-docs)`** — pass the parsed flags
above. The skill body handles `--full` (emit the 9 extension docs in addition to
the 5 base), `--regenerate` (overwrite existing docs after confirmation), and the
default no-flag case (synthesis of the 5 base docs). Governance derivation is
agent-synthesis only — there is no `--fast` deterministic path (v0.8.0).
