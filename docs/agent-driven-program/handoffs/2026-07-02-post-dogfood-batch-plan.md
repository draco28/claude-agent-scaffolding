# Session Handoff — post-#93 dogfood · batch the remaining backlog

**Date:** 2026-07-02 · **Author:** dogfood session (validated #93, filed #96) · **For:** next session (batch execution)
**Read first:** this handoff · `docs/agent-driven-program/dogfood-recommendation-policy-2026-07-02.md` (what the dogfood found) · the three issue bodies (`gh issue view 96 / 85 / 37`) · `docs/agent-driven-program/reconsideration-decision-38-37-10.md` (why #38/#37 are shaped as they are).
**Next-session focus:** knock out the three small backlog items (**#96 → #85 → #37**) in one batch cycle; open **#38** in its own context (it's a real feature, not a fix).
**Delta vs last handoff:** #10 wontfix'd (closed), #96 filed; #38/#37 reconsidered (decided-to-build). Backlog `#85 #38 #37 #10` → **`#85 #38 #37 #96`**.

---

## 0. Repo state

`main` tip **`1f90cbd`** (pushed, in sync with origin). **#10 CLOSED (wontfix), #96 OPEN (new bug), 0 open PRs.** Clean tree (only `.claude/` + `docs/superpowers/` untracked — leave both; never `git add -A`). No new tags this session (docs-only commit). **The agent does all git ops for this repo** (merge/push/tag) — standing authorization per [[feedback_codex_runs_pr_fix_cycle]]; the auto-mode classifier still wants explicit in-turn intent for `gh pr merge` / direct `git push origin main`.

**Plugin versions (unchanged this session):** workspace-init **0.4.0** · scaffold-onboard **0.12.0** · scaffold-dev **0.15.0** · architect-critic **0.5.0** · claude-security-audit **0.1.3** · ai-mentor **2.2.0**.

---

## 1. What this session did

Dogfooded the **#93 recommend-by-default policy** (first live run) on the real #38/#37/#10 "reconsider-first" decision. **Policy held on every exercised surface** (council + critique; `--neutral` verified on the critique surface), citations verified drift-free by an independent subagent, and — the headline — **Rule 5 held: the recommendation did not railroad the user** (council recommended cherry-pick-redaction-only for #38; user overrode → build all 5). Faithful `/critique` execution surfaced a **real bug (#96)**. Decisions executed: #10 wontfix, #38 build-all-5, #37 build-2+3. Full write-up in the dogfood observation record.

---

## 2. The batch plan (this is the point of the handoff)

**Recommended split: batch the three small items in one cycle; peel #38 into its own context.** Rationale below per item, with exact file pointers so the next session executes without re-discovery.

### 🟢 BATCH — small fixes (one cycle; may be 1 PR or split if bot-review churns)

**#96 — architect-critic critiquing-spec scorer wiring (bug). Smallest; do first.**
- **F1 (the bug):** `architect-critic/skills/critiquing-spec/SKILL.md` **L389** prescribes `arc scorer_score …` — nonexistent (`Unknown function: ac_scorer_score`). Change to **`arc scorer_score_rebuttal`**. Also fix `architect-critic/bin/arc` **L23** header comment (it advertises the same phantom).
- **F2:** `lib/scorer.sh:scorer_decide` maps ≤3→`restate`, ≥4→`concede`, diverging from the SKILL rubric's ≤3→"stands" (L391-392); `scorer_decide` is never wired into the SKILL flow. **Decide:** reconcile the rubric wording, or drop the unused `scorer_decide`.
- **F3 (design call, small):** `scorer_score_rebuttal` is a deterministic lexical gate that under-scored a material-new-info rebuttal (returned 3) — the exact failure `pp-e72993dfb626c518` warns against ([[feedback_agent_review_over_deterministic_gates]]). **Decide:** keep the helper as advisory (SKILL already says the agent mediates) or drop it and let the agent score inline. Either way small.
- **Test:** add/repair a test that actually runs the SKILL's prescribed rebuttal-scoring command end-to-end (the gap that let F1 ship). Version bump architect-critic → **0.5.1**.

**#85 — workspace-init trace-filter `--separate-git-dir` canonical (chore). Narrow.**
- `workspace-init/lib/trace-filter.sh` (~**L50**): the `wi_trace_filter_install` precondition gates on `[[ ! -d "${target_repo}/.git" ]]` and hardcodes `${target_repo}/.git/hooks`, so a `--separate-git-dir`/submodule canonical (where `.git` is a file) passes preflight then fails hook-install. **Fix:** compute the hooks dir via `git -C "$target_repo" rev-parse --git-path hooks` and relax the precondition to a real-repo check.
- **Invariant to preserve:** keep #71's deliberate linked-worktree reject intact — `wi_git_is_linked_worktree` must still reject, i.e. `--git-path hooks` must NOT re-admit a linked worktree. Add a `--separate-git-dir` fixture test. Version bump workspace-init → **0.4.1**.

**#37 — grill-me domain-language + ADR threshold (build legs 2+3; wontfix 1/4/5). Small prose.**
- **Leg 3 (scaffold-dev):** `scaffold-dev/skills/recording-architecture-decision/SKILL.md` — add the strict three-part ADR threshold (record only when **hard-to-reverse AND surprising AND a real tradeoff**). Watch the 500-line cap.
- **Leg 2 (ai-mentor):** `ai-mentor/skills/grill-me/SKILL.md` — add the "code contradicts claim" rule with the **mode-dependent source-of-truth** the user specified: in **development/implementation, code is authoritative** (update contradicting docs); in **vision-aligned planning, the vision/doc is authoritative** (fix contradicting code). *Build-time check:* confirm this isn't already effectively covered post-#88/#93 (which moved grill-me) — the meatiest batch item; pull it if the batch gets heavy.
- Legs 1/4/5 already recorded as wontfix on the issue. Version bumps: ai-mentor → **2.3.0**, scaffold-dev → **0.16.0** (leg 3 shares the bump with nothing else here).

**Batch mechanics:** spans 4 plugins → per-plugin `.claude-plugin` + `.codex-plugin` version bumps (dual-publish parity test `tests/test-codex-dual-publish.sh`), README version tables (NOT CI-guarded — update manually per [[reference_codex_dual_publish_test_location]]), then the 3-bot review cycle + tags. If bot-review churns, split #96 (bug) out from #37 (feature) into separate PRs.

### 🔴 SEPARATE CONTEXT — #38, the 5-leg handoff enhancement (a real feature)

Build **all 5 legs** (user override of council): (1) suggested-skills section, (2) artifact-reference discipline [refs by path/SHA → de-bloat + subagent-dispatchable], (3) redaction pass [**design its own failure modes**: false-pos/neg, hard-block vs warn-and-confirm], (4) next-session-focus field, (5) **lightweight/ephemeral non-dual-repo handoff mode**. Legs 3 and 5 carry real design (redaction safety behavior; handoffs that work outside the dual-repo/slice topology) — **brainstorm-first**, own context. Touches `scaffold-dev/skills/handing-off-session/`. Decision-of-record: `reconsideration-decision-38-37-10.md`.

---

## 3. Program state snapshot

**Open backlog (4):** **#96** (bug — scorer wiring) · **#85** (chore — trace-filter) · **#37** (build legs 2+3) · **#38** (build all 5 legs). #10 closed wontfix. The North Star (SPEC §1/§6) is a zero-open ledger; after the batch + #38, the program is at zero.

**Repo:** `main` `1f90cbd`, 0 open PRs, clean tree. **#96 OPEN, #10 CLOSED.**

---

## 4. Recommended next-session entry points

1. **Start the batch with #96** (trivial one-line SKILL fix + the missing test that would have caught it) → **#85** (narrow) → **#37** (prose). One cycle, version-bump 4 plugins, dual-publish + bot-review + tags.
2. **Then open #38 in a fresh context** — brainstorm-first; it's a feature, not a fix.
3. **Above all:** keep the fixes agent-first (don't re-introduce determinism — #96 F3 is a live reminder), verify on the real HEAD + by GraphQL thread-count (not the fix-cycle summary), and re-run `tests/test-recommendation-policy-parity.sh` (must stay 7/0) after any touch near the policy copies.
