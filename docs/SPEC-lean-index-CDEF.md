# SPEC — Lean-index deep-reference channels (scaffold #48: Parts C–F + 2 follow-ups)

**Date:** 2026-06-20 · **Plugins:** `scaffold-dev` + `scaffold-onboard` + `workspace-init`
**Issue:** [#48](https://github.com/draco28/claude-agent-scaffolding/issues/48) — *#33 follow-ups: lean-index Parts C–F + /defer marketplace routing + label auto-create*
**Companion to:** `docs/SPEC-lean-index-defer.md` (the A+B design-of-record). This spec covers the **remainder** of #33/#48 that A+B deferred.
**Status:** Design approved (brainstorm 2026-06-20, 4 forks settled with user). Next: stage the build per §6 (Stage 1 → Stage 2), each its own `writing-plans → inline TDD → bot-review → release` cycle.

> **Decision lens (binding):** [[feedback_agent_review_over_deterministic_gates]]. The *judgments* in this feature — does a memory entry restate tracked content? does a cited anchor still denote the same thing? which repo does this debt belong to? — are the agent's. Only mechanical I/O is deterministic: file/heading probes, ADR-file globs, `gh`/`git` invocation, manifest reads, idempotent appends. **No brittle deterministic semantic gate** (this is why Part F is *not* an mcrule — see §3.1).

---

## 1. Problem & context

The memory bank tends to accumulate full prose: it overloads, duplicates content already in MASTER-SPEC / SRS / ADRs / issues, and goes stale silently. #33 proposed the cure — **the bank stays a thin index of one-line pointers; depth lives in addressable external stores** (GitHub issues, doc anchors, ADRs, claude-mem). Following a pointer means resolving it, never re-reading re-stored prose.

**Already shipped (do not rebuild):**
- **Parts A + B** (scaffold-dev v0.2.0 / scaffold-onboard v0.3.8, PR #46): `/defer` → templated GitHub issue in the canonical repo + a one-line `[TD] <desc> → #N` pointer in the seeded `tech-debt.md`; two-layer blocker-recall. Design: `docs/SPEC-lean-index-defer.md`.
- **Part F** (scaffold-dev **v0.4.0**, SS-4, 2026-06-12): the lean-index linter, built as a **harvest write-time advisory** — `closing-vertical-slice` SKILL.md §9.4 (`#48-F, write-time prevention`): an agent-judged "restates tracked content?" leg (surface a pointer — `see ADR-0007` / `tracked in #N` — instead of harvesting prose) plus a mechanical length leg `sd_harvest_lint_length` (`lib/harvest.sh`, 3 tests). The program ledger (SPEC §6) already records F as shipped; the **issue #48 body is stale** on this and is reconciled in this cycle.

**This spec's remainder:** Parts C (doc-anchor refs + validator), D (ADR pointers + validator), E (claude-mem pointers, convention-only), plus the two A+B-build follow-ups — marketplace-repo routing for `/defer`, and `tech-debt` label auto-create.

---

## 2. Scope

**In scope (this spec):**
- **C** — `DOC §anchor` pointer convention + a resolution leg that confirms the anchor still exists.
- **D** — ADR-id pointer convention + a resolution leg that confirms the ADR file still exists (product *or* process series).
- **E** — claude-mem topic-pointer **convention only**, gated on claude-mem being present.
- **Follow-up 1** — `/defer --tooling` routes scaffold-tooling debt to a marketplace/tooling repo via a new optional `tooling_repo` manifest field.
- **Follow-up 2** — offer to auto-create the `tech-debt` label on first defer.

**Out of scope / settled non-builds:**
- **Part F mcrule variant.** Part F is *done* (§3.1). The issue *suggested* fitting it into the deterministic `03-code-patterns.md` mcrule DSL, but an mcrule is a deterministic check — exactly the "brittle deterministic semantic gate" the issue's own caveat (and the binding principle) forbid for a *semantic* "restates tracked content" judgment. **No new mcrule type.**
- **A claude-mem validator** (Part E). claude-mem is an optional external plugin, not present in every scaffold project; an automated "does this corpus/query resolve?" check is non-portable. E ships as convention + a presence-gated nudge only.
- **Reworking A+B.** The `/defer` interactive path, `sd_issue_create`/`sd_issue_list`/`sd_remote_check`, round-close sweep, and blocker-recall are untouched except where Follow-ups 1/2 extend them.

---

## 3. Settled design

### 3.1 Part F — DONE (record & reconcile)
No build. Record in this spec that §9.4 + `sd_harvest_lint_length` satisfy Part F, and reconcile the stale issue-body claim (§6 Stage 0). *Optional, cheap:* a one-line recall-time mirror of the §9.4 pointer nudge wherever a session reads a memory entry that restates tracked content — only if it earns its keep during Stage 1; not required for closure.

### 3.2 Pointer-citation conventions (C / D / E)
Reuse existing forms; **do not invent a unified `[ref:…]` DSL**. Each pointer is a lean line in a *dev-authored* memory file (`05`/`06`/`09`/`10`/`tech-debt`) or an inline reference inside a harvested entry.

| Part | Pointer form (lean) | Example |
|---|---|---|
| **C** doc-anchor | `<DOC> §<anchor>` (anchor = section number *or* heading title; optional quoted title) — the **same grammar `verifying-spec-citations` already uses for ARCH §-refs** | `see MASTER-SPEC.md §5.2`, `per SRS.md §FR-5`, `02-system-patterns.md §"Token Lifecycle"` |
| **D** ADR pointer | `ADR-<NNNN>` (uppercase id; never the prose) | `decision recorded — ADR-0003` |
| **E** claude-mem | `claude-mem: "<topic>" [corpus <name>]` — a topic/corpus query, never a transcript | `history: data-pipeline decisions → claude-mem: "data-pipeline" corpus pulse-trader` |

These conventions are documented where pointers are authored: the memory-bank templates (scaffold-onboard) and the harvest nudge (`closing-vertical-slice` §9.4, which already says "surface a pointer instead").

### 3.3 Validator — extend `verifying-spec-citations` (C + D)
The validator lives as **mechanical legs in `scaffold-dev/lib/citations.sh`** (the home of `verifying-spec-citations`' mechanical legs) plus **agent-judged drift legs documented in the skill** — mirroring exactly the existing file/signature (mechanical) vs REQ-ID/ARCH-§ (agent) split. The new legs are reused by the §9.4 harvest nudge (and the optional recall-time mirror) so a stale memory pointer is flagged at the moments pointers are written/followed.

**Leg contracts (mirror the existing `sd_citations_check_file` contract: rc 0 = resolves, rc 1 + `sd_log_warn` on miss, no stdout, manifest-free/pure):**

- **`sd_citations_check_anchor <doc-file> <anchor>`** (Part C, mechanical)
  - rc 0 iff `<doc-file>` exists **and** it contains a markdown heading (`^#{1,6} …`) resolving to `<anchor>` (the anchor token appears in a heading line — a section number like `5.2` or a title fragment). rc 1 + warn otherwise.
  - *Semantic drift* (the heading still denotes what the memory entry claims) is the **agent's** leg — judged in the skill, NOT in this file (same boundary as ARCH-§).

- **`sd_citations_check_adr <adr-id> <adr-dir>…`** (Part D, mechanical)
  - rc 0 iff any supplied `<adr-dir>` contains a file matching the id's numeric portion (`adr-<NNNN>-*.md`, case-insensitive on `ADR-`). rc 1 + warn otherwise.
  - The **caller** resolves the product-ADR and process-ADR dirs from the manifest (`recording-architecture-decision` routing — independent series, so pass **both** dirs) and passes them in. Keeping the helper manifest-free preserves the file's purity and testability (fixture dirs).

### 3.4 Part E — convention-only, presence-gated
- Document the §3.2 claude-mem pointer form in the memory-bank templates + a `closing-vertical-slice` §9.4 nudge line.
- The nudge fires **only when claude-mem is detected** (e.g. a claude-mem corpus/MCP surface is present in the session) — otherwise it is silent, so projects without the plugin see no dead guidance. No automated validator.

### 3.5 Follow-up 1 — marketplace routing (`/defer --tooling`)
- **Manifest (workspace-init):** add an **optional** `tooling_repo` object to `pairing.json` mirroring `canonical`'s sub-schema (`root` / `name` / `git_remote`), written by the init/pair skills and validated when present. Absent by default → today's behavior unchanged.
- **Routing (scaffold-dev):** `/defer --tooling` (flag parsed from `SCAFFOLD_DEV_ARGS` in `deferring-work-item`, passed through `commands/defer.md`) targets the tooling repo instead of canonical. `sd_issue_create` / `sd_issue_list` gain a way to run against a caller-chosen repo root (add an optional repo-root parameter — **do not fork** the primitives); the skill resolves the root via `sd_manifest_get '.tooling_repo.root'` when `--tooling` is set.
- **Degrade:** `--tooling` with no `tooling_repo` in the manifest → actionable error ("no tooling_repo configured; re-run without --tooling to file to canonical, or add tooling_repo via workspace-init"), no silent mis-file.

### 3.6 Follow-up 2 — `tech-debt` label auto-create
- **Helper (scaffold-dev):** `sd_label_ensure <label> [repo-root]` in `lib/pr.sh` — idempotent `gh label create <label>` (no-op if it already exists), rc 0 on present-or-created, rc 1 + message on failure.
- **Skill:** `deferring-work-item` §4 — when the graceful retry-without-label path fires (repo lacks `tech-debt`), **offer** to create the label via `sd_label_ensure` and re-file labeled. The offer is agent-driven and skippable; label setup never blocks recording the debt (the §4 A+B contract stands).

---

## 4. The deterministic / agent split (the spine)

**Agent-driven (judgment):**
- Whether a memory entry restates tracked content → pointer (Part F §9.4 — already shipped).
- Whether a cited `§anchor` / ADR still **denotes** what the entry claims (semantic drift) — the agent leg of C/D, mirroring ARCH-§/REQ-ID.
- Whether a deferral is *project* debt or *tooling* debt is the user's call surfaced via the explicit `--tooling` flag (no agent guessing — see fork-4 settlement).
- Whether to offer/skip label creation.

**Deterministic (mechanical facts only — `lib/citations.sh`, `lib/pr.sh`, `lib/manifest.sh`):**
- `sd_citations_check_anchor`, `sd_citations_check_adr` — file/heading/ADR-file existence.
- `sd_issue_create` / `sd_issue_list` with an optional repo-root; `sd_label_ensure`.
- `sd_manifest_get '.tooling_repo.root'`; manifest validation of the optional field.

No bash judges anchor *meaning* or repo *ownership*; no agent re-implements a file probe.

---

## 5. PR staging & versions

This is the plugin **source** repo (no `.workspace/pairing.json`) — develop with the plain `writing-plans → inline TDD → bot-review → release` flow; manual handoff committed to `main`.

- **Stage 0 — this spec (commit to `main`, no PR).** Author this doc; reconcile program SPEC §6 row + issue #48 body (Part F done).
- **Stage 1 — PR: Parts C + D + E.** scaffold-dev **minor** (`sd_citations_check_anchor` + `sd_citations_check_adr` + `test-citations.sh`; `verifying-spec-citations` + `closing-vertical-slice` §9.4 prose; optional recall mirror) + scaffold-onboard **patch/minor** (memory-bank template pointer conventions + presence-gated claude-mem nudge). Tags on merge.
- **Stage 2 — PR: Follow-ups 1 + 2.** workspace-init **minor** (`tooling_repo` field + init/pair skills + validation) + scaffold-dev **minor** (`/defer --tooling` routing + `sd_label_ensure`). Tags on merge.

Release mechanics per program SPEC §9: bump both `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` (parity enforced by `tests/test-codex-dual-publish.sh`) + README version row → merge → `git tag <plugin>-v<ver>` on the merge commit → push tags.

---

## 6. Testing

- **Per stage: run the FULL suite for each touched plugin** ([[feedback_full_suite_when_verifying_subagents]]) + repo-root `tests/test-codex-dual-publish.sh` after any version bump ([[reference_codex_dual_publish_test_location]]). scaffold-onboard suites are slow (55–75s) — background + generous timeouts ([[feedback_scaffold_onboard_test_suites_are_slow]]).
- **Stage 1 (mechanical, bash asserts in `test-citations.sh`):** `sd_citations_check_anchor` — heading present (numeric + title forms) → rc 0; heading absent → rc 1; missing doc-file → rc 1. `sd_citations_check_adr` — id present in product dir → rc 0; present in process dir → rc 0; absent in both → rc 1; multiple dirs scanned.
- **Stage 1 (agent decisions, LLM-judge evals):** the C/D semantic-drift legs (cited anchor/ADR still denotes the claimed thing); the §9.4 pointer nudge surfaces a pointer not prose; the Part-E claude-mem nudge fires **only when** claude-mem is present.
- **Stage 2 (mechanical, `test-pr.sh` + workspace-init manifest tests):** `tooling_repo` optional/validated/absent; `/defer --tooling` targets the tooling repo while absent-field → canonical fallback + message; `sd_label_ensure` creates-if-missing + idempotent (gh PATH-shim — extend for `label create`).
- **Stage 2 (evals):** `/defer --tooling` routes correctly; the label-create offer is surfaced (not silent) and skippable.

---

## 7. Open items carried into planning
- Exact `§anchor` heading-match rule in `sd_citations_check_anchor` (numeric `§5.2` vs title fragment vs optional quoted title) — keep lean; reuse the ARCH-§ matching intent. Settle in Stage 1 writing-plans.
- `tooling_repo` sub-schema field set + the exact `pairing.json` validation messages — settle in Stage 2 writing-plans (mirror `canonical`).
- Whether scaffold-onboard's Stage-1 change is a patch (doc-only template prose) or minor (new convention surface) — decide at implementation.
- The repo-root parameter shape on `sd_issue_create`/`sd_issue_list` (positional vs `--repo-root`) — pick the least-disruptive at Stage 2 (keep A+B callers byte-compatible).
