# Session Handoff — Issue-Backlog Tiers (remaining work)

**Date:** 2026-05-31 · **Repo:** `claude-agent-scaffolding` (plugin **source** repo — NOT a workspace-init'd project; no `.workspace/pairing.json`, so scaffold-dev slice/handoff skills don't apply here — handoffs are manual `docs/HANDOFF-*.md`).
**Repo state at handoff:** `main` @ `f50d0db` · **0 open PRs** · branch `docs/issue-backlog-triage` merged + deleted.
**Resume by:** reading §6 below, then `docs/SPEC-issue-backlog-triage.md` (the full triage). This session completed **Tier 0 only**; Tiers 1 & 2 remain.

---

## 1. The overall plan (what we set out to do)

You asked: *"create a proper spec to triage the GitHub issues, work the worthwhile ones, defer the rest."* We triaged all 14 open issues into tiers and ran **Tier 0** end-to-end. The authoritative plan is **`docs/SPEC-issue-backlog-triage.md`** (committed on main).

**Settled decision lens (for the Tier-0 cycle):** fix-before-feature + bug-fix-only release.
**Cross-cutting principle promoted** to architect-critic user-global (`pp-e72993dfb626c518`, `~/.claude/architect-critic/principles.md`): *prefer agent / LLM-judge review over brittle deterministic semantic-quality gates* (every filed bug was a deterministic-gate failure). This shapes how the deferred agent-review items should be designed — see [[feedback-agent-review-over-deterministic-gates]].

---

## 2. DONE this session — Tier 0, shipped as scaffold-dev v0.1.7

**Merged:** PR #41 → squash `2ecf5ed` on main; README bump `f50d0db`; tag `scaffold-dev-v0.1.7`.

| Issue | Outcome |
|---|---|
| **#35** | Quoted 4 `SKILL.md` frontmatter `description:` values (Codex Psych was skipping them) + YAML-parse regression in `tests/test-codex-dual-publish.sh`. **CLOSED.** |
| **#36** | Work-item template §6 → machine-checkable `auto:` block (single SoT); gate runs ACs in the worktree, loud-degrades on zero ACs; full grammar consistency across template/planner/gate/implementer/`lib/verify.sh`/evals. **CLOSED.** |
| **#30** | Bug-half was **already fixed + shipped** (v0.3.4 / `cb9b835`) — closed as resolved; enhancement-half reframed → **#42**. **CLOSED.** |
| **#43** | `implementation-checking` §6↔`sd_verify_auto_step` contract mismatch — resolved by the §6 "run directly in the worktree" fix. **CLOSED.** |

**Bot-review note:** the PR went through **4 rounds of Codex + CodeRabbit review (14 findings, all real)** before clean. The first #36 fix didn't actually run end-to-end; the rounds exposed every out-of-sync consumer of the AC grammar. Regression tests now lock each gap (`test-verify.sh` 17 tests, `test-render.sh` 19). Lesson logged: *trace into the lib helpers, not just the adjacent doc contract.*

**The work-item AC grammar is now (reference for any future AC work):**
```
- [ ] AC-1 auto: `<command>` → expected: <exit 0 | exit N | output contains <substring>>
- [ ] user: <manual demo step>
```
Backticks required (the verifier extracts the command from them); `AC-N` on **auto** rows only (drives the report cross-check); `output contains` substring is **unquoted**; `user:` rows carry **no** `AC-N` (slice-close demo steps, excluded from the report cross-check). Only `exit 0` / `exit N` / `output contains` are supported (no `count > 0`).

---

## 3. REMAINING work — Tiers 1 & 2 (the meat for next session)

All deferred issues are **labeled** (`v0.2` or `deferred`) per the triage buckets.

### Tier 1 → v0.2 (next priority)

**Recommended next theme (per triage spec): "Workflow-realism" — dogfooding-driven, highest real value** (you hand-roll both today):
- **#40** — PR-per-slice merge mode (manifest `merge_mode ∈ {direct, pr_per_slice, pr_per_work_item}`); `default_branch` only advances through a CI-gated PR.
- **#33** — lean-index memory bank + `/defer` + deep-reference channels (multi-part: A+B `/defer`+blocker-recall first; then C doc-anchors, D+E ADR/claude-mem pointers, F lean-index linter). *Design C/F validators as agent-assisted per the principle.*

**Artifact-integrity (agent-review-flavored — apply the promoted principle):**
- **#42** — agent-driven post-derivation doc review (reframed #30) — **scaffold-onboard**. Sub-agent reads derived `CLAUDE.md`/`WORKFLOW.md`/memory-bank against installed plugins' real command surface; advisory, not a deterministic gate.
- **#7** — `verifying-spec-citations` — redesign as **agent-assisted** citation review (not the original regex lint); cheap mechanical legs (file-path `test -f`) may stay deterministic.
- **#8** — ban `git stash` in spec/handoff templates (cheap; a literal banned-token list is legitimately deterministic).

**Other v0.2:**
- **#5** — pre-flight RED-tests gate (reconsider deterministic-vs-agent; changes executor runtime behavior — higher risk).
- **#9** — `pairing-existing-dual` skill (workspace-init, Scenario C: both repos already populated).

### Tier 2 → v0.3 / demand-gated (parked, NOT cancelled)
- **#10** — `coordinating-parallel-slices` (gate on a real parallel-slice usage signal first).
- **#6** — ADR Proposed→Accepted flip lifecycle (niche).
- **#37** — grilling: domain-language capture + ADR thresholds (external-benchmark-inspired).
- **#38** — handoff: suggested-skills + artifact-refs + redaction (external-benchmark; the **redaction** leg has standalone safety value — could pull forward independently).
- **#39** — architect-critic async external-adversary operability (external-benchmark, codex-plugin-cc patterns).

### New this session — needs triage into a bucket
- **#44** (bug, scaffold-dev) — **slice-demo** verification grammar (`closing-vertical-slice` uses quoted `output contains "<pat>"` + `count > 0`) is inconsistent with the now-fixed **work-item** grammar. Separate level (its own agent-run checker that genuinely supports `count > 0`). Decide: align it to the work-item grammar, or document the two dialects + verify the slice-demo checker tolerates quotes. *Unbucketed — assign v0.2 (artifact-integrity) or treat as a small standalone fix.*

---

## 4. Issues filed this session
- **#42** (v0.2) — reframed #30 enhancement-half (agent-driven doc review).
- **#43** (CLOSED) — gate↔helper contract; resolved within PR #41.
- **#44** (open, bug) — slice-demo grammar inconsistency.

---

## 5. Key context / gotchas for next session
- **Apply the promoted principle** (agent-review over deterministic semantic gates) when designing #42 / #7 / #5 / #33's validators. Deterministic checks stay only for mechanical facts (exit codes, parse-validity).
- **No pairing manifest here** — this is the plugin source repo. scaffold-dev's `planning-vertical-slice` / `handing-off-session` refuse without a manifest; develop with the plain brainstorm → writing-plans → subagent-driven-development flow (as this session did).
- **Release mechanics** (so a version bump actually reaches installs): `/plugin update` is **version-keyed** off each plugin's `plugin.json` (the marketplace.json carries no per-plugin version). A release = bump `plugin.json` (Claude + Codex — parity enforced by `tests/test-codex-dual-publish.sh`) + bump the **README version table** (`c5d0aca`-style direct-to-main docs commit) + merge + `git tag scaffold-dev-v<ver>`. GitHub Releases are only used by `claude-security-audit`. Installs update via `/plugin marketplace update` then `/plugin update`.
- **git hygiene:** after subagent-driven runs that `git commit --amend`, verify `git rev-parse --abbrev-ref HEAD` is the branch, not `HEAD` (a detached-amend bit us once this session).

---

## 6. How to resume (recommended first actions)
1. Read **`docs/SPEC-issue-backlog-triage.md`** (the triage + buckets) and this handoff §3.
2. **Decide the next cycle's appetite** — Tier 0 was deliberately bug-fix-only; pick the v0.2 scope (e.g., the Workflow-realism theme #40+#33, or one agent-review item).
3. For the chosen issue(s): **brainstorm → spec → writing-plans → subagent-driven implementation** (same flow as this session). For agent-review items (#42, #7), design around [[feedback-agent-review-over-deterministic-gates]].
4. **Triage #44** into a bucket.
5. When shipping: follow the release mechanics in §5 (don't forget the README table + the git tag).

## 7. Must-read files / pointers
- `docs/SPEC-issue-backlog-triage.md` — the triage (buckets, rationale, the §2.1 principle).
- `docs/PLAN-issue-backlog-tier0.md` — the executed Tier-0 plan (reference pattern for the next plan).
- `~/.claude/architect-critic/principles.md` — the promoted principle (`pp-e72993dfb626c518`).
- Memory: `feedback-agent-review-over-deterministic-gates`, `friction-log-first-realtest` (v0.1.7 closeout + release mechanics), `issue28-slice-id-fix-direction` (the prior cross-plugin fix, for context on the verify.sh/grammar lineage).
