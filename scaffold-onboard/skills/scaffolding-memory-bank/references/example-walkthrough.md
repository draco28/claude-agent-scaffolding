# Example walkthrough: `/scaffold-project` on `todo-cli`

A concrete trace of `/scaffold-project` deriving the 11-file memory bank + `CLAUDE.md` + `.claude/settings.json` from a closed `MASTER-SPEC.md`. The project is the same **todo-cli** (Rust CLI, `project_class = "CLI tool"`) that the onboarding-project walkthrough finished. We pick up after `/onboard` closed with `phase_10.4.include_karpathy = yes`.

Two variants are shown side-by-side: a **single-repo run** (no workspace-init manifest) and a **dual-repo run** (manifest routes `memory_bank` / `claude_md` / `scaffold_project_outputs` to `ai_workspace`). Both run from the same MASTER-SPEC; the only difference is the routing helper's answer.

---

## Setup (single-repo variant)

```
$ cd ~/work/todo-cli
$ ls
MASTER-SPEC.md  EXECUTIVE-SUMMARY.md  README.md  Cargo.toml  src/
$ /scaffold-project
```

`commands/scaffold-project.md` exports `$ARGUMENTS=""` and routes to `scaffold-onboard:scaffolding-memory-bank`. Skill body runs §1–§9 in order.

---

## Step 1 — Validate MASTER-SPEC + read state

Skill calls:

```bash
spec_path="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
# → /Users/<you>/work/todo-cli/MASTER-SPEC.md  (manifest absent → cwd fallback per §10.3)
sf_spec_validate "$spec_path"
# → exit 0 (clean spec — onboarding-project's close-depth critic already cleared it)
```

Then reads the Karpathy opt-in:

```bash
karpathy_answer="$(sf_state_read_answer phase_10.4.include_karpathy)"
# → "yes"
```

`include_karpathy=true` is folded into the CLAUDE.md template arg list. Any value other than the literal string `yes` would have produced `include_karpathy=false` (per §6 — `null`, `no`, missing state file all treated as opt-out).

---

## Step 2 — Manifest-aware routing decision

Skill calls `sf_discover_manifest`. The walk from `~/work/todo-cli/` reaches `/` without finding a `.workspace/pairing.json`. Single-repo fallback engages (SPEC §10.3). All three logical names resolve to cwd:

```bash
memory_bank_dir="$(sf_resolve_output_path memory_bank .claude/memory-bank)"
# → /Users/<you>/work/todo-cli/.claude/memory-bank
claude_md_path="$(sf_resolve_output_path claude_md CLAUDE.md)"
# → /Users/<you>/work/todo-cli/CLAUDE.md
settings_path="$(sf_resolve_output_path scaffold_project_outputs .claude/settings.json)"
# → /Users/<you>/work/todo-cli/.claude/settings.json
```

This is the v0.1.0 byte-identical regression path — the same paths v0.1.0 users have always written to.

---

## Step 3 — Composition refresh + architect-critic probe

Skill calls `sf_compose_refresh`. `composition.json` is refreshed at `${CLAUDE_PLUGIN_DATA}/composition.json`. ai-mentor v2.0 is present in the user's plugin cache → `has_ai_mentor=true`. superpowers is absent → `has_superpowers=false`.

Then the filesystem probe:

```bash
ac_status="$(sf_compose_detect_architect_critic)"
# → "v0.2"   (probe found .../architect-critic/0.2.0/skills/critiquing-spec/SKILL.md)
```

`has_architect_critic=true` is folded into the CLAUDE.md template arg list. Note: architect-critic is NOT recorded in `composition.json` per ac v0.2 settlement #1; filesystem probe only (§8 anti-pattern, §11).

---

## Step 4 — Derive the 11-file memory bank

Skill calls `sf_memory_bank_derive` (no `--force` — first run, nothing to preserve). The helper renders all 11 files using `_memory_bank_args` (timestamp, `project_class=CLI tool`, every `phase_<qid>=<answer>` from the state file, plus gate flags `ui_branch=true` / `dx_branch=true` / `backend_branch=false` / `frontend_branch=false` / `library_branch=false`).

**Files written under `/Users/<you>/work/todo-cli/.claude/memory-bank/`:**

| File | Bucket | Content shape |
|---|---|---|
| `00-project-brief.md` | derived | One-paragraph elevator pitch (sourced from `phase_1.1.1`) + MVP cut (sourced from `phase_1.3.2`). |
| `01-product-context.md` | derived | Users, use cases, ubiquitous language (Phase 1 + Phase 3 answers). Mentions `todo` / `tag` / `done` not `task` / `label` / `complete`. |
| `02-system-patterns.md` | derived | Architecture shape = CLI, async boundaries = none, primary language = Rust, data store = sqlite with FTS5 (Phase 5 post-critic edit). |
| `03-code-patterns.md` | derived | Decomposition (`core/` / `db/` / `cli/` / `bin/`), naming, error-handling notes (Phase 7) — plus the new `## Machine-checkable rules` SECTION SEEDED EMPTY (see Step 5). |
| `04-tech-context.md` | derived | Toolchain (cargo), CI (GitHub Actions), test types (unit + integration + property), pre-merge gates from Phase 9. |
| `05-active-context.md` | live-seed | Initial scaffolding ("Current focus: TBD — replace this as work begins"). PRESERVED on re-derive. |
| `06-progress.md` | live-seed | Initial scaffolding ("Phase 0: scaffolding complete. Phase 1: TBD."). PRESERVED on re-derive. |
| `07-constraints.md` | derived | Phase 4 (no PII, no auth, no network) + Phase 8 (cargo + Homebrew distribution constraints). |
| `08-governance.md` | derived | Pre-merge gates, success metric (100 installs in 60 days), risk register summary. |
| `index.md` | derived | Tier-2 entry point with relative links to 00–08 + WORKFLOW. |
| `WORKFLOW.md` | static | Copy-once from `templates/memory-bank/WORKFLOW.md` — project-agnostic, never re-rendered. |

The 8 derived files re-render and overwrite on `/scaffold-project` re-runs (idempotent for unchanged spec). The 2 live-seed files are emitted with starter content on first run and preserved on every subsequent run unless `--regenerate` is passed AND the user confirms (§4 + §9). `WORKFLOW.md` is copy-once regardless of `--regenerate` (§4 helper contract; `--force` does not touch it).

---

## Step 5 — R2 rules section seeded EMPTY in `03-code-patterns.md`

Near the end of `03-code-patterns.md`, the v0.2 template emits exactly this block:

```markdown
## Machine-checkable rules
<!-- TODO: add machine-checkable rules.
     Use `Skill(scaffold-onboard:authoring-machine-checkable-rules)` for guided authoring,
     or hand-author per SPEC §8.2 grammar (HTML-sentinel `<!-- mcrule:start type=... -->` blocks).
     scaffold-dev's `implementation-checking` skill consumes the rules at PR-verification time. -->
```

Heading + invitation comment only. **Zero `<!-- mcrule:start` sentinels are emitted by this skill.** Authoring rules is the responsibility of `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5) — that skill inserts `<!-- mcrule:start type=<T> --> ... <!-- mcrule:end -->` blocks between this heading and the next `## ` heading. Lane discipline matters: eval S2 explicitly fails any rule block emitted from this skill.

The fenced-block alternative (` ```mcrule ... ``` `) was drafted and rejected during v0.2 SPEC review — fence boundaries are invisible to Claude in rendered markdown, breaking the human/machine dual-readability requirement. Never emit fenced rule blocks even as examples (§5, §11).

---

## Step 6 — CLAUDE.md with tiered structure + Karpathy section

Skill calls `sf_claude_md_generate` with the assembled template args:

```
include_karpathy=true
has_ai_mentor=true
has_superpowers=false
has_architect_critic=true
project_class="CLI tool"
# ...plus all phase_<qid>=<answer> entries
```

The rendered `CLAUDE.md` at `/Users/<you>/work/todo-cli/CLAUDE.md` has the tiered structure:

1. **Tier-0 router preamble** — points at `.claude/memory-bank/index.md` as the canonical context entry point.
2. **Plugin-awareness blocks** — `{{#if has_ai_mentor}}` block emitted (suggests `Skill(ai-mentor:grill-me)` and `Skill(ai-mentor:council)` when surfacing major design questions); `{{#if has_architect_critic}}` block emitted (suggests `Skill(architect-critic:critiquing-spec)` for adversarial review on spec / patterns hand-edits); `{{#if has_superpowers}}` block OMITTED (superpowers absent).
3. **Karpathy section** (because `include_karpathy=true`) — emitted verbatim per §6 of the skill body:

   ```markdown
   ## Behavioral Discipline (Karpathy-inspired)

   *Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)*

   1. **Think Before Coding** — state assumptions, surface ambiguity, ask before guessing.
   2. **Simplicity First** — minimum code, no speculative abstractions.
   3. **Surgical Changes** — touch only what's needed, no orthogonal refactors.
   4. **Goal-Driven Execution** — vague asks → verifiable success criteria.
   ```

   The attribution line is verbatim — `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)` — never rephrased to "Karpathy's CLAUDE.md" or similar. Attribution is to Chang (the MIT-licensed `forrestchang/andrej-karpathy-skills` repo that distilled the principles), not directly to Karpathy.

4. **Project-specific guidance section** — short project-class-tailored prose (CLI tool conventions: prefer single-binary, use `clap` for parsing, keep stderr / stdout discipline, exit-code conventions).

---

## Step 7 — `.claude/settings.json`

Skill calls `sf_claude_settings_generate`. The file at `/Users/<you>/work/todo-cli/.claude/settings.json` is a v0.1.0-byte-identical baseline (permissions allowlist for `cargo`, `git`, `grep`, etc. — project-class-aware). v0.2 does not extend this content; it only re-routes the destination via `sf_resolve_output_path scaffold_project_outputs ...`.

---

## Step 8 — Dual-repo variant (manifest present, routes to ai_workspace)

Same MASTER-SPEC, same state, but the layout is:

```
~/work/todo-cli-pair/
├── canonical/
│   ├── .workspace/pairing.json
│   ├── MASTER-SPEC.md
│   ├── Cargo.toml
│   └── src/
└── ai_workspace/
    └── (empty — will receive memory-bank etc.)
```

`.workspace/pairing.json` includes:

```json
{
  "routing": {
    "memory_bank": "ai_workspace",
    "claude_md": "ai_workspace",
    "scaffold_project_outputs": "ai_workspace",
    "master_spec": "canonical"
  }
}
```

cwd at trigger time is `~/work/todo-cli-pair/canonical/`. `sf_discover_manifest` walks up, finds `.workspace/pairing.json`, returns the manifest path. Resolution becomes:

```bash
sf_resolve_output_path memory_bank .claude/memory-bank
# → /Users/<you>/work/todo-cli-pair/ai_workspace/.claude/memory-bank
sf_resolve_output_path claude_md CLAUDE.md
# → /Users/<you>/work/todo-cli-pair/ai_workspace/CLAUDE.md
sf_resolve_output_path scaffold_project_outputs .claude/settings.json
# → /Users/<you>/work/todo-cli-pair/ai_workspace/.claude/settings.json
sf_resolve_output_path master_spec MASTER-SPEC.md
# → /Users/<you>/work/todo-cli-pair/canonical/MASTER-SPEC.md   (read source from canonical)
```

The 11 memory-bank files land under `<ai_workspace>/.claude/memory-bank/`. CLAUDE.md lands at `<ai_workspace>/CLAUDE.md`. `<canonical>/.claude/memory-bank/` is never created (no double-write). MASTER-SPEC.md is read from canonical but never mutated.

---

## What this walkthrough demonstrates

- The 11-file shape is preserved byte-for-byte from v0.1.0 (8 derived + 2 live-seed + 1 static) — v0.2 changes routing and adds two new behaviors (R2 section seed, conditional Karpathy section); the doc-set cardinality and bucket assignments are unchanged.
- `## Machine-checkable rules` is seeded as heading + invitation comment only; the section is intentionally empty of `<!-- mcrule:start -->` blocks at scaffold time.
- Karpathy emission is gated strictly on the literal string `yes` for `phase_10.4.include_karpathy`. Attribution is verbatim and points at Chang (MIT) — not directly at Karpathy.
- ai-mentor + superpowers detection flows through `composition.json` (refreshed via `sf_compose_refresh`). architect-critic detection is a separate filesystem probe (`sf_compose_detect_architect_critic`) and never enters `composition.json`.
- Manifest-present and manifest-absent both route through `sf_resolve_output_path` — never hardcode `.claude/memory-bank/` or `CLAUDE.md` against `$(pwd)`.
- Edge cases (re-derive over existing files, manifest schema gaps, Karpathy opt-out, user-edited rules, stale composition) live in `references/edge-cases.md`.
