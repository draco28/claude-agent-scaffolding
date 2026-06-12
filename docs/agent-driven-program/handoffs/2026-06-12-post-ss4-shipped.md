# Session Handoff — SS-4 SHIPPED (scaffold-dev v0.4.0) · agent-single-authority over scaffold-dev's verification seams

**Date:** 2026-06-12 · **Author:** prior session (SS-4 brainstorm → build → PR #64 review-to-merge) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sub-spec sequence + §6 ledger). This handoff is the delta on top of it and on top of `2026-06-10-post-ss7-shipped.md` (still valid for SS-7/program context; this one supersedes its "SS-4 designed-not-started" line — SS-4 is now shipped).

---

## 1. What this session did (one line)

Took **SS-4** (agent-review of the verification seams — #52/#7/#5/#48-F) from **nothing** to **merged + tagged**: ran the full `brainstorm → spec → writing-plans → subagent-driven build (12 tasks) → bot-review → release` cycle, squash-merged **PR #64 → `f65ab44`**, tagged **`scaffold-dev-v0.4.0`**, closed **#52/#7/#5**; **#48** stays open for its C/D/E + routing remainder.

---

## 2. ⚠️ FIRST ACTION NEXT SESSION: pick the next sub-spec (SS-4 is DONE)

SS-4 is fully shipped — **no carry-forward fix work** from it. Fresh sub-spec cycle next. Recommended order (see §5):

1. **SS-5** (#47 — optional Codex implementation/synthesis backend) — **strongest next candidate.** SS-3 + SS-7 left every synthesis brief + dispatch path **tool-agnostic**; wiring `implementer_backend ∈ {claude_subagent, codex}` via `codex-companion.mjs` is the natural follow-on. **Honor the router-file boundary** from the SS-7 handoff §4 (the Codex path must NOT synthesize CLAUDE.md/settings.json/AGENTS.md either).
2. **SS-6** (#8/#9/#6/#10/#37/#38/#39/#48-remainder/#53) — standalone cleanup-to-zero; interleave. **#63** (SS-7 deferred edge case) can ride here.

Run each through its own `brainstorm → writing-plans → subagent-driven-development → bot-review → release` cycle.

---

## 3. SS-4 — what shipped + the review story 🔧

**Merge:** PR #64 squash-merged to `main` as `f65ab44` · tag `scaffold-dev-v0.4.0` (on the merge commit, pushed) · **#52 auto-closed** (PR body), **#7 + #5 manually closed** (see §6 gotcha) · #48 commented (Part F shipped) · SPEC §5/§6 ledger rows marked shipped (landed with the squash).

**The product change — one principle across four seams:** *the agent is the single authority over every **semantic** judgment; deterministic bash survives only as a real-command-execution leg. Bash that does semantic parsing/judgment is **deleted**, not demoted to a "labeled fallback."* (This supersedes the program-spec SS-4 entry's "labeled fallback" wording — recorded in the SS-4 spec §1.)

- **#52 harvest single-authority:** deleted the orphaned semantic AWK parsers (`sd_harvest_reports`/`sd_harvest_handoffs`/`_sd_harvest_extract_section` — already dead, nothing called them). `closing-vertical-slice` §9 is now **agent-sole-reader** of free-form `report.md`/handoff prose; `sd_harvest_apply` is the **single mechanical write authority** (provenance trailer + idempotency + derived-reroute). `report.md` Suggestions section marked agent-read, not machine-parsed — the AWK-vs-prose collision *dissolves*.
- **#48 Part F lean-index:** `sd_harvest_lint_length` (mechanical line-count, default ~12) + harvest §9.4 restate-prevention (agent), both at harvest write-time. **Partial standing:** prevention-only; the full existing-bank re-scan travels with C/D/E later.
- **#7 verifying-spec-citations:** new read-only skill + `lib/citations.sh` (`sd_citations_check_file` = `test -f`, `sd_citations_check_signature` = `grep -F`) + **opt-in** gate in `planning-vertical-slice` §6.4. Agent owns REQ-ID / ARCH §-ref denotation drift; bash owns file-exists + verbatim-signature.
- **#5 pre-flight RED-tests gate:** `executing-work-item` §3.6 + `sd_redgate_assert_red`. **Semantics refined to "not-already-GREEN"** (see §4).

**Build method:** subagent-driven-development — fresh implementer per task + two-stage (spec + code-quality) review per task, then a **final whole-implementation review**. Risk-ordered #52 → #48-F → #7 → #5 → release. ~18 build/fix commits on the branch.

**Review story — the final holistic pass earned its keep, then Codex's cycle improved two designs:**
- The per-task reviews all passed, but the **final whole-implementation review caught a Critical bug** the 11 per-task reviews were structurally blind to: `sd_redgate_assert_red` was **broken through its documented dispatcher path** — `bin/sd` runs `set -euo pipefail`, so a non-zero `bash -c "$cmd"` aborted the function before the `case`/`return`, collapsing RED and already-GREEN to the same code. In-process tests passed (no `set -e`). Fixed with an `if/else` form + **dispatcher-path regression tests**.
- **Codex (this repo's Codex can both review AND push fix commits)** then ran several rounds and improved two designs beyond what we shipped: (a) `sd_redgate_assert_red` gained an `[expected]` arg so "already-GREEN" is judged against the AC's **actual predicate** (`exit N` / `output contains X`), not a blind exit-0; (b) the §3.6 **skip-escape was reframed** from inline `pause_and_ask` to **gaps-mode + orchestrator-recorded handoff override** (a Mode-B implementer subagent has no interactive user channel mid-dispatch — gaps-mode is its only escalation; our original was inconsistent with that contract). Codex also fixed dispatcher-form harvest snippets, handoff `target_file`, citation routing/extraction, and the §6.4-gate bypass.
- **Convergence:** Codex's review on the HEAD commit (`c3759a7`) returned **"Didn't find any major issues"** — the merge signal per `feedback_bot_review_convergence_judgment`. The PR's remaining "unresolved" review **threads were all verified stale** (fixed by Codex's own follow-up commits; GitHub doesn't auto-resolve threads on later fixes) before merging.

---

## 4. Durable design decisions / lessons from SS-4 (apply next session) ⭐

- **Disposition rule: delete-semantic-bash, keep-mechanical-legs.** When the agent becomes single authority over a seam, bash that does *semantic parsing/judgment* is **deleted** (no "fallback"), and only *real-command-execution* legs survive (`test -f`, `grep -F`, line-count, run-command-check-exit, write-with-idempotency). These seams run **inline in the conducting agent's context** (not via dispatch), so "agent unavailable" is not a reachable state — there is nothing to fall back *to*. Mechanical legs **fail loud with remediation**, never silently skip.
- **The whole-implementation review catches what per-task reviews can't.** Per-task spec+quality reviews are scoped to one diff and miss cross-cutting runtime bugs (here: a helper that's correct in-process but broken under the dispatcher's `set -e`). **Always run a final holistic review** over the full branch diff *and have it actually run the gates*, before declaring merge-ready.
- **`bin/sd` runs `set -euo pipefail` AND sources every `lib/*.sh`.** Any new lib helper invoked via the dispatcher (`sd <verb>`) executes under `set -e` → a bare `cmd; rc=$?` aborts on non-zero. **Write helpers `set -e`-safe** (`if cmd; then …; else rc=$?; fi`), and **test them through `bin/sd`**, not just in-process. (The dispatcher auto-discovers libs, so no registration needed — but the `set -e` runtime is the trap.)
- **Skill bash snippets must use the `sd <verb>` dispatcher form, not direct `sd_<verb>` calls.** A fresh agent shell running a skill body does NOT have `lib/*.sh` sourced — only `bin/sd` does. So `sd harvest_apply …`, `sd redgate_assert_red …`, `sd citations_check_file …` in skill prose; reserve the underscore `sd_<verb>` form for *naming* the function in descriptions. (Codex flagged several direct-call snippets I wrote.)
- **RED-gate "not-already-GREEN" semantics (settled with user mid-build).** scaffold-dev's `executing-work-item` **authors** the failing test *during* §4 (per-AC TDD step 1), so at pre-flight a fresh AC's test file doesn't exist → its command exits 126/127. Therefore the gate can't require "every AC is RED." It **hard-blocks only the already-GREEN case** (the real anti-drift signal: an AC already satisfied before any work). RED → proceed; errored/uninvocable (126/127) → **non-blocking advisory**, proceed (§4 authors the test). The `--allow-skip-thrust-zero` escape **overrides the already-GREEN block** (e.g. a pure code-deletion AC legitimately passing). And "already-GREEN" is judged against the AC's **actual expected predicate**, not blind exit-0.
- **A Mode-B implementer subagent has no inline user-interaction channel.** Its ONLY escalation is the **gaps-mode return**. Any "ask the user / pause_and_ask" decision the implementer can't make alone must surface as gaps-mode → the **orchestrator** decides, records the override in the handoff, and **re-dispatches**. Don't put inline `pause_and_ask` in the implementer-agent body.
- **Reframe-don't-restructure when a refinement surfaces mid-build.** The RED-gate test-timing tension was resolved by *reframing the gate's purpose* (already-GREEN detection) rather than restructuring §4's interleaved TDD loop into an upfront RED-authoring phase. The spec §3.4 was updated to record the refinement honestly ("refines — does not contradict — the brainstorm's hard-block settlement").
- **Test the upgrade/legacy-input class.** The harvest path had to keep reading an *old* `- target_file:/suggestion:` report fine under the new agent-read model; the e2e re-point fixture and §3.6 evals were written to exercise that, per `feedback_test_upgrade_input_class`.

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):**
- SS-1 ✅ (#45) · SS-2 ✅ (#50/#49/#42) · SS-3 ✅ (#51) · #59 ✅ (v0.6.1) · #58 ✅ wontfix (v0.7.0) · SS-7 ✅ (#56 → scaffold-onboard v0.8.0) · **SS-4 ✅ SHIPPED (#52/#7/#5/#48-F → scaffold-dev v0.4.0)**
- **SS-5** — Codex implementer/synthesizer backend (#47). Independent. **Inherits SS-3's + SS-7's tool-agnostic synthesis prompts** — strongest next candidate. Honor the SS-7-handoff §4 router-file boundary.
- **SS-6** — standalone cleanup to zero (#8, #9, #6, #10, #37, #38, #39, #48-remainder, #53/CI). Interleave. **#63** rides here.

**Plugin versions (current main):** workspace-init 0.1.2 · scaffold-onboard 0.8.0 · **scaffold-dev 0.4.0** · architect-critic 0.2.2 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Open backlog (11, was 14):** #63 (SS-7 deferred edge case) · #53 (CI/SS-6) · #48 (C/D/E + `/defer` marketplace-routing + `tech-debt` label auto-create → SS-6; Part F done) · #47 (SS-5) · #39/#38/#37 (SS-6 external-benchmark trio) · #10/#9/#8/#6 (SS-6 buckets). **Closed this session: #52, #7, #5.**

---

## 6. Process notes / environment (load-bearing)

- **GitHub `Closes #a, #b, #c` only auto-closes the FIRST issue.** `Closes #52, #7, #5` closed only #52 → #7 and #5 had to be closed manually post-merge. Next time write `Closes #52, closes #7, closes #5` (keyword before each), or close the rest by hand.
- **Codex on this repo can review AND push fix commits.** The user drove `@codex review` rounds and Codex committed fixes directly to the PR branch (`f597617`…`c3759a7`). Convergence signal unchanged: the round where the **latest commit's Codex review has zero/no-major findings** is the merge signal. **Verify "unresolved" threads against HEAD before merging** — many are stale (Codex's own later commits fixed them; GitHub doesn't auto-resolve).
- **scaffold-dev test commands:** full suite `cd scaffold-dev && bash run-tests.sh` (→ 18 files / 0 failed; auto-discovers `tests/test-*.sh`, so new test files need no registration). Dual-publish parity is **repo-root, separate**: `bash tests/test-codex-dual-publish.sh` (→ 149/0) — run after any version bump (it checks both `.claude-plugin/` + `.codex-plugin/` plugin.json parity). The harness `assert_eq` signature is **`assert_eq <label> <expected> <actual>`** (label first); tests source `tests/_helpers.sh`.
- **Handoffs in this source repo are manual** (`docs/agent-driven-program/handoffs/`) — the scaffold-dev `/handoff` skill refuses (no `.workspace/pairing.json`; it's for paired AI-workspace slice transitions, not this program). Commit them to `main` directly.
- **`bin/sd` self-locates + sources all `lib/*.sh` under `set -euo pipefail`** (see §4). Skill setup snippets reference helpers via the `sd <verb>` dispatcher.

---

## 7. Recommended next-session entry points

1. **SS-5** (#47, Codex backend) — brainstorm → spec → plan → subagent-driven build → bot-review → release. Inherits the tool-agnostic briefs; **must respect the SS-7-handoff §4 router-file boundary** (don't synthesize CLAUDE.md/settings.json/AGENTS.md on the Codex path).
2. **SS-6** (#8/#9/#6/#10/#37/#38/#39/#48-rem/#53) — cleanup-to-zero; **#63** rides here.

Target remains **zero open backlog**. Agent-driven-only derivation is complete for scaffold-onboard (SS-7); the agent-single-authority principle is now extended to scaffold-dev's verification seams (SS-4). SS-5 extends the synthesis side cross-tool (Codex); SS-6 clears the independent remainder.
