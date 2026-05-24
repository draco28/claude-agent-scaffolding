---
name: scaffolding-memory-bank
description: Deterministically derive the 11-file memory bank + CLAUDE.md + .claude/settings.json from MASTER-SPEC.md. Use this when the user wants to scaffold the memory bank, derive memory bank artifacts, set up project memory, run /scaffold-project, or regenerate the project's tiered-context router after MASTER-SPEC changes. Seeds the R2 Machine-checkable rules section as empty (heading + invitation only — rule authoring is a separate skill), routes outputs via the workspace-init manifest when present, and conditionally emits the Karpathy Behavioral Discipline section in CLAUDE.md based on the Phase 10 opt-in answer.
---

# scaffolding-memory-bank

You wrap scaffold-onboard's v0.1.0 derivation pipeline (memory bank → CLAUDE.md → .claude/settings.json) and add three v0.2-specific responsibilities: manifest-aware routing, R2 rules-section seeding, and conditional Karpathy emission. The 11-file memory bank that v0.1.0 users know is preserved byte-for-byte where it can be — your job is to thread the new behaviors through without breaking that contract.

Bash helpers in `lib/memory-bank.sh`, `lib/routing.sh`, `lib/compose.sh`, and `lib/render.sh` do the I/O: state reads, template substitution, atomic writes, manifest resolution, filesystem probes. The judgment work — deciding when MASTER-SPEC is too thin to derive from, how to surface a routing destination to the user, whether to suggest composition-aware companions — happens here, in conversation.

---

## 1. Overview

When invoked, you read `MASTER-SPEC.md`, validate it with `sf_spec_validate`, and derive the 11-file memory bank under `.claude/memory-bank/` at the destination resolved by `sf_resolve_output_path memory_bank ...`. Eight files come from MASTER-SPEC (00–04, 07, 08, `index.md`). Two are live-seed (`05-active-context.md`, `06-progress.md`) — emitted only when missing, preserved on re-derive. One is static (`WORKFLOW.md`, copy-once). You then emit `CLAUDE.md` (with optional Karpathy section) and `.claude/settings.json`, each routed via its own logical name. Inside `03-code-patterns.md` you seed an empty `## Machine-checkable rules` section — heading plus invitation comment, zero rule blocks.

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
3. **State file present (recommended, not required).** `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` provides the Phase-10 Karpathy opt-in answer (`phase_10.4.include_karpathy`) and the gate flags that drive conditional template substitution. If the state file is absent (user hand-authored MASTER-SPEC outside `/onboard`), proceed with defaults: treat Karpathy opt-in as `no`, treat all branching gates as false unless inferred from MASTER-SPEC content. Surface one warning: *"No onboarding state file found — proceeding with conservative defaults. Re-run after `/onboard` to enable conditional CLAUDE.md sections."*

---

## 4. Derivation flow (11 files, three behaviors)

The 11-file memory bank is preserved from v0.1.0. Each file falls into one of three behavioral buckets:

| Bucket | Files | Behavior on first run | Behavior on re-derive |
|---|---|---|---|
| Derived | `00-project-brief`, `01-product-context`, `02-system-patterns`, `03-code-patterns`, `04-tech-context`, `07-constraints`, `08-governance`, `index` (8 files) | Render from `templates/memory-bank/<f>.md.tmpl` with MASTER-SPEC-derived args | Re-render and overwrite (idempotent for unchanged spec) |
| Live-seed | `05-active-context`, `06-progress` (2 files) | Render seed content from template | **Preserve existing file** — do not overwrite the user's work |
| Static | `WORKFLOW.md` (1 file) | Copy verbatim from `templates/memory-bank/WORKFLOW.md` | Copy only if missing |

**Helper:** `sf_memory_bank_derive` (lib/memory-bank.sh) implements all three behaviors. It accepts an optional `--force` flag that overrides the live-seed preservation (use only on explicit `/scaffold-project --regenerate`); `--force` does NOT overwrite WORKFLOW.md, which is project-agnostic and never warrants regeneration.

**Discipline:**

- Always confirm with the user before passing `--force`. Live-seed files often hold weeks of in-flight context (`05-active-context.md` is the daily working scratchpad); silently overwriting them is a data-loss bug.
- The 8 derived files share a substitution arg-list assembled by `_memory_bank_args` (timestamp, project_class, every state answer prefixed `phase_<qid>=`, and gate flags `ui_branch`, `dx_branch`, `backend_branch`, `frontend_branch`, `library_branch`). Do not re-inline that logic here; call the helper.

---

## 5. R2 rules section seeding (NEW in v0.2)

Inside `03-code-patterns.md`, the v0.2 template adds a new section near the end:

```markdown
## Machine-checkable rules
<!-- TODO: add machine-checkable rules.
     Use `Skill(scaffold-onboard:authoring-machine-checkable-rules)` for guided authoring,
     or hand-author per SPEC §8.2 grammar (HTML-sentinel `<!-- mcrule:start type=... -->` blocks).
     scaffold-dev's `implementation-checking` skill consumes the rules at PR-verification time. -->
```

**Critical:** this skill **seeds** the section — it emits the heading and the invitation comment only. It does NOT emit any actual `<!-- mcrule:start -->` rule blocks. Authoring rules is the responsibility of `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). Keep the lanes clean:

- Your output (this skill): zero `<!-- mcrule:start` sentinels in any derived file. Just the heading and invitation comment.
- Skill 5.5's output (later): one or more `<!-- mcrule:start type=<T> -->` ... `<!-- mcrule:end -->` blocks inserted between the heading and the next `## ` heading.

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
| `memory_bank`               | `ai_workspace`      | this skill — each of the 11 files routes through this name |
| `claude_md`                 | `ai_workspace`      | this skill — CLAUDE.md routes through this name |
| `scaffold_project_outputs`  | `ai_workspace`      | this skill — `.claude/settings.json` and other catch-all `/scaffold-project` outputs route through this name |

**Helper:** `sf_resolve_output_path <logical_name> <relative_path>` (lib/routing.sh):

```
memory_bank_dir="$(sf_resolve_output_path memory_bank .claude/memory-bank)"
claude_md_path="$(sf_resolve_output_path claude_md CLAUDE.md)"
settings_path="$(sf_resolve_output_path scaffold_project_outputs .claude/settings.json)"
```

For each of the 11 memory-bank files, resolve per-file:

```
brief_path="$(sf_resolve_output_path memory_bank .claude/memory-bank/00-project-brief.md)"
patterns_path="$(sf_resolve_output_path memory_bank .claude/memory-bank/03-code-patterns.md)"
# ...etc for the other 9
```

Behavior:

- **Manifest present** (walked up from `pwd` to find `.workspace/pairing.json`): returns the absolute path with the logical destination's root expanded (e.g., `<ai-workspace>/.claude/memory-bank/03-code-patterns.md`).
- **Manifest absent** (single-repo mode): returns `$(pwd)/<relative_path>` — exactly v0.1.0 behavior. v0.1.0 byte-identical regression tests pass through this fallback.
- **Manifest present but logical name missing** from `routing.*`: helper warns once and falls back to `$(pwd)/<relative_path>`. Forward-compatible with workspace-init manifests that pre-date a logical-name addition.

Always route through `sf_resolve_output_path` — never hardcode `.claude/memory-bank/` or `CLAUDE.md` against the cwd. The v0.1.0 derivation helpers (`sf_memory_bank_derive`, `sf_claude_md_generate`, `sf_claude_settings_generate`) currently write relative to `$(pwd)`; in v0.2, prefer wrapping their calls inside a directory that is the resolved destination (e.g., `pushd "$(sf_resolve_output_path memory_bank .)" && sf_memory_bank_derive && popd`) — or pass the resolved path through if the helper signature accepts it. Treat the helper as the single point of truth.

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

- *(no flag)* — derive memory bank; preserve live-seed files (`05-active-context.md`, `06-progress.md`); skip WORKFLOW.md if present; route via manifest if present, else `$(pwd)`.
- `--regenerate` — pass `--force` to `sf_memory_bank_derive`. Overwrites live-seed files (with explicit user confirmation). Does NOT overwrite WORKFLOW.md (static, project-agnostic). Always asks confirmation before clobbering `05-active-context.md` / `06-progress.md` — surface the path(s) that will be overwritten and require an explicit `yes`.

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` directly. If `$ARGUMENTS` contains a flag this skill doesn't recognize, surface a one-line error listing the supported flags and stop — do not silently ignore.

---

## 10. Bash bookkeeping helpers (the bookkeeping-vs-judgment line)

This skill never bash-orchestrates the judgment work (whether to overwrite live-seed, whether to suggest a composition companion, how to phrase the destination prompt). It calls helpers for I/O and templating only.

**Memory-bank derivation (lib/memory-bank.sh):** `sf_memory_bank_derive` (with optional `--force`), `sf_claude_md_generate`, `sf_claude_settings_generate`, `_memory_bank_args` (internal), `_composition_args` (internal).

**Rendering (lib/render.sh):** `sf_render` (generic template substitution — used by the derivation helpers; rarely called directly from this skill).

**Routing (lib/routing.sh):** `sf_resolve_output_path`, `sf_discover_manifest`.

**Composition (lib/compose.sh):** `sf_compose_refresh`, `sf_compose_detect_architect_critic`.

**State (lib/state.sh):** `sf_state_read_answer` (read the Karpathy opt-in), `sf_state_gate_passes` (re-used inside `_memory_bank_args` to set the branching gate flags — you don't call it directly here).

**Validation (lib/parser.sh):** `sf_spec_validate`.

These are pseudocode references — the implementations are in their respective lib files. macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 11. Anti-patterns (do not do these)

- **Inlining the 11-file template content in this skill body.** The templates live in `templates/memory-bank/` and `templates/claude-md/`. Pulling them in here inflates the body past the ≤500-line guidance and creates two sources of truth.
- **Emitting actual `<!-- mcrule:start -->` rule blocks from this skill.** R2 section seeding is heading-plus-invitation only. Rule authoring belongs to `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). Lane discipline matters — eval scenario S2 will FAIL on any rule block emitted by this skill.
- **Using the fenced-block mcrule alternative** (e.g., ` ```mcrule ... ``` ` fences). The v0.2 grammar is HTML-sentinel only (SPEC §8.2). Fenced blocks were drafted and rejected because their boundaries are invisible in rendered markdown.
- **Overwriting live-seed files (`05-active-context.md`, `06-progress.md`) silently on re-derive.** Always preserve unless `--regenerate` is explicit AND the user has confirmed. These files hold the user's in-flight work; silent clobber is a data-loss bug.
- **Overwriting WORKFLOW.md on `--regenerate`.** It's static project-agnostic content; the v0.1.0 helper deliberately treats it as copy-once. `--force` doesn't touch it.
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
