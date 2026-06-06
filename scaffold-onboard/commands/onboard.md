---
description: Run the 10-phase guided project onboarding conversation that authors MASTER-SPEC.md + EXECUTIVE-SUMMARY.md
argument-hint: "[--resume] [--regenerate] [--fresh] [--force-unlock]"
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
  FRESH=$(printf "%s" "$ARGS" | grep -oE -- "--fresh" | head -1 || true)
  FORCE_UNLOCK=$(printf "%s" "$ARGS" | grep -oE -- "--force-unlock" | head -1 || true)

  echo "onboard: ARGS=${ARGS:-<none>}"
  echo "onboard: RESUME=${RESUME:-<unset>}"
  echo "onboard: REGENERATE=${REGEN:-<unset>}"
  echo "onboard: FRESH=${FRESH:-<unset>}"
  echo "onboard: FORCE_UNLOCK=${FORCE_UNLOCK:-<unset>}"
'
```

Now invoke the skill in-conversation:

**`Skill(scaffold-onboard:onboarding-project)`** — pass the parsed flags above.
The skill body handles:
- `--resume` — continue at `current_phase` (or re-enter §8 if `status=close_pending`)
- `--regenerate` — reconcile-aware revise: asks which phases to revisit, runs §8 in reconcile mode; does NOT wipe phase records
- `--fresh` — full wipe-and-restart: discard all prior answers and phase records, re-author from Phase 1; requires explicit double-confirmation per SKILL §4 re-onboard escape hatch (`--regenerate --fresh` is equivalent to `--fresh` alone)
- `--force-unlock` — release a stale lock from a crashed prior session; requires user confirmation
- *(no flag)* — auto-detect: `new` if no state, `resume` if `in_progress`/`close_pending`, reconcile-revise (§4 re-onboard) if `complete`

See SKILL §9 for the full flag matrix and SKILL §4 for the re-onboard protocol.
