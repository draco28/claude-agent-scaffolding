# Session Handoff — ossify Plan A complete → Plan B next

**Date:** 2026-07-13
**Session:** "ossify" — designed the ossify plugin, wrote + executed Plan A (core state engine).
**Purpose of this doc:** preserve the *execution methodology and quality bar* used for Plan A so Plans B/C/D are planned and built with identical rigor. The *what/why* (design, decisions) is already in the specs, the plan, and the memory bank — this doc captures the **HOW** that otherwise lives only in session context.

---

## 0. Read these first (already-preserved context — do not re-derive)

- **Memory:** `~/.claude/.../memory/project_ossify_skeleton_first_lifecycle.md` — full design summary, Plan A ship status, deferred items, next step. (Indexed in MEMORY.md.)
- **Main spec (APPROVED):** `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` — the lifecycle model, §9.2 state-safety, §5.3 floor rules, §6.1 demo, §7 architecture-evolution, §13 open questions, §15 decision log (11 entries incl. the architect-critic close-audit concessions).
- **Companion spec (APPROVED):** `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` — part two; its §8 lists exact amendment touchpoints into the main spec.
- **Doctrine companion:** `docs/conventions/evolutionary-architecture-playbook.md` — Codex's one-shot playbook; 15 convergences, 13 mechanisms extracted, 4 rejected (recorded in main spec §14 + decision log #10/#11).
- **Plan A (executed):** `docs/superpowers/plans/2026-07-12-ossify-core.md` — its **"Series map"** section sketches Plans B/C/D and its Global Constraints block is the reusable constraint set.
- **SDD ledger (gitignored scratch, but READ IT):** `.superpowers/sdd/progress.md` — per-task record with every bug found, fix, and reviewer verdict. This is the ground truth for what happened.

---

## 1. Where we are

- **Plan A SHIPPED** on branch `feat/ossify-core` (16 commits `1a282d6..43e4adf`; last code commit `846b195`, docs `43e4adf`). **Branch kept, NOT merged** — Plans B/C/D may stack on it or branch fresh from `main`.
- Built: `oss` dispatcher + `lib/{id,state,doctor,entities,registries,ledger,demo}.sh` + per-lib test suites + integration test (121 assertions). All green; repo-root parity suite unaffected.
- ossify is **deliberately NOT registered** in `marketplace.json` — stays dormant until Plan D's eval ship gate. Do not register early.
- Docs committed to the branch; `README.md`'s "Development model" section is the USER's own uncommitted edit — leave it unless asked.

## 2. The 4-plan series (rolling-wave — detail each only after its predecessor ships)

Per the methodology we're building (and dogfooding): **do NOT write Plans B/C/D in full now.** Detail Plan B *now that A shipped and taught us the state-layer shape*; keep C/D as the series-map sketch until their predecessor lands. This is the "current release detailed + next sketched" rule applied to our own plans.

- **Plan A (DONE):** state engine, dispatcher, ID grammar, ledger runner.
- **Plan B (NEXT — detail it now):** onboarding + planning skills — `start` (spec-core onboarding: journey map, skeleton-cut, bones w/ smoke-test pass, posture block, risk gates, lean-bootstrap minimums, spec-core critic moment), `plan-release` (feature-map groom, class declaration + critic-veto interpretation w/ fail-closed default, RELEASE.md, pilot-evidence wiring), `plan-spine` (decomposition, DAG rounds, demo authoring w/ floor rules, citation fold-in). Entry-skill tree + `references/` progressive-disclosure layout, state-path/manifest resolution, eval fixtures for the planning judges. Spec: main §4-§5, §9.1; companion §3.
- **Plan C:** execution + close (work-item port, `close` router, ledger walkthrough + release close, harvest, patch lane, utility commands, pr_hierarchical). Main §6-§8.
- **Plan D:** boundary + ship gate (workspace-init additive extension, multi-repo worktrees + cross-repo dep overrides, boundary audit, the consolidated eval suite = THE ship gate, marketplace registration, Forge3D greenfield + pulse-trader adopt-forward pilots). Companion §4-§6; main §10, §13.4.

---

## 3. THE EXECUTION PLAYBOOK (this is the quality-preservation core)

Replicate this exactly for B/C/D. Each numbered step is load-bearing — the 9 bugs Plan A's review layer caught were caught *because* of this discipline.

### 3.1 Before writing a plan
1. **Detail only the current plan** (rolling-wave, §2 above). Use what the shipped predecessor taught (e.g. Plan B should mint IDs *inside* the lock — see §5).
2. Invoke **`superpowers:writing-plans`**. Non-negotiables from that skill that we held to:
   - **Complete code in EVERY step** — no placeholders, no "similar to Task N", no "add error handling". A reviewer/implementer reads tasks out of order.
   - **Bite-sized TDD steps:** write failing test → run to see it fail (RED) → minimal impl → run to see pass (GREEN) → commit. One deliverable per task, independently reviewable.
   - **Global Constraints block** at the top, copied verbatim into each task's dispatch. (Reuse Plan A's constraint block — strict-mode, BSD/macOS, §9.2, ID grammar, `_oss_apply_op` purity, `ossify/`-scoped commits.)
   - **Series map** for the not-yet-detailed plans.
   - **Self-review** the plan against the spec (placeholder scan, type consistency, spec coverage).
3. **Pre-flight scan the plan for self-authored bugs** before executing. On Plan A this caught a harness `set -e` bug I'd written. Fix unambiguous self-authored issues in the plan text directly; escalate genuine design ambiguities to the user.

### 3.2 Spec/plan review before executing (do this for each plan's spec-touching design)
- Run an **adversarial self-review** via a Workflow with 2 opposing-bias reviewers (one hunts contradictions/gaps/ambiguity, one fact-checks claims against the repo). Plan A's two spec self-review passes caught ~24 + ~24 findings.
- For load-bearing designs, run **`/critique --close`** (architect-critic with the external Codex fresh-frame adversary). On the ossify spec this produced 11 challenges, all folded. **Codex returns rc=143 from the wrapper but its JSON result IS written** — read `<output_dir>/codex-audit-*.json` even on nonzero rc (known [[reference_codex_cli_model_mismatch]] behavior; Codex CLI is on gpt-5.6-sol / 0.144.1 and works).
- Disposition-triage the challenges: auto-accept spec-aligned ones, escalate only load-bearing/vision-touching ones to the user. Fold ALL concessions into the spec + decision log before executing.

### 3.3 Subagent-driven execution loop (superpowers:subagent-driven-development)
Announce it, then per task:
1. **Ledger check** first (`.superpowers/sdd/progress.md`) — never re-dispatch a task the ledger marks complete (survives compaction). Start a FRESH ledger per plan (the Plan A one is done; note the prior one as superseded).
2. **Extract the brief:** `scripts/task-brief <plan> N` → prints a file path. Hand the implementer the *brief path*, not the plan.
3. **Dispatch implementer** (Agent, `general-purpose`, **model: sonnet** — good floor for bash transcription + test-debug; cheaper models take 2-3× the turns on strict-mode debugging). Dispatch prompt contains: 1 line on where the task fits, the brief path ("read this first — your requirements, exact values verbatim"), interfaces/decisions from earlier tasks the brief can't know, your resolution of any ambiguity, the report-file path, and the report contract. Bind the Global Constraints. **Tell the implementer: "the brief's literal code may contain a bug — if a test won't pass with it, debug the impl to satisfy the test's INTENT and document the deviation."** This line is what turned the implementers into a second bug-catching layer (they found 4 bugs in the plan's own code).
4. **Handle status:** DONE / DONE_WITH_CONCERNS (read concerns) / NEEDS_CONTEXT (provide + redispatch) / BLOCKED (more context, or more capable model, or split task).
5. **Review-package:** `scripts/review-package <BASE> HEAD` where BASE = the commit before THIS task (from the ledger), never `HEAD~1`.
6. **Dispatch task reviewer** (Agent, `general-purpose`, **model: sonnet**). Give it: brief path, report path, diff-package path, the binding Global Constraints, and **specific NAMED RISKS to check** (one focused check each — this is what makes reviews find real bugs vs. rubber-stamp). Instruct: treat the report as UNVERIFIED claims; verify against the diff; calibrate Critical/Important/Minor; plan-mandated findings labeled. Do NOT tell a reviewer what not to flag or pre-rate severity.
7. **Fix rounds:** dispatch fixes for Critical + Important. **Route fixes via `SendMessage` to the SAME implementer** (preserves context) with precise instructions + a required RED test proven to fail against current code. For a fix the reviewer already prescribed verbatim + small, **verify inline yourself** (git diff + run tests) instead of spending a re-review subagent. For bigger fixes, re-review via SendMessage to the SAME reviewer that raised the findings.
8. **Minor findings:** record in the ledger as "Minor-for-final", don't interrupt the flow; the final review triages them.
9. **Ledger line** on clean review: `Task N: complete (commits <base7>..<head7>, review clean)` + any Minor-for-final notes.

### 3.4 Fix-routing judgment (the rule that kept velocity)
- A finding that fixes code to **match the plan's own stated intent** (e.g. plan constraint says "handled as fail" but code passes) → **just fix it**, no user escalation. This covered ~all of Plan A's fixes.
- A finding that **contradicts the plan's design** → present finding + plan text to the USER, ask which governs. (Didn't happen in Plan A, but be ready.)
- Plan-prose over-specification (e.g. Interfaces line listing unused helpers) → fix the plan text (YAGNI), don't add dead code.

### 3.5 Final whole-branch review + finish
1. After all tasks: **`scripts/review-package <merge-base> HEAD`** (merge-base = `git merge-base main HEAD`).
2. Dispatch the final reviewer with **`requesting-code-review`'s code-reviewer.md** template, **model: opus** (most capable — this is the architecture-soundness gate). Point it at cross-cutting concerns the per-task reviews couldn't see (on Plan A: `_oss_apply_op` replay-safety as a SET, strict-mode consistency across all libs, schema coherence, rc-taxonomy consistency, test integrity) + the accumulated Minor-for-final list for triage.
3. **One fix subagent for the whole final-review findings list** (not one-per-finding — that rebuilds context each time). RED-prove behavior changes.
4. **`superpowers:finishing-a-development-branch`:** verify tests → detect env → present the 4 options → execute the user's choice. (Plan A: user chose "keep branch as-is".)

---

## 4. RECURRING TECHNICAL GOTCHAS (Plan B/C/D extend the SAME libs — these WILL recur)

The state/ledger/registry libs run under `set -euo pipefail` (sourced by `bin/oss`). Every one of these bit us at least once:

1. **Bare `x="$(cmd)"` under `set -e`** aborts the process on a nonzero rc — and if it sits between lock-acquire and lock-release, **leaks the lock forever (permanent DoS on the state file)**. This was a Critical. **Structural fix pattern (already in `state.sh`):** run the critical section as a body function invoked in `|| rc=$?` context — errexit is SUSPENDED for the whole body, so NO bare command-sub inside it can hard-exit — then release the lock unconditionally in the wrapper. Any new mutating ceremony in B/C MUST follow this pattern.
2. **Unguarded `jq` that finds nothing** → nonzero rc → aborts the dispatcher. Guard with `2>/dev/null || true` (or `|| { cleanup; return N; }`). This bit Task 2, 3, 4, 9.
3. **`[ "$v" -gt N ]` on a non-numeric `$v`** errors; inside an `if` it reads as false and falls through — a Critical silent-pass. Guard with a digits-only `case` before the comparison.
4. **`set +e; ...; set -e` toggle inside a function is fragile** — prefer NOT toggling global errexit; use the `|| rc=$?` / `if cmd; then` idioms. The test harness must NOT enable `set -e` (tests observe failures).
5. **`... | while read` (pipe) runs the loop in a SUBSHELL** → variable mutations lost. Use `while read ... done < <(process-substitution)` so accumulator vars (like `hit`) persist. (registries touch-check.)
6. **Chained `local a=... b="${a}..."` on ONE line** evaluates all RHS against PRE-statement values → `b` reads unset `a`. Split into sequential assignments. (id.sh parse bug.)
7. **`_oss_apply_op` ops MUST be pure deterministic jq transforms** (both mutate AND replay route through it). Any op that shells out / reads external state / is non-deterministic silently breaks replay-based drift detection. IDs + timestamps are minted by the CALLER and baked into the payload BEFORE journaling, so replay reproduces them. **Every new op in B/C must preserve this** and keep `test-state-replay.sh` green.
8. **`printf '%s' ""` → jq -R reads zero lines → no output** (not `[]`). Use `printf '%s\n'`. (csv helper.)
9. **Mechanical guards need trim/normalization** — the §5.3 inspector-phrasing floor was bypassable by a leading space until trimmed. Normalize before matching.
10. **Test harness must run under `bash`** (zsh errexit/NOMATCH differs). `run-all.sh` forces `bash "$t"`; keep it.
11. **Repo-root parity suite** (`tests/test-codex-dual-publish.sh`) uses a hardcoded `V0_PLUGINS` list — ossify's absence from `marketplace.json` is why it stays green. When Plan D registers ossify, add it to `V0_PLUGINS` + give it a Codex manifest or that suite breaks.

Cross-cutting principle the opus review verified: **rc taxonomy is consistent** — 1 generic / 2 usage / 3 lock / 4 apply / 5 drift / 6 schema / 7 unknown-ref. Keep it; don't introduce an overlapping code (Plan A had a `demo_run` jq abort returning jq's rc 2 that collided with usage-2 — fixed).

---

## 5. CARRIED-FORWARD STATE (things B/C/D must address)

- **[Plan B] ID-mint races the lock:** `oss_id_next_*` and `_oss_ledger_next_id` read the counter/arrays OUTSIDE the mutate lock, then mutate acquires it. Two concurrent ceremonies could mint the same id. Out of scope for single-session Plan A. **Plan B/C should mint the id INSIDE the locked section, or move id assignment into `_oss_apply_op` (server-side).** This is the one real concurrency gap the final review flagged.
- **[Plan D] Registration checklist:** `marketplace.json` entry + `V0_PLUGINS` + Codex manifest for the parity suite (see gotcha #11). Only at the eval ship gate.
- **Accepted Minor-for-final (deferred, non-blocking, logged in ledger):** `_oss_csv_to_json` empty-input now returns `[]` (fixed); replay rc=1/rc=4 paths + entity reject-path state-unmutated now have tests (fixed in the final wave). Remaining truly-deferred: none blocking — the final fix wave cleared the actionable ones.
- **State schema reserved-but-unwritten fields:** `project.composition_root` and `project.overlay_wiring` are init'd but unused — reserved for Plan C/D (boundary/composition). Don't remove them.
- **The integration test is currently the ONLY place entity/registry/ledger ops get replayed together** — keep it; it's the de-facto full-op replay guard.

## 6. REPO-SPECIFIC OPERATIONAL NOTES

- **Git-ops policy (this repo):** the agent does ALL git ops (commit/merge/push/tag). BUT the auto-mode classifier blocks `gh pr merge` + direct `git push origin main` until **explicit in-turn user authorization** (a standing "you do all git ops" counts as authorization when the user gives it in-turn). Local commits on a feature branch are fine.
- **No commit-msg hook** in THIS marketplace repo (it builds the trace-filter but doesn't self-apply it), so the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer is fine here. (Consumer projects that ARE workspace-init-paired DO block that trailer — different context.)
- **Commit scope:** always `git add ossify/...` / explicit paths — NEVER `git add -A`. Unrelated files live in the tree (`README.md` = user's, `.claude/`, other stray docs). The `.superpowers/` ledger is gitignored.
- **Test commands:** `bash ossify/tests/run-all.sh` (ossify suite) + `for t in tests/test-*.sh; do bash "$t" || echo "ROOT-FAIL: $t"; done` (repo-root parity — must stay clean).
- **Skill listing budget:** the OLD 3-plugin stack overflowed the 1% skill-listing budget (~1.5%). ossify's whole point includes ≤6 front-loaded entry skills with `references/` progressive disclosure — Plan B must honor this (verify against `/doctor` at implementation time). Consumer repos can phase-scope-disable dormant plugins ([[reference_phase_scoped_plugin_enablement]]).

## 7. NORTH STAR (keep future work aligned)

ossify exists because scaffold-dev's completed sprints never yielded usable software (pulse-trader: first tradeable UI was 7 sprints deep by spec design; half its "vertical slices" were horizontal). The whole model optimizes for **usable software early and continuously** (skeleton first, then rolling feature spines) with **mechanical, non-skippable quality gates** (cumulative demo, journey-line floor, bones registry) and **ceremony scaled by risk** (bone/flesh). When detailing B/C/D, every skill should serve that: does it get the user to a usable product faster, and does it make "the product still runs" a checked fact rather than an assumption? The playbook (`evolutionary-architecture-playbook.md`) is the doctrine layer to consult for framing.

---

## 8. IMMEDIATE NEXT ACTION for the fresh session

1. Read §0 docs + the SDD ledger.
2. Detail **Plan B** via `superpowers:writing-plans` (spec main §4-§5 + §9.1, companion §3), reusing Plan A's Global Constraints block and folding in the §5 carried-forward items (esp. ID-mint-inside-lock).
3. Adversarial self-review the Plan B design (§3.2), then execute subagent-driven (§3.3) with the SAME model choices (sonnet implementers/reviewers, opus final) and the SAME review rigor (named risks, RED-proven fixes, ledger discipline).
4. Start a FRESH `.superpowers/sdd/progress.md` for Plan B (mark the Plan A ledger superseded).
