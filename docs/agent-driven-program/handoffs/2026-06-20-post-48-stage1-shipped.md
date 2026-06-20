# Session Handoff — #48 Stage 1 SHIPPED (lean-index C/D/E → scaffold-dev v0.9.0 + scaffold-onboard v0.9.2)

**Date:** 2026-06-20 · **Author:** prior session (designed + staged #48; shipped Stage 1 → PR #80) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§5 sub-spec sequence + §6 issue ledger), this session's design-of-record `docs/SPEC-lean-index-CDEF.md`, and the prior handoff `2026-06-20-post-74-shipped.md`. This handoff is the delta: **#48 Stage 1 (Parts C/D/E) is shipped; #48 stays OPEN for Stage 2 (the two follow-ups).**

---

## 1. What this session did (one line)

Designed the whole **#48 remainder** (brainstorm → `docs/SPEC-lean-index-CDEF.md`, 4 forks settled), confirmed **Part F was already done** (v0.4.0; reconciled the stale #48 body), then **built + shipped Stage 1 (Parts C/D/E)** → PR **#80** merged (squash `7c485b1`), **scaffold-dev v0.9.0 + scaffold-onboard v0.9.2** tagged. **Stage 2 (follow-ups) NOT started.**

---

## 2. ⚠️ FIRST ACTION NEXT SESSION

**Build #48 Stage 2 — the two follow-ups** (the only remaining piece of #48). Fully specified in `docs/SPEC-lean-index-CDEF.md` **§3.5 + §3.6** (+ §5 staging, §6 testing). Cross-plugin → its own PR.

1. **Follow-up 1 — marketplace routing (`/defer --tooling`).**
   - **workspace-init:** add an **optional** `tooling_repo` object to `templates/pairing.json.tmpl` mirroring `canonical`'s sub-schema (`root`/`name`/`git_remote`); the init/pair skills write it + validate when present. Absent by default → today's behavior unchanged (no breaking change; mirror how `#39 Phase B` avoided a schema change where possible — but here a new optional field IS the mechanism).
   - **scaffold-dev:** `/defer --tooling` flag parsed in `deferring-work-item/SKILL.md` (passed through `commands/defer.md` via `SCAFFOLD_DEV_ARGS`); resolve the tooling root via `sd_manifest_get '.tooling_repo.root'`; route `sd_issue_create`/`sd_issue_list` to a caller-chosen repo root — **add an optional repo-root param, do NOT fork the primitives** (keep A+B callers byte-compatible). Degrade: `--tooling` with no `tooling_repo` → actionable error ("no tooling_repo configured…"), no silent mis-file.
2. **Follow-up 2 — `tech-debt` label auto-create.** `sd_label_ensure <label> [repo-root]` in `scaffold-dev/lib/pr.sh` (idempotent `gh label create`, rc 0 present-or-created); `deferring-work-item` §4 **offers** it when the graceful retry-without-label path fires. Label setup never blocks recording the debt (the §4 A+B contract stands). Small; rides with F1's scaffold-dev changes.
   - **gh PATH-shim:** extend `scaffold-dev/tests/fixtures/gh-shim/gh` for `label create` (it already handles `issue create`/`issue list`).
3. **Versions:** workspace-init **minor** (0.2.0 → 0.3.0) + scaffold-dev **minor** (0.9.0 → 0.10.0). Tags on merge.

**Develop with the plain `spec/writing-plans → inline TDD → bot-review → release` flow.** This is the plugin **source** repo (no `.workspace/pairing.json`) — scaffold-dev slice/handoff skills refuse here; handoffs are **manual**, committed to `main`.

### Open backlog (8 issues — all enhancement/chore, zero bugs)

| # | Title | Flavor | After Stage 2? |
|---|---|---|---|
| **#48** | lean-index C–F + /defer routing + label auto-create | enhancement | **CLOSES** when Stage 2 ships |
| **#79** | count-aware `auto:` form `expected: ran ≥N` (#74 Option A) | enhancement | stays open |
| **#77** | closing/planning SKILL.md > 500-line cap | chore (grew again this session — §9.4 + §11) | stays open |
| **#76** | direct-mode async review-bundle diff baseline | enhancement (Phase-B follow-up) | stays open |
| **#71** | PR #70 review follow-ups (incl. CI SHA-pin) | chore | stays open |
| **#38** | handoff suggested-skills + artifact-refs + redaction | enhancement (partial / cherry-pick) | stays open |
| **#37** | grill domain-language + ADR thresholds | enhancement (partial / cherry-pick) | stays open |
| **#10** | coordinating-parallel-slices | enhancement (demand-gated) | stays open |

### ⚠️ Unfinished thread carried forward
- **Operator real-Codex smoke** of the #39 async review-gate path is still open (manual; see `2026-06-20-post-74-shipped.md` §2). CI uses the shim only.

---

## 3. What shipped this session 🔧

**Stage 0 (to `main`, no PR):** `docs/SPEC-lean-index-CDEF.md` — design-of-record for the #48 remainder, settling 4 forks (AskUserQuestion): **Part F = done** (no mcrule — the §9.4 harvest check + `sd_harvest_lint_length` from v0.4.0 already IS the agent-assisted shape; reconciled the stale #48 body that still listed F deferred); **validator extends `verifying-spec-citations`**; **Part E convention-only + presence-gated** (claude-mem is optional/non-portable to validate); **marketplace routing via `/defer --tooling` + `tooling_repo` field**. Program SPEC §6 ledger row for #48 updated.

**Stage 1 (PR #80, squash `7c485b1`):**
- **`lib/citations.sh`:** `sd_citations_check_anchor <doc-file> <anchor>` (Part C — heading-only resolution; **boundary-aware** structured tokens so `§FR-5`≠`FR-50` and `§5.2`≠`15.20`; literal title-fragment match; strips matching quotes; empty anchor fails) + `sd_citations_check_adr <adr-id> <adr-dir>...` (Part D — accepts **both** `adr-<NNNN>-*.md` AND scaffold-onboard's seeded `<NNNN>-*.md`; zero-pad-tolerant; manifest-free, caller passes product+process dirs). Extend the existing mechanical(file/sig)/agent(REQ-ID/ARCH-§) split; semantic drift stays the agent's leg. **22 citation tests.**
- **`closing-vertical-slice` §9.4:** the harvest pointer-nudge now names the conventions, **resolution-checks** a surfaced/harvested pointer (no dangling refs), and adds a **presence-gated** claude-mem topic-pointer channel (E).
- **`verifying-spec-citations` §6.2/§11:** document the new legs (ARCH §-ref existence probe can now be mechanized).
- **scaffold-onboard `WORKFLOW.md`:** single-source **Lean-index pointer conventions** section; `09`/`10` headers point to it. Docs-only (v0.9.2).
- Eval **S7** (`closing-vertical-slice`): restate→pointer with resolution check + E gating.

**Review story:** CI green · CodeRabbit pass · Devin pass. **Operator ran Codex locally** to address 2 Codex P2s and pushed `2589a0c`: (1) ADR leg matched only `adr-NNNN` while scaffold-onboard seeds bare `0001-*.md` → accept both; (2) substring anchor match false-resolved `FR-5`→`FR-50` / `5.2`→`15.20` → token-boundary matching. Both verified correct + regression-tested (`test_check_adr_unprefixed_seed_filename`, `test_check_anchor_structured_boundaries`). The GitHub Codex connector did not re-review within ~27 min (timed out, as on #74/#75); merged on the convergence judgment (green + 0 unresolved + both P2s fixed). The 2 stale pre-fix threads were resolved with fix-citing replies.

---

## 4. Durable lessons (apply next session) ⭐

1. **README version-table drift is invisible to CI.** The scaffold-dev/scaffold-onboard README rows had lagged **~6 minor versions** behind `plugin.json` (only architect-critic's row was kept current). `tests/test-codex-dual-publish.sh` guards claude↔codex **manifest** parity, NOT README↔plugin.json. Corrected this PR. **Re-check + bump the README version table every release** (SPEC §9 requires it; nothing enforces it). [[project_friction_log_first_realtest]] #48 Stage 1 lesson 1.
2. **ADR filename forms COEXIST cross-plugin.** scaffold-onboard seeds `docs/adr/0001-record-architecture-decisions.md` (bare), scaffold-dev mints `adr-NNNN-*.md`. Any cross-plugin ADR resolution must accept both — Codex caught this. Verify a review bot's fix against the actual producer before merging.
3. **Mechanical matching on doc structure needs boundary awareness.** Substring match on structured ids/section-numbers false-resolves siblings; token boundaries for structured tokens, literal substring for title fragments.
4. **Convergence with a user-run Codex:** local Codex = same engine as the GitHub connector; once it converges + CodeRabbit/Devin pass + 0 unresolved + findings fixed-and-tested, merge on the convergence judgment when the GitHub Codex re-review times out (~20–27 min). [[feedback_bot_review_convergence_judgment]].

---

## 5. Program state snapshot

**Does Stage 2 / closing #48 close the program? No.** Two distinct things:
- **Closing #48** (Stage 2) retires **one** issue. After it, **7 issues remain open** (#79, #77, #76, #71, #38, #37, #10) — all enhancements/chores, **zero correctness bugs**.
- **Closing the agent-driven program** = the SPEC §6 ledger reaching **zero open backlog** (the North Star, SPEC §1). That requires retiring those 7 too — each either **built** or **consciously wontfix'd / decommissioned** ([[feedback_reconsider_deferred_before_building]] — a dormant feature deserves a fresh value-reconsideration; e.g. **#10** is demand-gated, **#37/#38** are partial cherry-picks that may not earn a full build).

So: **#48 Stage 2 is one more step toward program close, not the close itself.** The program ends when all 8 → 0.

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — final phase, in progress.** All correctness bugs cleared (#74/#66/#63). SS-6 remainder = the #48 Stage-2 follow-ups + the demand-gated/partial enhancements (#10/#37/#38) + chores/follow-ups (#71/#76/#77/#79) + #59 (SS-3 residual polish, "future").

**Plugin versions (current main, HEAD `d3c9c90`):** workspace-init 0.2.0 · scaffold-onboard **0.9.2** · **scaffold-dev 0.9.0** · architect-critic 0.3.0 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Tags this session:** `scaffold-dev-v0.9.0` + `scaffold-onboard-v0.9.2` (both on merge commit `7c485b1`).

**Repo state:** local `main` = origin `main` = `d3c9c90`, clean tree. 0 open PRs. CI green. #48 OPEN (Stage 2). `.claude/` remains untracked locally, as before — **stage specific paths, never `git add -A`**.

---

## 6. Recommended next-session entry points

1. **#48 Stage 2** (the natural continuation) — brainstorm-light is unnecessary (design locked in `SPEC-lean-index-CDEF.md` §3.5/§3.6); go straight to writing-plans → inline TDD for `tooling_repo` field + `/defer --tooling` routing + `sd_label_ensure`. Cross-plugin (workspace-init + scaffold-dev) → one PR. **Closes #48.**
2. After #48: pick the next zero-backlog item — **#77** (SKILL.md cap; the §9.4 + §11 edits this session made closing/verifying-spec-citations a little longer), **#79** (count-aware `auto:` form), **#76** (direct-mode diff baseline), **#71** (CI SHA-pin), or reconsider the deferred trio **#37/#38/#10** (some may be wontfix per the reconsider-deferred lesson).

**Target remains zero open backlog** (8 → 0). All remaining work is enhancement/chore burn-down — no bugs, no architectural blockers.
