---
name: planning-vertical-slice
description: Drive the full vertical-slice lifecycle — decompose into 4-5 work items, identify rounds via DAG, author specs upfront, offer grill-me at three gates, invoke architect-critic, then per round spawn worktrees + dispatch `scaffold-dev:implementer-agent` subagents. Use this when the user wants to plan VS-1.1.1, orchestrate VS-1.1.1, start a new vertical slice, or says "let's plan the next slice". Refuses to start without a workspace-init pairing manifest.
---

# planning-vertical-slice

You are the conductor of scaffold-dev v0.1's vertical-slice lifecycle. Once `MASTER-SPEC.md`, the memory bank, and `ROADMAP.md` exist (authored upstream by scaffold-onboard v0.2), this skill walks the user through one full slice: decomposition → round identification → spec authoring → architect-critic audit → per-round subagent dispatch → verification → commit + merge → round-close → slice-close handoff.

Bash helpers in `lib/manifest.sh`, `lib/state.sh`, `lib/worktree.sh`, `lib/merge.sh`, `lib/compose.sh`, and `lib/render.sh` do the bookkeeping (manifest resolution, atomic state writes, worktree mechanics, merge orchestration, filesystem probes, template substitution). The judgment work — how to slice the VS into work items, when to surface the grill-me offer, whether a subagent gap is blocking or nice-to-have, how to interpret a verification fail — happens here, in conversation.

This skill is the orchestrator's entry point. It does NOT author work-item implementations (that's `executing-work-item` running as the `scaffold-dev:implementer-agent` subagent body per SPEC §6), does NOT run the per-work-item verification gate (that's `implementation-checking` per §12), and does NOT close the slice (that's `closing-vertical-slice` per §14). Those are downstream skills this body invokes or hands off to.

---

## 1. Overview

When invoked, you, in order:

1. **Pre-flight (§3):** discover the manifest (refuse fail-fast if absent); field-read the target slice by exact `id` from `project-roadmap.json` (get `sprint_id` + metadata); merge-mode pre-flight (§3.3a); read MASTER-SPEC + memory-bank Tier 0 + the active-context cursor.
2. **Decompose (§4)** into 4-5 work items (~200-500 LOC, stable `N.NN` ids); iterate; **offer grill-me (gate 1)**.
3. **Identify rounds (§5)** via strict-layer DAG sort; user may loosen/tighten.
4. **Author the full slice scaffold upfront (§6):** README + every `spec.md` + empty `handoff.md`/`report.md` placeholders. **Offer grill-me (gate 2)** + the **spec-citations check (§6.3)**.
5. **Invoke architect-critic (§7)** in-conversation (SPEC §16.3 moment 1; sync author-depth by default, or close-depth/async per the `review_gate`).
6. **Per round (§8, sequential):** create worktrees → author handoff → dispatch the implementer (Claude subagent or Codex backend) → process gaps/complete returns → `implementation-checking` (gate; **grill-me gate 3** on fix-up) → commit + merge per `git_policy` (HALT on conflict) → round-complete handoff.
7. **At slice-close intent (§10):** suggest `closing-vertical-slice`.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/planning-vertical-slice.md` — the four scenarios there are the binding spec.

---

## 2. When to use

**Trigger phrases (description-match):**

- `plan VS-N.M.K`, `orchestrate VS-N.M.K`, `start vertical slice N.M`
- `start a new vertical slice`, `let's plan the next slice`
- `/orchestrate VS-N.M.K` (slash command — see §13 for the `$SCAFFOLD_DEV_ARGS` env-var bridge)

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` does not exist. The slice is downstream of MASTER-SPEC + ROADMAP; without them there is nothing to plan against. Route to `Skill(scaffold-onboard:onboarding-project)` (or `/onboard`) and stop.
- `ROADMAP.md` does not exist OR does not contain the target VS. Route to `Skill(scaffold-onboard:planning-project-roadmap)` (or `/plan-roadmap --add-slice <id>`) and stop. §3 covers the missing-VS error path.
- The user wants to *execute* a work item from an already-planned slice — that's `executing-work-item` (either as the subagent body via Task dispatch, or as a manual fresh-session skill per §6.4).
- The user wants to *verify* a completed work item — that's `implementation-checking` (SPEC §12.1).
- The user wants to *close* a slice whose rounds have all completed — that's `closing-vertical-slice` (SPEC §14).

If the user types something ambiguous like "let's work on VS-1.1.1", ask: *"Plan VS-1.1.1 from scratch (decomposition → spec authoring → round-1 execution), or resume an in-flight slice (next round / next work item)?"*. A resume case routes to either `executing-work-item` (round in progress) or `implementation-checking` (round-close pending) per the active-context cursor.

---

## 3. Pre-flight

Before any decomposition step, validate prerequisites in this order. Any failure surfaces the verbatim refusal/error string and stops.

### 3.1 Manifest discovery (refuses fail-fast)

Call `sd_manifest_discover` (lib/manifest.sh) to walk up from `pwd` for `.workspace/pairing.json`. If discovery returns absent — i.e. `sd_manifest_require` exits non-zero — surface this verbatim refusal and stop:

> scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.

The literal slash-command tokens `/init-workspace` and `/pair-workspace` are load-bearing — eval S2's judge rejects paraphrased substitutes that omit either token. Do NOT proceed to read ROADMAP.md, do NOT author any files, do NOT invoke architect-critic. The refusal is grounded in the helper's absent-result, not in a heuristic guess.

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
# Manifest probe (S2 contract)
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw inline `jq -r '...' .workspace/pairing.json` — eval S1's green-light criterion is binding: **all manifest field reads MUST go through `sd_manifest_get` / `sd_manifest_resolve`**. The helpers handle walk-up discovery, `${var}` expansion, and `${PLUGIN_DATA:<plugin-name>}` resolution per workspace-init's contract.

### 3.2 Read manifest fields

Resolve the fields this skill needs:

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
canonical="$(sd manifest_get '.canonical.root')"
worktrees_dir="$(sd manifest_resolve "$ai_workspace" "$(sd manifest_get '.during_dev.worktrees_dir')")"
branch_naming="$(sd manifest_get '.during_dev.branch_naming')"
sprint_dir_template="$(sd manifest_get '.during_dev.sprint_dir_template')"
```

The slice's identity and structure come from the **structured roadmap state** (`project-roadmap.json`) that scaffold-onboard publishes — NOT from grepping `ROADMAP.md`. Resolve its path via the helper, which honors the manifest's `well_known_paths.roadmap_state` and falls back to the canonical workspace location (`${ai_workspace.root}/.workspace/project-roadmap.json`) for older manifests predating workspace-init 0.1.2:

```bash
roadmap_state="$(sd roadmap_state_path)"
```

Do **NOT** read `.routing.roadmap` as a path — it is a repo *selector* string (`"canonical"` / `"ai_workspace"`), never a filesystem path. The published JSON, carrying explicit `id` + `sprint_id` fields per slice, is the structured contract surface scaffold-onboard and scaffold-dev share (#28).

### 3.3 Field-read the target VS from the structured roadmap

Look up the slice by its **exact `id`** in `project-roadmap.json`. Never grep a `#### VS-…:` heading, and never string-split the id to recover the sprint — that was the #28 slice-ID arity bug (a 3-part `VS-1.1.1` collapsed to the wrong `sprint-1` instead of `sprint-1.1`).

```bash
vs_record="$(sd roadmap_slice_json "$vs_id")"        # fails if id not found
sprint_id="$(sd roadmap_slice_sprint_id "$vs_id")"   # e.g. "1.1" for VS-1.1.1
vs_name="$(printf '%s' "$vs_record" | jq -r '.name // empty')"
vs_summary="$(printf '%s' "$vs_record" | jq -r '.summary // empty')"
vs_kebab="$(printf '%s' "$vs_name" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[[:space:]_]+/-/g; s/[^a-z0-9-]//g; s/-+/-/g; s/^-+|-+$//g')"
if [[ -z "$vs_kebab" ]]; then
  echo "VS ${vs_id} has no usable roadmap name for a directory slug; update project-roadmap.json and re-publish via /plan-roadmap." >&2
  exit 1
fi
```

If no slice matches the id, `sd roadmap_slice_json` fails and its error lists the available ids; surface this to the user (S3 contract):

> VS-<id> not found in the published roadmap (`<roadmap_state path>`). Available: <ids>. Run `/plan-roadmap --add-slice <id>` to author the slice first, then `/plan-roadmap` to re-publish the structured state.

The error MUST name the missing id explicitly, cite the resolved `project-roadmap.json` path, and include the literal `/plan-roadmap --add-slice` token. Then stop — do NOT auto-fix the roadmap, do NOT create `docs/specs/sprint-<sprint_id>/` directories, do NOT invoke architect-critic.

When the record is found, read every field directly from `vs_record` (all carried in the structured state — no prose parsing): VS `name`, one-paragraph `summary`, declared `demo_criteria` (the `auto:` / `user:` lines, per SPEC §14.1 grammar; rendered into the slice README at §6), and the traceability arrays `traces_fr` / `traces_nfr` / `traces_backlog`. Derive `vs_kebab` from the roadmap `name` field before §6.1 uses it in `slice_root`; if the name sanitizes to empty, stop and surface a roadmap data error rather than inventing a directory slug. Carry the trace IDs into every work-item spec and implementation handoff as `traceability_block`; if an array is empty, render `- FR: None`, `- NFR: None`, and `- Backlog: None` explicitly rather than inventing IDs.

### 3.3a Merge-mode pre-flight (pr_hierarchical)

Read the mode early (it gates §8.1 + §8.6 + slice-close):

```bash
merge_mode="$(sd merge_mode)"   # "direct" (default) | "pr_hierarchical"
```

`direct` mode needs nothing further — behavior is unchanged from v0.1. `pr_hierarchical` mode runs a remote/gh pre-flight (refuse fast, never silently fall back to `direct`), ensures the sprint integration branch exists on origin and is current (strict sync-before-push order), runs the slice-ordering check, then cuts the slice branch off the sprint branch and carries `$slice_branch` forward (§8.1 bases worktrees on it; §8.6 merges into it). Full steps + the order-matters rationale in `references/pr-hierarchical-preflight.md`; topology in `references/git-workflow.md`.

### 3.4 Read MASTER-SPEC + memory bank + cursor

- **MASTER-SPEC.md** — read via the manifest-resolved master-spec path. Surfaces project class, constraints, tech stack — feeds decomposition rationale.
- **Memory bank Tier 0** — auto-loaded by scaffold-dev's SessionStart hook (per SPEC §15.1, §18). If the hook hasn't fired in this session (e.g., started outside the AI workspace), surface a soft warning and continue.
- **Active-context cursor** — read `<ai-workspace>/.claude/memory-bank/05-active-context.md` for the current active sprint / slice / round position (per SPEC §17). If the cursor names a different active slice and the user is invoking this skill for a NEW slice, surface: *"Cursor shows VS-<X.Y.Z> active. Plan VS-<N.M.K> as a new slice (cursor will update on first commit), or resume VS-<X.Y.Z> instead?"* and wait for choice.
- **Recommend-by-default (#93)** — having read the spec + memory bank above, attach **one firm recommendation** + a one-line *cited* rationale to every gate below (§4 decomposition, §5 rounds, §7.2 audit-skip, §8.5 fix-up, §8.7 round/slice-close), grounded in MASTER-SPEC/memory-bank (per `references/recommendation-policy.md`); the user may **accept / rebut / defer**. `--neutral` (§13) suppresses all gate recommendations (revert to neutral menus) **and is forwarded into every nested skill gate** — `architect-critic` (§7.2/§7.2a) and `grill-me` (§§4.1/6.3/8.5) invocations receive `--neutral` too; never auto-advance (§15).

---

## 4. Decomposition (4-5 work items + grill-me gate 1)

Propose a draft decomposition into 4-5 work items, surfaced to the user as a numbered list with one-line summaries. Each work item:

- Targets ~200-500 LOC of canonical changes (the feature-size band per SPEC §4.4).
- Carries a stable `<slice-index>.<nn>` identifier — e.g., `1.01`, `1.02` for `VS-1.1.1` (slice index 1), `2.01` for `VS-1.1.2` — that survives reordering. The `<slice-index>` is the slice's position within its sprint (the 3rd field of the id); the two-digit `<nn>` suffix is deliberate (per SPEC §4.4). Keep work ids compact (`1.01`, **not** the 4-dotted `1.1.1.01`): the work id is unique across sibling slices in a sprint because the branch and path also carry `sprint-<sprint_id>`.
- Has a kebab-case slug for its directory name (`work-1.01-pulse-db-migration`).
- Declares dependencies on prior work items as a list of `<slice-index>.<nn>` ids (used for §5 DAG sort).
- Carries an explicit rationale: why this slice and why this size.

**Iteration loop:**

1. Surface the draft (numbered list, one-line summaries).
2. **Recommend** (one firm option + one-line rationale cited to MASTER-SPEC, per `references/recommendation-policy.md`), then ask: *"Recommended: accept — <why, cites MASTER-SPEC §…>. This decomposition: accept as-is, refine (which items?), or restart?"* (omit the recommendation under `--neutral`).
3. On refine: re-draft per user feedback. Loop until the user accepts.

Anti-patterns: **mega-items** (1500 LOC behind one bullet — break it); **microscope items** (rename-one-constant — fold into a sibling); **hidden dependencies** (a shared schema migration that's not its own item — surface it as 1.01); **demoability drift** (an item advancing zero demo criteria — justify or merge).

### 4.1 grill-me offer (gate 1, post-decomposition)

After the user accepts the decomposition, probe ai-mentor via `sd_compose_detect_ai_mentor` (lib/compose.sh); if present, surface an **explicit offer** (not auto-invocation — eval S1 rejects both silent skip and silent invocation): *"Decomposition settled (N items). Want to grill-me on it before locking spec authoring? (yes/no, default no)"*. **yes** → `Skill(ai-mentor:grill-me)` with `target=decomposition` (when `neutral_mode=true`, also pass `--neutral` so grill-me stays neutral; loop back to §4 on revisions); **no/skip** → record + proceed to §5. If ai-mentor is absent, skip silently (grill-me is enrichment, not a contract).

---

## 5. Round identification (strict-layer DAG)

Run a strict-layer topological sort over the declared dependency edges from §4. Output: a sequence of rounds, where round K contains all work items whose dependencies are fully covered by rounds 1..K-1.

Surface the proposed round structure to the user:

> Round 1: 1.01, 1.02 (parallel)
> Round 2: 1.03 (depends on 1.01)
> Round 3: 1.04, 1.05 (parallel; both depend on 1.03)

Then ask:

> Recommended: use the proposed rounds — <one-line, cites the DAG / MASTER-SPEC §… where relevant> (omit this Recommended line under `--neutral`). Use the proposed rounds, loosen (move items earlier — must not violate declared deps), or tighten (move items later — always allowed as soft ordering)?

Iterate until accepted. Persist the round assignment in each work item's spec (§6).

**Discipline:**

- **No dep-violating loosening.** If the user requests "move 1.03 into round 1 alongside 1.01", check the dependency graph — refuse with: *"1.03 depends on 1.01; can't run in the same round. Loosen by dropping the dependency, or keep the proposed round."*.
- **Tightening is always allowed.** The DAG produces the *minimum* round count; the user may always serialize further (e.g., turn a parallel-2 round into two serial rounds) — that's soft ordering, not a dep violation.
- **No empty rounds.** If user edits produce a round with zero items, collapse and renumber.

---

## 6. Spec authoring upfront (§5.5 contract)

At this point, author the FULL slice scaffold to disk — README + every work-item spec + empty placeholder files. This MUST happen BEFORE the architect-critic invocation (§7); the eval S1 contract requires all spec files to exist on disk when the critic skill is invoked.

### 6.1 Slice directory layout

Resolve the slice root. The sprint segment is the **field-read `sprint_id`** (§3.3), NOT a split of the slice id:

```bash
# vs_id is the full 3-part id, e.g. "VS-1.1.1"; sprint_id e.g. "1.1"
slice_root="${ai_workspace}/docs/specs/sprint-${sprint_id}/${vs_id}-${vs_kebab}"
mkdir -p "$slice_root"
# → …/docs/specs/sprint-1.1/VS-1.1.1-<kebab>
```

For each work item, create (work id is the compact `<slice-index>.<nn>` from §4 — e.g. `1.01` for the first slice's work items — never the full 3-part slice id re-embedded):

```text
${slice_root}/
├── README.md
└── work-${work_id}-${work_kebab}/
    ├── spec.md
    ├── handoff.md       (empty placeholder; populated per-round in §8)
    └── report.md        (empty placeholder; populated by implementer subagent in §8)
```

The `handoff.md` and `report.md` placeholders are created as empty files (`: > "$path"` or equivalent zero-byte writes). They're authored later in the lifecycle — handoff at round start, report by the subagent — but creating the placeholders here keeps the directory shape uniform and lets `git status` / IDE file trees show the full slice surface at planning time.

### 6.2 Template substitution

Use `sd_render` (lib/render.sh, ported from scaffold-onboard) to fill templates:

- `templates/vertical-slice-readme.md.tmpl` → `${slice_root}/README.md`
  - Vars: `vs_id`, `vs_name`, `vs_description`, `demo_criteria` (the `auto:` / `user:` lines from ROADMAP), `work_items_table`, `round_plan`, `sprint_context`.
- `templates/work-item-spec.md.tmpl` → each `work-N.NN-<kebab>/spec.md` (8 sections per SPEC §9). Author §6 `acs_block` as machine-checkable `auto:` / `user:` lines per the SPEC §14.1 grammar — one `auto:` line per programmatically-verifiable AC, in exactly this shape:

  ```
  - [ ] AC-1 auto: `pytest tests/test_foo.py` → expected: exit 0
  - [ ] AC-2 auto: `grep -q "TARGET" src/foo.py` → expected: exit 0
  - [ ] user: click "Export" and confirm a CSV downloads
  ```

  These are the single AC source of truth the `implementation-checking` gate parses; never author a parallel prose AC table (the split caused the zero-ACs bug, #36). Two hard requirements the `lib/verify.sh` helpers enforce — get either wrong and the gate misfires: **(a)** every `auto:` command MUST be backtick-wrapped; **(b)** every `auto:` line MUST carry an `AC-N` label (`user:` lines carry none). Supported `expected:` forms only: `exit 0`, `exit N`, `output contains <substring>` (substring unquoted). Full rules + rationale in `references/ac-authoring-grammar.md`.

The worktree path and branch are computed at spec-authoring time (so the spec is self-contained as a fresh-session starter per §6.4) but the actual `git worktree add` does NOT happen until the round starts (§8.1).

### 6.3 Pre-audit offers (grill-me gate 2 + spec-citations)

After all specs are written, surface two opt-in offers **before** architect-critic (so undecided items + citation drift surface first), each probed for presence and silent-skipped if absent (enrichment, not a contract):

- **grill-me (gate 2, SPEC §16.4 offer 2):** *"Specs authored (N items). Want to grill-me on the specs before adversarial review? (yes/no, default no)"* → `Skill(ai-mentor:grill-me)` with `target=specs` (pass `--neutral` when `neutral_mode=true`).
- **spec-citations (§6.4 opt-in):** *"… verify spec citations (file paths, signatures, REQ-IDs, ARCH §-refs) before adversarial review? (yes/no, default no)"* → `Skill(scaffold-dev:verifying-spec-citations)` over each `work-N.NN-*/spec.md`.

Either may produce edits — re-write affected `spec.md` via `sd_render`, then continue to §7. Never block planning on their absence or on a project without a REQ-ID scheme.

---

## 7. Architect-critic invocation (in-conversation, §16.3 moment 1)

After specs are written and the §6.3 pre-audit offers (gate-2 grill-me + citation check) have settled, invoke architect-critic for adversarial review.

### 7.0 Review-gate resolution (#39 Phase B — opt-in async)

The opt-in `review_gate` (manifest `.review_gate`, default `off`) decides whether the spec-author audit runs **synchronously** at the default `depth=author` (today's behavior) or as a **close-depth** audit — dispatched async when supported, else synchronous. Resolve the gate FIRST:

1. Resolve the gate, honoring any per-invocation `--gate` override carried from §13:
   ```bash
   gate_override_args=()
   [[ -n "${gate_override:-}" ]] && gate_override_args=(--gate "$gate_override")
   gate="$(cd "$ai_workspace" && sd review_gate_resolve "${gate_override_args[@]}")"
   ```
   → `off | slice_close | spec_close | both`. **Resolve from the AI-workspace root** — `sd review_gate_resolve` walks up from the CWD for the pairing manifest, which lives under the AI workspace; resolving from there is correct regardless of where the orchestrator's CWD sits. Precedence: `--gate` override > manifest `.review_gate` > `off` (an invalid value fails loud). Default `off` = **today's behavior** exactly (the synchronous author-depth review in §7.2).
2. `cap="$(sd compose_detect_architect_critic 2>/dev/null || true)"` → `v0.3 | v0.2 | absent` (§7.1). The `|| true` is load-bearing: the probe prints `absent` but **exits 1 by design** when architect-critic is missing, and an unguarded command substitution would abort a `set -e` block before the §7.3 warn-and-proceed branch runs. **Advisory only** and **host-agnostic**: it reports what is installed across *all* plugin caches, but only the **active host's** architect-critic is invocable here. Two consequences: (a) **Runnability** — if the probe reports present but `Skill(architect-critic:critiquing-spec)` is not runnable in the active host (e.g. installed only in the *other* host's cache), treat it as **`absent`** and take §7.3 — never invoke a skill the active host cannot resolve. (b) **Version/host** — a mixed-version cache can never force a phantom background job; the react-to-return step (§7.2a step 4) degrades any non-async outcome to a synchronous review.

Route (the spec attach point fires for `spec_close`/`both` only — `slice_close` gates the *slice-close* moment, not this one):

- `cap=absent` (or reported-present-but-not-runnable-in-the-active-host, per the runnability check above) → **§7.3** (warn-and-proceed), regardless of gate.
- gate ∈ {`spec_close`, `both`} (architect-critic present) → **§7.2a** — request a close-depth audit (async when supported). Async is **Claude-host** → Codex-adversary only; under Codex-host or architect-critic v0.2 the same call runs a **synchronous** close-depth review instead (§7.2a step 4) — still the upgraded depth, only without background dispatch.
- gate ∈ {`off`, `slice_close`} → **§7.2** synchronous author-depth review (today's behavior).

**Depth note (load-bearing):** async exists only at **close depth**, so turning the gate on at the spec moment **upgrades the default author-depth** spec audit to a heavier **close-depth** adversary audit. The upgrade holds whether or not async is available: architect-critic v0.2 (which still supports synchronous close depth) and Codex-host lose only the *background dispatch*, **not** the close depth — §7.2a step 4 runs a synchronous close-depth review in those cases. The lighter author-depth Claude-self-audit remains the default only when the gate is off.

### 7.1 Detection (filesystem probe; binary)

Call `sd_compose_detect_architect_critic` (lib/compose.sh). It walks `~/.claude/plugins/cache/*/architect-critic/*/skills/{critiquing-spec,managing-async-critique}/SKILL.md` and prints `v0.3` (async-capable — the `managing-async-critique` skill is present), `v0.2` (sync-only — only `critiquing-spec`), or `absent`. This is **NOT a composition.json read** — scaffold-dev does not maintain a composition.json cache (per SPEC §16.3).

### 7.2 Invocation — synchronous (when present)

When routed here by §7.0 (gate `off`, or `slice_close` which gates the *slice-close* moment, not this one) — **synchronous** author-depth review (the default; gate `off` preserves this exactly). With gate `off`, **everything** lands here (including `v0.2`/Codex-host) — that is the default. Only when `review_gate` is `spec_close`/`both` do the `v0.2` and Codex-host cases route through §7.2a instead, whose react-to-return step runs a synchronous **close**-depth review (the gate's depth upgrade is preserved; only background dispatch is lost):

1. Announce with a recommendation unless `neutral_mode=true`: *"Specs authored — invoking architect-critic for a spec-audit on the combined work-item specs. Recommended: run the audit — <one-line MASTER-SPEC/memory-bank rationale>. Type `skip` to bypass."* If the spec is trivial or the user explicitly opted out of audit depth, the recommendation may be *"Recommended: skip — <why this is low-value now>."*
2. End the turn and wait. If the user types `skip` (case-insensitive): log the skip in the slice README and proceed to §8.
3. Otherwise, if `neutral_mode=true`, export `ARCHITECT_CRITIC_ARGS="${ARCHITECT_CRITIC_ARGS:-} --neutral"` before invoking `Skill(architect-critic:critiquing-spec)` with:
   - `target=spec`
   - `depth=author` (per ac v0.2 §5.1 — author-depth is the lighter Claude-self-audit; close-depth at slice-close is a separate moment per §14.3)
   - `spec_paths=<list of all work-N.NN-<kebab>/spec.md absolute paths>`
   - Context note: this is the slice-spec-author moment per scaffold-dev SPEC §16.3 moment 1.
4. architect-critic runs its own challenge-resolution loop (sequential rebuttal, scoring, optional auto-promotion) and returns the structured summary.
5. When control returns: surface any challenges that stood as edit candidates. The user may accept-and-revise; for each accepted revision, re-write the affected spec.md via `sd_render`. If revisions are substantial, offer gate-3 grill-me on the fix-up (§9).

**Eval contract:** S1's tool-call log assertion requires exactly ONE `Skill(architect-critic:critiquing-spec)` invocation AFTER all spec files are written. Do NOT invoke before spec writes complete; do NOT invoke via Task tool; do NOT write to `inbox/` or `outbox/` paths (file-IPC was removed in architect-critic v0.2 per SPEC §16.3).

### 7.2a Invocation — close-depth audit, async dispatch-and-defer when supported (review_gate=spec_close|both) [#39 Phase B]

The gate runs a **close-depth** adversarial spec audit (upgraded from the default author-depth — see §7.0), requesting background dispatch so planning is not blocked. **Dispatch-and-defer:** when async is available the audit runs in the background and the rebuttal is consolidated later via resume; otherwise the very same call degrades to a **synchronous** close-depth review (still the upgraded depth, never a phantom job). The gate **reacts to what architect-critic actually returns** rather than predicting host/version.

1. Announce + usage warning with a recommendation unless `neutral_mode=true`: *"review_gate is on — requesting a close-depth architect-critic spec audit, dispatched as a background job when supported (**Claude-host** + architect-critic v0.3) and run synchronously otherwise. This consumes Codex/subscription usage. Recommended: run the audit — <one-line MASTER-SPEC/memory-bank rationale>. Type `skip` to bypass."* If cost/latency clearly outweighs value now, say *"Recommended: skip — <why>."*
2. End the turn and wait. On `skip` (case-insensitive): log the skip in the slice README and proceed to §8.
3. **Build the combined-spec bundle (one tested call).** architect-critic's async/CLI path reads exactly ONE artifact file (`critiquing-spec` Step 1a), so concatenate all work-item specs into a single artifact via the tested helper `sd review_gate_bundle` (`lib/review_gate.sh`) — it writes **under the slice dir** (a trusted git root, never `/tmp`, so the async target-root pre-flight accepts it) and appends each `HEADING PATH` section. No `--diff-*` here — the spec moment has no slice diff:
   ```bash
   bundle="$(sd review_gate_bundle --slice-root "$slice_root" \
     --title "Combined work-item specs: $vs_id" \
     "spec: <work-id>" "<work-item spec.md>")"   # repeat the spec pair per work item
   ```
   The helper echoes the bundle path; step 5 removes it after dispatch (a dotfile, kept out of `work-*/spec.md` globs, never committed).
4. Drive architect-critic through its **real CLI contract** — informal parameters do NOT set async (`async_mode` is read only from `--async` in `$ARCHITECT_CRITIC_ARGS`; see [[feedback_slash_command_dollar_n_bug]]). **Export** the args through the same env-var bridge `/critique` uses — a plain (non-exported) assignment is NOT visible to the `critiquing-spec` bash that reads `$ARCHITECT_CRITIC_ARGS`. Pass the bundle as an explicit, quoted `--spec` path (Step 1a checks `--spec` before any positional, and quoting guards a bundle path that contains spaces): `neutral_arg=""; [[ "${neutral_mode:-false}" == true ]] && neutral_arg=" --neutral"; export ARCHITECT_CRITIC_ARGS="--spec \"$bundle\" --close --async${neutral_arg}"`. Then invoke `Skill(architect-critic:critiquing-spec)` **EXACTLY ONCE**. (`--close` = upgraded close depth; `--async` = defer-to-resume; `--neutral` is forwarded from `/orchestrate --neutral`.)
5. **React to the return — three outcomes** (do NOT assume async happened); `rm -f "$bundle"` once the call returns (the artifact is fully consumed at dispatch):
   - **Async dispatched** — architect-critic returns a background **job handle `<id>`** and STOPS without a rebuttal: record the handle in the slice README (job `<id>`, dispatched async at spec-author, resume command `/critique-jobs resume <id>`), then surface and **PROCEED to §8**:
     > Spec audit running in the background as job `<id>`. Planning proceeds now; resume with `/critique-jobs resume <id>` to fold both adversaries into one rebuttal, then accept-and-revise any standing challenges into the affected `spec.md` via `sd_render`. If it never completes (stalled/capped/failed), `/critique-jobs status <id>` shows the disposition — planning is not blocked either way.
   - **Ran synchronously** — architect-critic instead completed its rebuttal cycle inline (no job handle: the Codex-host, architect-critic v0.2, or foreground-size-hint cases): treat it exactly as §7.2 step 5 — surface standing challenges as edit candidates, accept-and-revise into the affected `spec.md` via `sd_render`, then proceed to §8. Do NOT record a `/critique-jobs resume` pointer — there is no job.
   - **Pre-flight hard-fail** — under Claude-host + v0.3 but Codex uninstalled/unauthed/untrusted, `critiquing-spec` Step 6-async HARD-FAILS with remediation and **no** silent foreground fallback, so it returns NEITHER a job handle NOR a rebuttal. Do NOT stall: surface the remediation verbatim, note that `/critique-doctor` diagnoses readiness and that a synchronous review is available by re-running without `--async`, log the skipped audit in the slice README, and **PROCEED to §8** (the gate is non-blocking by contract). Re-run synchronously only if the user asks.

**Eval contract (still holds):** still EXACTLY ONE `Skill(architect-critic:critiquing-spec)` invocation AFTER all spec files are written — only driven through the exported `ARCHITECT_CRITIC_ARGS="--spec \"$bundle\" --close --async"`. No Task tool; no `inbox/`/`outbox/` writes.

### 7.3 Absent / warn-and-skip (S4 contract)

If `sd_compose_detect_architect_critic` returns `absent`, emit ONE warning and continue (do NOT block, do NOT prompt to install, do NOT retry the probe):

> architect-critic not detected — adversarial review skipped. Install architect-critic v0.2+ via `/plugin install architect-critic` for spec audit at this moment.

The warning MUST reference either `architect-critic` (plugin name) OR `adversarial review` (capability name) so the user can identify what was skipped. Then proceed to §8. S4's assertion explicitly rejects silent skip AND rejects blocking error — warn-and-proceed is the only correct path.

### 7.4 Slice-plan handoff

After §7.2 or §7.3 settles, surface:

> VS-<N.M.K> specs authored and audited. Ready for round-1 execution — invoke "execute round 1" when ready.

Do NOT auto-spawn implementer-agent subagents on this same turn. Round execution (§8) is a separate user-initiated step. Eval S1 explicitly asserts that no `Task(subagent_type="scaffold-dev:implementer-agent", ...)` invocation and no `${canonical}/.worktrees/sprint-*/work-*` directories are created on the slice-planning turn.

---

## 8. Per-round execution loop

When the user invokes round execution (e.g., "execute round 1", "run round K"), enter the per-round loop. Rounds are processed in declared order (round 1, then 2, …); work items within a round are dispatched in parallel where the user opted to keep them in the same round.

### 8.1 Create worktrees

For each work item in the round (`{N}` in `${branch_naming}` = `sprint_id`, field-read in §3.3, NOT split from the slice id):

```bash
if [[ "${merge_mode:-direct}" == "pr_hierarchical" ]]; then
  sd worktree_add "${work_id}" "${vs_id}" "${kebab}" "${sprint_id}" "${slice_branch}"
else
  sd worktree_add "${work_id}" "${vs_id}" "${kebab}" "${sprint_id}"
fi
# → ${worktrees_dir}/sprint-${sprint_id}/work-${work_id}-${kebab}
```

Halt if `sd_worktree_add` fails (dirty canonical tree, existing branch, etc.); surface the failure-response menu (SPEC §12.2 "Merge conflict" row adapted for setup conflicts).

Then record the **slice-start baseline** once (#76) — the canonical default-branch HEAD at slice start — so the direct-mode slice-close review bundle can diff `<recorded-base>..HEAD` (`closing-vertical-slice` §7.2a; today direct mode yields an empty diff because the slice is already merged by close). `sd slice_baseline_write` is append-once, so calling it every round is safe (round 2+ re-computes but no-ops, preserving the round-1 value):

```bash
default_branch="$(cd "$ai_workspace" && sd manifest_get '.canonical.default_branch')" || default_branch="main"
base_sha="$(git -C "$canonical" rev-parse "$default_branch")"
sd slice_baseline_write "$slice_root" "$base_sha" "$default_branch"
```

### 8.2 Author handoff per work item

Render `templates/implementation-handoff.md.tmpl` into each `work-N.NN-<kebab>/handoff.md` via `sd_render`. The handoff is heavy + self-contained (~200-400 lines per SPEC §10): pre-flight calibration, worktree absolute path, what's already merged, memory-bank pointers, ACs embedded, verification commands embedded, constraints (git_policy + STAGE-not-commit + subagent return format), report template, notes-for-orchestrator footer.

The handoff works in BOTH contexts (per SPEC §6.4) — as a Task tool prompt AND as a manual fresh-session starter.

### 8.3 Dispatch implementer

**Resolve the backend first.** Each work item runs on either the Claude implementer subagent (default) or the optional Codex backend (SS-5), chosen by:

```bash
backend_override_args=()
if [[ -n "${backend_override:-}" ]]; then
  backend_override_args=(--backend "$backend_override")
fi
backend="$(sd backend_resolve "${backend_override_args[@]}")"
```

Precedence: a **per-invocation override** (the user asked to run this slice/round on Codex, e.g. `/orchestrate VS-N --backend codex`) > the manifest's optional `.implementer_backend` > the default `claude_subagent`. An invalid value fails loud. Projects without the field run on Claude, unchanged.

The **manual fresh-session handoff** remains a first-class path for either backend whenever the user wants a fresh boundary: stop after writing the handoff and hand over the absolute `handoff.md` path — the handoff is self-contained by design.

Both dispatch templates live in **`references/backend-dispatch.md`**:

- **`claude_subagent` (default, §8.3a):** dispatch each work item via `Task(subagent_type="scaffold-dev:implementer-agent", …)` — the `scaffold-dev:` prefix is load-bearing (the registered custom subagent type per SPEC §6.1).
- **`codex` (optional backend, §8.3b):** dispatches the same work item to the `codex-plugin-cc` companion via `lib/codex.sh` under the same `{mode,…}` contract + no-commit boundary, sequentially within a round. Flow: `sd codex_preflight` (hard gate, no silent fallback) → assemble a prompt-file outside the worktree (Codex doesn't auto-load the skill — the contract is prompt-carried) → record baseline + `sd codex_dispatch` + `sd codex_wait` → `sd codex_verify_nocommit` immediately (even on non-`completed` term, since an aborted run may have moved HEAD) → `sd codex_result` on `completed` → judge dirtiness (a `complete`+`ok-clean` return is suspect) → join §8.4 backend-agnostic.

### 8.4 Process returns (§6.3 multi-call protocol)

Per SPEC §13, returns are processed **strictly in decomposition order** — work item N+1 is NOT verified until N is fully committed + merged (prevents the H3 "1.03 verified while 1.02 failed" interleaving). For each work item in order:

- **`mode: gaps-surfaced`** — surface the gaps, gather clarifications, append a `## Clarifications` section to the work item's `handoff.md`, then re-dispatch on the **same backend** (`claude_subagent`: same `Task(...)`; `codex`: §8.3b with `sd codex_dispatch … --resume-last`). Loop until pre-flight passes; halt at 3+ gaps iterations (§12.2 "Subagent loops in gaps-mode"). **Blocker-recall (#33):** before re-dispatching, run `sd issue_list` and JUDGE whether an open issue already covers the gap — if so, surface "known — see #N" and fold it into the clarification (skip silently if `sd remote_check` fails; judgment, not string-match).
- **`mode: complete`** — read `report.md` from disk (path returned by subagent), proceed to §8.5.
- **Malformed / crash / timeout** — halt and surface the §12.2 "Subagent crash" menu (re-invoke / extend-timeout / manual session per §6.4 / abandon).

### 8.5 Verification (§12.1 gate)

After complete-mode return, invoke `implementation-checking` on the work item:

```text
Skill(scaffold-dev:implementation-checking) with: work_item_id=<N.NN>
```

That skill (per SPEC §12.1) runs each `auto:` AC step in the worktree, cross-checks the report against actuals, and consults `sd_rules_check` for R2 mcrule violations. On fail: surface the failure-response menu (§12.2 — AC fail, report cross-check, or rule check row as applicable).

**Fix-up grill-me (gate 3):** if the menu choice is "replan" or "re-spawn with fix-up", offer grill-me before re-authoring:

> Fix-up replan triggered. Recommended: grill-me — <one-line rationale from the failure + MASTER-SPEC/memory-bank>. Want to grill-me on the failure before re-authoring the handoff? (yes/no, default no)

Per §4.1, probe ai-mentor first; offer only when detected. When `neutral_mode=true`, drop the `Recommended:` line from the prompt and pass `--neutral` to the grill-me invocation.

### 8.6 Commit + merge

On verification pass: (1) commit in the work-item worktree per `git_policy` — the subagent staged but did NOT commit (SPEC §6.2); the orchestrator owns the commit boundary. (2) Merge via `sd_merge_work_item "<worktree>" "<branch>"` (direct → `default_branch`) or `… "${slice_branch}"` (pr_hierarchical → slice branch locally, **no push/PR at this level**); **HALT on conflict** (SPEC §11, §12.2 "Merge conflict" row). (3) Mark the work-item status complete in the VS README.

Do **NOT** remove the worktree at round close — per SPEC §11, worktrees + branches survive until slice close for demo verification + harvest inspection.

### 8.7 Round-complete handoff

After all work items in the round are committed + merged: (1) set round status → complete in the VS README. (2) **Deferral auto-file (agent-driven, #33):** re-read each `report.md` **"Deferrals"** section (judgment, not parsing — there is no deterministic parser), JUDGE which warrant a tracked issue (de-dup via `sd issue_list`), surface the proposed issues as ONE batch for confirm (never file silently), and file each confirmed one via `Skill(scaffold-dev:deferring-work-item)` (or inline `sd issue_create` + the `[TD] …→#N` line). If `sd remote_check` fails, SKIP filing (deferrals stay in the reports) and proceed without blocking. (3) Surface:

> Round K complete (M items committed + merged). Recommended: proceed to the next round — <one-line rationale from remaining DAG/work status>, or close VS-<N.M.K>?

"next round" → loop §8.1 for K+1; "close slice" → proceed to §10. Under `neutral_mode=true`, omit the `Recommended:` line from the prompt above.

---

## 9. State management (cursor + slice README)

State IS the artifacts (SPEC §17 — no separate state file). Two cursors: **`05-active-context.md`** (top-level: active sprint/slice/round/work-item — updated via `sd_state_write_cursor` on round transitions, NOT every commit) and **`${slice_root}/README.md`** (slice-level: per-work-item + per-round status, demo verification filled by `closing-vertical-slice`). Never write the file the implementer-agent subagent writes (SPEC §17 write-conflict separation: orchestrator → AI workspace; subagent → canonical worktree + its own `report.md`).

---

## 10. Slice-close handoff

When the user signals slice close (after all rounds complete), suggest the slice-close ceremony skill:

> All rounds complete. Invoke `Skill(scaffold-dev:closing-vertical-slice)` (or `/close-slice VS-<N.M.K>`) to run the 3-layer close ceremony: auto-demo execution → manual-demo prompting → architect-critic adversarial review at close depth → retrospective + memory-bank harvest → worktree + branch cleanup.

Do NOT auto-invoke `closing-vertical-slice` — slice close is a deliberate gate the user opts into (often after manual demoing). This skill's lane ends at the round-complete handoff; the close ceremony is downstream.

---

## 11. Failure-response menu (per §12.2)

Whenever a per-round step fails — verification fail, report cross-check mismatch, rule violation, merge conflict, subagent crash/timeout/malformed — surface the matching SPEC §12.2 row as an explicit numbered menu and wait; never silently retry or auto-escalate. This body routes to the row rather than re-inlining the §12.2 table. **Hard discipline:** on any halt, leave a deterministic state — items 1..N merged, N+1 halted with menu surfaced, N+2.. not started, worktrees + branches preserved; never auto-cleanup on halt.

---

## 12. Bash bookkeeping helpers

This skill calls helpers for I/O + templating only; never bash-orchestrate judgment work. All route through the `sd` dispatcher:

- **manifest.sh:** `sd_manifest_discover` / `_require` / `_get` / `_resolve`
- **state.sh:** `sd_state_read_cursor` / `_write_cursor`; **slice_meta.sh:** `sd_slice_baseline_write` / `_read` (#76)
- **worktree.sh:** `sd_worktree_add` / `_list` / `_remove` (remove only at slice-close); **merge.sh:** `sd_merge_work_item`
- **compose.sh:** `sd_compose_detect_architect_critic` / `_ai_mentor`; **render.sh:** `sd_render <template> <output> <var=val …>` (Wabash `{{var}}` substitution)
- **backend.sh / codex.sh / review_gate.sh:** backend resolution + Codex companion + review-gate bundle (see the §7/§8.3 references)

macOS-portable patterns (BSD awk, bash 3.2) required for any inline snippet; prefer calling helpers over re-inlining shell.

---

## 13. Slash-command interaction (`/orchestrate VS-N.M.K`)

The `/orchestrate VS-N.M.K` slash command (`commands/orchestrate.md`) exports the raw slash-argument string as `$SCAFFOLD_DEV_ARGS` (per `feedback_slash_command_dollar_n_bug` — Claude Code corrupts bash positionals at template-render time). **Parse `$SCAFFOLD_DEV_ARGS` in bash; never reference `$1` / `$2`.** Extract the VS-id (the full 3-part `VS-<phase>.<sprint>.<slice>`) plus the optional `--backend` / `--gate` / `--neutral` overrides, then carry `backend_override` through §8.3 (`sd backend_resolve --backend …`) and `gate_override` through §7.0 (`sd review_gate_resolve --gate …`) when set, set `neutral_mode=true` when `--neutral` is present (suppresses every gate recommendation per §3.4), and proceed to §3 pre-flight. Full arg-parser in `references/orchestrate-args.md`. Unknown or missing VS-id → `> /orchestrate requires a VS-id argument. Example: /orchestrate VS-1.1.1` and stop.

---

## 14. Anti-patterns (do not do these)

- **Reading manifest fields via raw `jq`** — all reads MUST route through `sd_manifest_get` / `sd_manifest_resolve` (walk-up + var expansion); inline jq breaks both (eval S1).
- **Paraphrasing the manifest-absent refusal** — the §3.1 sentence with the `/init-workspace` + `/pair-workspace` tokens is load-bearing (eval S2 rejects omitting either).
- **Authoring specs AFTER the architect-critic invocation** — eval S1 requires all spec files on disk before the `Skill(architect-critic:critiquing-spec)` call.
- **Invoking architect-critic via Task tool or `inbox/`/`outbox/` file IPC** (eval S1) — only the in-conversation `Skill(architect-critic:critiquing-spec)` is correct; never the legacy `Skill(architect-critic:critique)` name.
- **Spawning implementer-agent subagents (or creating worktrees) on the slice-planning turn** — round execution is a separate user-initiated step (eval S1).
- **Auto-fixing ROADMAP.md on the missing-VS path** — surface the error + `/plan-roadmap --add-slice` hint and stop (eval S3, no ROADMAP writes).
- **Silent skip OR blocking error when architect-critic is absent** — emit the §7.3 warning and proceed (eval S4); never prompt to install.
- **Auto-invoking grill-me** — all three gates (§4.1 / §6.3 / §8.5) are explicit user-decidable offers (eval S1).
- **Skipping `implementation-checking` before commit + merge** (SPEC §13); **removing worktrees at round close** (SPEC §11 defers to slice close).
- **Letting dispatch contracts drift from their helpers** — keep prose aligned with `lib/*.sh`; extract reference material when a subsection grows too large to audit locally.
- **Letting this body exceed 500 lines.** Hard cap per superpowers:writing-skills Pass D guidance; move reference-grade detail to `references/*.md` (the body keeps operative steps + seams).

---

## 15. Notes on tool boundaries

- **You** make every judgment call: how to decompose, how to read a subagent gap, whether a fail warrants replan vs re-spawn, when round-complete is the right next thing to say.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: manifest reads, atomic state writes, worktree/merge mechanics, probes, template substitution.
- **`scaffold-dev:implementer-agent`** (Task-dispatched) owns work-item execution (`executing-work-item` body, TDD + verify); **`implementation-checking`** owns the per-item gate; **`architect-critic:critiquing-spec`** owns the spec audit; **`ai-mentor:grill-me`** owns the three optional gates; **`closing-vertical-slice`** owns slice close (§10).
- **The user** is the final authority — accepts/refines the decomposition + rounds (each gate carries a recommendation per §3.4 unless `--neutral`; a recommendation is a lean, not a decision), opts in/out of each grill-me, picks the failure-response option, gates slice close. Never auto-advance past a decision boundary.

The bookkeeping-vs-judgment line: a user-facing decision (which items, how to recap, whether to escalate) belongs in this body; pure I/O (manifest read, worktree create, render, atomic write) belongs in a lib helper.
