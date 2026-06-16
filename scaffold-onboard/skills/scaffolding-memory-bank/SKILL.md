---
name: scaffolding-memory-bank
description: Derive the 14-file memory bank + CLAUDE.md + AGENTS.md Codex section + .claude/settings.json from MASTER-SPEC.md via LLM sub-agent synthesis (the only derivation path — no deterministic fallback as of v0.8.0). Use this when the user wants to scaffold the memory bank, derive memory-bank artifacts, set up project memory, run /scaffold-project, or regenerate the tiered-context router after MASTER-SPEC changes. Seeds an empty Machine-checkable rules section, preserves user-authored AGENTS.md content, and conditionally emits the Karpathy Behavioral Discipline section per the Phase-10 opt-in.
---

# scaffolding-memory-bank

You wrap scaffold-onboard's v0.1.0 derivation pipeline (memory bank → CLAUDE.md → .claude/settings.json) and add three v0.2-specific responsibilities: manifest-aware routing, R2 rules-section seeding, and conditional Karpathy emission. The 11-file memory bank that v0.1.0 users know is preserved byte-for-byte where it can be — your job is to thread the new behaviors through without breaking that contract. A 12th file, `tech-debt.md`, is now seeded from `templates/memory-bank/tech-debt.md.tmpl` (header only, no `[TD]` entries); scaffold-dev's `/defer` command and round-close auto-file sweep append `[TD]` entries into it over the project lifetime. Two further live-seed files (`09-known-issues.md`, `10-decisions-log.md`) bring the total to 14 files (8 derived + 4 live-seed + 1 static + 1 seeded index).

Bash helpers in `lib/memory-bank.sh`, `lib/routing.sh`, `lib/compose.sh`, and `lib/render.sh` do the I/O: state reads, template substitution, atomic writes, manifest resolution, filesystem probes. The judgment work — deciding when MASTER-SPEC is too thin to derive from, how to surface a routing destination to the user, whether to suggest composition-aware companions — happens here, in conversation.

---

## 1. Overview

When invoked, you read `MASTER-SPEC.md`, validate it with `sf_spec_validate`, and derive the 14-file memory bank under `.claude/memory-bank/` at the destination resolved by `sf_resolve_output_path memory_bank ...`. Eight files come from MASTER-SPEC (00–04, 07, 08, `index.md`). Four are live-seed (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`) — emitted only when missing, preserved on re-derive. One is static (`WORKFLOW.md`, copy-once). One is a seeded index (`tech-debt.md`, header-only seed from `tech-debt.md.tmpl`, preserved on re-derive — scaffold-dev appends entries). You then emit `CLAUDE.md` (with optional Karpathy section), section-merge the scaffold-managed Codex block into `AGENTS.md`, and emit `.claude/settings.json`, each routed via its own logical name. Inside `03-code-patterns.md` you seed an empty `## Machine-checkable rules` section — heading plus invitation comment, zero rule blocks.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/scaffold-project` (slash command — see §9 for the `$ARGUMENTS` env-var bridge)
- "scaffold the memory bank", "derive memory bank", "regenerate memory bank"
- "set up project memory", "build the tiered-context router", "rebuild CLAUDE.md from MASTER-SPEC"
- "re-derive memory bank after MASTER-SPEC changes"

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` does not exist yet. Memory bank is derived FROM MASTER-SPEC; without it there is nothing to derive. Route the user to `Skill(scaffold-onboard:onboarding-project)` (or `/onboard`) and stop.
- The user wants to **author or edit machine-checkable rules** — that's `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). Your section seeding is one-shot scaffolding; rule authoring happens after. If the user says "add a machine-checkable rule" or "write an mcrule", route there.
- The user wants governance docs (PRD / SRS / BACKLOG / etc.) — that's `scaffold-onboard:scaffolding-governance-docs` (SPEC §5.3) reached via `/scaffold-docs`.
- The user wants to author the Phase → Sprint → Vertical-Slice hierarchy — that's `scaffold-onboard:planning-project-roadmap` (SPEC §5.4) reached via `/plan-roadmap`. ROADMAP.md is its output, not yours.

If you're uncertain whether to invoke (e.g., the user says "set up the project's memory" and MASTER-SPEC is absent), ask: *"MASTER-SPEC.md hasn't been authored yet. Do you want to start onboarding first (`/onboard`), or are you regenerating from an existing MASTER-SPEC at a non-default location?"*

---

## 3. Prerequisites

Before any derivation step:

1. **MASTER-SPEC.md must exist.** Resolve its expected path via `sf_resolve_output_path master_spec MASTER-SPEC.md` and confirm the file is present. If absent, do not proceed — surface the routing prompt above.
2. **MASTER-SPEC.md must validate.** Call `sf_spec_validate <path>` (lib/parser.sh — unchanged from v0.1.0). Non-zero exit means the spec is malformed (missing phase header, broken yaml frontmatter, etc.). Surface the validator's stderr to the user verbatim and stop — do not attempt to derive from a broken spec; downstream templates will silently emit `{{placeholder}}` artifacts that look complete but aren't.
3. **State file present (recommended, not required).** The project-scoped `$(sf project_data_dir)/onboarding-state.json` provides the Phase-10 Karpathy opt-in answer (`phase_10.4.include_karpathy`) and the gate flags that drive conditional template substitution. If the state file is absent (user hand-authored MASTER-SPEC outside `/onboard`), proceed with defaults: treat Karpathy opt-in as `no`, treat all branching gates as false unless inferred from MASTER-SPEC content. Surface one warning: *"No onboarding state file found — proceeding with conservative defaults. Re-run after `/onboard` to enable conditional CLAUDE.md sections."*

---

## 4. Derivation flow (14 files, four behaviors)

The core 11-file memory bank from v0.1.0 is preserved; three further files bring the total to 14: `tech-debt.md` (seeded index), `09-known-issues.md`, and `10-decisions-log.md` (both live-seed). Each file falls into one of four behavioral buckets:

| Bucket | Files | Behavior on first run | Behavior on re-derive |
|---|---|---|---|
| Derived | `00-project-brief`, `01-product-context`, `02-system-patterns`, `03-code-patterns`, `04-tech-context`, `07-constraints`, `08-governance`, `index` (8 files) | Render from `templates/memory-bank/<f>.md.tmpl` with MASTER-SPEC-derived args | Re-render and overwrite (idempotent for unchanged spec) |
| Live-seed | `05-active-context`, `06-progress`, `09-known-issues`, `10-decisions-log` (4 files) | Render seed content from template | **Preserve existing file** — do not overwrite the user's work |
| Static | `WORKFLOW.md` (1 file) | Copy verbatim from `templates/memory-bank/WORKFLOW.md` | Copy only if missing on normal re-derive; overwrite when invoked with `--force` |
| Seeded index | `tech-debt.md` (1 file) | Render header-only from `templates/memory-bank/tech-debt.md.tmpl` — no `[TD]` entries | **Preserve existing file** — scaffold-dev's `/defer` and round-close sweep append entries over time |

> The bucket table above describes derive *behavior*. For when each file is updated across the whole lifecycle (and by whom), the single source is `memory-bank/WORKFLOW.md` → **Memory-bank update cadence** — do not restate it here.

**Helpers:** the 8 derived files are **agent-synthesized** (§13 — the only path). The live/static behaviors are mechanical: `sf_memory_bank_seed_live_static` (lib/memory-bank.sh) seeds the 4 live files + `WORKFLOW.md` + `tech-debt.md`. It accepts an optional `--force` flag (which `--regenerate` passes) that overrides live-seed preservation **and** refreshes static `WORKFLOW.md` from `templates/memory-bank/WORKFLOW.md`. A *normal* run (no `--force`/`--regenerate`) preserves an existing `WORKFLOW.md` (copy-only-if-missing); `--force`/`--regenerate` overwrites it — so `WORKFLOW.md` must be named in the `--force` confirmation alongside the live-seed files.

**Discipline:**

- Always confirm with the user before passing `--force`. It overwrites the live-seed files (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`) **and** refreshes `WORKFLOW.md` — name all five paths in the confirmation. Live-seed files often hold weeks of in-flight context, and a user may have customized `WORKFLOW.md`; silently overwriting any of them is a data-loss bug.
- The 8 derived files share a substitution arg-list assembled by `_memory_bank_args` (timestamp, project_class, every state answer prefixed `phase_<qid>=`, and gate flags `ui_branch`, `dx_branch`, `backend_branch`, `frontend_branch`, `library_branch`). Do not re-inline that logic here; call the helper.

---

## 5. R2 rules section seeding (NEW in v0.2)

Inside `03-code-patterns.md`, the v0.2 template adds a new section near the end:

```markdown
<!-- mcrules:preserve:start -->
<!-- This zone is PRESERVED across /scaffold-project re-derive. Everything else in
     this file re-renders from MASTER-SPEC.md. Rules added here by
     authoring-machine-checkable-rules survive regeneration. See
     `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**. -->
## Machine-checkable rules

<!--
  Project rules live below in the HTML-sentinel `mcrule` DSL (SPEC §8.2).
  Use `/add-project-rule` (skill: authoring-machine-checkable-rules) to add
  rules; this section is intentionally seeded empty for tools that parse it.
-->
<!-- mcrules:preserve:end -->
```

**Critical:** this skill **seeds** the section — it emits the heading and the invitation comment only. It does NOT emit any actual `<!-- mcrule:start -->` rule blocks. Authoring rules is the responsibility of `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). Keep the lanes clean:

- Your output (this skill): zero `<!-- mcrule:start` sentinels in any derived file. Just the heading and invitation comment.
- Skill 5.5's output (later): one or more `<!-- mcrule:start type=<T> -->` ... `<!-- mcrule:end -->` blocks inserted inside the preserve zone, before `<!-- mcrules:preserve:end -->`.

The HTML-sentinel format is the only supported rule grammar (per SPEC §8.2). A fenced-block alternative (` ```mcrule ... ``` `) was drafted but rejected — fence boundaries are invisible to Claude in rendered markdown, breaking the human/machine dual-readability requirement. Never emit fenced rule blocks even as examples in this seed.

---

## 6. Karpathy section opt-in (NEW in v0.2)

`onboarding-project` captures the Phase 10 opt-in answer (`phase_10.4.include_karpathy = yes|no`) via `sf_state_write_answer`. Your job is to read it and conditionally emit the section in CLAUDE.md.

**Read the answer:** call `sf_state_read_answer phase_10.4.include_karpathy`. Treat any value other than the literal string `yes` (including `null`, `no`, or a missing state file per §3 fallback) as opt-out.

**If `yes`, emit the section into CLAUDE.md** after the plugin-awareness blocks (`{{#if has_ai_mentor}}` / `{{#if has_architect_critic}}` / `{{#if has_superpowers}}`), before the project-specific guidance section. The template at `templates/claude-md/CLAUDE.md.tmpl` wraps the section in `{{#if include_karpathy}}` — pass `include_karpathy=true` into the render arg list when the state answer is `yes`.

**Section content (verbatim attribution required):**

```markdown
## Behavioral Discipline (Karpathy-inspired)

*Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)*

1. **Think Before Coding** — state assumptions, surface ambiguity, ask before guessing.
2. **Simplicity First** — minimum code, no speculative abstractions.
3. **Surgical Changes** — touch only what's needed, no orthogonal refactors.
4. **Goal-Driven Execution** — vague asks → verifiable success criteria.
```

The attribution line is verbatim — the literal string `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)`. Do NOT use *"Karpathy's CLAUDE.md"* or any rephrased variant; attribution is to Chang (the MIT-licensed `forrestchang/andrej-karpathy-skills` repo that distilled the principles from Karpathy's Jan 2026 X-post observations), not directly to Karpathy.

All-or-nothing for v0.2. Per-principle granularity defers to v0.3+ if user feedback requests it.

---

## 7. Manifest-aware output routing (NEW in v0.2)

scaffold-onboard authors three logical outputs:

| Logical name                | Default destination | Emitted by |
|-----------------------------|---------------------|------------|
| `memory_bank`               | `ai_workspace`      | this skill — each of the 14 files routes through this name |
| `claude_md`                 | `ai_workspace`      | this skill — CLAUDE.md routes through this name |
| `scaffold_project_outputs`  | `ai_workspace`      | this skill — `.claude/settings.json` and other catch-all `/scaffold-project` outputs route through this name |

**Helper:** `sf_resolve_output_path <logical_name> <relative_path>` (lib/routing.sh):

```
memory_bank_dir="$(sf_resolve_output_path memory_bank .claude/memory-bank)"
claude_md_path="$(sf_resolve_output_path claude_md CLAUDE.md)"
settings_path="$(sf_resolve_output_path scaffold_project_outputs .claude/settings.json)"
```

For each of the 14 memory-bank files, resolve per-file:

```
brief_path="$(sf_resolve_output_path memory_bank .claude/memory-bank/00-project-brief.md)"
patterns_path="$(sf_resolve_output_path memory_bank .claude/memory-bank/03-code-patterns.md)"
# ...etc for the other 12
```

Behavior:

- **Manifest present** (walked up from `pwd` to find `.workspace/pairing.json`): returns the absolute path with the logical destination's root expanded (e.g., `<ai-workspace>/.claude/memory-bank/03-code-patterns.md`).
- **Manifest absent** (single-repo mode): returns `$(pwd)/<relative_path>` — exactly v0.1.0 behavior. v0.1.0 byte-identical regression tests pass through this fallback.
- **Manifest present but logical name missing** from `routing.*`: helper warns once and falls back to `$(pwd)/<relative_path>`. Forward-compatible with workspace-init manifests that pre-date a logical-name addition.

Always route through `sf_resolve_output_path` — never hardcode `.claude/memory-bank/` or `CLAUDE.md` against the cwd. The mechanical helpers (`sf_memory_bank_seed_live_static`, `sf_claude_md_generate`, `sf_claude_settings_generate`) write relative to `$(pwd)`; wrap their calls inside the resolved destination (e.g., `pushd "$(sf_resolve_output_path memory_bank .)" && sf_memory_bank_seed_live_static && popd`). The synthesis dispatch (§13) resolves each artifact's path explicitly. Treat `sf_resolve_output_path` as the single point of truth.

---

## 8. Composition awareness

scaffold-onboard maintains a `composition.json` registry for **ai-mentor** + **superpowers** detection (per SPEC §12.2). architect-critic is detected separately via filesystem probe (SPEC §12.2 binary v0.2-or-absent — there is no fallback path to older architect-critic versions, since pre-v0.2 ac shipped with no `skills/` directory and the `Skill(architect-critic:...)` grammar cannot resolve against it).

**At derivation start, before rendering CLAUDE.md:**

1. Refresh composition.json via `sf_compose_refresh` (lib/compose.sh) so ai-mentor / superpowers presence is current.
2. Read `has_ai_mentor`, `has_superpowers` from the composition args (folded into the template arg list by `_composition_args` in lib/memory-bank.sh).
3. Probe for architect-critic via `sf_compose_detect_architect_critic` — it walks plugin cache directories looking for `architect-critic/*/skills/critiquing-spec/SKILL.md` and prints `v0.2` or `absent`. Set `has_architect_critic=true` iff it returns `v0.2`.
4. When the corresponding `{{#if has_*}}` block in `templates/claude-md/CLAUDE.md.tmpl` is enabled, the rendered CLAUDE.md gains the matching plugin-awareness section (preserves v0.1.0 behavior).

**Optional in-conversation suggestions (warn-and-skip if absent):**

- If `has_ai_mentor=true` and the user mentions wanting a sanity check on the derived `02-system-patterns.md` or `03-code-patterns.md`, suggest: *"Want to stress-test the derived patterns? `Skill(ai-mentor:grill-me)` can interview you on the assumptions baked into them."*
- If `has_architect_critic=true` and the user has just hand-edited the seeded `## Machine-checkable rules` section, suggest: *"Want adversarial review of the rules you just added? `Skill(architect-critic:critiquing-spec)` (target: `master-spec-phase`, depth: `premise-audit`) gives a fresh-frame second opinion."* The v0.2 critic skill name is `critiquing-spec` — never invoke the legacy `Skill(architect-critic:critique)` slash-command-shaped name (removed in ac v0.2 per its SPEC §3 NG1).

These are suggestions, not gates. The user may decline; you proceed with the derivation regardless. architect-critic itself is NOT recorded in composition.json per ac v0.2 settlement #1; filesystem probe only.

---

## 9. Slash-command interaction (`/scaffold-project` via `$ARGUMENTS` bridge)

The `/scaffold-project` slash command wrapper (`commands/scaffold-project.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. in command bodies at template-render time, silently corrupting bash positionals).

Supported flags:

- *(no flag)* — derive memory bank; preserve live-seed files (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`); skip WORKFLOW.md if present; route via manifest if present, else `$(pwd)`.
- `--regenerate` — re-synthesize the derived files unconditionally and pass `--force` to `sf_memory_bank_seed_live_static`. Overwrites live-seed files **and** refreshes `WORKFLOW.md` (with explicit user confirmation). Always asks confirmation before clobbering `05-active-context.md` / `06-progress.md` / `09-known-issues.md` / `10-decisions-log.md` / `WORKFLOW.md` — surface every path that will be overwritten and require an explicit `yes`. **Exception (data-safety):** if the one-time SS-1 migration relocated legacy harvested content into `09-known-issues.md` during this same run, `sf_memory_bank_seed_live_static` **automatically preserves** `09` rather than force-overwriting it (it tracks the in-run migration internally via `_SF_MB_MIGRATED_TO_KNOWN_ISSUES` — the orchestrator does not special-case it) — otherwise the just-migrated notes would be lost in the same call. The other live files still follow the confirmed-overwrite path.

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` directly. If `$ARGUMENTS` contains a flag this skill doesn't recognize, surface a one-line error listing the supported flags and stop — do not silently ignore.

---

## 10. Bash bookkeeping helpers (the bookkeeping-vs-judgment line)

This skill never bash-orchestrates the judgment work (whether to overwrite live-seed, whether to suggest a composition companion, how to phrase the destination prompt). It calls helpers for I/O and templating only.

**Memory-bank mechanical helpers (lib/memory-bank.sh):** `sf_memory_bank_seed_live_static` (with optional `--force` — seeds the 4 live files + `WORKFLOW.md` + `tech-debt.md`), `sf_claude_md_generate`, `sf_agents_md_generate`, `sf_claude_settings_generate`, `_memory_bank_args` (internal), `_composition_args` (internal), `_sf_mb_extract_preserve_zone` / `_sf_mb_reinject_preserve_zone` (internal — the `03` rules-zone preserve helpers §13 uses), `_sf_mb_migrate_harvested` (internal — the SS-1 one-time harvest migration). The 8 derived files are agent-synthesized (§13), not rendered by a lib helper.

**Rendering (lib/render.sh):** `sf_render` (generic template substitution — used by the derivation helpers; rarely called directly from this skill).

**Routing (lib/routing.sh):** `sf_resolve_output_path`, `sf_discover_manifest`.

**Composition (lib/compose.sh):** `sf_compose_refresh`, `sf_compose_detect_architect_critic`.

**State (lib/state.sh):** `sf_state_read_answer` (read the Karpathy opt-in), `sf_state_gate_passes` (re-used inside `_memory_bank_args` to set the branching gate flags — you don't call it directly here).

**Validation (lib/parser.sh):** `sf_spec_validate`.

These are pseudocode references — the implementations are in their respective lib files. macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 11. Anti-patterns (do not do these)

- **Inlining the 14-file template content in this skill body.** The templates live in `templates/memory-bank/` and `templates/claude-md/`. Pulling them in here inflates the body past the ≤500-line guidance and creates two sources of truth.
- **Emitting actual `<!-- mcrule:start -->` rule blocks from this skill.** R2 section seeding is heading-plus-invitation only. Rule authoring belongs to `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). Lane discipline matters — eval scenario S2 will FAIL on any rule block emitted by this skill.
- **Using the fenced-block mcrule alternative** (e.g., ` ```mcrule ... ``` ` fences). The v0.2 grammar is HTML-sentinel only (SPEC §8.2). Fenced blocks were drafted and rejected because their boundaries are invisible in rendered markdown.
- **Overwriting live-seed files (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`) silently on re-derive.** Always preserve unless `--regenerate` is explicit AND the user has confirmed. These files hold the user's in-flight work; silent clobber is a data-loss bug.
- **Overwriting `WORKFLOW.md` on `--regenerate` WITHOUT naming it in the confirmation.** `--force` (which `--regenerate` passes) DOES refresh `WORKFLOW.md` from the template — intentional, since it's project-agnostic — but a user may have customized it, so it MUST appear in the `--force` confirmation alongside the live-seed files; never clobber it silently.
- **Hardcoding `.claude/memory-bank/` against `$(pwd)`.** Always route via `sf_resolve_output_path memory_bank .claude/memory-bank/...`.
- **Reading `composition.json` to detect architect-critic.** Use `sf_compose_detect_architect_critic` (filesystem probe). The composition.json registry tracks ai-mentor + superpowers only in v0.2 (per ac v0.2 settlement #1).
- **Invoking `Skill(architect-critic:critique)`.** That's the v0.1.x slash-command-shaped name, removed in ac v0.2. Use `Skill(architect-critic:critiquing-spec)`.
- **Skipping `sf_spec_validate`.** A malformed MASTER-SPEC silently emits `{{placeholder}}` artifacts that look complete but are broken. Validate up-front; refuse to proceed on non-zero exit.
- **Emitting a Karpathy section on `null`, `no`, or any value other than the literal string `yes`.** The Phase-10 opt-in is explicit; defaulting to "include" on missing state would silently push opinionated cognitive guidance into projects that opted out.

---

## 12. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: whether MASTER-SPEC is too thin to derive from, whether to confirm a live-seed overwrite, when to suggest ai-mentor / architect-critic companions, how to phrase the routing destination prompt.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: template substitution, atomic file writes, manifest resolution, filesystem probes, state file reads.
- **`onboarding-project`** owns the Phase 10 opt-in capture — you only READ `phase_10.4.include_karpathy`; you never write to it.
- **`authoring-machine-checkable-rules`** owns rule authoring inside `03-code-patterns.md` — you seed the empty section; it populates the rules.
- **The user** is the final authority. For destructive operations (`--regenerate` against live-seed files), require explicit confirmation. Never auto-finalize a re-derive that clobbers work without an explicit `yes`.

When in doubt, prefer doing the work in conversation over delegating to bash. v0.1.x got this wrong — `/scaffold-project` lived almost entirely inside `bash -c` blocks Claude never read; v0.2 corrects that by making this skill body the readable orchestration layer and keeping bash to bookkeeping.

---

## 13. Synthesis dispatch (v0.3)

The **8 derived memory-bank files** are authored by **sub-agent synthesis — the only derivation path** for derived content (the deterministic `--fast` renderer was removed in v0.8.0, SS-7). **`CLAUDE.md` is NOT synthesized** — it is mechanically generated by `sf_claude_md_generate` in the §13.2 finalize (it is a structured/conditional router file whose composition gates + verbatim-attribution Karpathy opt-in a synthesis agent cannot reliably reproduce; see §13.2). This section describes the orchestration logic you (the orchestrator session reading this skill) must execute. Bash cannot dispatch sub-agents; this logic lives here as prose instructions.

**Agent-unavailable model (uniform across all synthesis here):** dispatch the sub-agent → if no Task tool (headless), perform the synthesis **inline in the main context** from the same brief → if a synthesized artifact is structurally invalid, **re-dispatch once** with a corrective instruction → if it still fails, **hard-fail with actionable remediation** (state preserved; re-run `/scaffold-project`). There is **no deterministic content fallback**.

### 13.1 Setup

Source both synthesis and routing helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/memory-bank.sh"   # sf_memory_bank_seed_live_static, sf_claude_*, _memory_bank_args, _sf_mb_*
source "${CLAUDE_PLUGIN_ROOT}/lib/compose.sh"       # sf_compose_detect_architect_critic — _composition_args (inside sf_claude_md_generate) needs it; without it the probe is undefined and has_architect_critic renders false, dropping the /critique block from CLAUDE.md
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"        # sf_render_executive_summary_from_synthesized, sf_exec_summary_staleness
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"         # sf_project_name, sf_state_read_answer, sf_state_gate_passes
source "${CLAUDE_PLUGIN_ROOT}/lib/backend.sh"       # sf_backend_resolve — synthesizer backend selector (SS-5.1)
source "${CLAUDE_PLUGIN_ROOT}/lib/codex.sh"         # sf_codex_* — Codex synthesis adapter (SS-5.1; call as `sf codex_<verb>`)
```

Resolve the synthesizer backend **once** (SS-5.1):

```bash
if ! backend="$(sf_backend_resolve)"; then
  return 1  # invalid configured backend; do not silently fall back to Claude
fi
```

When `backend == codex`, every derived artifact below is synthesized by the Codex companion instead of the Claude `synthesis-agent`, under the **same** assembled prompt and the **same** post-validation (§13.2). The **router files** (`CLAUDE.md`, `.claude/settings.json`, `AGENTS.md`) are NEVER synthesized on either path — they stay mechanical in the §13.2 finalize. There is no silent fallback to Claude: if `codex` is selected and pre-flight fails, the skill hard-fails with remediation.

Resolve source documents:

```bash
master="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
exec_summary="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
# EXEC-SUMMARY is produced by onboarding (single authoritative producer, §8). Here we
# only CONSUME it: best-effort produce-once via SYNTHESIS if a legacy project lacks it
# (SS-7: no deterministic extract), and warn (never silently refresh) if it is stale.
#
# CONSUMER ≠ PRODUCER (SS-7 spec §4): unlike the onboarding-close producer, this
# consumer path has NO inline fallback when headless and does NOT hard-fail. Here
# EXEC-SUMMARY is OPTIONAL enriching context — MASTER-SPEC is the SSoT and the 8
# derived files synthesize fine from it alone. So if it cannot be produced (no Task
# tool, or synthesis + the one corrective retry both fail), warn and proceed deriving
# from MASTER-SPEC only. Its authoritative producer is /onboard.
if [[ ! -f "$exec_summary" ]]; then
  exec_brief="${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md"
  prompt="$(sf_synth_brief_assemble "$exec_brief" "$(sf_synth_ledger_empty)" "$exec_summary" "$master" "")"
  # If a Task tool is available, dispatch scaffold-onboard:synthesis-agent with
  # "$prompt" (the brief synthesizes from the FULL MASTER-SPEC — vision/users/MVP/
  # success criteria), then write it back with the guarded helper:
  #   sf_render_executive_summary_from_synthesized "$master" "$exec_summary" \
  #     "$(sf_project_name)" "$(sf_state_read_answer 1.3.1)"
  # On structural rejection, re-dispatch once with a corrective instruction. Headless
  # (no Task tool): skip — do NOT inline-author here (that is the producer's job, §8).
  if [[ ! -f "$exec_summary" ]]; then
    sf_log_warn "could not produce EXECUTIVE-SUMMARY.md — proceeding with MASTER-SPEC only (it is the SSoT); run /onboard to author the standalone summary"
    exec_summary=""
  fi
elif ! sf_exec_summary_staleness "$master" "$exec_summary"; then
  sf_log_warn "EXECUTIVE-SUMMARY.md is older than MASTER-SPEC.md — re-run onboarding synthesis to refresh it (this command consumes but does not refresh the summary)."
fi
```

### 13.2 Synthesis wave dispatch

Dispatch the 8 artifacts in Wave 4. All artifacts are independent of each other (no sequential ID-dependency within this skill). Claude subagents can be dispatched in parallel; the Codex backend runs Wave 4 sequentially to avoid companion same-session races against the shared memory-bank target root. Maintain a running ledger from the start:

> **CLAUDE.md is NOT synthesized** — it is mechanically generated by `sf_claude_md_generate` in the §13.2 finalize (see below), alongside `.claude/settings.json` and the AGENTS.md managed section. CLAUDE.md is a structured/conditional router file (plugin-awareness composition gates + the verbatim-attribution Karpathy opt-in §6), not prose: it belongs with the other mechanical router files, exactly like settings.json/AGENTS.md, and is the only path that honors `phase_10.4.include_karpathy` (a synthesis agent has no access to the gate values and cannot reproduce the verbatim attribution reliably).

```bash
ledger="$(sf_synth_ledger_empty)"
```

Briefs live at `${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/<name>.brief.md`.

Before dispatching derived artifacts in `--regenerate` mode, run the SS-1
harvest migration while the old derived files still exist. This preserves any
provenance-trailed harvested entries before synthesis agents replace those files:

```bash
if [[ "${regenerate:-0}" == "1" ]]; then
  # Run the migration AT the routed memory-bank root, not pwd. In a manifest-routed
  # (dual-repo) workspace the memory_bank destination resolves OUTSIDE pwd, and
  # _sf_mb_migrate_harvested scans/writes `.claude/memory-bank` relative to its cwd;
  # a bare call would scan the wrong directory. Use pushd/popd (NOT a forking
  # `( cd … )` subshell): when _sf_mb_migrate_harvested relocates harvested notes
  # into 09-known-issues.md it sets the GLOBAL flag _SF_MB_MIGRATED_TO_KNOWN_ISSUES,
  # and the live/static seed below (run with --force under --regenerate) reads that
  # flag to AVOID force-overwriting the just-migrated 09. A forking subshell would
  # discard the flag, so --force would clobber the migrated notes (data loss). Running
  # the migration in THIS shell via pushd/popd lets the flag persist into the parent
  # shell — the seed subshell below then inherits it — while still restoring cwd even
  # on failure. (_sf_mb_migrate_harvested is sourced from memory-bank.sh in §13.1.)
  # sf_log_error only LOGS (it does not exit), so guard the pushd explicitly: if the
  # routed memory_bank root is missing/inaccessible, STOP — never run the migration in
  # the caller's cwd (it would relocate notes from the wrong .claude/memory-bank and
  # set the preserve flag against the wrong 09).
  if ! pushd "$(sf_resolve_output_path memory_bank .)" >/dev/null; then
    sf_log_error "could not enter the memory_bank root for harvest migration — aborting /scaffold-project --regenerate (state preserved); fix the routed memory_bank destination and re-run"
    return 1
  fi
  _sf_mb_migrate_harvested || sf_log_warn "harvest migration reported an error — continuing to synthesis"
  popd >/dev/null
fi
# Wave 4 — all 8 artifacts may overwrite derived files after this point.
```

**Wave 4 — all 8 artifacts** (all model `sonnet`; `routes_to` per brief):

Dispatch each of the following using the standard pattern. For `backend == codex`, run this pattern one artifact at a time; for `claude_subagent`, the Task dispatches may still be parallel:

```bash
brief="${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/<NAME>.brief.md"
out="$(sf_resolve_output_path <routes_to> .claude/memory-bank/<name>.md)"
prompt="$(sf_synth_brief_assemble "$brief" "$ledger" "$out" "$master" "$exec_summary")"   # UNCHANGED — same prompt to both backends
if [[ "$backend" == "codex" ]]; then
  # SS-5.1 Codex synthesizer backend — dispatch the SAME prompt to the codex
  # companion. NO Claude fallback on pre-flight failure (the user chose Codex).
  target_root="$(sf codex_target_root "$out")"     # output artifact's repo root → sandbox=workspace-write covers the write
  sf codex_preflight "$target_root"                # hard-fail with remediation if Codex unavailable/untrusted
  pf="$(mktemp "${TMPDIR:-/tmp}/sf-codex-prompt.XXXXXX.md")"
  {
    printf '%s\n\n' "$prompt"
    printf '%s\n' '## Return contract'
    printf '%s\n' 'Your final message MUST end with exactly one fenced JSON block matching one of these shapes:'
    printf '%s\n' '```json'
    printf '%s\n' '{"mode":"complete","output_path":"<abs>","ids_minted":{"use_cases":[],"frs":[],"nfrs":[],"backlog":[]},"ids_cited":[],"summary":"<one line>"}'
    printf '%s\n' '```'
    printf '%s\n' 'or:'
    printf '%s\n' '```json'
    printf '%s\n' '{"mode":"failed","reason":"<why>","partial_output_path":null}'
    printf '%s\n' '```'
  } > "$pf"   # temp OUTSIDE any output tree
  trap 'rm -f "$pf"' EXIT INT TERM
  job="$(sf codex_dispatch "$target_root" "$pf")"
  rm -f "$pf"; trap - EXIT INT TERM
  term="$(sf codex_wait "$target_root" "$job")"    # completed|failed|cancelled|stalled|capped|error
  if [[ "$term" == "completed" ]]; then
    result="$(sf codex_result "$target_root" "$job")"  # {mode, output_path, ids_minted, ids_cited, summary}
  else
    result="$(jq -nc --arg term "$term" '{mode:"failed",reason:"Codex job ended with terminal status: \($term)",partial_output_path:null}')"
  fi
else
  Task(subagent_type="scaffold-onboard:synthesis-agent",
       description="Synthesize <name>",
       model="claude-sonnet-4-5",
       prompt="$prompt")
  # result = the agent's returned {mode, output_path, ids_minted, ids_cited, summary} JSON
fi
mode="$(printf '%s' "$result" | jq -r '.mode // empty')"
if [[ "$mode" == "complete" ]]; then
  :  # continue to the shared validation block below
else
  :  # route to the same-backend retry/fail path below; do not validate a failed/stale artifact
fi
```

The dispatch is the **only** backend branch: the prompt above and the `mode:complete` validation below (`sf_synth_ledger_merge` + the three `sf_synth_assert_*`) are identical for both backends. For Codex, run validation only after `term == completed` and `mode == complete`; any other terminal status or `mode:failed` routes to the same-backend retry path. On `mode:failed` or any validation failure, re-dispatch that artifact **once** via the **same** backend (`codex` → `sf codex_dispatch … --resume-last`).

The 8 artifacts and their output paths:

| Artifact | `routes_to` | Output path |
|---|---|---|
| `00-project-brief` | `memory_bank` | `.claude/memory-bank/00-project-brief.md` |
| `01-product-context` | `memory_bank` | `.claude/memory-bank/01-product-context.md` |
| `02-system-patterns` | `memory_bank` | `.claude/memory-bank/02-system-patterns.md` |
| `03-code-patterns` | `memory_bank` | `.claude/memory-bank/03-code-patterns.md` |
| `04-tech-context` | `memory_bank` | `.claude/memory-bank/04-tech-context.md` |
| `07-constraints` | `memory_bank` | `.claude/memory-bank/07-constraints.md` |
| `08-governance` | `memory_bank` | `.claude/memory-bank/08-governance.md` |
| `index` | `memory_bank` | `.claude/memory-bank/index.md` |

**Live files and WORKFLOW.md are NOT synthesized:**

- `05-active-context.md`, `06-progress.md`, `09-known-issues.md`, and `10-decisions-log.md` keep today's seed-once behavior — `sf_memory_bank_seed_live_static` handles them (preserve if present, seed only if missing). Do not dispatch sub-agents for them.
- `WORKFLOW.md` remains a static copy. Do not dispatch a sub-agent for it.

**03-code-patterns special note (preserved rules zone — SS-1 W2):** `03` carries a
`<!-- mcrules:preserve:start -->` … `<!-- mcrules:preserve:end -->` zone that must
survive re-derive. BEFORE dispatching the `03-code-patterns` sub-agent, capture the
existing zone with the lib helper:

    saved_zone="$(_sf_mb_extract_preserve_zone "$out_03")"   # $out_03 = resolved 03 path

The brief instructs the agent to emit the section wrapped in those exact sentinels
(empty: heading + invitation only). AFTER the agent returns `mode:complete` and the
file is written, re-attach the captured zone with the single helper:

    if [[ -n "$saved_zone" ]]; then
      _sf_mb_restore_preserve_zone "$out_03" "$saved_zone"
    fi

`_sf_mb_restore_preserve_zone` **guarantees exactly one** `## Machine-checkable rules`
section. When the synthesized `03` kept the sentinels it replaces the freshly-rendered
zone in place; when synthesis **dropped** the sentinels it strips any bare
`## Machine-checkable rules` heading the agent may have emitted **before** re-appending
the saved sentinel-wrapped zone — so the file never ends up with two headings (which
would silently lose authored rules on the next re-derive, #63). This is mechanical
preservation of the user's already-authored rules — never a deterministic re-render of
`03` content (there is no deterministic renderer as of v0.8.0). Optionally re-dispatch
`03` once with a corrective instruction ("wrap the section in the exact
`mcrules:preserve` sentinels") before falling back to the mechanical re-attach.

On `mode:complete` for each artifact: merge returned IDs and validate:

```bash
ledger="$(sf_synth_ledger_merge "$ledger" "<ids_minted from return JSON>")"
sf_synth_assert_sections "$brief" "$out"
sf_synth_assert_no_markers "$out"
sf_synth_validate_cited "$ledger" "<ids_cited from return JSON>"
```

On `mode:failed` or any validation failure: **re-dispatch that artifact once** with a corrective instruction (cite the failed assertion — missing section, stray fill-in marker, uncited ID). If it fails again: `sf_log_error "<artifact> synthesis failed after retry — re-run /scaffold-project to retry; partial bundle left in place"` and **stop** (do not silently substitute a deterministic render — there is none as of v0.8.0). Artifacts that already succeeded remain; the re-run skips them via the skip-if-exists semantics (§13.3) unless `--regenerate`.

After all 8 artifacts complete, seed the live files and copy the static file:

```bash
# Seed AT the routed memory-bank root, not pwd. sf_memory_bank_seed_live_static
# writes the 4 live files (05/06/09/10), WORKFLOW.md, and tech-debt.md under
# `.claude/memory-bank` relative to its cwd; in a manifest-routed workspace the
# memory_bank destination resolves OUTSIDE pwd, so a bare call would split-brain
# the bundle (synthesized derived files routed correctly, live files landing in
# pwd). These are keep-forever files (dev-authored live + SS-1 migration target),
# so they must route. (sf_memory_bank_seed_live_static is sourced from
# memory-bank.sh in §13.1; the subshell inherits it.)
( cd "$(sf_resolve_output_path memory_bank .)" && \
  if [[ "$regenerate" == "1" ]]; then
    sf_memory_bank_seed_live_static --force   # regenerate mode: confirmed live/static overwrite path
  else
    sf_memory_bank_seed_live_static           # normal mode: preserve live files; copy WORKFLOW only if missing
  fi )
```

This seed-only helper is load-bearing: it seeds the live/static files **without
touching the 8 derived files** the synthesis agents just authored. (It is the only
memory-bank file helper that runs here — there is no deterministic derived-file
renderer as of v0.8.0.)

Only the seed + harvest migration go inside the memory_bank `cd` — they touch
memory-bank files exclusively, all under one `memory_bank` root. `.claude/settings.json`,
`AGENTS.md`, and `CLAUDE.md` are emitted by SEPARATE helpers
(`sf_claude_settings_generate`, `sf_agents_md_generate`, `sf_claude_md_generate`) that
route via their OWN logical names (`scaffold_project_outputs`, `claude_md`); do NOT move
those inside the memory_bank `cd` (they would land in the wrong root).

Then emit `CLAUDE.md`, `.claude/settings.json`, and the AGENTS.md managed section via
their helpers (all mechanical — these three structured/conditional router files are not
synthesized):

```bash
# sf_claude_md_generate renders CLAUDE.md.tmpl (composition gates + the conditional
# Karpathy section per phase_10.4.include_karpathy, §6) but writes to a RELATIVE
# CLAUDE.md, so route it: run it from the resolved claude_md root. claude_md routes
# to ai_workspace (the same root as memory_bank, where .workspace/pairing.json lives),
# so this cd does NOT break the helper's manifest/composition discovery — it matches
# the documented routing pattern (§ "Routing"). A bare call would land CLAUDE.md in
# pwd and leave the intended ai_workspace CLAUDE.md missing/stale in a dual-repo run.
# This is the ONLY path that honors the Karpathy opt-in — it must run on every
# /scaffold-project.
( cd "$(sf_resolve_output_path claude_md .)" && sf_claude_md_generate )
sf_claude_settings_generate
sf_agents_md_generate
```

`sf_claude_md_generate` reads the opt-in (`sf_state_read_answer phase_10.4.include_karpathy`)
and the composition gates itself, then writes `CLAUDE.md` to its `claude_md` root — there is
no deterministic *content* renderer left (the 8 memory-bank derived files are agent-synthesized,
above), but CLAUDE.md, settings.json, and AGENTS.md remain mechanically generated because they
are structured router/config files, not prose.

### 13.3 Skip / regenerate semantics

Before assembling a prompt for any derived artifact, check whether its resolved output path already exists; if it does and `--regenerate` was not passed, skip it (emit `sf_log_info "preserved: <path>"`) and do not dispatch a sub-agent for it. With `--regenerate`, dispatch unconditionally (and pass `--force` to `sf_memory_bank_seed_live_static` for the live/static files, per §9).

For the 4 live files (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`), always apply the preserve-unless-`--regenerate` + explicit-confirmation discipline from §4 — even in synthesis mode. Sub-agents never touch live files.

### 13.4 Coverage report

After all waves complete (regardless of per-artifact fallbacks), collect every ID cited across all synthesized docs into a single newline-separated list and print:

```bash
sf_synth_coverage_report "$ledger" "<all cited IDs, newline-separated>"
```

This surfaces any FR/NFR that no artifact cited so the user can identify gaps before committing the bundle.

## 14. Post-derivation review (#42 — advisory, SS-2)

After the synthesis waves complete, dispatch ONE read-only review over the bundle. Non-blocking: surface the report,
do not gate. The `derivation-reviewer` agent is structurally read-only (no Write,
no Task) — it returns its full report **in its final message**, and **you (the
orchestrator) persist it**, mirroring how `synthesis-agent`'s `mode:complete`
returns are consumed in §13.2.

```bash
master_hash="$(cksum < "$master" | awk '{print $1"-"$2}')"
bundle="$(sf_resolve_output_path memory_bank .claude/memory-bank)"
claude_path="$(sf_resolve_output_path claude_md CLAUDE.md)"
artifacts="$(printf '%s, %s, %s, %s, %s, %s, %s, %s, %s' \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/00-project-brief.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/01-product-context.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/02-system-patterns.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/03-code-patterns.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/04-tech-context.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/07-constraints.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/08-governance.md)" \
  "$(sf_resolve_output_path memory_bank .claude/memory-bank/index.md)" \
  "$claude_path")"
review_prompt="Review these freshly synthesized memory-bank artifacts: ${artifacts}. Compare against MASTER-SPEC ${master} (cksum:${master_hash}) and EXECUTIVE-SUMMARY ${exec_summary}. Return your review report per your contract."
Task(subagent_type="scaffold-onboard:derivation-reviewer",
     description="Review memory-bank derivation",
     model="claude-sonnet-4-5",
     prompt="$review_prompt")
```

On `review-complete`: write the returned report body (the markdown table the agent
emitted — NOT the trailing sentinel JSON) to `${bundle}/derivation-review.md`,
print the report path + a one-line summary, and for each `regenerate <file>` finding
surface `/scaffold-project --regenerate` plus the single artifact name to
re-dispatch internally through the §13.2 per-artifact loop. The user decides;
nothing is auto-applied and no public per-file flag is introduced in SS-2.

**Targeted regenerate (apply path):** keep the user-facing CLI aligned with §9's
documented boolean `--regenerate`. Per-file targeting is an orchestration action:
re-dispatch just that artifact's synthesis brief through the §13.2 loop, then run
the normal validators/fallback for that one file. No new lib or slash-command flag
is required for SS-2.
