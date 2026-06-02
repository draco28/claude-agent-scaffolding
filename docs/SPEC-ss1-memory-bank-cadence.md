# SS-1 — Memory-Bank Ownership + Single-Point Update Cadence (closes #45)

**Status:** Draft (sub-spec of `docs/SPEC-agent-driven-program.md` → SS-1) · **Date:** 2026-06-02
**Closes:** `#45` (harvest ↔ derived-file SSoT contradiction). **Related:** `#52`/N4 (harvest grammar — SS-4), `#48` C/D/E.
**Plugins touched:** `scaffold-onboard` (memory-bank derive, templates, SSoT note) + `scaffold-dev` (harvest, /defer, sprint-retro) — cross-plugin.

> **Design settled with user 2026-06-02** (during SS-1 brainstorm). Memory: `project_agent_driven_first_class_pivot`. This sub-spec is design-locked except for the explicit settle-points in §7.

---

## 1. The core realization

Classify every memory-bank file by **who owns its content**, and #45 shrinks from "build a reconciliation engine" to "stop two writers colliding in two files":

- **Pure spec-derived** (regenerate freely, never merged): `00`, `01`, `02`, `04`, `07`, `08`, `index`.
- **Pure dev-authored** (written while building; preserved on re-derive): `05-active-context`, `06-progress`, `tech-debt`, **+ NEW `09-known-issues`, `10-decisions-log`**.
- **Mixed (minimal residual): only `03-code-patterns`** = derived code-style prose **+ one preserved zone** for the `## Machine-checkable rules` section.
- **Static:** `WORKFLOW.md`.

**Consequence:** because dev-authored learnings now live in their own pure-dev files, derived files become safely regenerable. The only in-place preservation is `03`'s rules zone — a mechanical fixed-section extract/re-inject, which is a non-reasoning fact (KEEP-MECH per the program north star). **No agent-merge engine is needed for SS-1** (OQ-2 resolved: mechanical zone-preservation, not whole-file agent-merge).

---

## 2. Settled decisions

1. **Separate files + rules stay in `03`.** Add two pure-dev (live-seed) files for harvested learnings; keep machine-checkable rules in `03` (they *are* code-patterns) inside a marked preserved zone. `04` returns to pure-derived (no harvest into it).
2. **New live-seed files:** `09-known-issues.md`, `10-decisions-log.md` — seeded header-only on first `/scaffold-project`, preserved on re-derive (same bucket as `05`/`06`). **Scope (SP-2):** `09` = caveats/gotchas/workarounds **+ dev-discovered stack/tech notes** ("things that bite / behaviors to watch"); `10` = build-time decisions **+ advisory patterns/conventions** ("things we chose / established"). Enforceable patterns do NOT go here — they escalate to machine-checkable rules in `03`. **Load-tier (SP-4):** `09` = Tier 0 (always-load); `10` = on-demand/branch-load.
3. **`03` preserved zone:** the `## Machine-checkable rules` section is wrapped in markers and survives re-derive via deterministic extract-before-render / re-inject-after. Everything else in `03` re-renders from MASTER-SPEC.
4. **Single-point cadence policy.** One canonical "Memory-bank update cadence" policy (event × bank × who) is the *only* place the cadence is stated. **De-contamination sweep:** every other skill/template/plugin mention of when/which-bank-updates is rewritten to *point to* the policy — no restatements, no conflicting assertions (§5).
5. **Harvest target-set fix.** Kill the phantom targets in `closing-vertical-slice` (`09`/`10`/`06-product-context` were never real files); route harvest to the new pure-dev files per the policy; never append into derived `03`/`04` prose. (Discovered enforceable patterns become machine-checkable rules via the authoring flow → `03` rules zone, not a raw harvest append.)
6. **CLAUDE.md SSoT note rewrite.** Distinguish spec-derived (regenerated) from dev-authored (preserved, updated per the cadence policy); point to the single policy.

---

## 3. Target cadence matrix (draft — the single policy)

| Event | Banks updated | By whom | Mechanism |
|---|---|---|---|
| **Onboard / `/scaffold-project`** | derive `00-04,07,08,index` (preserve `03` rules zone); seed-if-missing `05,06,09,10,tech-debt,WORKFLOW` | scaffolding-memory-bank (agent synthesis default; bash `--fast`) | derive + seed |
| **Work-item close** | **none** — suggestions captured in `report.md §7` for later harvest | implementer-agent | — |
| **Vertical-slice close** | `05` cursor; `09-known-issues` + `10-decisions-log` (harvest, agent-judged); `tech-debt` (auto-file sweep); `03` rules zone *only if* a discovered pattern is promoted to a rule | closing-vertical-slice orchestrator | agent-judged append to pure-dev files |
| **Sprint close** | **none** (write-nothing — SP-3 confirmed; sprint-retro stays read-only aggregation, writes `sprint-retrospective.md` which is not a memory-bank file) | writing-sprint-retrospective | — |
| **Continuous** | `05` cursor (orchestrator); `06` progress (changelog/hand); `03` rules (authoring-machine-checkable-rules); `tech-debt` (`/defer`) | various | append |
| **Enhancement re-derive** | re-derive spec files (preserve `03` rules zone); all pure-dev files untouched | `/scaffold-project` re-run | mechanical preservation — no agent merge |

---

## 4. Work breakdown

- **W1 (scaffold-onboard):** add `09-known-issues.md.tmpl` + `10-decisions-log.md.tmpl`; register both as live-seed in `sf_memory_bank_derive`; add to `index` + load-tier matrix.
- **W2 (scaffold-onboard):** implement `03` rules-zone marker preservation in the derive path (both bash and synthesis); add markers to `03-code-patterns.md.tmpl` around the rules section.
- **W3 (scaffold-onboard):** author the single cadence policy (location per §7) + rewrite the CLAUDE.md SSoT note to point to it.
- **W4 (scaffold-dev):** rewrite `closing-vertical-slice` harvest target-set → route to `09`/`10` per policy; kill phantoms; fix the file-count wording.
- **W5 (both plugins):** de-contamination sweep (§5) — redirect every cadence mention to the policy.
- **W6:** tests — new-file seeding + preservation, `03` rules-zone survives re-derive, harvest routes correctly, no skill restates cadence (a grep-guard test).
- **W7 (scaffold-onboard, migration — SP-5):** one-time relocate step in the derive path — detect provenance-trailed harvest content (`<!-- Added from VS… -->`) in `03`/`04`, **relocate** it to `09`/`10` before regenerating those files, and print a summary. **Never silent-drop.** Covers existing projects on the 12-file bank (e.g. the PulseTrader test project).

---

## 5. De-contamination sweep targets (every current cadence mention → point to policy)

| Location | Current statement | Action |
|---|---|---|
| `WORKFLOW.md` "When to update memory-bank" | live-vs-derived rule | becomes (or points to) THE policy |
| `05-active-context.md.tmpl` / `06-progress.md.tmpl` headers | "live file, update by hand / slice commands" | point to policy |
| `closing-vertical-slice §9` (harvest) | targets + ceremony | reference policy for *which* files |
| `executing-work-item §6/§17` | "no memory-bank writes; suggestions → report.md" | point to policy |
| `deferring-work-item §5` | tech-debt append | point to policy |
| `authoring-machine-checkable-rules` | writes `03` rules | point to policy |
| `writing-sprint-retrospective §10` | sprint promotion deferred | resolve per §7 + point to policy |
| `scaffolding-memory-bank §4/§5` | derive vs preserve | point to policy |
| `CLAUDE.md.tmpl` SSoT section | "hand-edits overwritten" | rewrite + point to policy |
| `tech-debt.md.tmpl` header | "filed by /defer + auto-file sweep" | point to policy |

---

## 6. Tests / acceptance

- New `09`/`10` seeded header-only on first derive; **preserved** (byte-identical) on re-derive without `--regenerate`.
- `03` machine-checkable rules survive a re-derive (author a rule → re-derive → rule still present); derived prose around it refreshes.
- Harvest writes only to policy-sanctioned files; a harvest aimed at a derived file is refused/rerouted.
- Grep-guard: no skill body independently states an update cadence that the policy doesn't own (enforces single-source).
- Existing memory-bank + scaffold-dev suites stay green.

---

## 7. Settle-points — ALL RESOLVED (2026-06-02)

- **SP-1 — Policy location → `WORKFLOW.md`.** Canonical "Memory-bank update cadence" policy authored in scaffold-onboard's `WORKFLOW.md` template (Static/project-agnostic, already has a "When to update" section). Every skill points to `memory-bank/WORKFLOW.md → Memory-bank update cadence`. One source, materialized once per project.
- **SP-2 — Routing → two buckets.** `09` absorbs known-issues + stack/tech notes; `10` absorbs decisions + advisory patterns; enforceable patterns → machine-checkable rules in `03`. No third file. (Folded into §2.2.)
- **SP-3 — Sprint-close → write-nothing.** Slice close stays the single promotion event; sprint-retro is read-only aggregation. (Folded into §3.)
- **SP-4 — Load-tier →** `09` Tier 0 (always-load), `10` on-demand/branch-load. Tunable later. (Folded into §2.2.)
- **SP-5 — Migration → one-time relocate, never silent-drop.** (New work item W7, §4.)
