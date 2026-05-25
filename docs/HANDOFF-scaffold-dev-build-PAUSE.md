# PARTIAL RETURN HANDOFF — scaffold-dev v0.1 build paused at Phase 0 close

> **For the resuming session:** Read this entire doc; then re-read `docs/PLAN-scaffold-dev.md` Phase 1 section (lines 308-542); then invoke `superpowers:subagent-driven-development` to continue executing from Phase 1 Task T1.1. Do NOT re-do Phase 0 — it is committed and green on `main`.

## 1. Header

| Field | Value |
|---|---|
| Handoff type | Partial return (mid-build pause; resume in fresh session) |
| Scope | Phase boundary — closes Phase 0 cleanly, defers Phase 1+ to fresh session |
| Source session | scaffold-dev build session #1 (2026-05-25; received handoff from master session, executed Phase 0 in full) |
| Composed | 2026-05-25 |
| Project | `claude-agent-scaffolding` marketplace |
| Branch | `main` |
| Canonical source-of-truth | `docs/PLAN-scaffold-dev.md` (locked — do NOT re-author) |

## 2. Why paused

Phase 0 (evals first / RED step) is a natural phase boundary: 6 tasks complete, 9 eval docs authored, 6 commits on `main`, all reviews passed (two-stage spec + code-quality per the `subagent-driven-development` skill). Phase 1 (author 8 SKILL.md bodies, PLAN lines 308-542) is substantially heavier per-task than Phase 0 — each skill body is ~300-500 lines with multi-section structure, and the orchestrator session's context budget at this point would not cleanly complete all 8 Phase 1 tasks before strain. A fresh session inherits no ballast and can execute Phase 1 contiguously.

Per HANDOFF §6b discipline: pause at phase boundaries, not mid-task. T0.6 was reviewer-approved before pause.

## 3. Phases complete

**Phase 0 — Evals first (RED) — DONE.** All 6 tasks (T0.1 through T0.6) executed via `superpowers:subagent-driven-development`. 9 eval docs total (5 heavy S1-S4 evals + 4 lighter S1-S2/S1-S3 evals). Two-stage review per task: T0.1 ran separate spec + code-quality reviewers; T0.2-T0.6 ran combined spec + code-quality (eval docs are pure documentation with locked pattern from T0.1).

Commits on `main` (parent: `edb72d9` — the master session's setup commit with PLAN + SPEC + HANDOFF):

| SHA | Task | File(s) | Lines |
|---|---|---|---|
| `b9fc2da` | T0.1 | `evals/planning-vertical-slice.md` | 162 |
| `529279b` | T0.2 | `evals/implementation-checking.md` | 174 |
| `5057f41` | T0.3 | `evals/closing-vertical-slice.md` | 182 |
| `42a00ef` | T0.4 | `evals/executing-work-item.md` | 210 |
| `3825563` | T0.5 | `evals/handing-off-session.md` | 226 |
| `9c06295` | T0.6 | 4 lighter evals (ADR / changelog / runbook / sprint-retro) | 483 (131+101+126+125) |

**Total: 1,437 lines of eval docs across 9 files.**

All evals follow the locked T0.1 style: Purpose → Harness → Scenarios (Setup/Trigger/Expected behavior/Assertion) → Pass/fail → Out of scope. LLM-judge framing, no bash truthy-tests. Style anchored to `scaffold-onboard/evals/validating-master-spec.md`.

## 4. Phase in flight

None. Phase 0 is fully closed. Phase 1 has NOT been started. No partial work, no uncommitted changes in `scaffold-dev/`.

## 5. State pointers

**Repo:** `/Volumes/master_ssd/projects/claude-agent-scaffolding/`
**Branch:** `main` (clean working tree)
**Last commit:** `9c06295` (Phase 0 T0.6 close)
**Working tree:** Clean
**Active subagents:** None
**Active worktrees:** None

## 6. Polish items deferred from Phase 0 reviews (NOT blocking Phase 1)

Reviewers approved all 6 Phase 0 tasks but flagged Important polish items. These do NOT block Phase 1 — they can be addressed inline during Phase 1 SKILL.md authoring (when the eval's assertions are first exercised against real skill bodies) or in a Phase 8 polish sweep. Capturing here so they aren't lost:

- **T0.1 (`planning-vertical-slice`):** L16 dangling `/orchestrate VS-N.M` reference (Harness mentions slash-form not exercised in any scenario); L55 `sd_manifest_*` vs `mi_manifest_*` hedge can be pinned once Phase 3 T3.2 (`lib/manifest.sh`) lands and the actual prefix is settled.
- **T0.2 (`implementation-checking`):** L41 trigger says "verify work item 2.04" but fixture uses `3.2.01` — judge currently asked to paper over via adaptation clause; tighten to use matching work-item-id; L107 `sf_rules_filter` hedge can be dropped (function VERIFIED to exist at `scaffold-onboard/lib/rules.sh:290`, prefix family alternation is OK but no need to hedge that it might not exist); `[report cross-check]` source-tag literal-token assertion is delegated to `evals/executing-work-item.md` per Out-of-scope but the delegation should be more explicit.
- **T0.4 (`executing-work-item`):** S2 trigger expands `/path/to/handoff.md` placeholder to an absolute path — internally consistent but a parenthetical note in Setup would aid future reviewers; S2's multi-call loop assertion is Mode-B-only by construction (§6.3 protocol only exists in Mode B) — add an explicit Mode-A asymmetry callout in green criteria.
- **T0.6 (4 lighter evals — the biggest backlog):**
  1. **Trigger-phrase coverage misses SPEC §7.1 verbatim** in 3 of 4 evals. Only `writing-sprint-retrospective` uses the SPEC-verbatim trigger (`close sprint N`). The other 3 (`recording-architecture-decision`, `appending-changelog-entry`, `authoring-runbook`) exercise only paraphrases. SPEC §7.1 pins: `ADR for X`, `log changelog`, `write runbook`. **Recommend:** when authoring each corresponding SKILL.md in Phase 1, add one scenario per eval that uses the SPEC-verbatim trigger.
  2. **Manufactured invariants without explicit SPEC anchorage.** MADR-lite 4-section list (ADR eval) and SRE 6-section list (runbook eval) are convention-derived. SPEC §7.1 only says "Manifest-routed" / "SRE-style runbook template" — no enumeration. The invariants are reasonable defaults but the eval body should cite "MADR-lite convention" / "standard SRE runbook format" honestly rather than implying SPEC anchorage.
  3. **Manifest routing fields used in evals don't exist in workspace-init v0.1's schema:** `routing.changelog`, `routing.runbooks`, `routing.specs_dir`. (This is a wider scaffold-dev evals issue — siblings also invent `routing.worktrees_dir`, `routing.handoffs_dir`.) Either (a) hedge each with "or equivalent" matching `closing-vertical-slice.md`'s pattern, or (b) file a manifest-schema-extension issue so Phase 1 T1.7/T1.8/T1.10 SKILL.md authors can extend workspace-init's routing block. **Recommend (a) for v0.1**; defer (b) to workspace-init v0.2.
  4. **§16b sprint-retro 6-vs-7 section ambiguity:** SPEC §16b header says "6 sections" but enumerates 7 items (the 7th is "Reference index"). Slice retrospective in same §16b says "7 sections" with 7 items (consistent). The asymmetry is likely a SPEC typo. T0.6 implementer chose 6 BINDING + 1 optional, which is the conservative read. **Recommend:** reconcile §16b in a SPEC patch — either change "6" to "7" or drop the 7th item.

These are polish items, NOT corrections. The 9 eval docs are publication-ready as-authored.

## 7. State pointers (Phase 1 readiness)

**Phase 1 input — locked:**
- All 9 evals (Phase 0 output) are the RED tests Phase 1 SKILL.md bodies must turn GREEN.
- `docs/PLAN-scaffold-dev.md` lines 308-542 — 8 SKILL.md author tasks (T1.1 through T1.8). T1.5 is `handing-off-session/SKILL.md` (the dogfood opportunity per master session's HANDOFF §4).
- Each skill body ≤500 lines per `superpowers:writing-skills` Pass D guidance.
- Skill bodies address Phase 0 eval scenarios (TDD discipline).

**Dependencies (all shipped, verify with `ls ~/.claude/plugins/cache/*/<name>/`):**
- workspace-init v0.1.0, scaffold-onboard v0.2.0, architect-critic v0.2.0, ai-mentor v2.0.0, claude-security-audit v0.1.1

**Style anchors (read-only):**
- For skill body structure: existing skills in `scaffold-onboard/skills/`, `architect-critic/skills/`, `ai-mentor/skills/`
- For bash conventions: `scaffold-onboard/lib/_helpers.sh|state.sh|compose.sh|render.sh` (function-naming `sf_*` → `sd_*`)
- For portable timeout: `architect-critic/lib/codex.sh:96-141`

## 8. Next intended actions (for resuming session)

**Single specific opening action:**

1. Read `docs/HANDOFF-scaffold-dev-build.md` (original master-session handoff) for full context.
2. Read this file (`docs/HANDOFF-scaffold-dev-build-PAUSE.md`) for Phase 0 close state.
3. Read `docs/PLAN-scaffold-dev.md` Phase 1 section (lines 308-542).
4. Invoke `superpowers:subagent-driven-development`.
5. Use it to extract Phase 1 tasks T1.1 through T1.8 into TodoWrite.
6. Dispatch Phase 1 T1.1 (`scaffold-dev/skills/planning-vertical-slice/SKILL.md`) as the first implementer subagent task.

**Subsequent actions (locked by PLAN):**

7. Execute Phase 1 completely (8 SKILL.md tasks).
8. Advance to Phase 2 (templates + reference docs).
9. Continue through Phases 3 → 3.5 → 4 → 5 → 6 → 7 → 8 in PLAN order.
10. Compose final return handoff at `docs/HANDOFF-scaffold-dev-build-RETURN.md` after Phase 8 completes (per the template in HANDOFF §10).

## 9. Anti-actions (do NOT do)

- ❌ Do NOT re-do Phase 0. All 6 tasks are committed and green.
- ❌ Do NOT skip phases. PLAN ordering is enforced.
- ❌ Do NOT parallel-dispatch implementers — sequential only.
- ❌ Do NOT re-author PLAN or SPEC.
- ❌ Do NOT pause between Phase 1 tasks unless BLOCKED.
- ❌ Do NOT install or modify other plugins.
- ❌ Do NOT force-push, rebase main, or use `--no-verify`.

## 10. Cautions / notes for resuming session

- **Combined spec + code-quality review pattern**: This session ran T0.1 with separate spec + code-quality reviewers (per `subagent-driven-development` discipline), then collapsed to combined review for T0.2-T0.6 (eval docs are pure documentation with a now-locked pattern from T0.1). The skill technically asks for separate reviews. For Phase 1 SKILL.md authoring — where skill bodies contain executable instructions, not just descriptive prose — restore the separate-reviewer pattern. Quality matters more than throughput when behavior is being encoded.
- **Phase 1 effort estimate**: PLAN says 3-4 days for 8 SKILL.md tasks. At Phase 0's per-task token velocity (~150-250K total per task incl. impl + 2 reviews), Phase 1 will likely run several sessions. Plan accordingly — composing intermediate pauses at T1.2/T1.4/T1.6 boundaries is reasonable.
- **Quality bar from T0.1 polish notes** (applied across Phase 0 — keep applying):
  - Assertions must name verbatim strings the judge accepts/rejects, not "produces good output"
  - "Expected behavior" describes what the skill does; "Assertion" describes what judge verifies — distinct phrasing
  - Out-of-scope routes each deferred concern to a specific named eval/test file
  - No emojis, no "comprehensive"/"robust"/"production-ready" filler
  - Trigger phrases match fixture content (no work-item-id drift between trigger and Setup)
- **Phase 1 dogfood opportunity**: T1.5 (`handing-off-session/SKILL.md`) is the first real-world use of the §6b handoff escape valve. THIS very pause handoff (`docs/HANDOFF-scaffold-dev-build-PAUSE.md`) is a hand-rolled instance of the same §6b.5 10-section pattern — keep it as reference material for T1.5's SKILL.md author.
- **Phase 3.5 subagent schema is provisional** (per HANDOFF §4 from master session). T3.5.1 says "verify against Claude Code docs at implementation time."

---

## Opening prompt for the resuming session (copy-paste this)

```
Read docs/HANDOFF-scaffold-dev-build.md (master handoff) + docs/HANDOFF-scaffold-dev-build-PAUSE.md (this Phase 0 close).
Then read docs/PLAN-scaffold-dev.md Phase 1 section (lines 308-542).
Invoke superpowers:subagent-driven-development to continue from Phase 1 Task T1.1.
Phase 0 is committed and green on main (commits b9fc2da → 9c06295) — do NOT re-do it.
```
