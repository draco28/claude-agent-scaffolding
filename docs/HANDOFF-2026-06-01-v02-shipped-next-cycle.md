# Session Handoff — scaffold-dev v0.2.0 shipped; next: triage #45 → pick next cycle

**Date:** 2026-06-01 · **Repo:** `claude-agent-scaffolding` (plugin **source** repo — NOT a workspace-init'd project; no `.workspace/pairing.json`, so scaffold-dev's `/handoff` / slice skills refuse here. Handoffs are manual `docs/HANDOFF-*.md`).
**Repo state at handoff:** `main` @ `59012c2` · **0 open PRs** · branch `feat/pr-hierarchical-merge-mode` merged + deleted.
**Resume by:** reading §5 (next steps) below, then §4 (open backlog). Start with **triage #45**, then pick the next cycle.

---

## 1. What just shipped (this session)

**Combined PR #46 → squash-merged `59012c2` on main.** One v0.2 cycle, three features, the "Workflow-realism" theme + a related bug:

| Issue | What shipped |
|---|---|
| **#40** | **pr_hierarchical merge mode** (opt-in `during_dev.merge_mode`): work-item → slice → sprint → main, with agent-driven PR gates at slice→sprint and sprint→main. New `lib/pr.sh` mechanical git/`gh` primitives; back-compat `direct` mode unchanged. |
| **#44** | **Agent-judged slice demos**: `closing-vertical-slice` runs the `auto:` command and *judges* output (exit-code stays deterministic); work-item ACs stay deterministic. Resolved the slice-demo↔work-item grammar drift. |
| **#33 A+B** | **Lean-index `/defer` loop**: `/defer` command + `deferring-work-item` skill (orchestrator-only), round-close auto-file, `sd_issue_create`/`sd_issue_list`, dedicated `tech-debt.md` index seeded by scaffold-onboard, two-layer blocker-recall. **Parts C–F deferred → #48.** |

**Releases (tags on `59012c2`):** `scaffold-dev-v0.2.0`, `scaffold-onboard-v0.3.8`.
**Closed:** #40, #44, #33. **Filed:** #47 (Codex implementer backend, v0.3), #48 (#33 C–F + /defer marketplace routing + label auto-create).

**Review hardening (the bulk of the effort):** PR #46 went through **5 review passes** with the Codex GitHub app + CodeRabbit — R1 (Codex macOS app fixed), R2/R3/R4 (Claude fixed, verified each finding first per `receiving-code-review`), then a **proactive Claude adversarial self-audit** that caught the last load-bearing defect (`sd_pr_review_comments` folded gh stderr into stdout via `2>&1` → broke jq on the success path, silently dropping the inline comments the gate exists to surface — tests couldn't catch it). Final Codex pass on `0c97adf` = clean (👍, no findings). All suites green at merge: scaffold-dev 17/0, scaffold-onboard 14/0, dual-publish 148/0.

---

## 2. The "overall spec" timeline (`docs/SPEC-issue-backlog-triage.md`)

| Tier | Scope | Status |
|---|---|---|
| **Tier 0** — bug-fix | #35, #36 (+#30, #43) | ✅ shipped scaffold-dev **v0.1.7** (2026-05-31) |
| **Tier 1** — v0.2 headline ("Workflow-realism") | #40, #33 A+B, #44 | ✅ shipped **v0.2.0** / scaffold-onboard **v0.3.8** (2026-06-01, PR #46) |
| **Tier 1** — remaining v0.2 tail | #42, #7, #8, #5, #9 | ⏳ open (5) |
| **Tier 2** — v0.3 / demand-gated | #10, #6, #37, #38, #39 | 🅿️ parked (5) |

Both shipped tiers complete; the two biggest hand-rolled-today items (#40, #33) are now first-class.

---

## 3. THE PLAN for the next session (settled with user 2026-06-01)

1. **Triage #45 first, and fortify it.** (See §5.1.) It's the only untriaged issue and is an architectural-consistency question adjacent to what we just shipped.
2. **Then pick the next cycle** (see §5.2 options) and run it: brainstorm → spec → plan → subagent-driven impl → bot-review babysitting → release (same flow as this session).

---

## 4. Open backlog (13 issues)

**Remaining v0.2 (Tier-1 tail):**
- **#8** — ban `git stash` in spec/handoff templates. *Tiny; legitimately deterministic (banned-token list). Cheapest win.*
- **#7** — `verifying-spec-citations` → **agent-assisted** review (not the original regex lint). Medium.
- **#42** — agent-driven post-derivation doc review (**scaffold-onboard**; reframed from #30). Medium.
- **#5** — pre-flight RED-tests gate. *Higher risk — changes executor runtime behavior.*
- **#9** — `pairing-existing-dual` skill (workspace-init Scenario C: both repos already populated).

**v0.3 / parked:** #10 (coordinating-parallel-slices), #6 (ADR Proposed→Accepted flip), #37/#38/#39 (external-benchmark trio — grilling domain-language · handoff suggested-skills+redaction · architect-critic async adversary). Demand-gate before building. *#38's redaction leg has standalone safety value.*

**New, need decisions:**
- **#45** — *untriaged, no labels:* "memory-bank harvest (scaffold-dev) contradicts derived-file SSoT discipline (scaffold-onboard) — per-slice memory updates shouldn't route through MASTER-SPEC." **← triage this first.**
- **#47** — optional **Codex implementation backend** for work items (orchestrator chooses `implementer-agent` vs Codex via `codex-plugin-cc`). v0.3. Researched: invoke via `node "$CODEX_PLUGIN_ROOT/scripts/codex-companion.mjs" task --write [--model X] [--effort none|minimal|low|medium|high|xhigh] --prompt-file <handoff.md>`; omit model/effort to use `~/.codex/config.toml` default (GPT-5.5-high-fast). No `--fast` CLI flag. Key risk: Codex under `workspace-write` can't be hard-blocked from `git commit` — the no-commit/stage-only contract must be prompt-carried + orchestrator-verified.
- **#48** — #33 Parts C–F (doc-anchors + ADR/claude-mem pointers + lean-index linter) + /defer marketplace routing + tech-debt label auto-create. Apply the agent-review principle to the C/F validators.

---

## 5. Next-step detail

### 5.1 Triage #45 (do first)
`gh issue view 45`. The claim: scaffold-dev's `closing-vertical-slice` memory-bank **harvest** writes per-slice learnings into memory-bank files, but scaffold-onboard treats the 8 derived memory-bank files as **derived-from-MASTER-SPEC (SSoT)** — so a harvest write to a derived file would be clobbered on the next `/scaffold-project` re-derive (or contradicts the SSoT model). Decide: (a) is this a real contradiction? (b) if so, does harvest target only the *non-derived* files (`05-active-context`, `06-progress`, `09-known-issues`, `tech-debt.md`) and never the 8 derived ones? Adjacent to the `tech-debt.md` seeding we just shipped (it's correctly a non-derived seeded-index file). A `/critique`-style decision likely settles it; may need a small doc/skill fix to make harvest's target set explicit. Then label + bucket it.

### 5.2 Next-cycle options (pick after #45)
- **Option A — v0.2 tail closeout:** bundle **#8 (trivial) + #7 + #42** (the agent-review items showcase the promoted principle) → one small release. Finishes Tier 1 cleanly. *Recommended to clear the deck before bigger work.*
- **Option B — #47 Codex implementer backend:** higher value (offloads implementation from the Claude subscription) but v0.3-scoped and larger. Go here if reducing Claude consumption is the priority.

---

## 6. Key context / gotchas

- **No pairing manifest here** (plugin source repo). scaffold-dev's `planning-vertical-slice` / `handing-off-session` refuse without `.workspace/pairing.json`. Develop with the plain **brainstorm → writing-plans → subagent-driven-development** superpowers flow (as this session did). Handoffs = manual `docs/HANDOFF-*.md`.
- **Bot-review babysitting workflow (proven this session):** the user triggers the Codex GitHub app (sometimes the Codex macOS app pushes fixes directly); you fetch the PR's inline review comments via `gh api repos/<o>/<r>/pulls/<n>/comments`, **verify each finding against the code** (`receiving-code-review` — don't blindly apply; one Codex *fix-ordering* was itself a bug Codex later caught), fix + test + push. Codex posts a **👍 reaction** (not a review object) when it has **no** findings — that's the clean signal. Consider a proactive adversarial self-audit to get ahead of the rounds.
- **Squash-merge reconcile gotcha:** after a squash-merge, local `main` (which held the spec/plan commits now folded into the squash) **diverges** from `origin/main` → `git pull --ff-only` fails. Fix: `git fetch && git reset --hard origin/main` (safe — the squash contains all content).
- **Release mechanics:** bump `plugin.json` (Claude **and** Codex — parity enforced by `tests/test-codex-dual-publish.sh`) + README version table/tree → merge → `git tag <plugin>-v<ver>` on the merge commit → push tags. `/plugin update` is version-keyed off `plugin.json`.
- **Binding principle:** *agent-review over deterministic semantic gates; deterministic only for mechanical facts (exit codes, `gh`/git rc, parse-validity).* Drove #40/#44/#33's whole design. (`~/.claude/architect-critic/principles.md`, `pp-e72993dfb626c518`.)
- **Untracked `.claude/`** in the working tree is a session artifact — do NOT commit it (keep `git add` targeted).
- **scaffold-onboard test suites are slow** (55–75s+ each, ~14 files) — run in background with a generous timeout; short timeouts masquerade as hangs.

---

## 7. Must-read files / pointers
- `docs/SPEC-issue-backlog-triage.md` — the tiered backlog roadmap (the "overall spec").
- `docs/SPEC-pr-hierarchical-merge-mode.md` / `docs/SPEC-slice-demo-agent-eval.md` / `docs/SPEC-lean-index-defer.md` — the three v0.2 designs (+ their `PLAN-*.md`).
- `scaffold-dev/lib/pr.sh` — the merge-mode primitives (read for any #47 / pr_hierarchical follow-up).
- `scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md` — the pr_hierarchical workflow contract + agent-driven pre-merge gate.
- Memory: `project_scaffold_dev_v02_branch` (full v0.2 build + review-round log), `feedback_agent_review_over_deterministic_gates`, `feedback_subagent_vs_inline_threshold`, `friction_log_first_realtest`.
