# SS-8 — `/amend-spec`: incremental, change-driven MASTER-SPEC amendment (closes #86)

**Status:** Design-locked for `scaffold-onboard v0.12.0` (sub-spec of `docs/agent-driven-program/SPEC-agent-driven-program.md` → SS-8) · **Date:** 2026-06-26
**Closes:** `#86` (the greenfield → full-lifecycle-tool gap). Demand-validated by PulseDB at its v0.5.x → vNext maintenance boundary (one reliability NFR for a storage-format-modernization sprint).
**Plugins touched:** `scaffold-onboard` only (new `amending-spec` skill + `/amend-spec` command). **No new `lib/*.sh`.**

> **Design settled with user 2026-06-26** (brainstorm). Four forks locked via AskUserQuestion (§3). Binding constraint reaffirmed mid-brainstorm: **skill-first / agent-driven — no deterministic code where reasoning belongs** (program North Star §1).

---

## 1. The problem

`scaffold-onboard` is optimized for **greenfield → MVP**: `/onboard` authors `MASTER-SPEC.md` from scratch; `/scaffold-docs` re-derives the whole governance bundle. At the **post-MVP / vNext** boundary, planning becomes **change-driven** — fold in *one* FR/NFR/capability per increment — and the greenfield model offers no first-class path. Today you either hand-edit the SSoT and hope, or re-run heavyweight greenfield flows. `/amend-spec` is the missing front door.

## 2. Envelope — front-door MVP, defer the doc-merge

The expensive, no-precedent part of #86 is the **diff-aware governance-doc update** (targeted SRS/BACKLOG section amendment). That is exactly the partial-reconcile complexity the program already evaluated as not worth it (#58 wontfix), one layer down. So the MVP **defers it**: `/amend-spec` makes the surgical, SSoT-consistent, traceable amendment to `MASTER-SPEC.md` and **routes propagation to the existing `/scaffold-docs` + `/plan-roadmap`**.

Honest limitation owned by the MVP: doc propagation is whole-bundle re-derive (curated SRS/BACKLOG edits are re-authored). The impact analysis is the user's guide to what *should* change.

## 3. Settled forks (brainstorm 2026-06-26)

1. **Scope envelope → front-door, defer doc-merge.** (vs. full diff-aware / analysis-only.)
2. **SSoT consistency → edit spec + fold a note into the `phase_record`.** `MASTER-SPEC.md` is synthesized from `onboarding-state.json`; `/onboard --regenerate` re-synthesizes from that state. Editing only the derived spec would be clobbered on re-onboard — so the amendment's rationale is folded forward into the affected phase's record (existing `sf_state_write_phase_record`).
3. **Amendment trail → in-spec `## Revision History` + a new `**Spec revision:**` field.** `**Spec version:**` stays pinned at the *schema/parser* version (`1.0`) — bumping it would falsely signal a schema change and trip `sf_spec_validate`'s warning (parser.sh:134). Content revisions live in the new field + dated Revision-History entries.
4. **ID minting → deferred with the doc-merge.** `MASTER-SPEC.md` is **ID-free** (`MASTER-SPEC.brief.md` `mints: []`); FR/NFR/BACKLOG IDs live only in derived docs and `/scaffold-docs` **re-mints them all wholesale** on each derive (IDs aren't stable across runs today). Writing a stable `FR-13` *is* a targeted SRS edit — the deferred slice. So `/amend-spec` **surfaces** the prospective requirement in the impact analysis but writes **no ID** into any file; ID assignment happens at the next `/scaffold-docs`.

## 4. The flow (`amending-spec` SKILL.md — all agent reasoning; ⚙️ = existing mechanical reuse via `sf`)

1. **Orient** — emit the `📍 You are here` block (#88 convention: Topic / Where-it-sits + weight / Why; ask when thin).
2. **Preflight** ⚙️ — `sf resolve_output_path master_spec MASTER-SPEC.md`; absent → route to `/onboard`, stop. `sf spec_validate`. `sf state_lock_acquire` (release only if acquired). Note `sf state_mode`; `project_mismatch` is a safety stop.
3. **Capture & classify** — net-new capability / NFR-hardening → continue; **pure maintenance → `/defer`, stop** (no spec edit).
4. **Impact analysis** — read `MASTER-SPEC` (+ derived SRS/BACKLOG/PRD/ROADMAP if present): target phase section, touched requirements/slices, prospective new requirement (surfaced, not minted). **Present for confirmation — the edit gate.**
5. **Targeted edit** — fold the change into the right phase section (marker preserved, not a rewrite); append a dated `## Revision History` entry outside phase-marker content (before the first phase marker, not EOF); add/bump `**Spec revision:**` (leave `**Spec version:**`); re-validate ⚙️.
6. **SSoT fold** ⚙️ — read the affected `phase_record`, preserve all fields, merge a short amendment note, write the complete object back (`sf state_write_phase_record`). Skipped (with a note) when `sf state_mode == new` (no state → nothing to clobber).
7. **EXEC-SUMMARY** ⚙️ — `sf exec_summary_staleness`; agent judges; update the `## Executive Summary` section in MASTER-SPEC if summary-worthy and refresh `EXECUTIVE-SUMMARY.md` only on explicit user agreement by writing a fresh H2 body and calling the full `sf render_executive_summary_from_synthesized "$master" "$exec" "$(sf project_name)" "$(sf spec_project_class "$master")"` signature; else flag stale-by-design. **Never a silent second producer.**
8. **Propagation handoff** — name `/scaffold-docs` (honestly flagged whole-bundle) + optional `/plan-roadmap --add-slice` / `sf roadmap_append_mutation add-slice` stub; release the lock; 3-line summary.

## 5. Reuse vs. new

- **Reused, no new code:** `sf_resolve_output_path`, `sf_spec_validate`, `sf_state_mode`, `sf_state_stored_project_root`, `sf_project_identity_root`, `sf_state_read_phase_record`, `sf_state_write_phase_record`, `sf_state_lock_acquire/release`, `sf_exec_summary_staleness`, `sf_project_name`, `sf_spec_project_class`, `sf_render_executive_summary_from_synthesized`, `sf_roadmap_append_mutation`.
- **New:** `skills/amending-spec/SKILL.md` (prose), `commands/amend-spec.md` (thin `$ARGUMENTS` bridge), `tests/test-amend-spec.md` (manual behavioral fixture). **Zero new `lib/*.sh`** — the only bash is the command's `$ARGUMENTS` parse.

## 6. Durable carrier (a deliberate consequence)

The `phase_record` note is the **durable carrier** of an amendment: it survives `/onboard --regenerate` (reconciled forward via the synthesis digest). The in-spec `## Revision History` + `**Spec revision:**` are **presentation** — a full first-author re-synthesis may reset them, but the substance persists in state. This is acceptable and intentional under the front-door envelope.

## 7. Out of scope (deferred → future enhancements)

- Diff-aware section-level SRS/BACKLOG merge (the no-precedent mechanism; #58-class complexity).
- Stable / collision-safe ID minting (deferred *with* the doc-merge — see §3.4).
- Per-change change-request artifact files; a maintenance-vs-feature roadmap lane (#86 gap #5).

## 8. Testing

`tests/test-amend-spec.md` — 12 manual behavioral fixtures (routing, classification→/defer, impact-analysis gate, targeted edit + version-field pinning, SSoT fold-forward, no-state skip, EXEC-SUMMARY judgment, propagation honesty, orientation + thin-context-asks, out-of-scope honesty, lock release discipline, post-edit validation failure). Manual by design — the flow is agent prose, not deterministic (consistent with the skill-first plugins; no unit test because there is no new helper). The dual-publish parity gate validates the new SKILL.md frontmatter.

## 9. Ledger placement

SS-8 is its own sub-spec line (the strategic greenfield→lifecycle item) but ships as **one PR** (small, mostly prose) → `scaffold-onboard v0.12.0`. Closes #86.
