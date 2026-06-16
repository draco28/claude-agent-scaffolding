# Session Handoff — SS-6: #63 SHIPPED (last real correctness bug closed)

**Date:** 2026-06-16 · **Author:** prior session (fixed #63 → PR #72, scaffold-onboard **v0.9.1**) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sub-spec sequence + §6 issue ledger → zero backlog) and the prior handoff `2026-06-16-post-ss6-quickwins-shipped.md`. This handoff is the delta: **the one remaining real correctness bug (#63) is now closed; everything left in SS-6 is enhancement/chore.**

---

## 1. What this session did (one line)

Fixed **#63** (scaffold-onboard `03` mcrules-zone duplicate-section / silent rule-loss) → PR **#72** merged (squash `0d8e020`), **scaffold-onboard v0.9.1** tagged; **open backlog 7 → 6**.

---

## 2. ⚠️ FIRST ACTION NEXT SESSION: continue SS-6 toward zero backlog

**6 issues remain open — all enhancements/chores** (no correctness bugs left):

| # | Title | Flavor | Notes |
|---|---|---|---|
| **#39** | architect-critic external **async** adversary (codex-plugin-cc) | enhancement (synergistic) | **Strongest next pick.** The natural next "Codex does X" surface — reuses the proven `lib/codex.sh` async dispatch/wait/result spine (proven ×3 now: SS-5 implementer, SS-5.1 synthesizer, and this would be #3). Today `critiquing-spec §6` invokes Codex **synchronously** (`ac_codex_run_audit` → `codex exec`); #39's AC set is broader: readiness doctor, async dispatch, durable external-adversary metadata in `state.json`, resume semantics, optional review gate. The synthesizer variant (no worktree / no no-commit-verify) is the closer analog. ~92% of the spine is reusable. |
| **#48** | scaffold-dev #33 follow-ups: lean-index Parts C–F + `/defer` marketplace routing + label auto-create | enhancement (mechanical) | Good mechanical batch. Suggested order F→C→D+E (Part F already shipped in SS-4). |
| **#10** | scaffold-dev coordinating-parallel-slices skill | enhancement (demand-gated) | Larger; only if a real multi-slice need arises. |
| **#37** | grill domain-language capture + ADR thresholds | enhancement (partial principle) | Deferred. |
| **#38** | scaffold-dev handoffs: suggested-skills + artifact refs + redaction | enhancement | Deferred (redaction leg has standalone safety value). |
| **#71** | PR #70 review follow-ups (deferred non-blocking) | chore | Fold into a future scaffold-dev / workspace-init touch. |

Run substantive issues through the plain superpowers cycle (`brainstorm → writing-plans → TDD build → bot-review → release`) — this is the plugin **source** repo (no `.workspace/pairing.json`, so scaffold-dev slice skills refuse; handoffs are manual, committed direct to `main`). **Suggested first pick: #39** (reuses the proven codex spine, the last "agent-driven Codex surface" gap).

**Operator follow-up still open (not code):** the SS-5.1 **real-Codex smoke** (throwaway workspace with `.synthesizer_backend=codex`, real Codex authed + repo trusted, run `/scaffold-docs`; confirm a real synthesis writes a valid artifact, an early failure surfaces within a poll interval, router files stay mechanical). No live Codex in CI.

---

## 3. What shipped this session 🔧

**#63 — `03` mcrules-zone re-attach guarantees exactly one section (PR #72, scaffold-onboard v0.9.1).** When `03-code-patterns` synthesis dropped the `<!-- mcrules:preserve -->` sentinels but still emitted a bare `## Machine-checkable rules` heading, the old fallback **blind-appended** the saved zone → **two** headings; the next `/scaffold-project` re-derive extracted the sentinelled zone while `authoring-machine-checkable-rules` (targets the first heading) wrote under the bare one → **silent rule loss**. New `lib/memory-bank.sh` helper **`_sf_mb_restore_preserve_zone`** (zone-aware `_sf_mb_strip_bare_rules_section` + `_sf_mb_strip_bare_rules_inplace`) guarantees one section on **both** paths: sentinels dropped → strip any bare heading before re-appending; sentinels kept → reinject in place **and** strip any stray out-of-zone heading. Both call sites (the `scaffolding-memory-bank §13` orchestration prose **and** the test fixture) now call the one helper. Two regression tests added. Existing `_sf_mb_reinject_preserve_zone` unchanged (delegated to).

**Review story:** CI green on Linux first try (no portability whack-a-mole — pre-scan + portable awk). CodeRabbit = 1 doc nit (MD046 indented→fenced; SkillSpector "hidden instructions" was a false positive on the legit `mcrules:preserve` sentinels). Devin = no issues. **Codex = 1 real P2** that earned its keep: it caught the **sentinels-present stray-heading sibling case** I'd scoped OUT of the plan as "less reachable" — same loss mechanism, same bug class → accepted, fixed (made the strip zone-aware + applied on both paths), 👍'd, resolved.

---

## 4. Durable lesson (apply next session) ⭐

**A fix that asserts an invariant must enforce it on EVERY input branch — not just the reported one.** The helper's docstring promised "exactly one section," but the reinject-success path didn't strip strays. "Less reachable" is a weak reason to leave a same-mechanism hole; an adversarial reviewer (here Codex) will find it. When a change claims a guarantee, enumerate every branch that can violate it and test each. (Extends [[feedback_bot_review_convergence_judgment]] / the agent-review-over-deterministic-gates principle.)

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — in progress** (cleared #66 + #8/#9/#6/#53 + **#63**; remaining #10/#37/#38/#39/#48/#71 — all enhancement/chore).

**Plugin versions (current main, HEAD `0d8e020`):** workspace-init 0.2.0 · **scaffold-onboard 0.9.1** · scaffold-dev 0.7.0 · architect-critic 0.2.2 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Tag this session:** `scaffold-onboard-v0.9.1` (#63).

**Open backlog (6 — all SS-6, all enhancement/chore):** #10 #37 #38 #39 #48 #71. Closed this session: **#63**.

---

## 6. Recommended next-session entry points

1. **#39** (architect-critic async external adversary — reuses the proven `lib/codex.sh` spine; the last agent-driven Codex surface). **#48** is a good mechanical batch. #10/#37/#38 are demand-gated/deferred.
2. **#71** review follow-ups (lightweight; fold into a related touch).
3. **Operator real-Codex smoke** of the SS-5.1 synthesizer (manual; §2).

**Target remains zero open backlog.** SS-6 went 7 → 6 this session; the substantive remainder is **#39** (codex-spine reuse) and **#48** (mechanical batch). The rest are deferred enhancements/chores.
