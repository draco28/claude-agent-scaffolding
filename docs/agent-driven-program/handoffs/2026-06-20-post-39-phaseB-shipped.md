# Session Handoff — #39 Phase B SHIPPED (scaffold-dev review gate → v0.8.0); #39 CLOSED

**Date:** 2026-06-20 · **Author:** prior session (built #39 Phase B → PR #75, scaffold-dev **v0.8.0**) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§5 sub-spec sequence + §6 issue ledger), the **#39 spec** `specs/2026-06-18-architect-critic-async-adversary.md` (§4 = Phase B), and the prior handoff `2026-06-18-post-39-phaseA-shipped.md`. This handoff is the delta: **#39 is fully CLOSED (both phases); SS-6 backlog continues; one open correctness bug (#74) is the strongest next pick.**

---

## 1. What this session did (one line)

Built **#39 Phase B** (opt-in scaffold-dev `review_gate` consuming the Phase A async API) via the full TDD + 3-bot-review cycle → PR **#75** merged (squash `17593ad`), **scaffold-dev v0.8.0** tagged, **#39 CLOSED**. Filed 2 follow-ups (#76, #77).

---

## 2. ⚠️ FIRST ACTION NEXT SESSION

**Pick the next SS-6 item.** Recommended order (bugs before enhancements):

1. **#74 — `auto:` AC `exit 0` vacuous pass (TDD false-green)** — the only open **bug**. A test-runner filter matching zero tests exits 0, so an `auto:` acceptance-criterion passes vacuously (a slice can demo-verify green having run *nothing*). This is a correctness hole in scaffold-dev's verify gate (`implementation-checking` / `closing-vertical-slice` auto-demo). **Strongest next pick** — it undermines the demo-verification guarantee. Needs: detect "0 tests collected" per runner and fail (or warn-loud) instead of trusting `exit 0`.
2. **#48 — scaffold-dev #33 follow-ups** (lean-index Parts C–F + `/defer` marketplace routing + label auto-create). Good substantive batch; C/F want agent-assisted validators.
3. **#76 / #77 — Phase B follow-ups** (this session). #77 (closing/planning SKILL.md over the self-declared 500-line cap → extract to `references/`) is maintainability and touches files we just edited; #76 (record slice-start baseline so `direct`-mode async review-bundles get a real diff) deepens the gate.
4. **#71** — PR #70 review follow-ups incl. **CI SHA-pinning** (`actions/checkout@v4` Node-20 deprecation). Chore.
5. **#10 / #37 / #38** — deferred enhancements (demand-gated / partial); cheap cherry-picks exist (#37 strict ADR threshold, #38 redaction leg).

**Open SS-6 / backlog (8 issues):**

| # | Title | Flavor | Note |
|---|---|---|---|
| **#74** | `auto:` AC `exit 0` vacuous pass (TDD false-green) | **bug** | **Strongest pick** — verify-gate correctness; zero-tests-collected must not pass. |
| **#48** | #33 lean-index C–F + /defer routing + label auto-create | enhancement | Substantive batch; some agent-assisted validators. |
| **#76** | direct-mode async review-bundle diff baseline | enhancement (Phase B follow-up) | Record canonical-HEAD-at-slice-start in planning §8.1 → slice state → read at close. |
| **#77** | closing/planning SKILL.md > 500-line cap | chore (Phase B follow-up) | Pre-existing (closing was 572 pre-#39B); extract reference detail to `references/*.md`. |
| **#71** | PR #70 review follow-ups (incl. CI SHA-pin) | chore | `actions/checkout@v4` → pin to SHA. |
| **#37** | grill domain-language + ADR thresholds | enhancement (partial) | Cheap cherry-pick: strict ADR threshold. |
| **#38** | handoff suggested-skills + artifact-refs + **redaction** | enhancement | Redaction leg has standalone safety value. |
| **#10** | coordinating-parallel-slices | enhancement (demand-gated) | Park unless a real multi-slice need appears. |

**Operator follow-up still open (manual, not code):** the **real-Codex smoke** for the #39 async path — covers **both** Phase A (`/critique --close --async`) and **Phase B** (set `.review_gate=slice_close`, run a real slice close → confirm async dispatch + handle recorded + non-blocking + `/critique-jobs resume` folds the rebuttal; `off` → legacy sync path byte-unchanged). CI uses the shim only; no live Codex.

This is the plugin **source** repo (no `.workspace/pairing.json`) — scaffold-dev slice/handoff skills refuse here; develop with the plain `brainstorm → spec → writing-plans → inline TDD → bot-review → release` flow and **manual** handoffs committed to `main`.

---

## 3. What shipped this session 🔧 (scaffold-dev v0.8.0, PR #75)

- **`review_gate` config** (`off`/`slice_close`/`spec_close`/`both`, default `off`) — `lib/review_gate.sh::sd_review_gate_resolve`, mirrors `sd_backend_resolve` (override > manifest `.review_gate` > `off`; set-e-safe; invalid fails loud). `--gate` override wired through `/orchestrate` §13.
- **`sd_review_gate_bundle`** (tested helper, 7 unit tests) — assembles the single review artifact the async path needs: writes **under the slice root** (trusted git root, never `/tmp` — async pre-flight rejects untrusted roots), includes the slice diff **only when non-empty** (direct-mode `merge-base==HEAD` → omitted, #76), concats README/spec/report sections, fails loud on malformed args.
- **Capability detection** — `sd_compose_detect_architect_critic` now reports `v0.3`/`v0.2`/`absent`; §7.0 adds an **active-host runnability guard** (probe is host-agnostic → treat not-runnable-here as absent).
- **§7 gate** in `closing-vertical-slice` + `planning-vertical-slice`: resolve gate (from the **AI-workspace root** — §5 cd's to canonical), build the bundle, **export** the real `--close --async` CLI bridge with a quoted `--spec`, **react-to-return** (job handle → defer; synchronous rebuttal / preflight-hardfail → capture inline; all outcomes carried to the §8 render, not written pre-render). Every *decision* stays agent-driven prose.
- **Spec gate `spec_close`/`both` upgrades** the default author-depth audit to close-depth (async is close-only); v0.2 / Codex-host degrade to synchronous close-depth.
- **De-staled** scaffold-dev README; corrected closing §13 (no `/close-slice` command — NL/orchestrate-invoked).

**Review story:** 7 bot-review rounds (~26 findings, all addressed). Early = real feature bugs (async never fired via informal params; v0.2 fallback dropped depth). Middle = mechanical bundle-plumbing bugs → **root-caused by extracting the tested `sd_review_gate_bundle` helper** (user-approved mid-PR). Late = pre-existing file issues (#77 line cap, fictional `/close-slice`). Merged on green CI + clean verdicts + 0 unresolved threads.

---

## 4. Durable lessons (apply next session) ⭐

1. **Recurring mechanical bugs in agent-prose bash → extract to a tested `lib/` helper.** When bot review keeps hitting the same prose-bash across rounds, it's mechanical-fact logic in the wrong place (judgment → agent; mechanical → tested bash). [[feedback_extract_mechanical_prose_on_recurring_findings]] — extends [[feedback_agent_review_over_deterministic_gates]] + [[feedback_bot_review_convergence_judgment]].
2. **architect-critic `ARCHITECT_CRITIC_ARGS` bridge has 4 traps:** must `export` (not set); `--async` only via the args string (not informal params); single-artifact + quoted `--spec` (word-splits on spaces); async bundle must live under a trusted git root (not `/tmp`). React to the actual return, don't predict host/version. [[reference_architect_critic_args_bridge_contract]].
3. **Poll PR threads by unresolved-count, not `commit_id`.** GitHub review-submission `commit_id`/`submitted_at` lag HEAD (bots attribute threads to older review objects), so commit-keyed babysit polls give false "not reviewed yet."

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — in progress** (cleared #66/#8/#9/#6/#53/#63/#39 both phases; remaining #74/#48/#10/#37/#38/#71 + Phase-B follow-ups #76/#77).

**Plugin versions (current main, HEAD `17593ad`):** workspace-init 0.2.0 · scaffold-onboard 0.9.1 · **scaffold-dev 0.8.0** · architect-critic 0.3.0 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Tag this session:** `scaffold-dev-v0.8.0` (#39 Phase B).

**Repo state:** local `main` = origin `main` = `17593ad`, clean tree. 0 open PRs. CI green (Linux). #39 CLOSED.

---

## 6. Recommended next-session entry points

1. **#74** (TDD false-green verify bug) — the only open correctness bug; brainstorm → fix → scaffold-dev patch release.
2. **#48** mechanical batch, or the **#76/#77** Phase-B follow-ups (#77 is a clean references/ extraction across the two now-oversized skills).
3. **Operator real-Codex smoke** of the #39 async path (manual; §2) — covers both phases.
4. Else a cheap cherry-pick from #37 (ADR threshold) / #38 (redaction) / #71 (CI SHA-pin).

**Target remains zero open backlog.** Substantive remainder: **#74** (bug) + **#48** + the two Phase-B follow-ups; the rest are deferred enhancements/chores.
