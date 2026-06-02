# Session Handoff — agent-driven program launched; SS-1 design-locked & ready to BUILD

**Date:** 2026-06-02 · **Repo:** `claude-agent-scaffolding` (plugin **source** repo — no `.workspace/pairing.json`, so scaffold-dev's slice/handoff skills refuse here; develop with the plain **brainstorm → writing-plans → subagent-driven-development** superpowers flow. Handoffs are manual `docs/HANDOFF-*.md`.)
**Repo state:** `main` @ `89f6f70` (all design docs committed; nothing pushed to origin) · **0 open PRs** · untracked `.claude/` (do NOT commit).
**Resume by:** reading `docs/SPEC-agent-driven-program.md` (the program) then `docs/SPEC-ss1-memory-bank-cadence.md` (SS-1, design-locked). Then **build SS-1**.

---

## 1. What this session did (no code yet — design + planning cycle)

Started at "triage #45," reframed into a full program (user chose **Option C** — full mechanical→agent-driven refactor across all 3 plugins; #45 is the *wedge*).

- **Triaged #45** → confirmed real, live-biting, cross-plugin (worse than reported: phantom harvest targets + latent mcrules clobber). Labeled `bug, scaffold-dev, scaffold-onboard, v0.2`; full findings on the issue.
- **Six-stream audit** of the whole flow → **three root anti-patterns**: **A** regeneration-not-reconciliation · **B** transcription-where-synthesis-belongs · **C** dual-path/grammar-collision. Answered the MASTER-SPEC question: it's **mechanical transcription**, not synthesis.
- **Program spec** `docs/SPEC-agent-driven-program.md` — 6 phased sub-specs (SS-1..SS-6) + issue ledger → **zero backlog**.
- **Filed 5 new issues** from the audit: **#49** EXEC-SUMMARY hole · **#50** verify "dark" synthesis (CRITICAL, = OQ-1) · **#51** MASTER-SPEC→agent synthesis · **#52** harvest grammar-collision · **#53** no CI. (Zero unfiled deferrals — backlog all tracked.)
- **Codex daily-run findings triaged** (program spec §7): #44 + version findings STALE (Codex ran the pre-merge branch); only #53 (no CI) genuine.
- **SS-1 design-locked** + all five settle-points resolved (see §3).

Commits on `main`: `82a51fd` (program spec), `9cb0983` (SS-1 sub-spec + program link). Nothing pushed.

---

## 2. The program in one screen

**North star:** agent-driven first-class; bash only for non-reasoning facts; **derivation = reconciliation, not regeneration**; SSoT (`MASTER-SPEC` + `EXEC-SUMMARY`) is itself synthesized + reconcilable; **one source of truth per job**.

| Sub-spec | Goal | Closes |
|---|---|---|
| **SS-1** (this handoff) | memory-bank ownership + single-point cadence | **#45** |
| SS-2 | turn synthesis ON + verify (OQ-1/#50) + post-derivation review | #42, #50, #49 |
| SS-3 | agent-synthesized resumable onboarding (phased-discussion file) | #51, #49 |
| SS-4 | agent-review of verification seams | #7, #5, #48F, #52 |
| SS-5 | Codex implementer/synthesizer backend | #47 |
| SS-6 | standalone cleanup to zero | #8,#9,#6,#10,#37,#38,#39,#48*,#53 |

---

## 3. SS-1 — what to build (design-locked: `docs/SPEC-ss1-memory-bank-cadence.md`)

**Core idea:** classify each memory-bank file by ownership → #45 shrinks to **two files**. Dev-authored learnings move to their own pure-dev files; derived files become safely regenerable. **No agent-merge engine** (OQ-2 resolved) — just file separation + one mechanical preserved zone.

**Settled (SP-1..SP-5):**
- **New live-seed files `09-known-issues` + `10-decisions-log`.** `09` = caveats/gotchas/workarounds + dev-discovered stack/tech notes (Tier 0, always-load). `10` = decisions + advisory patterns (on-demand load). Enforceable patterns → machine-checkable rules in `03`.
- **`03`** keeps one **mechanically-preserved zone** for the `## Machine-checkable rules` section (marker extract-before-render / re-inject-after, on both bash and synthesis paths). `04` returns to pure-derived.
- **Single-point cadence policy** authored in `WORKFLOW.md` ("Memory-bank update cadence", event×bank×who). **De-contamination sweep:** every other skill/template mention of cadence is rewritten to *point to* the policy — no restatements (sweep targets listed in sub-spec §5). Add a grep-guard test.
- **Sprint close stays write-nothing** (slice close is the single promotion event).
- **Migration (W7):** one-time relocate of provenance-trailed harvest content (`<!-- Added from VS… -->`) out of `03`/`04` into `09`/`10` before regenerating; warn, never silent-drop.
- **Harvest target-set rewrite** in `closing-vertical-slice`: kill phantoms, route to `09`/`10` per policy.
- **CLAUDE.md SSoT note rewrite** → distinguish derived vs dev-authored; point to the policy.

**Work items:** W1 new files+templates+live-seed registration+index/load-tier · W2 `03` rules-zone preservation in derive · W3 cadence policy + SSoT-note rewrite · W4 harvest target-set rewrite · W5 de-contamination sweep (both plugins) · W6 tests · W7 migration. (Sub-spec §4.)

**How to start:** `writing-plans` against the SS-1 sub-spec → subagent-driven build → run full suites (scaffold-onboard + scaffold-dev + dual-publish) → bot-review babysitting → release (bump both plugin.json Claude+Codex + README; tag).

---

## 4. Key gotchas (standing + new)

- **No pairing manifest here** — plain superpowers flow; manual handoffs.
- **Bot-review babysitting** (proven): user triggers Codex GitHub app; fetch inline comments via `gh api repos/<o>/<r>/pulls/<n>/comments`; **verify each finding before applying** (`receiving-code-review`); Codex 👍 reaction = clean. Consider a proactive adversarial self-audit.
- **Squash-merge reconcile:** after squash-merge, `git fetch && git reset --hard origin/main`.
- **Release mechanics:** bump `plugin.json` Claude **and** Codex (parity enforced by `tests/test-codex-dual-publish.sh`) + README table → merge → `git tag <plugin>-v<ver>` → push tags.
- **scaffold-onboard suites are slow** (55–75s+ each) — run in background, generous timeouts.
- **Don't commit `.claude/`** — targeted `git add` only.
- **Single-source discipline is a hard requirement** (user, emphatic): after SS-1, NO skill/plugin may independently state a memory-bank update cadence — all point to the one policy. The grep-guard test enforces it.

---

## 5. Must-read
- `docs/SPEC-agent-driven-program.md` — the program (north star, anti-patterns, ledger, OQs).
- `docs/SPEC-ss1-memory-bank-cadence.md` — SS-1, design-locked (§4 work items, §5 sweep targets, §6 tests, §7 resolved settle-points).
- Memory: `project_agent_driven_first_class_pivot` (full pivot state + SS-1 resolution), `feedback_agent_review_over_deterministic_gates`, `feedback_subagent_vs_inline_threshold`.
- Audit evidence is in this session's transcript (six per-flow reports); the program spec §2–§3 distills it.
