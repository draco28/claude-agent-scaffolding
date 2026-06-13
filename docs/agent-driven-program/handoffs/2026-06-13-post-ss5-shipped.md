# Session Handoff — SS-5 SHIPPED (scaffold-dev v0.5.0) · optional Codex implementer backend

**Date:** 2026-06-13 · **Author:** prior session (SS-5 brainstorm → build → holistic review → PR #65 review-to-merge) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sub-spec sequence + §6 ledger) and `specs/SS-5-codex-implementer-backend.md` (the SS-5 design-of-record). This handoff is the delta on top of them and supersedes the `2026-06-12-post-ss4-shipped.md` "SS-5 designed-not-started" line — SS-5 is now shipped.

---

## 1. What this session did (one line)

Took **SS-5** (optional Codex implementer backend — #47) from **nothing** to **merged + tagged**: full `brainstorm → spec → subagent-driven build (5 work items) → adversarial holistic review → bot-review → release` cycle; merged **PR #65 → `d566a83`**, tagged **`scaffold-dev-v0.5.0`**, closed **#47**.

---

## 2. ⚠️ FIRST ACTION NEXT SESSION: pick the next sub-spec (SS-5 is DONE)

SS-5 is fully shipped — **no carry-forward fix work**. Two tracks for next:

1. **SS-5.1 — Codex *synthesizer* backend (the explicit fast-follow).** SS-5 narrowed to **implementer-only**; the scaffold-onboard *derivation* side (4 synthesis-dispatch skills) is still Claude-only. The `lib/codex.sh` adapter + the `{mode,…}`/gaps-mode pattern are proven and reusable. **Honor the SS-7-handoff §4 router-file boundary** — the Codex synthesis path must NOT author `CLAUDE.md`/`.claude/settings.json`/`AGENTS.md` (those stay mechanical via `sf_claude_md_generate` etc.). No issue filed yet; file one or fold into a brainstorm.
2. **SS-6 — cleanup-to-zero** (#8/#9/#6/#10/#37/#38/#39/#48-rem/#53/#63 + new **#66**). Standalone; interleave.

Run each through its own `brainstorm → spec → subagent-driven-development → bot-review → release` cycle.

---

## 3. SS-5 — what shipped + the review story 🔧

**Merge:** PR #65 **merge-committed** (not squashed — branch history preserved) to `main` as `d566a83` · tag `scaffold-dev-v0.5.0` on the merge commit (pushed) · **#47 auto-closed** (single-issue `Closes #47`) · SPEC §5/§6 ledger marked shipped (landed in the merge).

**The product change.** When the resolved `implementer_backend` is `codex`, `planning-vertical-slice §8.3b` dispatches a work item to OpenAI's externally-installed **`codex-plugin-cc`** companion via the new **`lib/codex.sh`** adapter, instead of the Claude `implementer-agent` subagent — under the **same** `{mode,report_path,summary,stage_status,gaps}` contract, gaps-mode escalation, and no-commit boundary. **Default stays `claude_subagent`; existing projects unchanged.** Scope is **implementer-only** (synthesizer = SS-5.1).

- **`lib/codex.sh`** — `sd_codex_resolve_companion` / `preflight` / `dispatch` / `wait` / `result` / `verify_nocommit`. All `set -e`-safe (SS-4 lesson) and tested through `bin/sd`.
- **`lib/backend.sh`** — `sd_backend_resolve` (override > manifest `.implementer_backend` > `claude_subagent`; invalid → fail loud).
- **Liveness:** `task --background` → poll `status` (~45s) + stall heuristic (job-log mtime, ~5min) + wall-cap (~20min); clarification-stop → **gaps-mode** → orchestrator decides + re-dispatches (`--resume-last`/`--fresh`).
- **Access:** `task --write` → `approval=never` + `sandbox=workspace-write`; repo trusted → non-interactive. Worktree-trust is a pre-flight path-prefix check.
- **Tests:** `test-codex.sh` + `test-backend.sh` against an env-driven **mock companion shim** (no real Codex / no network), incl. the `set -e` regression guard on `wait`.

**Build method:** inline TDD (single coherent authorship — the work centred on one shared `lib/codex.sh` with the known `set -e` sharp edge), then an **adversarial holistic-review Workflow** (4 lenses → independent skeptic per finding, 13 agents).

**The review story — strong convergence, two backends checking each other:**
- The **first dispatcher-path smoke caught an SS-4-class `set -e` bug** (`preflight` aborting on the bare `_sd_codex_worktree_trusted` call before its `case`) — fixed before commit. *Dispatcher-path testing is non-negotiable.*
- The **holistic-review Workflow** returned **8 findings, all LOW/NIT** — the set-e-safety and spec-conformance lenses were *clean*; the companion-fidelity lens **ran a live end-to-end task against real Codex** and confirmed all 7 JSON field paths. One genuine code fix (version-aware companion resolution — cache preferred over a stale marketplace copy) + negative-path test hardening.
- **Codex's own bot-review** (3 followup commits on the PR) then improved it further: replaced my non-portable `sort -V` with a pure-bash `_sd_codex_version_gt` (**macOS/BSD `sort` has no `-V`** — my version would mis-resolve on a non-GNU box), added `--resume-last`/`--resume`/`--fresh` to dispatch, normalized companion `done`→`completed`, and moved the prompt-file **outside** the worktree (so it can't pollute the no-commit verify). Convergence = the round where Codex's review on the latest commit was clean → merged.

**Verified post-merge:** full scaffold-dev suite **20 files / 0 failed**; dual-publish parity **149/0**; `resolve_companion` returns the versioned cache copy.

---

## 4. Durable design decisions / lessons from SS-5 (apply next session) ⭐

- **The Codex backend is a Mode-B implementer with *async liveness*.** SS-4 settled that a Mode-B implementer has no inline user channel; its only escalation is gaps-mode → orchestrator decides + re-dispatches. Codex run `approval=never` **is** exactly that. The ONLY new machinery is polling-for-the-surface (background job + `status` poll + stall/cap) because Codex is an external process. Reuse this framing verbatim for SS-5.1.
- **The SS-4 `set -e` dispatcher trap recurs — guard every external call, test through `bin/sd`.** A helper correct in-process aborts under the dispatcher's `set -euo pipefail` on any bare non-zero (here: a `_helper "$x"` whose rc≠0 short-circuits the function before its `case`). Use `if out="$(cmd)"; then …; else rc=$?; fi`; never `cmd; rc=$?`; avoid bare `(( … ))`. The first dispatcher-path smoke caught it; in-process tests never would.
- **`sort -V` is NOT portable** (GNU-only; macOS/BSD `sort` lacks it). For version selection write a pure-bash field-wise comparator (`_sd_codex_version_gt`) or guard the platform. Any "pick newest version" leg has this trap.
- **A lib helper that drives an external CLI must own its prompt/temp artifacts OUTSIDE the worktree.** The dispatch prompt-file was moved out of the worktree + removed after dispatch, so it can't show up in the no-commit `git status --porcelain` verify. Temp inputs to an agent that edits a tree must not live in that tree.
- **Resolve external-plugin paths version-aware AND layout-aware.** The companion exists in two layouts (`cache/openai-codex/codex/<ver>/scripts` and `marketplaces/openai-codex/plugins/codex/scripts`). Prefer the versioned cache's newest; fall back to marketplace only when no cache copy exists. A naive `sort | tail` lets the lexical path prefix beat the version.
- **The adversarial holistic-review Workflow earns its keep — and can validate against the real dependency.** 4 diverse lenses + a skeptic-per-finding filtered 9 raw → 8 confirmed (all LOW/NIT) and, crucially, one lens **ran a live task against real Codex** to prove field-path fidelity the mock alone couldn't. For any feature wrapping an external tool, have one review lens exercise the real thing.
- **Mock the external companion via an env-driven shim selected by an override env.** `SCAFFOLD_CODEX_COMPANION` points tests at a fake `.mjs` emitting canned `setup/status/result` JSON (modeled on `tests/fixtures/gh-shim/gh`); knobs (`CODEX_SHIM_FAIL`/`_NO_JOBID`/`_STATUS_RAW`) exercise negative paths. No real Codex / no network in CI.

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):**
- SS-1 ✅ · SS-2 ✅ · SS-3 ✅ · #59 ✅ · #58 ✅ wontfix · SS-7 ✅ (scaffold-onboard v0.8.0) · SS-4 ✅ (scaffold-dev v0.4.0) · **SS-5 ✅ SHIPPED (#47 → scaffold-dev v0.5.0)**
- **SS-5.1** — Codex *synthesizer* backend (scaffold-onboard derivation). The explicit fast-follow; inherits the `lib/codex.sh` pattern; must honor the SS-7-handoff §4 router-file boundary. No issue yet.
- **SS-6** — cleanup-to-zero. Now includes **#66** (new).

**Plugin versions (current main):** workspace-init 0.1.2 · scaffold-onboard 0.8.0 · **scaffold-dev 0.5.0** · architect-critic 0.2.2 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Open backlog (11):** #6 · #8 · #9 · #10 · #37 · #38 · #39 · #48 (C/D/E + routing/label remainder) · #53 (CI) · #63 (SS-7 deferred edge) · **#66 (new — `closing-vertical-slice` leaves `05-active-context.md` stale; no close-time status-flip / Next-up cursor advance; scaffold-dev, SS-6 candidate)**. **Closed this session: #47.**

---

## 6. Process notes / environment (load-bearing)

- **This PR was MERGE-committed, not squashed** (unlike SS-4) — the branch's individual commits (incl. Codex's 3 followups `8994306`/`734287e`/`31e61e3`) are preserved on `main`. Either merge style is fine; tag goes on the merge commit.
- **Codex on this repo reviews AND pushes fix commits to the PR branch.** The user drove `@codex review` rounds; convergence = the round where Codex's review on the **latest** commit is clean. Verify "unresolved" threads against HEAD before merging (Codex's own later commits fix many; GitHub doesn't auto-resolve).
- **The Codex backend depends on an EXTERNAL plugin** (`openai-codex` / `codex-plugin-cc`, installed at `~/.claude/plugins/{cache,marketplaces}/openai-codex/...`). The full verified companion interface (`setup`/`task`/`status`/`result`/`cancel` `--json` shapes) is documented in `specs/SS-5-codex-implementer-backend.md` §1. `SCAFFOLD_CODEX_COMPANION` overrides resolution.
- **scaffold-dev test commands:** full suite `cd scaffold-dev && bash run-tests.sh` (→ 20 files / 0 failed; auto-discovers `tests/test-*.sh`). Dual-publish parity is **repo-root, separate**: `bash tests/test-codex-dual-publish.sh` (→ 149/0) — run after any version bump. `assert_eq <label> <expected> <actual>` (label first); tests source `tests/_helpers.sh` (which exports a stable `CLAUDE_PLUGIN_DATA`).
- **`codex_*` tests require `node`** (they exercise `node <companion>`); `test-codex.sh` skip-guards with a loud notice if `node` is absent.
- **Handoffs in this source repo are manual** (`docs/agent-driven-program/handoffs/`); the scaffold-dev `/handoff` skill refuses (no pairing manifest). Commit to `main` directly.

---

## 7. Recommended next-session entry points

1. **SS-5.1** (Codex *synthesizer* backend) — brainstorm → spec → build → bot-review → release. Reuses `lib/codex.sh`; wires the 4 scaffold-onboard synthesis-dispatch skills; **must respect the SS-7-handoff §4 router-file boundary** (don't synthesize CLAUDE.md/settings.json/AGENTS.md on the Codex path).
2. **SS-6** (#8/#9/#6/#10/#37/#38/#39/#48-rem/#53/#63/**#66**) — cleanup-to-zero; interleave.

**Operator follow-ups (not code):** (a) **real-Codex smoke** — a throwaway slice with `implementer_backend=codex` to confirm non-interactive run + early-stop-surfaces-as-gaps + no-commit verify (no live Codex in CI); (b) delete the local `feat/ss5-codex-implementer-backend` branch.

Target remains **zero open backlog**. SS-5 extended the agent-driven story cross-tool on the *implementer* side; SS-5.1 extends it to *synthesis*; SS-6 clears the independent remainder.
