---
description: Author Phase → Sprint → Vertical Slice hierarchy into ROADMAP.md (R1 contract for scaffold-dev)
argument-hint: "[--resume] [--phase-only] [--sprint-only] [--add-phase] [--add-sprint <id>] [--add-slice <id>] [--refine-slice <id>] [--reorganize]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse flags from `$ARGUMENTS` using the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `scaffold-onboard:planning-project-roadmap` skill. The skill
body owns the three-sub-phase R1.A/R1.B/R1.C interactive authoring, time-budget
checkpoints, demo-criteria sub-flow, and architect-critic close audit per
scaffold-onboard SPEC §5.4 + §13. ROADMAP.md is the R1 input contract consumed
by scaffold-dev's orchestrator-implementer cycle (scaffold-dev SPEC §16.2).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"

  # Boolean flags
  RESUME=$(printf "%s" "$ARGS" | grep -oE -- "--resume" | head -1 || true)
  PHASE_ONLY=$(printf "%s" "$ARGS" | grep -oE -- "--phase-only" | head -1 || true)
  SPRINT_ONLY=$(printf "%s" "$ARGS" | grep -oE -- "--sprint-only" | head -1 || true)
  ADD_PHASE=$(printf "%s" "$ARGS" | grep -oE -- "--add-phase" | head -1 || true)
  REORGANIZE=$(printf "%s" "$ARGS" | grep -oE -- "--reorganize" | head -1 || true)

  # Value-taking flags: accept --flag=VALUE or --flag VALUE
  ADD_SPRINT_ID=$(printf "%s" "$ARGS" | sed -nE "s/.*--add-sprint[= ]+([^ ]+).*/\\1/p" | head -1)
  ADD_SLICE_ID=$(printf "%s" "$ARGS" | sed -nE "s/.*--add-slice[= ]+([^ ]+).*/\\1/p" | head -1)
  REFINE_SLICE_ID=$(printf "%s" "$ARGS" | sed -nE "s/.*--refine-slice[= ]+([^ ]+).*/\\1/p" | head -1)

  echo "plan-roadmap: ARGS=${ARGS:-<none>}"
  echo "plan-roadmap: RESUME=${RESUME:-<unset>}"
  echo "plan-roadmap: PHASE_ONLY=${PHASE_ONLY:-<unset>}"
  echo "plan-roadmap: SPRINT_ONLY=${SPRINT_ONLY:-<unset>}"
  echo "plan-roadmap: ADD_PHASE=${ADD_PHASE:-<unset>}"
  echo "plan-roadmap: ADD_SPRINT_ID=${ADD_SPRINT_ID:-<unset>}"
  echo "plan-roadmap: ADD_SLICE_ID=${ADD_SLICE_ID:-<unset>}"
  echo "plan-roadmap: REFINE_SLICE_ID=${REFINE_SLICE_ID:-<unset>}"
  echo "plan-roadmap: REORGANIZE=${REORGANIZE:-<unset>}"
'
```

Now invoke the skill in-conversation:

**`Skill(scaffold-onboard:planning-project-roadmap)`** — pass the parsed flags
above. The skill body dispatches per mode:

- **(no flags)** — start fresh at R1.A (auto-detect resume if `project-roadmap.json` exists)
- **`--resume`** — pick up at the last checkpoint
- **`--phase-only`** — author R1.A only, stop after Phases
- **`--sprint-only`** — author R1.B only, requires R1.A complete
- **`--add-phase`** — re-run mode: append a phase to a closed roadmap
- **`--add-sprint <id>`** — re-run mode: append a sprint to phase `<id>`
- **`--add-slice <id>`** — re-run mode: append a slice to sprint `<id>`
- **`--refine-slice <id>`** — re-run mode: refine slice `<id>` (demo criteria, etc.)
- **`--reorganize`** — re-run mode: re-sequence phases/sprints/slices

See skill §9 (re-run modes) and §5 (sub-phase loop) for the full dispatch
matrix.
