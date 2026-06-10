# Session Handoff — SS-7 SHIPPED (scaffold-onboard v0.8.0) · agent-driven-only derivation complete for scaffold-onboard

**Date:** 2026-06-10 · **Author:** prior session (SS-7 PR #62 review-to-merge) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sub-spec sequence + §6 ledger). This handoff is the delta on top of it and on top of `2026-06-10-post-ss7-in-review.md` (which is now stale — it described SS-7 as in-review; SS-7 is merged).

---

## 1. What this session did (one line)

Took **SS-7** (remove the deterministic `--fast` fallback, #56) from open-PR-in-review to **merged + tagged**: triaged + fixed **3 rounds of bot review** (Codex 5+5+3 P2 + CodeRabbit), pushed back where warranted, deferred one edge case to **#63**, then squash-merged **PR #62 → `83fabba`**, tagged **`scaffold-onboard-v0.8.0`**, **#56 CLOSED**.

---

## 2. ⚠️ FIRST ACTION NEXT SESSION: pick the next sub-spec (SS-7 is DONE)

SS-7 is fully shipped — there is **no carry-forward fix work** from it. The next session starts a fresh sub-spec cycle. Recommended order (see §5 for why):

1. **SS-5** (#47 — optional Codex implementation/synthesis backend) — **strongest next candidate.** SS-3 + SS-7 left every synthesis brief + dispatch path **tool-agnostic**; wiring the Codex backend (`implementer_backend ∈ {claude_subagent, codex}`, `codex-companion.mjs`) is the natural follow-on for the synthesis side. NOTE the boundary lesson in §4 applies here.
2. **SS-4** (#52/#7/#5/#48-F) — agent-review of scaffold-dev's verification seams (anti-pattern C).
3. **SS-6** (#8/#9/#6/#10/#37/#38/#39/#48-rem/#53) — standalone cleanup-to-zero; interleave.

Run each through its own `brainstorm → writing-plans → executing-plans → bot-review → release` cycle.

**Also queued (small, optional):** **#63** — the one SS-7 edge case deferred during review (see §3). Cheap-ish, owns a clean fix direction; could be folded into SS-6 or done standalone.

---

## 3. SS-7 — what shipped + the review story 🔧

**Merge:** PR #62 squash-merged to `main` as `83fabba` · tag `scaffold-onboard-v0.8.0` (on the merge commit, pushed) · **#56 auto-closed** (PR body `Closes #56`) · SPEC ledger N6 = CLOSED (already on the branch, landed with the squash).

**The product change (recap):** agent synthesis is the **only** content-derivation path. Removed `--fast` / `sf_synth_mode` / `SF_SYNTH_FAST` and all deterministic content renderers (`sf_memory_bank_derive`, `sf_docs_derive` + `lib/docs.sh`→stub, the two EXEC-SUMMARY renderers). Uniform agent-unavailable model on every content surface: **dispatch → main-context-inline → re-dispatch-once → hard-fail with remediation.** Mechanical helpers kept for non-reasoning facts (seed live/static, harvest migration, mcrules-zone preserve, the guarded EXEC-SUMMARY write-back, and the structured router files — see §4).

**Review: 3 rounds, converged clean.** Codex does NOT auto-fire here — each round was a manual `@codex review`.
- **Round 1 (5 Codex P2 + 2 CodeRabbit):** the 2 high-severity ones — (a) `--regenerate` **data loss**: the §13 harvest migration ran in a forking `( cd … )` subshell so the global `_SF_MB_MIGRATED_TO_KNOWN_ISSUES` flag never reached the separate `--force` seed subshell → migrated `09-known-issues.md` was clobbered → fixed with non-forking `pushd/popd`; (b) **Karpathy opt-in lost**: CLAUDE.md had been a *synthesized* artifact since v0.3 via `CLAUDE.brief.md`, which never handled the Karpathy opt-in or composition gates — `--fast`'s deterministic path was the ONLY thing honoring them → fixed by making **CLAUDE.md mechanically generated** (see §4). Plus EXEC-SUMMARY full-spec wording, roadmap fallback, governance-fixture routing, FAST-guard widening.
- **Round 2 (5 Codex P2):** all consistency follow-ons to round-1 — §13 opening still mislabeled CLAUDE.md as synthesized; the mechanical CLAUDE.md write needed routing via the `claude_md` root; the `pushd` needed a real hard-stop (`sf_log_error` only logs, doesn't exit); EXEC-SUMMARY produce-once consumer block (both skills); roadmap §16.2 needed the re-dispatch-once the §16 intro promised.
- **Round 3 (3 Codex P2):** sourced `lib/compose.sh` in §13 setup (the new mechanical `sf_claude_md_generate` → `_composition_args` → `sf_compose_detect_architect_critic` was otherwise undefined, swallowed by `|| true`, dropping the `/critique` block); **pushed back** on "hard-fail the consumer EXEC-SUMMARY" (see §4); **deferred** the duplicate-rules edge case → **#63**.
- **Round 4:** Codex review on the latest commit (`f797e58`) returned with **zero inline findings** — the convergence/merge signal per `feedback_bot_review_convergence_judgment`. CodeRabbit check SUCCESS; its only Critical (the pushd one) it auto-marked "✅ Addressed."

**Commits on the merged branch (squashed):** 18 build tasks + 3 review-fix commits `9b4a405` (round-1), `eca8e32` (round-2), `f797e58` (round-3).

**#63 (deferred, `scaffold-onboard,deferred`):** the `03` mcrules-zone fallback, when the synthesis omits the `mcrules:preserve` sentinels but still emits a `## Machine-checkable rules` heading, **appends** the saved sentinel-wrapped zone → a **duplicate** heading. The rule-authoring skill inserts into the *first* (un-sentinelled) heading, but the next `--regenerate` extracts only the *later* sentinel-wrapped zone → newly authored rules dropped. Pre-existing (SS-1 W2 logic), narrow trigger. Fix direction in the issue: a `reinject-or-replace` lib helper (strip any existing rules section before writing the saved zone) + `test-memory-bank` coverage. Not a regression from this PR; the now-mandatory corrective re-dispatch-once makes the trigger rarer.

---

## 4. Durable design decisions / lessons from SS-7 (apply next session) ⭐

- **BOUNDARY: an "agent-only / remove all determinism" pivot does NOT make every file agent-authored.** Structured/conditional **router files stay mechanical**: `CLAUDE.md` (composition gates `{{#if has_*}}` + the **verbatim** Karpathy attribution + the `phase_10.4.include_karpathy` opt-in), `.claude/settings.json`, and the AGENTS.md managed section. They're generated by `sf_claude_md_generate` / `sf_claude_settings_generate` / `sf_agents_md_generate`, NOT synthesized. **The line is: prose-content → synthesize; structured-router-with-verbatim-or-gated-content → mechanical.** A synthesis agent can't reliably reproduce a verbatim attribution string or thread composition gate values. (CLAUDE.md was wrongly in the synthesized "9-artifact" wave since v0.3; SS-7 dropped it to 8, generates it in the §13 finalize, deleted the orphan `CLAUDE.brief.md`.) **This directly governs SS-5** (Codex backend): the Codex synthesis path must NOT try to author these router files either.
- **CONSUMER ≠ PRODUCER for optional artifacts.** EXEC-SUMMARY's authoritative **producer** is onboarding §8 (dispatch → inline-if-headless → re-dispatch-once → **hard-fail**). The **consumer** produce-once-if-missing in `/scaffold-project` (memory-bank §13.1) and `/scaffold-docs` (governance setup) is **best-effort** per SS-7 spec §4: **no inline fallback when headless, no hard-fail** — EXEC-SUMMARY is optional enriching context there; MASTER-SPEC is the SSoT, so it warns and derives from MASTER-SPEC only. Codex pushed for hard-fail; I pushed back (hard-failing would break headless `/scaffold-project` on legacy projects) and made the asymmetry explicit in both skills. If you ever touch this, keep the asymmetry.
- **Bot-review convergence held exactly** (`feedback_bot_review_convergence_judgment`): Codex auto-posts a per-commit review; the round where the **latest commit's review has zero inline findings** is the merge signal. Don't wait for CodeRabbit-clean (asymptotic on prose-heavy PRs) — its substantive findings land in the first 1-2 rounds, then it just confirms. Triage every finding against the code (don't trust badges); fix genuine bugs + cheap wins, **push back with spec/code rationale** on the wrong ones, **defer scope-y/pre-existing items to a filed issue** with a fix direction.
- **`sf_log_error` only logs — it does not exit.** Any `cmd || sf_log_error "…"` falls through. Guard control-flow explicitly (`if ! cmd; then sf_log_error …; return 1; fi`).
- **Test-strategy reminder (SS-7's template, unchanged):** bash can't run a live agent, so memory-bank/governance/e2e assert the **mechanical layer** via canned-synthesis fixtures (`seed_memory_bank_synth_fixture`, `seed_governance_docs_fixture` — the latter now routes via `sf_resolve_output_path` with the real §11 logical names); content-correctness rides on the `evals/` LLM-judge. Dispatch-skill prose is guarded by **grep-style assertions** in `test-synthesis-dispatch.sh` (e.g. the new non-forking-migration guard, the CLAUDE.md-mechanical-and-routed guard). When you change dispatch prose, expect to update those greps.

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):**
- SS-1 ✅ (#45) · SS-2 ✅ (#50/#49/#42) · SS-3 ✅ (#51) · #59 ✅ (v0.6.1) · #58 ✅ wontfix (v0.7.0) · **SS-7 ✅ SHIPPED (#56 → v0.8.0)**
- **SS-4** — agent-review of verification seams (#52, #7, #5, #48-F). Independent. Designed-not-started.
- **SS-5** — Codex implementer/synthesizer backend (#47). Independent. **Inherits SS-3's + SS-7's tool-agnostic synthesis prompts** — strongest next candidate. Honor §4's router-file boundary.
- **SS-6** — standalone cleanup to zero (#8, #9, #6, #10, #37, #38, #39, #48-remainder, #53/CI). Interleave.

**Plugin versions (current main):** workspace-init 0.1.2 · **scaffold-onboard 0.8.0** · scaffold-dev 0.3.0 · architect-critic 0.2.2 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Open backlog (14):** #63 (SS-7 deferred edge case, NEW) · #53 (CI/SS-6) · #52 (SS-4) · #48 (F→SS-4, routing→SS-6) · #47 (SS-5) · #39/#38/#37 (SS-6 external-benchmark trio) · #10/#9/#8/#7/#6/#5 (SS-4/SS-6 buckets).

---

## 6. Process notes / environment (unchanged but load-bearing)

- **Codex does NOT auto-trigger on this repo's PRs** — always comment `@codex review` and wait (~8-10 min/round). It posts a per-commit **review** (state COMMENTED) plus inline P2 comments; reply in-thread via `gh api repos/draco28/claude-agent-scaffolding/pulls/<pr>/comments/<id>/replies`.
- **Suites are slow** (55-75s/file; per-project git/cksum cost) — run `cd scaffold-onboard && bash run-tests.sh` (→ 18 files / 0 failed) in the background with a generous window. Repo-root **dual-publish** is separate: `bash tests/test-codex-dual-publish.sh` (→ 148/0) — run it after any version bump (it's the version-parity/frontmatter guard, NOT under the plugin's own `tests/`).
- **Handoffs in this source repo are manual** (`docs/agent-driven-program/handoffs/`) — the `/handoff` skill refuses (no `.workspace/pairing.json`). Commit them to `main` directly.
- **`bin/sf` sources all `lib/*.sh`** in production, but the dispatch-skill **setup snippets list explicit `source` lines** — the orchestrator follows those, so a helper that needs a new lib (e.g. `compose.sh` for `sf_claude_md_generate`) must have it added to the §13/§11 setup, not just rely on `bin/sf`.

---

## 7. Recommended next-session entry points

1. **SS-5** (#47, Codex backend) — brainstorm → spec → plan → build. Inherits the tool-agnostic briefs; **must respect §4's router-file boundary** (don't synthesize CLAUDE.md/settings.json/AGENTS.md on the Codex path either).
2. **SS-4** (#52/#7/#5/#48-F) — agent-review of scaffold-dev's verification seams.
3. **SS-6** (#8/#9/#6/#10/#37/#38/#39/#48-rem/#53) — cleanup-to-zero; #63 can ride here.

Target remains: zero open backlog. The agent-driven-only stance is now **complete for scaffold-onboard derivation** (SS-7 finished it); SS-5 extends it cross-tool (Codex), SS-4 extends the principle to scaffold-dev's verification seams.
