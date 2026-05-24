# Edge cases: scaffolding-governance-docs

Non-happy-path scenarios for `/scaffold-docs`. Each entry names the trigger, the helper behavior, and what this skill body should surface. The happy path lives in `example-walkthrough.md`.

---

## 1. Phase 9.3.1 = "no" → 3 LLM-gated docs skipped with reason

**Trigger:** user runs `/scaffold-docs --full` on a project whose state has `phase_9.3.1 = "no"` (no LLM features). This is the typical case for the vast majority of v0.1.0 / v0.2 projects (including the canonical todo-cli walkthrough).

**Helper behavior:** `sf_docs_derive --full` evaluates the LLM gate via `sf_state_read_answer phase_9.3.1`. On `"no"`, the helper logs the skip line to stderr:

```
LLM-gated --full docs skipped (phase 9.3.1 != yes)
```

The 3 templates `EVALS_PLAN.md.tmpl`, `MODEL_CARD.md.tmpl`, `PROMPT_GOVERNANCE.md.tmpl` are NOT rendered; the destination files are NOT written.

**Skill body surfacing (the critical contract):** the skip-with-reason MUST be visible to the user. Silent omission is a documented failure mode (eval S2 fails on it). Surface a block like:

> Skipped 3 LLM-gated docs because Phase 9.3.1 (`uses_llm`) = "no":
>   - `EVALS_PLAN.md` (would route via `product_adrs` → canonical)
>   - `MODEL_CARD.md` (would route via `product_adrs` → canonical)
>   - `PROMPT_GOVERNANCE.md` (would route via `process_adrs` → ai_workspace)
>
> If your project will use LLM features, re-run `/onboard --resume` to flip Phase 9.3.1 to "yes", then re-run `/scaffold-docs --full`.

Name the answer ("no"), name the gate (Phase 9.3.1 / `uses_llm`), name the files. Don't paraphrase.

---

## 2. Manifest absent → all docs route to cwd (single-repo mode)

**Trigger:** user runs `/scaffold-docs` (or `--full`) from a directory with no `.workspace/pairing.json` anywhere up the tree. This is the v0.1.0-equivalent single-repo case.

**Helper behavior:** `sf_discover_manifest` walks from cwd up to `/` without finding `.workspace/pairing.json`. Returns empty. `sf_resolve_output_path` for every logical name (`prd`, `srs`, `backlog`, `project_plan`, `product_adrs`, `process_adrs`) falls back to `$(pwd)/<relative_path>` per SPEC §10.3.

**Result:** all 5 (or 14 with `--full`) docs land under `$(pwd)/docs/...`. The `process_adrs` destination collapses to cwd just like the others — there's no separate ai_workspace tree in single-repo mode. This is **exactly v0.1.0 behavior**; v0.1.0 byte-identical regression tests exercise this path.

**Skill body surfacing:** no manifest-absent warning is needed. Single-repo mode is the documented v0.1.0-equivalent path, not an error condition (per eval S4 assertion in scaffolding-memory-bank).

**Subtle gotcha:** in single-repo mode, `DEFINITION_OF_DONE.md` / `DEMO_RUNBOOK.md` / `PROMPT_GOVERNANCE.md` (the `process_adrs` docs) land at `$(pwd)/docs/...` alongside the product-facing docs. In dual-repo mode they'd be in a different tree entirely (`<ai_workspace>/docs/...`). Users moving from single- to dual-repo will see these 3 files relocate — that's intentional, not a bug.

---

## 3. Re-generate on existing repo (preservation + `--regenerate` opt-in)

**Trigger:** user runs `/scaffold-docs` a second time on a repo where PRD.md / SRS.md / etc. already exist (possibly with hand-edits since the first run).

**Helper behavior (no `--regenerate`):** `sf_docs_derive` honors `sf_docs_preserve_user_files` — for each doc, if the file already exists at the resolved destination, the helper skips re-rendering and preserves the user's content. The skill body surfaces a per-doc preservation summary:

> Preserved 5 existing docs (no `--regenerate` flag):
>   - `docs/PRD.md` — preserved (mtime: 2026-05-22)
>   - `docs/SRS.md` — preserved
>   - `docs/BACKLOG.md` — preserved
>   - `docs/PROJECT_PLAN.md` — preserved
>   - `docs/adr/0001-record-architecture-decisions.md` — preserved
>
> No files written. To overwrite, re-run with `/scaffold-docs --regenerate`.

**Helper behavior (`--regenerate`):** `sf_docs_derive --regenerate` overrides the preservation. Before clobbering, the skill body ALWAYS lists the absolute paths that will be overwritten and requires explicit `yes` confirmation:

> `--regenerate` will overwrite these files:
>   - `/Users/<you>/work/todo-cli/docs/PRD.md`
>   - `/Users/<you>/work/todo-cli/docs/SRS.md`
>   - `/Users/<you>/work/todo-cli/docs/BACKLOG.md`
>   - `/Users/<you>/work/todo-cli/docs/PROJECT_PLAN.md`
>   - `/Users/<you>/work/todo-cli/docs/adr/0001-record-architecture-decisions.md`
>
> All hand-edits since the last `/scaffold-docs` run will be LOST. Type `yes` to proceed, anything else to cancel.

If the user types anything other than `yes`, drop back to the preservation path. This is the same confirmation discipline as scaffolding-memory-bank's live-seed clobber path (§10 anti-patterns + §8 of the skill body) — destructive operations always require explicit `yes`.

---

## 4. `process_adrs` unique routing destination (canonical vs ai_workspace split)

**Trigger:** dual-repo run with `.workspace/pairing.json` present. Manifest has `routing.product_adrs = "canonical"` and `routing.process_adrs = "ai_workspace"` (per SPEC §10.1 defaults).

**Helper behavior:** `sf_resolve_output_path` resolves `product_adrs` → `<canonical>/docs/...` and `process_adrs` → `<ai_workspace>/docs/...`. The 14 `--full` docs split:

- **11 docs to canonical:** `PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `ADR-0001.md`, `RISK_REGISTER.md`, `THREAT_MODEL.md`, `TEST_STRATEGY.md`, `CUTOVER_PLAN.md`, `EVALS_PLAN.md`, `MODEL_CARD.md`.
- **3 docs to ai_workspace:** `DEFINITION_OF_DONE.md`, `DEMO_RUNBOOK.md`, `PROMPT_GOVERNANCE.md`.

**Why `process_adrs` is the outlier:** the 3 process ADRs describe HOW THE TEAM WORKS (Definition of Done, demo runbook, prompt-governance guardrails) rather than what the product IS. Per SPEC §10.1 rationale, that lives in the AI workspace tree alongside memory-bank / CLAUDE.md, separate from the canonical product repo. Most other governance docs (PRD, SRS, etc.) describe the product itself and live in canonical.

**Skill body surfacing:** the close summary should make the destination split visible:

> Wrote 11 docs to `<canonical>/docs/`: PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001, RISK_REGISTER, THREAT_MODEL, TEST_STRATEGY, CUTOVER_PLAN, EVALS_PLAN, MODEL_CARD.
> Wrote 3 process ADRs to `<ai_workspace>/docs/`: DEFINITION_OF_DONE, DEMO_RUNBOOK, PROMPT_GOVERNANCE.

This makes the SPEC §10.1 routing visible to users who may otherwise wonder why their `DEFINITION_OF_DONE.md` is in a different tree.

---

## 5. MASTER-SPEC.md absent → route to /onboard

**Trigger:** user runs `/scaffold-docs` from a directory where `MASTER-SPEC.md` does not exist at the resolved destination (per `sf_resolve_output_path master_spec MASTER-SPEC.md`).

**Helper behavior:** the skill body checks `[ -f "$spec_path" ]` before calling `sf_spec_validate`. On absence, do not proceed — surface the routing prompt and stop (per §2 + §3 of the skill body).

**Skill body surfacing:**

> `MASTER-SPEC.md` not found at `/Users/<you>/work/todo-cli/MASTER-SPEC.md`.
>
> Governance docs are derived from MASTER-SPEC — without it there is nothing to derive. Start onboarding first:
>
>   /onboard
>
> After onboarding closes, re-run `/scaffold-docs` to derive the governance bundle.

Do NOT attempt to scaffold a stub MASTER-SPEC from this skill. MASTER-SPEC authoring is `onboarding-project`'s lane (SPEC §5.1) — this skill is downstream of a closed spec.

**Variant — MASTER-SPEC present but invalid:** if `sf_spec_validate` exits non-zero (broken YAML frontmatter, missing phase marker, unknown `project_class` enum), surface the validator's stderr verbatim and stop (per §3 step 2 + §10 anti-patterns). Templates would otherwise silently emit `{{placeholder}}` artifacts that look complete but aren't. Route the user to `validating-master-spec` (SPEC §5.7) for richer error-with-remediation surfacing.

---

## 6. Unknown flag in `$ARGUMENTS`

**Trigger:** user runs `/scaffold-docs --bogus-flag` or `/scaffold-docs --partial`.

**Helper behavior:** none — flag parsing happens in the skill body (§8). Parse `$ARGUMENTS` in bash; recognize `--full`, `--regenerate`, and the `--full --regenerate` combination. Any other token is unrecognized.

**Skill body surfacing:** emit a one-line error listing the supported flags and stop. Do NOT silently ignore:

> Unrecognized flag(s) in `$ARGUMENTS`: `--bogus-flag`.
>
> Supported flags:
>   /scaffold-docs                 # 5 default docs, preserve existing
>   /scaffold-docs --full          # 5 default + 9 full docs (3 LLM-gated)
>   /scaffold-docs --regenerate    # overwrite existing (asks confirmation)
>   /scaffold-docs --full --regenerate

Silent ignore would be a stealth bug — the user thought they passed a flag that altered behavior, but didn't.

---

## What these edge cases protect

- **Skip-with-reason for LLM gate** keeps the doc-set cardinality contract transparent. Silent omission of 3 docs from a `--full` run would be a stealth content-loss bug.
- **Manifest-absent fallback** preserves v0.1.0 single-repo behavior byte-identically. No warnings, no behavior change.
- **Preserve-by-default + explicit `--regenerate` confirmation** prevents accidental clobber of hand-edits. Users who customize PRD.md / SRS.md keep their work on re-runs.
- **`process_adrs` destination split** is the SPEC §10.1 rationale made visible — process docs live with the AI workspace; product docs live with canonical.
- **Refuse-on-missing-or-invalid-spec** keeps this skill in its lane (downstream of `/onboard`) and avoids the `{{placeholder}}` failure mode.
- **Reject unrecognized flags loudly** instead of silently ignoring — stealth bugs are worse than loud errors.
