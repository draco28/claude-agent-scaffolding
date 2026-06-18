# Session Handoff — #39 Phase A SHIPPED (architect-critic async adversary → v0.3.0)

**Date:** 2026-06-18 · **Author:** prior session (built #39 Phase A → PR #73, architect-critic **v0.3.0**) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§5 sub-spec sequence + §6 issue ledger), the **spec** `docs/agent-driven-program/specs/2026-06-18-architect-critic-async-adversary.md` and its **plan** `…/plans/2026-06-18-architect-critic-async-adversary-plan.md`, and the prior handoff `2026-06-16-post-63-shipped.md`. This handoff is the delta: **#39 Phase A is shipped; #39 Phase B (scaffold-dev review gate) is the natural next pick.**

---

## 1. What this session did (one line)

Built **#39 Phase A** (architect-critic async external adversary + readiness doctor + state v3) via the full superpowers cycle → PR **#73** merged (squash `1be49b4`), **architect-critic v0.3.0** tagged. **#39 kept OPEN for Phase B.**

---

## 2. ⚠️ FIRST ACTION NEXT SESSION

**Decide the next SS-6 pick.** Recommended: **#39 Phase B** — the opt-in, bounded **scaffold-dev review gate** (improvement #6), a monitored architect-critic close-depth audit at slice/spec close that **consumes the Phase A async API just shipped**. It is the natural continuation and the API was designed for it (spec §4). Ships separately as **scaffold-dev v0.8.0** with its **own** writing-plans pass (Phase B was deliberately deferred to its own plan).

**Open SS-6 backlog (6 issues):**

| # | Title | Flavor | Note |
|---|---|---|---|
| **#39 (Phase B)** | scaffold-dev review gate (#6) | enhancement (cross-plugin) | **Strongest next pick** — consumes the v0.3.0 async API. Opt-in config `review_gate ∈ {off, slice_close, spec_close, both}`; attach in `closing-vertical-slice` + `planning-vertical-slice`; bounded monitor (`--cap`/`--stall`) + usage warning. Spec §4 + plan "Post-Phase-A" section. |
| **#48** | scaffold-dev #33 follow-ups (lean-index C–F + /defer routing + label auto-create) | enhancement (mechanical-ish) | Good batch; C/F need agent-assisted validators. |
| **#10** | coordinating-parallel-slices | enhancement (demand-gated) | Park unless a real multi-slice need appears. |
| **#37** | grill domain-language + ADR thresholds | enhancement (partial) | Cheap cherry-pick available: strict ADR threshold. |
| **#38** | handoff suggested-skills + artifact-refs + **redaction** | enhancement | Redaction leg has standalone safety value. |
| **#71** | PR #70 review follow-ups (incl. **CI SHA-pinning**) | chore | Note: the v0.3.0 PR's CI annotation flagged `actions/checkout@v4` Node-20 deprecation — that's the SHA-pin item here. |

This is the plugin **source** repo (no `.workspace/pairing.json`) — scaffold-dev slice/handoff skills refuse; develop with the plain `brainstorm → spec → writing-plans → inline TDD → bot-review → release` flow and **manual** handoffs committed to `main`.

**Operator follow-up still open (not code):** the #39 **real-Codex smoke** — throwaway repo, real Codex authed + trusted; `/critique --close --async` a large spec; confirm it dispatches without blocking, `/critique-jobs resume` consolidates both adversaries into one rebuttal, an early failure surfaces within a poll interval, and the sync path still works foreground. No live Codex in CI.

---

## 3. What shipped this session 🔧 (architect-critic v0.3.0, PR #73)

- **Async close-depth Codex adversary** — `/critique --close --async` dispatches Codex via the companion `task --background` (**read-only**, no `--write`); **defer-to-resume (unified)** model: turn 1 = read-only host self-audit preview + persist + dispatch; `resume` consolidates *both* adversaries (cross-confirmation preserved) → one unified rebuttal. Reuses the SS-5/SS-5.1 `lib/codex.sh` spine (3rd use), ported to `ac_` prefix.
- **Job manager** — `managing-async-critique` skill + `/critique-jobs <status|result|cancel|resume>`; resume re-enters the shared "Consolidate + Rebuttal + Append" procedure (critiquing-spec Steps 7–9); concluded run resumes **inspect-only**.
- **Readiness doctor** — `checking-adversary-readiness` skill + `/critique-doctor` (`ac_codex_doctor`, fail-soft).
- **Size guidance** (`ac_codex_size_hint`) + **state.json v2→v3** `external_runs[]` durable job memory (+ idempotent `ac_state_migrate`); history lists in-flight audits; session-start surfaces a read-only count.
- **Infra side-effects:** architect-critic now has a `run-tests.sh` runner and runs in CI (was absent); fixed a **pre-existing macOS-only suppression-date bug** (BSD `date -v` arg-order silently ignored, masked by circular date tests).
- **Codex review (3 fix commits, all reviewed + accepted):** atomic `ac_state_external_run_finalize_resume` (append + resolve under one lock, vs the original two-transaction path); `trim_external_runs` that **preserves unresolved/live jobs** (the original `.[-20:]` cap could drop a running job); lock-before-existence-check (TOCTOU); status-value + missing-flag-value validation.

**Review story:** CI green on Linux first try (no portability whack-a-mole — pre-scan + dual-dialect helpers). 3-bot stack (Devin/Codex/CodeRabbit) all non-blocking; **22 threads, 0 unresolved**; merged on clean + green + 0 unresolved.

**Dual-publish constraint (documented):** async = Claude-host → Codex-adversary only (the proven companion backend); Codex-host keeps the synchronous path. Skills/commands ship on both surfaces.

---

## 4. Durable lessons (apply next session) ⭐

1. **Distrust the cap/atomicity of state-mutating helpers written solo.** Codex caught a cap that dropped *live* background jobs and a non-atomic two-step resume — the same class an adversarial reviewer reliably finds. Prefer one locked transaction for "append + mark resolved"; never trim a collection in a way that can evict an in-flight record. (Extends [[feedback_bot_review_convergence_judgment]].)
2. **Portable date math + non-circular date tests** — [[feedback_bsd_date_argorder_and_circular_datetests]] (BSD `date -v` must precede `-f`; never compute a test's expected timestamp with the lib's own command).
3. **Bringing a plugin under CI surfaces its latent macOS-isms** — pre-scan for BSD/GNU divergence (`date`, `stat`, `mktemp`, bare `$TMPDIR`) and use dual-dialect helpers; it paid off (green first try).

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — in progress** (cleared #66/#8/#9/#6/#53/#63; **#39 Phase A shipped**; remaining #39-Phase-B/#10/#37/#38/#48/#71).

**Plugin versions (current main, HEAD `1be49b4`):** workspace-init 0.2.0 · scaffold-onboard 0.9.1 · scaffold-dev 0.7.0 · **architect-critic 0.3.0** · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Tag this session:** `architect-critic-v0.3.0` (#39 Phase A).

**Repo state:** local `main` = origin `main` = `1be49b4`, clean tree. 0 open PRs. CI: architect-critic suite now included (Linux, green).

---

## 6. Recommended next-session entry points

1. **#39 Phase B** (scaffold-dev review gate) — brainstorm/spec is mostly settled in `specs/2026-06-18-architect-critic-async-adversary.md` §4; needs its own writing-plans pass + scaffold-dev v0.8.0 release. Consumes the v0.3.0 async API.
2. **Operator real-Codex smoke** of the v0.3.0 async path (manual; §2).
3. Else a quick-win cherry-pick from #37 (ADR threshold) / #38 (redaction) / #71 (CI SHA-pin), or the #48 mechanical batch.

**Target remains zero open backlog.** SS-6's substantive remainder after this session is **#39 Phase B** + **#48**; the rest are deferred enhancements/chores.
