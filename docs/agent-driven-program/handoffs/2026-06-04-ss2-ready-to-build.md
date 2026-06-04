# Session Handoff — SS-2 design-locked, critique-hardened & planned; ready to BUILD

**Date:** 2026-06-04 · **Repo:** `claude-agent-scaffolding` (plugin **source** repo — **no** `.workspace/pairing.json`, so scaffold-dev's slice/handoff skills **refuse** here; develop with the plain **subagent-driven-development** superpowers flow. Handoffs are manual `docs/agent-driven-program/handoffs/*.md`.)
**Repo state:** `main` @ `af8f8c6` — all SS-2 design + plan committed **and pushed**; **0 open PRs**; working tree clean except untracked `.claude/` (do NOT commit). SS-1 is **shipped** (tags `scaffold-onboard-v0.4.0`, `scaffold-dev-v0.3.0`; #45 closed).
**Resume by:** reading `docs/agent-driven-program/specs/SS-2-synthesis-live-and-verified.md` (the design-locked, critique-hardened sub-spec) then `docs/agent-driven-program/plans/2026-06-04-ss2-synthesis-live-and-verified.md` (the implementation plan). Then **build SS-2 via `subagent-driven-development`**.

---

## 1. What the prior session did (design + critique + plan — no SS-2 code yet)

- **Shipped SS-1** (memory-bank ownership + single-point cadence) end-to-end: subagent-driven build → 3 bot-review rounds (Codex caught 4 real data-loss-on-upgrade bugs the build missed) → merged PR #54 → tagged → closed #45 → labeled #52/#49/#53 with their sub-specs. Lesson saved: `feedback_test_upgrade_input_class`.
- **Started SS-2.** Resolved the gating **OQ-1** empirically (investigation subagent + verified two load-bearing claims): synthesis is **LIVE-BUT-BUGGY + entirely untested**, not "dark." Then ran `brainstorming` (4 scope forks settled) → wrote the SS-2 sub-spec → ran `architect-critic` **close-depth** (claude self + **Codex fresh-frame**) which cross-confirmed 3 premise-level findings → **hardened the spec** (6 concessions) → wrote the implementation plan via `writing-plans`.
- **Commits on `main` (pushed):** `a11f400` (SS-2 design-lock + OQ-1 resolved in ledger), `f871c96` (critique-hardened spec), `af8f8c6` (SS-2 plan).

---

## 2. The program in one screen

**North star:** agent-driven first-class; bash only for non-reasoning facts; derivation = reconciliation not regeneration; one source of truth per job; SSoT (`MASTER-SPEC` + `EXEC-SUMMARY`) itself synthesized.

| Sub-spec | Goal | Status |
|---|---|---|
| **SS-1** | memory-bank ownership + single-point cadence | ✅ SHIPPED (PR #54, #45 closed) |
| **SS-2** (this handoff) | synthesis live & verified + EXEC-SUMMARY + post-derivation review | **design-locked + planned → BUILD** |
| SS-3 | resumable agent-synthesized onboarding (MASTER-SPEC synthesis) | #51, #49-remainder · next after SS-2 |
| SS-4 | agent-review of verification seams (harvest grammar) | #52, #7, #5, #48F |
| SS-5 | Codex implementer/synthesizer backend | #47 |
| SS-6 | standalone cleanup to zero | #8,#9,#6,#10,#37,#38,#39,#53 |

Issues labeled with sub-specs: **#52→SS-4, #49→SS-3, #53→SS-6** (so the daily 9am Codex run sees they're phased, not blockers).

---

## 3. SS-2 — what to build (OQ-1 verdict + the plan)

**OQ-1 verdict (the framing):** the synthesis path defaults to `synthesize` (no wrapper forces `--fast`) and *would attempt* dispatch, but it **aborts at the edges** and is **untested**:
- **Decisive bug:** `scaffolding-memory-bank/SKILL.md` §13.1 sources only `synthesis.sh`+`routing.sh`, but §13's dispatch/fallback/finalize body calls `sf_memory_bank_derive`, `sf_claude_*`, `_memory_bank_args`, `_sf_mb_*`, `sf_render` (all `lib/memory-bank.sh`/`render.sh`) → **abort under `set -u`**. Same class in `scaffolding-governance-docs/SKILL.md` §11 (calls `sf_docs_derive` from unsourced `lib/docs.sh`).
- Comment-only `# STOP` in both fast-path short-circuits (no real exit).
- **#49 EXEC-SUMMARY:** `sf_render_executive_summary` is **phantom** (referenced, defined nowhere); `{{executive_summary}}` has no source; onboarding §8 *claims* to render it. MASTER-SPEC's pinned section is `## Executive Summary` (MASTER-SPEC.md.tmpl:13).
- **Zero tests exercise dispatch** — a broken dispatch is invisible to CI.

**The 6-task plan** (see the plan doc for exact code — TDD per task):
- **W1** — source the dispatch libs in §13.1/§11.1; replace `# STOP` with `return 0`; + a **source-guard** test binding SKILL text → sourced libs.
- **W2** — EXEC-SUMMARY = **single authoritative producer** (onboarding-close); `/scaffold-*` consume-if-missing + **staleness warn** (never refresh → kills the #45-class two-writer); implement the **real** `sf_render_executive_summary` with the pinned `## Executive Summary` **parser contract** (errors loudly on absent/empty) + `cksum` provenance trailer; remove the phantom.
- **W3** — read-only `derivation-reviewer` agent; **advisory** review → `derivation-review.md` (artifact-linked, MASTER-SPEC-hash-tagged) with a targeted `--regenerate=<file>` apply path.
- **W4 (the real OQ-1 closer)** — **behavioral harness**: extract §13's `bash` blocks, shim `Task()`, run under `set -euo pipefail` with faked agent outputs (a real abort fails CI) + per-artifact fallback-domain test. New `tests/test-synthesis-dispatch.sh`.
- **W5** — one in-session **real** synthesize-mode smoke (supplementary evidence; the W4 harness is the repeatable signal).
- **W6** — release: scaffold-onboard `0.4.0 → 0.5.0` (Claude+Codex parity), CHANGELOG/README, PR → bot-review → tag → close **#50, #49, #42**.

**Critique-hardening already baked into the spec (§8):** behavioral harness over stub+source-guard (premise #1); EXEC-SUMMARY single producer + parser contract (premise #2); per-artifact fallback domain + serial ledger (#3/#6); #42 disposition lifecycle (premise #4). Documented rebuttals: no concurrent write-race (distinct files + serial ledger merge); scaffold-dev boundary is real (authoring mechanism changes, output contracts don't). **scaffold-onboard-only; scaffold-dev untouched.**

**How to start:** create branch `feat/ss2-synthesis-live-and-verified` off `main`; run `subagent-driven-development` against the plan → fresh subagent per task + spec-compliance + code-quality review between tasks → full suites (`scaffold-onboard/run-tests.sh` + `tests/test-codex-dual-publish.sh`) → final holistic review → PR → bot-review babysitting → release.

---

## 4. Key gotchas (standing + SS-2-specific)

- **No pairing manifest here** — plain superpowers flow; `subagent-driven-development`; manual handoffs. scaffold-dev slice/handoff skills refuse.
- **Behavioral harness honest boundary (spec §2.5):** the harness proves the *shell* the orchestrator runs is executable (catches the unsourced-helper class for real); it CANNOT prove the LLM chooses to dispatch — that's irreducibly prose, covered once by W5. Don't over-claim.
- **EXEC-SUMMARY chicken-and-egg:** when synthesizing EXEC-SUMMARY itself, source is **MASTER-SPEC only** — pass an empty `exec_summary` arg to `sf_synth_brief_assemble` (the agent must not be told to read a file that doesn't exist yet). The new brief has `consumes: []`, `wave: 0`.
- **macOS / bash 3.2 / BSD** awk-sed-cksum only. The new `lib/render.sh` helpers use `cksum` + BSD awk (no `sed -z`, no GNU-only flags).
- **scaffold-onboard suites are slow** (55–75s+/file) — background + generous timeouts; run the **whole** suite before declaring green (`feedback_full_suite_when_verifying_subagents`).
- **Bot-review babysitting (proven, SS-1):** push triggers CodeRabbit; **Codex does NOT auto-review on push** — comment `@codex review` to trigger it, and its "no issues" verdict posts as a PR **issue-comment** (`/issues/<n>/comments`), not a review object. Verify each finding before applying (`receiving-code-review`). Resolve review threads only after verifying the fix is in the current head.
- **Don't commit `.claude/`** — targeted `git add` only.
- **Side-finding to maybe `/defer`:** architect-critic's `state_append_run` has a state-path bug (resolves to a nonexistent `~/.claude/plugins/data/codex-openai-codex/state.json`). Non-blocking; not SS-2's concern.

---

## 5. Must-read (in order)
1. `docs/agent-driven-program/specs/SS-2-synthesis-live-and-verified.md` — design-locked + critique-hardened (§7 settle-points, §8 critique record).
2. `docs/agent-driven-program/plans/2026-06-04-ss2-synthesis-live-and-verified.md` — the 6-task TDD plan with exact code.
3. `docs/agent-driven-program/SPEC-agent-driven-program.md` — program north star + ledger (SS-2 design-locked, OQ-1 resolved).
4. Memory: `project_agent_driven_first_class_pivot` (program state, SS-1 shipped, next=SS-2), `feedback_test_upgrade_input_class`, `feedback_agent_review_over_deterministic_gates`, `feedback_full_suite_when_verifying_subagents`, `feedback_subagent_vs_inline_threshold`.
5. Key code to hold in context for the build: `scaffolding-memory-bank/SKILL.md` §13, `scaffolding-governance-docs/SKILL.md` §11, `lib/render.sh`, `lib/docs.sh`, `lib/synthesis.sh`, `agents/synthesis-agent.md`, `templates/synthesis-briefs/00-project-brief.brief.md` (brief model), `templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl`.
