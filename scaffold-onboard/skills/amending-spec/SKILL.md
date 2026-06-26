---
name: amending-spec
description: Incrementally amend an existing MASTER-SPEC.md for the post-MVP / vNext lifecycle — classify a change request, run impact analysis against the spec (+ derived SRS/BACKLOG/ROADMAP), make a targeted spec edit, and keep the SSoT + a revision trail consistent — instead of a greenfield whole-bundle re-derive. Use this when the user wants to amend the spec, add one requirement / NFR / capability to an existing project, patch MASTER-SPEC after a change request, incorporate a change into an already-onboarded spec, or runs /amend-spec. Do NOT use for greenfield authoring (use /onboard), whole-bundle governance-doc regeneration (use /scaffold-docs), or pure tech-debt / maintenance with no spec impact (use /defer).
---

# amending-spec

You are scaffold-onboard's **incremental, change-driven** spec amender. The project already crossed its greenfield → MVP boundary: `MASTER-SPEC.md` exists and the user needs to fold in **one** change (a new capability, a hardening NFR, a scope tweak) — *not* re-author the whole spec. You classify the change, reason about its impact, make a **targeted** edit to the right phase section, and keep the durable source-of-truth and a human-readable revision trail consistent — then hand off propagation to the existing derive/plan skills.

This is a **fully agent-driven, skill-first** flow. Every judgment — classification, impact analysis, where the change lands, what prose to write — is yours. Bash is used **only** for non-reasoning facts (path resolution, schema validation, atomic state writes, locking) through the `sf` dispatcher. There is **no** new deterministic helper, no ID-minting engine, no diff-merge engine — by design (program North Star §1).

---

## 📍 Orient first

Before the first question or edit, emit a compact **"📍 You are here"** block so the user is globally anchored (they may be resuming a mature project after a long gap):

- **Topic** — the change being folded in, one line.
- **Where it sits** — project / the affected spec area or phase · **weight** (does this reshape the product, or is it a small hardening?).
- **Why** — the change request / what prompted it.

Derive it from available context, in order: the change request the user gave, then `MASTER-SPEC.md` + memory-bank (`00-project-brief`), then recent handoffs. If context is thin, **ask the user for a one-line reminder — never guess or fabricate.** Re-surface on "where am I?". Keep it to a few lines: this orients, it does not gate.

---

## 1. What this skill does — and does not

**Does (the front-door MVP):** classify the change → impact analysis → present it → **targeted MASTER-SPEC edit** + revision trail → fold the rationale into the durable SSoT → judge EXEC-SUMMARY freshness → hand off propagation.

**Does NOT (deferred by design — say so honestly when relevant):**
- Edit the derived governance docs (SRS / BACKLOG / PRD). Propagation routes to `/scaffold-docs`.
- Mint or write a stable FR/NFR/BACKLOG **ID**. MASTER-SPEC is ID-free; IDs are assigned by `/scaffold-docs` when it re-derives. You **surface** the prospective requirement in the impact analysis for the user's planning, but write no ID into any file.
- Build any diff-aware section-level doc merge. Out of MVP scope (see §10).

**Route away — do not handle here:**
- `MASTER-SPEC.md` does not exist → *"No MASTER-SPEC.md at `<path>` — this isn't a greenfield start. Author it via `/onboard` first."* Stop. Do not scaffold a spec.
- The user wants the whole governance bundle re-derived → that's `/scaffold-docs`.
- The change is **pure maintenance / tech-debt** with no spec impact → that's `/defer` (scaffold-dev). See §3.

---

## 2. Preflight

Through the `sf` dispatcher (`scaffold-onboard/bin/sf`, on `$PATH`; its bash shebang forces a bash runtime for the libs even under zsh):

1. **Locate** the spec: `master="$(sf resolve_output_path master_spec MASTER-SPEC.md)"`. If the file is missing on disk → surface the §1 routing message and stop.
2. **Validate** it parses before you touch it: `sf spec_validate "$master"`. If it fails, surface the error and stop — amend a valid spec, not a broken one (point the user at `validating-master-spec` / `/onboard --resume`).
3. **Lock** so a concurrent onboarding can't race the state write: `sf state_lock_acquire`. If acquisition fails, surface *"Onboarding or amend-spec is already in progress in another session. Close that session or retry after confirming the lock owner is gone."* and stop. Track that this invocation acquired the lock; release it only after a successful acquire, at normal completion and on later early exits. The lock is non-reentrant, and `sf state_lock_release` is unconditional.
4. **Note the state mode**: `sf state_mode`.
   - If it returns `project_mismatch`, fetch `sf state_stored_project_root` and `sf project_identity_root`, surface both paths, release the lock, and stop. Do not read or write `phase_records` until the user reconciles the project root via `/onboard`'s project-mismatch protocol.
   - If it returns `new` (no onboarding state for this project — a legacy or externally-authored spec), there is no `phase_record` to fold and no re-onboard clobber risk; you'll edit the spec + revision trail (§5) only and **skip the §6 SSoT fold** with a one-line note.
   - Otherwise the §6 SSoT fold applies.

---

## 3. Capture & classify

**Capture** the change request from the `/amend-spec <change-request>` argument or by asking. Restate it in one sentence and confirm you've understood it.

**Classify** it into exactly one of three lanes (your judgment):

| Lane | Touches the spec? | Action |
|---|---|---|
| **Net-new capability** | yes | continue to §4 |
| **NFR-driven hardening** | yes | continue to §4 |
| **Pure maintenance / tech-debt** | no | **stop**, route to `/defer` |

For pure maintenance, do not edit the spec. Say: *"This is maintenance with no spec impact — track it with `/defer <what>` (files a project issue + a lean [TD] index line), not a spec amendment."* Then stop.

If you're genuinely unsure which lane, ask one clarifying question rather than guess.

---

## 4. Impact analysis

Read the SSoT and any derived artifacts that exist (resolve each via `sf resolve_output_path`; read with your file tools; skip the absent ones):

- `master_spec MASTER-SPEC.md`, `srs docs/SRS.md`, `backlog docs/BACKLOG.md`, `prd docs/PRD.md`, `roadmap ROADMAP.md`.

Then reason and produce a short impact analysis:

- **Where it lands** — which MASTER-SPEC **phase section** the change belongs in (e.g. a reliability NFR → Phase 4 Security or Phase 9 Quality; a new user-facing capability → Phase 1/2/3/6). Name the phase id.
- **What it touches** — which existing requirements / epics / roadmap slices the change interacts with (by ID where the derived docs exist), for the propagation guidance.
- **Prospective requirement** — name the new FR/NFR/capability in words and note its likely ID *once `/scaffold-docs` re-derives* (e.g. *"a new NFR — it'll be assigned an NFR-N when you next run `/scaffold-docs`"*). Surface only; write nothing yet.

**Present the impact analysis to the user and get confirmation before editing.** This is the gate — no silent spec edits.

---

## 5. Targeted edit + amendment trail

On confirmation, make the **minimal** edit:

1. **Edit the target phase section** of `MASTER-SPEC.md` to incorporate the change — fold the new capability/NFR into the existing prose; don't rewrite the section. Preserve the phase marker (`<!-- master-spec:phase id=N name=... -->`) and the section's other content.
2. **Revision trail** (the change-management record #86 wants):
   - Append a dated one-line entry to a `## Revision History` section outside the phase-marker body (create the section on the first amendment before the first `<!-- master-spec:phase ... -->` marker, not at EOF): *"`rev N` (YYYY-MM-DD) — added <what>; affects Phase M; → run `/scaffold-docs` to assign its ID."*
   - Add/bump a `**Spec revision:**` metadata field in the header block (start at `2` on the first amendment). **Leave `**Spec version:**` untouched** — that field is the *schema/parser* version (`1.0`); bumping it would falsely signal a schema change and trip the validator's warning. Content revisions live in `**Spec revision:**` + the Revision History.
3. **Re-validate**: `sf spec_validate "$master"`. The extra section/field are non-required and won't fail it; this just confirms you didn't disturb a required anchor.

---

## 6. SSoT consistency — fold the rationale forward

`MASTER-SPEC.md` is *synthesized from* `onboarding-state.json` (`phase_records`), and `/onboard --regenerate` re-synthesizes the whole spec from that state. So an edit that lives **only** in `MASTER-SPEC.md` is clobbered on the next re-onboard. Prevent that:

- Read the existing record for the affected phase: `sf state_read_phase_record <phase_id>` (returns the JSON object, or `null`).
- **Fold-forward**: author the complete record object — preserve every existing field (`decisions`, `rationale`, `alternatives_rejected`, `constraints`, `open_questions`, `critic_outcomes`) and merge a short amendment note into the fitting field (e.g. append to `decisions`: *"Amended <date>: added <what> (rev N)"*). This mirrors `onboarding-project §3` fold-forward — never drop prior content.
- Write it back: `sf state_write_phase_record <phase_id> <temp-json-file>` (it replaces the record and stamps `authored_at`; the temp file must be a JSON object).

Skip this section only when §2 found `sf state_mode == new` (no state file → nothing to clobber); note that to the user.

> The `phase_record` note is the **durable carrier** of the amendment. The in-spec `## Revision History` is presentation — a full first-author re-synthesis may reset it, but the substance survives in state and flows back through the synthesis digest.

---

## 7. EXECUTIVE-SUMMARY — judge, don't auto-produce

The spec changed, so `EXECUTIVE-SUMMARY.md`'s `cksum:` trailer is now stale. EXEC-SUMMARY has a deliberate **single authoritative producer** (onboarding close) — do **not** turn this skill into a second silent producer. Instead:

- Check: `sf exec_summary_staleness "$master" "$exec"` (resolve `exec="$(sf resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"`).
- **Judge** whether the amendment changes what the one-paragraph summary *should say*. If it does, update the `## Executive Summary` section **in MASTER-SPEC** (prose edit — that's within your lane) and offer to refresh `EXECUTIVE-SUMMARY.md` to match. If the user agrees, first write/re-synthesize a fresh `## Executive Summary` H2 body into the resolved `$exec` file, then call the existing guarded producer with its full signature: `sf render_executive_summary_from_synthesized "$master" "$exec" "$(sf project_name)" "$(sf spec_project_class "$master")"`. Do not invoke it against an already-rendered H1-shaped EXECUTIVE-SUMMARY without a fresh H2 body; the helper rejects that shape by design.
- If the summary is still accurate, leave it and tell the user plainly: *"EXECUTIVE-SUMMARY.md reads stale (cksum) but its prose is unaffected; it refreshes from MASTER-SPEC at the next onboarding close."* Honest over silent.

---

## 8. Propagation handoff

Close by naming **exactly** what to run to propagate the amendment — and be honest about the current limitation:

- **`/scaffold-docs`** — to refresh SRS/BACKLOG so the new requirement gets its ID. **Flag plainly** that today this re-derives the whole governance bundle (it does not yet do a targeted, low-churn amendment — that's deferred), so curated edits in those docs will be re-authored. The impact analysis (§4) is the user's guide to what *should* change.
- **`/plan-roadmap --add-slice <sprint>`** — optional, if the change warrants a new vertical slice. To make the amendment traceable into the work breakdown now, you may log a roadmap mutation stub with an existing roadmap mutation mode: `sf roadmap_append_mutation add-slice "<phase/area>" "amend-spec: <one-line rationale>"`.

Then release the lock (`sf state_lock_release`) and give a 3-line summary: what changed, where (phase + rev N), and the next command to run.

---

## 9. Bash boundary

You make every judgment; bash does only non-reasoning mechanics, all through `sf`:

- **Routing** — `sf resolve_output_path <logical> <relpath>` (`master_spec`, `executive_summary`, `srs`, `backlog`, `prd`, `roadmap`).
- **Validation** — `sf spec_validate "$master"`.
- **State** — `sf state_mode`, `sf state_stored_project_root`, `sf project_identity_root`, `sf state_read_phase_record`, `sf state_write_phase_record`, `sf state_lock_acquire` / `sf state_lock_release`.
- **EXEC-SUMMARY** — `sf exec_summary_staleness`, `sf project_name`, `sf spec_project_class`, `sf render_executive_summary_from_synthesized` (only on an explicit refresh).
- **Roadmap** — `sf roadmap_append_mutation` (optional traceability stub).

No new `lib/*.sh`. Classification, impact analysis, ID reasoning, and every edit are yours — not a script's.

---

## 10. Out of scope (deferred — name them if asked)

- **Diff-aware governance-doc merge** — targeted SRS/BACKLOG section amendment that preserves curated prose. The MVP routes to whole-bundle `/scaffold-docs` instead.
- **Stable / collision-safe ID minting** — deferred with the doc-merge (MASTER-SPEC is ID-free; IDs are re-minted on derive).
- **Per-change change-request artifact files** and a **maintenance-vs-feature roadmap lane**. Not built; tracked as future enhancements.

---

## 11. Anti-patterns

- **Editing SRS/BACKLOG/PRD from this skill.** That's the deferred doc-merge — route to `/scaffold-docs`.
- **Writing an FR/NFR ID into any file.** MASTER-SPEC has none; surface the prospective ID, don't mint it.
- **Bumping `**Spec version:**`.** It's the schema version — leave it at `1.0`; bump `**Spec revision:**` instead.
- **Editing the spec without showing the impact analysis first.** §4 is a confirmation gate.
- **Skipping the `phase_record` fold when state exists.** The amendment would be clobbered on the next `/onboard --regenerate`.
- **Silently refreshing EXECUTIVE-SUMMARY.** Respect its single-producer invariant; refresh only explicitly.
- **Adding a deterministic helper for classification/impact/minting.** This flow is agent-driven by design.
- **Re-authoring a whole phase section** when a targeted fold-in suffices. Amend, don't regenerate.
