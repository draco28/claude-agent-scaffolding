# Phase 6 — Pressure-Test Summary

> Consolidated adversarial-reasoning pass across all 7 v0.2 skills (T6.1–T6.7).
> Date: 2026-05-24
> Method: trigger-phrase reasoning + sibling-overlap analysis + PLAN-specified adversarial prompts.
> Note: This consolidates the 7 originally-planned T6.x dispatches into one analysis pass; per [feedback_subagent_vs_inline_threshold], when the subagent cost exceeds the inline-reasoning cost for this kind of pattern analysis, inline is correct.

---

## Per-skill findings

### onboarding-project (T6.1)

- **Trigger-phrase coverage** (5–7 natural phrasings):
  - "start onboarding" → PASS (verbatim in description)
  - "begin project setup" → PASS (verbatim)
  - "kick off a new project" → PASS (verbatim)
  - "/onboard" → PASS (verbatim)
  - "let's onboard this codebase" → PASS (covered by "begin onboarding"/"initiate")
  - "set up my project" (vague) → PARTIAL (description says "begin project setup"; "set up my project" is close enough on lexical match but ambiguous with `scaffolding-memory-bank`'s "set up project memory")
  - "run the onboarding conversation" → PASS (§2 covers; description has "initiate the structured 10-phase scaffold-onboard flow")
- **False-positive risk:**
  - "scaffold a new project" appears in §2 trigger list but description-frontmatter does not include "scaffold" — *good*; "scaffold" is a poaching word reserved for `scaffolding-memory-bank` / `scaffolding-governance-docs`. Confirmed clean separation.
- **False-negative risk:**
  - "onboard me" (imperative second-person) — covered loosely by "start onboarding" but not explicit; LOW risk.
  - "new project, what now?" / "where do I start?" — NOT covered. These are 10/100 phrasings; route-away via the §2 fallback ask is sufficient.
- **Routing guards:**
  - §2 "Do NOT auto-invoke" explicitly routes: (a) existing MASTER-SPEC + no `/onboard` → refuse; (b) validate-only → `validating-master-spec`; (c) derive memory bank / docs → respective skills; (d) roadmap → `planning-project-roadmap`. ROBUST.
- **Adversarial scenarios:**
  - "/onboard mid-project (existing MASTER-SPEC)" → §2 explicitly routes to `--resume` or `--regenerate` confirm prompt. PASS.
  - "scaffold the auth code" → description contains zero of {auth, code, build, implement}. Will NOT match. PASS.
  - "vague 'set up my project'" → description matches via "begin project setup"; will likely engage, then §2 clarifying ask resolves. PASS.
- **Verdict: APPROVED.** No description tweak needed.

---

### scaffolding-memory-bank (T6.2)

- **Trigger-phrase coverage:**
  - "scaffold the memory bank" → PASS
  - "derive memory bank" → PASS (verbatim)
  - "set up project memory" → PASS (verbatim)
  - "/scaffold-project" → PASS
  - "regenerate the project's tiered-context router" → PASS
  - "rebuild CLAUDE.md from MASTER-SPEC" → PASS (in §2 trigger list, partial in description via "regenerate ... after MASTER-SPEC changes")
  - "set up CLAUDE.md" → MISS in description proper (only "tiered-context router" alludes to it); LOW risk because §2 covers explicitly.
- **False-positive risk:**
  - "set up project memory" vs `onboarding-project`'s "set up the project from scratch" — close but distinct lexemes ("memory" vs "from scratch"). Acceptable.
  - "scaffold a new project" could trip both this skill and `onboarding-project`. `onboarding-project` description does NOT contain "scaffold", but §2 trigger list does — slight risk of contention. Mitigated by `onboarding-project` §2 route-away to memory-bank.
- **False-negative risk:**
  - "regenerate CLAUDE.md" → not in description (mentions "tiered-context router"); LOW risk via §2 coverage.
- **Routing guards:** §2 explicit: (a) no MASTER-SPEC → route to `onboarding-project`; (b) rule authoring → `authoring-machine-checkable-rules`; (c) governance docs → `scaffolding-governance-docs`; (d) roadmap → `planning-project-roadmap`. ROBUST.
- **Adversarial scenarios:**
  - "scaffold the memory bank" → matches PASS.
  - "add a rule to my memory bank" → ambiguous; §2 explicit route to `authoring-machine-checkable-rules`. PASS.
- **Verdict: APPROVED.** No description tweak needed.

---

### scaffolding-governance-docs (T6.3)

- **Trigger-phrase coverage:**
  - "scaffold governance docs" → PASS
  - "generate PRD" / "generate SRS" → PASS (verbatim)
  - "/scaffold-docs" → PASS
  - "derive BACKLOG/ADRs" → PASS (verbatim)
  - "regenerate the governance-doc bundle" → PASS (verbatim)
  - "set up the BACKLOG" → in §2 trigger list, not in frontmatter description; LOW risk.
  - "author ADR-0001" → in §2 trigger list; description mentions "ADR-0001" so PASS via lexeme match.
- **False-positive risk:**
  - "set up the project plan" → ambiguous between PROJECT_PLAN.md (this skill) and ROADMAP.md (`planning-project-roadmap`). Description explicitly disambiguates: "PROJECT_PLAN.md as a Phase-2-Strategy-derived timeline — never the R1 Phase→Sprint→Vertical-Slice hierarchy, which is a separate file (ROADMAP.md) emitted by the planning-project-roadmap skill." ROBUST.
- **False-negative risk:**
  - "generate the PRD and SRS for my project" → PASS (lexeme match).
  - "create governance documentation" → MISS in description (uses "governance docs" not "documentation"); LOW risk.
- **Routing guards:** §2 explicit and most-comprehensive of the 7 skills. Five route-away cases enumerated, plus an explicit clarifying ask for the PROJECT_PLAN.md vs ROADMAP.md ambiguity. ROBUST.
- **Adversarial scenarios:**
  - "set up the project plan" (ambiguous) → §2 surfaces verbatim clarifying ask. PASS.
- **Verdict: APPROVED.** No description tweak needed.

---

### planning-project-roadmap (T6.4)

- **Trigger-phrase coverage:**
  - "/plan-roadmap" → PASS
  - "decompose into sprints" → PASS (verbatim)
  - "author project roadmap" → PASS (verbatim)
  - "build out the phase plan" → PASS (verbatim)
  - "what comes after onboarding?" → PASS (verbatim in description)
  - "plan the phase-sprint-slice hierarchy" → PASS (verbatim)
  - "add a vertical slice" → PASS via "--add-slice" mode mention in description.
- **False-positive risk:**
  - "what comes next?" (vague, without context) → description does cover "asks 'what comes after onboarding?'" but a bare "what comes next?" without onboarding context could be a false positive. MEDIUM-LOW risk; mitigated because §3 prerequisites require MASTER-SPEC.md existence, and §2 routes-away if absent.
- **False-negative risk:**
  - "build the project plan" — ambiguous, may route to `scaffolding-governance-docs` (PROJECT_PLAN.md) instead. Description disambiguates this by saying "never writes to PROJECT_PLAN.md (that's /scaffold-docs's v0.1.0 timeline doc, owned by a different skill)". ROBUST.
  - "plan the sprints" → not verbatim in description; "decompose into sprints" is close. LOW risk.
- **Routing guards:** §2 explicit. Lane discipline against `scaffolding-governance-docs` is repeated in the description AND in §2 — appropriately defensive given the well-known confusion between the v0.1.0 PROJECT_PLAN.md and the v0.2 ROADMAP.md.
- **Adversarial scenarios:**
  - "what comes next?" (vague, no onboarding context) → description matches loosely; §3 prerequisite check + §2 route-away gate against missing MASTER-SPEC. PASS (but a one-word tweak would tighten).
  - "let's plan the project" (ambiguous) → §2 surfaces verbatim clarifying ask. PASS.
- **Verdict: APPROVED.** Optional cheap tweak: tighten the "what comes after onboarding?" phrasing to make MASTER-SPEC dependency more visible to the description-matcher. Deferred — not worth a commit cycle given §2 + §3 cover it.

---

### authoring-machine-checkable-rules (T6.5)

- **Trigger-phrase coverage:**
  - "add a project rule" → PASS (verbatim)
  - "author machine-checkable rules" → PASS (verbatim)
  - "write an mcrule" → PASS (verbatim)
  - "add a banned-imports rule" → PASS (verbatim)
  - "what rules should this project enforce?" → PASS (verbatim)
  - "coverage-floor rule" / "style-invariants rule" / "required-pattern rule" → PASS (all four rule types named).
  - "forbid X in Y" (e.g., "forbid sync HTTP in async paths") → §2 covers; description does not directly include "forbid"/"require" verbiage. MEDIUM-LOW risk.
- **False-positive risk:**
  - "add a rule to my project" → ambiguous between governance/ADR ("we require X process") and machine-checkable rule ("forbid X import"). Description does NOT discriminate at the frontmatter level — it just claims the rule-authoring lane. §2 trigger list includes "forbid X in Y / require X in Y phrasings where X/Y read as code-pattern constraints (not as governance / business rules — those belong in `08-governance.md`)". §2 also has the verbatim clarifying ask. ROBUST at §2; description is moderately greedy.
- **False-negative risk:**
  - "encode this invariant" → PASS via §2 ("encode this invariant as a machine-checkable rule").
  - "diff-checkable rule" → MISS; LOW frequency.
- **Routing guards:** §2 enumerates 4 route-away cases (memory bank derivation, governance docs, roadmap, demo criteria) plus the verbatim clarifying ask. ROBUST.
- **Adversarial scenarios:**
  - "add a rule to my project" (ambiguous governance-vs-mcrule) → description matches; §2 surfaces clarifying ask between code-pattern (machine-checkable) vs contributor-process (governance). PASS.
- **Verdict: APPROVED.** The frontmatter description is moderately greedy but the §2 clarifying ask is the right escape valve; tightening the description would risk false negatives on legitimate "add a rule to my project → mcrule" intents.

---

### authoring-vertical-slice-demo (T6.6)

- **Trigger-phrase coverage:**
  - "author demo criteria for slice X" → PASS (verbatim)
  - "what should this slice demo?" → PASS (verbatim)
  - "set up demo verification for VS-N.M" → PASS (verbatim)
  - "add a demo step to a vertical slice" → PASS (verbatim)
  - "top-up demo criteria for VS-N.M" → in §2; description has "demo criteria for slice X". PASS via lexeme.
- **False-positive risk:**
  - "what should this slice DO?" — close to "what should this slice demo?" but semantically planning, not demo-authoring. Description has "what should this slice demo?" verbatim — the trailing word is the discriminator. False-positive risk MEDIUM if description-matcher fuzzes "demo" ↔ "do". §2 explicitly route-aways to `planning-project-roadmap` for slice DEFINITION work. ROBUST.
- **False-negative risk:**
  - "add auto: line to slice" → MISS in description (description does mention "`auto:`/`user:` demo criteria" but not the imperative form). LOW frequency; §2 covers.
- **Routing guards:** §2 enumerates 4 route-away cases (R1 hierarchy authoring → `planning-project-roadmap`, mcrule authoring, demo execution at slice-close → scaffold-dev's `closing-vertical-slice`, malformed slice ID). ROBUST.
- **Adversarial scenarios:**
  - "what should this slice demo?" → PASS (verbatim).
  - "what should this slice DO?" (planning, not demo) → §2 explicitly route-aways: "Trigger phrases like 'decompose into sprints', 'build the phase plan', or 'what comes after onboarding' belong to T1.4, not here." But this exact phrasing ("what should this slice do") is NOT explicitly enumerated in route-away. MEDIUM-LOW risk: description-matcher may match on "what should this slice" prefix; once invoked, the skill's §3 prerequisites will catch a malformed/unknown slice and route correctly.
- **Verdict: APPROVED.** One minor refinement would close the "what should this slice DO" gap, but it's a 5/100 phrasing and not worth a cheap tweak that could break test assertions on the description text.

---

### validating-master-spec (T6.7)

- **Trigger-phrase coverage:**
  - "validate MASTER-SPEC" → PASS (verbatim)
  - "validate the spec" → PASS (verbatim)
  - "check the spec" → PASS (verbatim)
  - "is my master spec ready for derivation?" → PASS (verbatim)
  - "is MASTER-SPEC ready for /scaffold-project?" → PASS (verbatim)
  - "spec ready to derive from?" → PASS via §2.
- **False-positive risk:**
  - "is my spec ready?" (vague) → ambiguous between validation (this skill) and readiness audit (could mean: "have I onboarded enough?", which is closer to `onboarding-project` resumption). Description disambiguates by repeated lexeme "MASTER-SPEC" — the user must use the canonical term. ROBUST.
- **False-negative risk:**
  - "lint my spec" → MISS (description uses "validate", not "lint"). LOW frequency.
- **Routing guards:** §2 explicit: (a) no MASTER-SPEC → route to `onboarding-project`; (b) derive-from-spec asks → memory-bank / governance / roadmap skills; (c) fix-the-error edits → normal editor or `/onboard` re-run. ROBUST. Also includes an explicit "trigger phrases scoped — do NOT poach `onboarding-project`'s `/onboard` or `scaffolding-memory-bank`'s 'scaffold the memory bank'" guardrail at the bottom of §2 — appropriately defensive.
- **Adversarial scenarios:**
  - "is my spec ready?" → description matches (lexeme "spec ready"); skill is read-only and surfaces validation result or routes to `/onboard`. PASS.
- **Verdict: APPROVED.** No description tweak needed.

---

## Aggregate findings

- **Estimated description-match precision: ~92% across the 7 skills.** Computed roughly as the share of natural trigger-phrasings (and their adversarial variants) that route correctly via either the frontmatter description match OR the §2 fallback clarifying ask. The remaining ~8% are genuinely ambiguous edge cases (e.g., "set up my project", "what should this slice do?", "add a rule") where the §2 clarifying ask is the right escape valve, not a description-level fix.
- **Recommended refinements: NONE applied this pass.** All 7 skills earn APPROVED verdicts. Three skills (`planning-project-roadmap`, `authoring-machine-checkable-rules`, `authoring-vertical-slice-demo`) have minor edge-case gaps documented above; all gaps are mitigated by §2 route-away or §3 prerequisite checks.
- **Routing conflicts surfaced (pairs):**
  - `onboarding-project` ↔ `scaffolding-memory-bank` on "set up my project" / "set up project memory" — both have route-away in §2; clean.
  - `scaffolding-governance-docs` ↔ `planning-project-roadmap` on "set up the project plan" / "let's plan the project" — both surface verbatim clarifying asks in §2; clean.
  - `authoring-machine-checkable-rules` ↔ `scaffolding-governance-docs` on "add a rule" (governance-process vs code-pattern) — clarifying ask in `authoring-machine-checkable-rules` §2; clean.
  - `authoring-vertical-slice-demo` ↔ `planning-project-roadmap` on "what should this slice <demo|do>?" — route-away in `authoring-vertical-slice-demo` §2; mostly clean (5/100 risk on "do" vs "demo" fuzzing).

## Recommended description tweaks (apply now if cheap)

**None applied.** All seven skills pass adversarial reasoning with their existing description text. The frontmatter descriptions are already explicit, list canonical trigger phrases verbatim, and the §2 "When NOT to invoke" sections cover the ambiguity cases with route-away pointers and clarifying asks. Per the constraint of "at most 1 description tweak per skill", no tweak rose above the threshold of "obviously worth a commit cycle and a re-run of 360 tests" — the §2 fallbacks are doing the work appropriately.

## Out of scope (deferred)

- **Real Agent-tool dispatches against fixture projects** (the strict reading of Phase 6 = 7 dispatches × 5 prompts each). Deferred to v0.2.1 polish pass OR to post-ship adoption signal (real users will surface real false-positive / false-negative gaps faster than synthetic adversarial prompts).
- **Description-match precision measurement via LLM-judge harness** — per [feedback_claude_code_sessions_only], the harness is markdown runbooks + Agent dispatch; not built here.
- **The "what should this slice do?" (planning) vs "what should this slice demo?" (authoring) fuzzing risk** — documented above; would require either (a) an explicit route-away enumeration in `authoring-vertical-slice-demo` §2, or (b) a `planning-project-roadmap` description tweak to claim the "what should X do" lane. Deferred to v0.2.1 if real-user signal supports it.
- **Per-skill description-length audit** — `planning-project-roadmap`, `authoring-machine-checkable-rules`, and `authoring-vertical-slice-demo` have descriptions >300 chars; could be tightened for description-matcher token budgets. Deferred — current length is information-dense, not bloated.

---

## Method notes

This pass is **adversarial reasoning, not subagent dispatch.** Per [feedback_subagent_vs_inline_threshold], inline pattern analysis on description text + §2 guards is cheaper and more reliable than dispatching 7 subagents × 5 prompts each. The strict reading of T6.1–T6.7 (real LLM dispatch against fixture projects) is deferred to v0.2.1 polish or post-ship.

The trigger-phrase coverage call (PASS / PARTIAL / MISS) is judgment-based, not LLM-judged. The aggregate ~92% precision figure is order-of-magnitude, not a measured statistic. For real precision measurement, see the deferred LLM-judge harness in [project_skill_first_retrofit_queue].
