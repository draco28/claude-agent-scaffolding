---
description: Run the 10-phase guided project onboarding conversation that authors MASTER-SPEC.md + EXECUTIVE-SUMMARY.md
argument-hint: "[--resume] [--regenerate]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse flags from `$ARGUMENTS` using the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `scaffold-onboard:onboarding-project` skill. The skill body owns
the 10-phase loop, state machine, lock handling, and template rendering per
scaffold-onboard SPEC §5.1.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  RESUME=$(printf "%s" "$ARGS" | grep -oE -- "--resume" | head -1 || true)
  REGEN=$(printf "%s" "$ARGS" | grep -oE -- "--regenerate" | head -1 || true)

  echo "onboard: ARGS=${ARGS:-<none>}"
  echo "onboard: RESUME=${RESUME:-<unset>}"
  echo "onboard: REGENERATE=${REGEN:-<unset>}"
'
```

Now invoke the skill in-conversation:

**`Skill(scaffold-onboard:onboarding-project)`** — pass the parsed flags above.
The skill body handles `--resume` (continue at `current_phase`), `--regenerate`
(re-onboard / overwrite MASTER-SPEC.md after confirmation), and the default
no-flag case (start at Phase 1 or detect resume/reonboard mode automatically).
See SPEC §5.1 for the full mode matrix.
