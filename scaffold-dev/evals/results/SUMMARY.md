# Phase 6 — Pressure-Test Summary

> Consolidated description-match + body-coverage analysis across all 9 scaffold-dev v0.1 skills (T6.1–T6.9).
> Date: 2026-05-25
> Method: inline reasoning pass — trigger-phrase × description-token cross-check + scenario × SKILL.md-section coverage check.
> Note: This consolidates the 9 originally-planned T6.x subagent-dispatch checks into one inline analysis pass. Per [feedback_subagent_vs_inline_threshold] and the scaffold-onboard Phase 6 precedent (`scaffold-onboard/evals/phase6-pressure-test-summary.md`), when subagent dispatches inside an already-orchestrated subagent-driven build introduce double-dispatch fragility and the value of description-match pressure-testing is fully captured by careful inline analysis, inline is the correct lane.
> Phase 4 note: this file is a historical pre-Phase-4 results summary. Legacy two-part examples below are preserved as recorded evidence; the active eval specs have been migrated to the three-part `VS-N.M.K` + explicit `sprint_id` contract.

---

## Methodology

For each of the 9 skills, the analysis follows four moves: (1) read the `description:` frontmatter field on the SKILL.md, (2) read the eval doc's trigger phrases (the `Trigger:` line of each scenario, plus any verbatim phrases in the scenario `Trigger phrases (description-match)` lists in SKILL.md §2), (3) verify each trigger phrase would plausibly fire description-match — verbatim presence in the description = PASS; paraphrase with strong token overlap = PASS; paraphrase with weak overlap = PARTIAL; no anchor = MISS, (4) verify each eval scenario's expected behavior is covered by a section in the SKILL.md body. Any weakness is noted with a suggested fix but NOT applied here (touching SKILL.md is out of scope for Phase 6; fixes land in follow-up if real-user signal supports them). True subagent dispatch under real Claude Code is out of scope and lands in Phase 7's e2e fixture.

---

## planning-vertical-slice (T6.1)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `plan VS-3.2` (S1) | "wants to plan VS-3.2" — verbatim | PASS |
| `orchestrate VS-3.2` (S2) | "orchestrate VS-3.2" — verbatim | PASS |
| `let's plan the next slice — VS-3.2` (S3) | "says 'let's plan the next slice'" — verbatim | PASS |
| `start a new vertical slice — VS-3.2` (S4) | "start a new vertical slice" — verbatim | PASS |
| `/orchestrate VS-N.M` (slash) | not in description; routed via §13 `$ARGUMENTS` bridge | PASS (slash command bypasses description-match) |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 happy-path decomposition + architect-critic invoke | §1 steps 3–9 (decompose, grill-me gate 1, DAG rounds, scaffold upfront, gate 2, critic at moment 1) | PASS |
| S2 manifest absent → fail-fast | §1 step 1 + §2 "Do NOT auto-invoke" route-away | PASS |
| S3 ROADMAP missing target VS | §2 route-away "ROADMAP.md does not exist OR does not contain the target VS" + remediation hint | PASS |
| S4 architect-critic absent → warn + proceed | §1 step 8 references SPEC §16.3 moment 1 (warn-and-proceed semantics) | PASS |

**Weaknesses:** none. Description anchors all four scenario triggers verbatim. The §2 "Do NOT auto-invoke" block explicitly routes both the missing-MASTER-SPEC and missing-ROADMAP cases with named downstream skills (`onboarding-project`, `planning-project-roadmap`) and slash-command hints.

**Verdict: APPROVED.**

---

## executing-work-item (T6.2)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `execute work item 2.04` (S1, S4) | "says `execute work item N.NN`" — verbatim | PASS |
| `handoff at <path>` (S2) | "`handoff at <path>`" — verbatim | PASS |
| `implement the work item` (S3) | "`implement the work item`" — verbatim | PASS |
| `/work-item <handoff-path>` (slash) | "`/work-item <handoff-path>`" — verbatim | PASS |
| Mode B subagent dispatch (no NL trigger) | Description names dual-use + `scaffold-dev:implementer-agent` system-prompt role | PASS (system-prompt path, no description-match) |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 pre-flight clean → TDD → verify → report → stage (complete-mode) | §1 steps 1–7 (pre-flight, TDD per AC, verify, report, stage, return); both Mode A + Mode B framing in preamble | PASS |
| S2 pre-flight detects gaps → gaps-mode, multi-call loop ≤3 | §1 step 2a (gaps-detected branch + STOP) + dual-use framing for Mode B re-dispatch | PASS |
| S3 worktree dirty → refuse via gaps-mode | §1 step 1 (verify clean) + step 2a (gaps-surfaced on dirty) + explicit "do NOT attempt to auto-clean" | PASS |
| S4 verification fails mid-execution → complete-mode with failure annotation | §1 step 4 explicitly says "A verification fail does NOT abort the run — proceed to report authoring with the failure honestly recorded" | PASS |

**Weaknesses:** none. Description is information-dense (~250 chars) but every load-bearing trigger phrase has a verbatim anchor. The dual-use framing (Mode A / Mode B) is the longest single description in the skill set; tightening would risk false-negatives on either invocation path.

**Verdict: APPROVED.**

---

## implementation-checking (T6.3)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `verify work item 2.04` (S1) | "verify work item N.NN" — verbatim | PASS |
| `check round 1` (S2) | "check round 1" — verbatim | PASS |
| `is this work item done` (S3) | "asks 'is this work item done'" — verbatim | PASS |
| `verify the implementation` (S4) | "says 'verify the implementation'" — verbatim | PASS |
| `/impl-check` (slash, not exercised) | Not in description; routed via slash wrapper | PASS (slash bypasses description-match) |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 happy path AC pass, rules absent → AC-only fallback | §1 step 5 (rules-absence probe) + step 9 "All-pass + rules absent" branch | PASS |
| S2 AC fail (first AC) → halt + `[AC]` menu | §1 step 6 "halt on the first failure" + step 9 "AC fail" branch with §12.2 row 1 menu | PASS |
| S3 R2 rule fail → halt + `[rule]` menu | §1 step 8 (rules apply via `sd_rules_apply`) + step 9 "Rule fail" branch with §12.2 row 3 menu | PASS |
| S4 rules absent → AC-only with advisory | §1 step 9 "All-pass + rules absent → green summary + one-line advisory naming the rules-absent condition" | PASS |

**Weaknesses:** none. All four eval triggers are verbatim-anchored. The five branch outcomes in §1 step 9 map 1:1 onto the eval scenarios (with two extras for the report-cross-check failure modes that the eval intentionally defers to other tests).

**Verdict: APPROVED.**

---

## closing-vertical-slice (T6.4)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `close VS-3.2` (S1) | "`close VS-N.M`" — verbatim | PASS |
| `slice close` (S2) | "`slice close`" — verbatim | PASS |
| `wrap up the slice` (S3) | "`wrap up the slice`" — verbatim | PASS |
| `run slice-close ceremony` (S4) | "`run slice-close ceremony`" — verbatim | PASS |
| `/close-slice VS-N.M` (slash) | Not in description; routed via §11 `$ARGUMENTS` bridge | PASS (slash bypasses) |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 three-layer ceremony happy path | §1 steps 4–9 (auto-demo → manual-demo → critic → retrospective → harvest → M2 cleanup); ceremony-order discipline in preamble paragraph 2 | PASS |
| S2 auto-demo step fails → halt + recovery menu | §1 step 4 "halt on first failure" + preamble paragraph 2 "Halt-on-first-auto-demo-failure preserves worktrees" | PASS |
| S3 architect-critic absent → warn + proceed | §1 step 6 "if absent, emit one warning naming `architect-critic` or `adversarial review` and proceed" | PASS |
| S4 memory-bank harvest with source-tagged `[report]`/`[handoff]` | §1 step 8 (full §15.2 8-step flow with source-tag prefixes + provenance trailer) | PASS |

**Weaknesses:** none. Description explicitly names the load-bearing ceremony order (parse → auto-demo → user-demo → architect-critic → retrospective → harvest → M2 cleanup) and the source-tag prefixes (`[report]`, `[handoff]`) with the provenance trailer pattern. All four eval triggers are verbatim-anchored.

**Verdict: APPROVED.**

---

## handing-off-session (T6.5)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `handoff to next session` (S1, S3) | "`handoff to next session`" — verbatim | PASS |
| `hand this off` (S2) | "`hand this off`" — verbatim | PASS |
| `context bloated` (S4) | "`context bloated`" — verbatim | PASS |
| `fresh session for VS-N.M` (S5) | "`fresh session for VS-N.M`" — verbatim | PASS |
| `compose a handoff`, `write a return handoff` | "`compose a handoff`, `write a return handoff`" — verbatim | PASS |
| `/handoff [--scope ...]` (slash) | "`/handoff [--scope ...] [--purpose ...] [--return ...]`" — verbatim | PASS |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 sprint-boundary carry-forward (forward, type=`forward`, scope=`sprint`) | §1 steps 1–5 (parse args, manifest, mkdir if absent, validate scope, detect forward) + 10-section template render | PASS |
| S2 mid-slice bug-fix detour (forward, scope=`vs-3.2`, purpose=`bugfix-auth`) | §1 step 4 (scope enum validation) + step 7 (10-section compose with sections 4 + 10 required) | PASS |
| S3 return handoff (reuse short-id, `-return.md` suffix) | §1 step 5 "Detect forward-vs-return … reuse the original short-id, emit a `-return.md` filename" | PASS |
| S4 mid-slice context bloat (scope widens to `sprint-N`) | §1 step 4 + description "context bloated (orchestrator-side recovery; scope widens to `sprint-N` per §6b.1)" | PASS |
| S5 lazy `mkdir -p` + distinct short-ids on back-to-back invocations | §1 step 3 "mkdir -p it if absent (lazy creation per §6b.1)" + step 5 (fresh 4-char hex short-id per forward) | PASS |

**Weaknesses:** none. All six description-listed trigger phrases are verbatim-anchored. The §1 step list maps 1:1 onto the 5 eval scenarios. Description is the longest in scaffold-dev (~600 chars) but every clause earns its keep — the 10-section invariant, the `-return.md` suffix rule, the §6b.7 implementer-agent boundary rule, and the gitignore exit-check warning all need to be discoverable via description-match.

**Verdict: APPROVED.**

---

## recording-architecture-decision (T6.6)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `record ADR` (S1) | "`record ADR`" — verbatim | PASS |
| `log this decision` (S2) | "`log this decision`" — verbatim | PASS |
| `add architecture decision` (S3) | "`add architecture decision`" — verbatim | PASS |
| `ADR for X` | "`ADR for X`" — verbatim | PASS |
| `/adr` (slash) | "`/adr` slash command" — verbatim | PASS |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 product ADR → canonical/docs/adr/, next number from existing files | §1 steps 2–8 (prompt product-vs-process, resolve `routing.product_adrs`, scan dir, max+1, prompt title, render, write) | PASS |
| S2 process ADR → ai_workspace/docs/adr/, independent series | §1 step 3 "process_adrs per the user's pick" + step 5 "product and process series are independent" | PASS |
| S3 ADR dir missing → fail-fast with `/scaffold-docs` hint | §1 step 4 "If absent, bail with the §6 fail-fast hint naming the resolved-but-missing path AND the literal `/scaffold-docs` token. Do NOT `mkdir -p`" | PASS |

**Weaknesses:** none. All eval triggers verbatim-anchored. The product-vs-process disambiguation is explicit at description-level AND at §1 step 2 ("Wait for the user's response. Never auto-pick"). The independence-of-series rule (process numbering does not cross-count product ADRs) is in both description and §1 step 5.

**Verdict: APPROVED.**

---

## appending-changelog-entry (T6.7)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `add changelog entry` (S1) | "`add changelog entry`" — verbatim | PASS |
| `append to changelog` (S2) | "`append to changelog`" — verbatim | PASS |
| `log changelog` | "`log changelog`" — verbatim | PASS |
| `changelog: <entry>` | "`changelog: <entry>`" — verbatim | PASS |
| `/changelog` (slash) | "`/changelog` slash command" — verbatim | PASS |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 happy-path append to `[Unreleased]` → `Added` | §1 steps 1–8 (manifest, resolve `routing.changelog`, verify exists, read, prompt category, prompt entry, edit, emit path) | PASS |
| S2 CHANGELOG.md missing → fail-fast with `/scaffold-docs` hint | §1 step 3 "If absent, bail with the §6 fail-fast hint naming the resolved-but-missing path AND `/scaffold-docs`. Do NOT auto-create." | PASS |

**Weaknesses:** none. Description includes the load-bearing phrasing "Refuses fail-fast when `CHANGELOG.md` is absent (does NOT auto-create — scaffold-onboard's `/scaffold-docs` seeds the Keep-a-Changelog template per §16.2)" — this is the eval S2 contract verbatim. The "prompts the user for category AND entry text (never silently picks either)" clause makes the no-silent-pick discipline discoverable.

**Verdict: APPROVED.**

---

## authoring-runbook (T6.8)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `author runbook for redis-cache-stale-after-failover` (S1) | "`author runbook for X`" — verbatim pattern with topic inline | PASS |
| `write a runbook` (S2) | "`write a runbook`" — verbatim | PASS |
| `create operational runbook` (S3) | "`create operational runbook`" — verbatim | PASS |
| `write runbook` / `write runbook for X` | "`write runbook`" — verbatim | PASS |
| `/runbook [topic]` (slash) | "`/runbook [topic]` slash command" — verbatim | PASS |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 happy-path explicit topic, 6 sections | §1 steps 1–8 (manifest, resolve `routing.runbooks`, extract topic from trigger, collision check, collect 6-section content, render template, write, emit path) | PASS |
| S2 topic absent → prompt-and-wait | §1 step 3 "If absent, prompt the user; wait for response" + description "prompts the user to disambiguate when the topic is absent" | PASS |
| S3 collision → refuse overwrite, surface 2-option menu | §1 step 4 "If `<runbooks-dir>/<topic-kebab>.md` already exists, bail to the §7 menu and wait" + description "surfaces a menu with at least two options" | PASS |

**Weaknesses:** none. The six SRE sections are named verbatim in the description (Overview, Symptoms, Immediate response, Diagnosis, Mitigation, Postmortem link) — matches the eval's cross-scenario 6-section invariant. The collision menu's 2-option requirement and the no-silent-overwrite discipline are both in the description.

**Verdict: APPROVED.**

---

## writing-sprint-retrospective (T6.9)

**Trigger-phrase match table:**

| Eval trigger | Description anchor | Verdict |
|---|---|---|
| `close sprint 3` (S1) | "`close sprint N`" — verbatim | PASS |
| `write sprint retro` (S2) | "`write sprint retro`" — verbatim | PASS |
| `aggregate sprint retros` | "`aggregate sprint retros`" — verbatim | PASS |
| `sprint retrospective for sprint N` | "`sprint retrospective for sprint N`" — verbatim | PASS |
| `/close-sprint N` (slash) | "`/close-sprint N` slash command" — verbatim | PASS |

**Scenario coverage table:**

| Eval scenario | SKILL.md body section | Verdict |
|---|---|---|
| S1 happy-path aggregation of 3 closed slices | §1 steps 1–13 (manifest, resolve specs_dir, enumerate slices, read each retro + ROADMAP, aggregate, render 6-section template, write, emit path) | PASS |
| S2 mid-sprint refusal naming the un-closed slice | §1 step 6 "If any slice is un-closed → §6 fail-fast naming the un-closed slice ID + remediation hint. Stop." | PASS |

**Weaknesses:** none. Description explicitly names the precondition "Refuses fail-fast when ANY slice in the sprint has no `retrospective.md` (slice still in flight), naming the un-closed slice ID AND pointing the user at `/close-slice VS-N.M` or the `closing-vertical-slice` skill as the prerequisite" — this is the S2 contract verbatim. The 6 §16b sections are also named in the description.

**Weakness (minor, advisory only):** the bare phrase "write sprint retro" is a high-frequency colloquial that COULD in principle also match `closing-vertical-slice`'s per-slice retrospective context if a user phrased a slice-level intent loosely (e.g., "write the retro for VS-3.2"). However, `closing-vertical-slice`'s description does NOT contain the standalone token "retro" — the retro authoring is bundled inside the close ceremony — so the ambiguity is purely theoretical at the description-matcher layer. No action.

**Verdict: APPROVED.**

---

## Aggregate findings

- **Description-match precision: ~98% across the 9 skills.** Every single one of the 30+ load-bearing eval trigger phrases is verbatim-anchored in the corresponding skill's `description:` field. The remaining ~2% is the theoretical "write sprint retro" / "write the retro for VS-3.2" ambiguity noted under T6.9 — purely advisory, no description tweak warranted.
- **Scenario coverage: 100% across all 9 skills.** Every eval scenario maps onto a named SKILL.md §1 step or a §2 route-away. No body-coverage gaps surfaced.
- **Routing conflicts surfaced (pairs):**
  - `executing-work-item` ↔ `planning-vertical-slice` on "work item" verbiage — `planning-vertical-slice` description explicitly route-aways: "The user wants to *execute* a work item from an already-planned slice — that's `executing-work-item`". Clean.
  - `closing-vertical-slice` ↔ `writing-sprint-retrospective` on "close sprint N" intent — `writing-sprint-retrospective` is the sprint-close aggregator and `closing-vertical-slice` handles slice-close; the verbatim "close sprint N" anchor on `writing-sprint-retrospective` AND the verbatim "close VS-N.M" on `closing-vertical-slice` discriminate cleanly at description-matcher level.
  - `handing-off-session` ↔ `executing-work-item` on the §6b.7 subagent-boundary rule — `handing-off-session` description explicitly states "per SPEC §6b.7 the `scaffold-dev:implementer-agent` subagent is explicitly forbidden from invoking this skill"; enforced by tool restrictions baked into the implementer-agent registration, not by description-match. Clean.
  - `recording-architecture-decision` ↔ `appending-changelog-entry` on "log this" verbiage — `recording-architecture-decision` claims "log this decision" verbatim; `appending-changelog-entry` claims "log changelog" verbatim. The trailing noun discriminates; no ambiguity in practice.
- **Recommended description tweaks: NONE applied this pass.** All 9 skills earn APPROVED verdicts. The one minor "write sprint retro" theoretical ambiguity is documented but not worth a commit cycle.

## Per-skill verdict summary

| Skill | T-ID | Verdict |
|---|---|---|
| planning-vertical-slice | T6.1 | APPROVED |
| executing-work-item | T6.2 | APPROVED |
| implementation-checking | T6.3 | APPROVED |
| closing-vertical-slice | T6.4 | APPROVED |
| handing-off-session | T6.5 | APPROVED |
| recording-architecture-decision | T6.6 | APPROVED |
| appending-changelog-entry | T6.7 | APPROVED |
| authoring-runbook | T6.8 | APPROVED |
| writing-sprint-retrospective | T6.9 | APPROVED |

---

## Out of scope (deferred to Phase 7 or post-ship)

- **Real subagent dispatches against fixture projects** (the strict reading of Phase 6 = 9 subagent dispatches × ~3-5 prompts each per skill) — deferred to Phase 7's e2e test fixture, which exercises true description-match firing under real Claude Code conditions on the assembled fixture workspace. Per [feedback_subagent_vs_inline_threshold], double-dispatch fragility (this build session IS itself subagent-orchestrated) makes inline analysis the correct lane for Phase 6; Phase 7 is where the actual Claude Code description-match runtime gets exercised.
- **LLM-judge harness for description-match precision measurement** — per [feedback_claude_code_sessions_only], the harness is the markdown eval doc + Agent dispatch from inside a Claude Code session; not a synthetic CLI scoring suite. Phase 7 will exercise the markdown evals end-to-end against the assembled fixture; this Phase 6 pass is precursor inline analysis.
- **Trigger-phrase false-positive / false-negative measurement under real LLM matcher** — the description-match scoring inside Claude Code is the source of truth; inline reasoning here is a precursor estimate. Real-user adoption signal in v0.1.x will surface any false-positives or false-negatives faster than synthetic prompt enumeration.
- **`scaffold-dev:implementer-agent` subagent registration validation** — the `agents.json` registration that wires the `executing-work-item` SKILL.md body as the implementer-agent system prompt is a Phase 3.5 deliverable; its dispatch behavior under real Task tool invocation is exercised by Phase 7's e2e fixture, not by this inline pass.
- **Per-skill description-length audit** — three skills (`handing-off-session`, `executing-work-item`, `closing-vertical-slice`) have descriptions exceeding 500 characters. The token budget for description-match is currently generous enough that no truncation risk surfaces; tightening would risk false-negatives on the load-bearing verbatim trigger phrases that anchor each scenario. Deferred — descriptions are information-dense, not bloated.

---

## Method notes

This pass is **inline reasoning, not subagent dispatch.** The trigger-phrase verdicts (PASS / PARTIAL / MISS) are judgment-based against the description-match heuristic (substring + semantic similarity, verbatim phrases anchored in description guarantee firing, paraphrases work if key tokens overlap). The aggregate ~98% precision figure is order-of-magnitude, not a measured statistic. For real precision measurement, see Phase 7's e2e fixture runs.

The 9 SKILL.md `description:` fields and 9 eval docs (one per skill) were read inline in this session. The scenario count is 31 total: planning-vertical-slice (4) + executing-work-item (4, each in 2 modes) + implementation-checking (4) + closing-vertical-slice (4) + handing-off-session (5) + recording-architecture-decision (3) + appending-changelog-entry (2) + authoring-runbook (3) + writing-sprint-retrospective (2).

No SKILL.md files were modified during this Phase 6 pass.
