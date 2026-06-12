# SS-5 — Optional Codex implementer backend (scaffold-dev)

**Date:** 2026-06-12 · **Type:** additive (optional backend behind a manifest selector) · **Depends on:** none (independent; inherits SS-3/SS-7 tool-agnostic dispatch)
**Ledger:** #47 · **Plugins touched:** `scaffold-dev` only · **Release:** `scaffold-dev` minor bump (v0.4.0 → v0.5.0)
**Design settled with user 2026-06-12** (this brainstorm): implementer-only scope · direct-call lib adapter · background-poll-gaps liveness · manifest+override config · hard-fail-on-unavailable.

---

## 1. Decision

Add an **optional Codex implementer backend** to scaffold-dev's work-item dispatch. When the resolved
`implementer_backend` is `codex`, the orchestrator (`planning-vertical-slice §8.3`) dispatches a work
item to OpenAI's externally-installed **`codex-plugin-cc`** (`codex` plugin, installed globally) via a
new tested mechanical adapter `lib/codex.sh`, instead of the Claude `scaffold-dev:implementer-agent`
subagent. The default stays `claude_subagent` — **existing projects are unchanged**.

The same `{mode,…}` return contract, the same gaps-mode escalation, and the same no-commit boundary
that govern the Claude implementer govern the Codex one. **Everything downstream of obtaining
`{mode,…}` is identical for both backends** (§8.4 returns / §8.5 verify / §8.6 commit+merge unchanged).
The only genuinely new conceptual surface is **async liveness** — Codex is an external process, so the
orchestrator polls for the surface instead of receiving a subagent return.

Closes **#47**. Scope is **implementer-only**; the scaffold-onboard synthesis backend is a future
fast-follow (out of scope, §7).

## 2. The unifying spine — agent authority vs mechanical legs

Per the SS-4 disposition rule (`feedback_agent_review_over_deterministic_gates`): semantic judgment is
agent-owned; deterministic bash survives only as real-command-execution legs.

| Concern | Mechanical leg (deterministic — `lib/codex.sh`) | Agent authority (orchestrator prose) |
|---|---|---|
| **Locate Codex** | `sd_codex_resolve_companion` — glob newest companion / override env / fail-loud | — |
| **Availability** | `sd_codex_preflight` — `setup --json` parse + worktree-trust path-prefix check | decide remediation vs abort on hard-fail |
| **Dispatch** | `sd_codex_dispatch` — `task --background --write --prompt-file` → echo job-id | author the work-item prompt (contract + handoff + return-shape) |
| **Liveness** | `sd_codex_wait` — bounded poll on `status`; stall heuristic; `cancel` on stall/cap | what to tell Codex on a clarification-stop; resume vs fresh |
| **Read return** | `sd_codex_result` — extract the fenced `{mode,…}` JSON tail | judge a `gaps-surfaced` return; judge a `complete` report |
| **No-commit** | `sd_codex_verify_nocommit` — HEAD==baseline; tree-non-empty (complete only) | decide remediation on a commit-violation |
| **Config** | `sd_backend_resolve` — override > manifest field > `claude_subagent` default | — |

Every work item maps to one or more rows.

## 3. Per-component design

### 3.1 Invocation — direct call via `lib/codex.sh` (settled: Option 1)
A new lib (auto-discovered by `bin/sd`, which runs `set -euo pipefail` and sources every `lib/*.sh`).
Helpers are dispatched as `sd codex_<verb>` in skill prose (a fresh skill shell sources no libs — only
`bin/sd` does; SS-4 lesson). The `codex-plugin-cc` rescue-forwarder subagent was rejected: it returns
raw stdout with no structured contract and is semantically "rescue," not "execute-work-item."

**Companion resolution** mirrors `lib/compose.sh`'s glob-probe idiom: honor `SCAFFOLD_CODEX_COMPANION`
override first; else glob newest `~/.claude/plugins/{cache,marketplaces}/openai-codex/codex/*/scripts/codex-companion.mjs`;
fail-loud + remediation if absent.

### 3.2 Access — non-interactive full-access (settled: Option 1)
`task --write` maps (verified in the companion's `lib/codex.mjs`) to `approval=never` +
`sandbox=workspace-write`. The repo is `trust_level=trusted` in `~/.codex/config.toml`, so no trust
prompt. This reproduces the user's manual full-access runs (no per-action prompts). **Worktree-trust is
a real pre-flight item**: trust is path-prefix based, so the default `worktrees_dir =
${canonical.root}/.worktrees` inherits trust, but a custom worktrees_dir outside a trusted prefix would
not → `sd_codex_preflight` verifies the worktree path against a trusted root. `workspace-write`, not
`danger-full-access` (a work item is TDD + file edits, no network).

### 3.3 Liveness — background + poll + gaps-mode (settled: Option 1)
The user's real pain: a foreground Codex run blocks the orchestrator 20–30 min, then reveals Codex
never got past thrust 0/1. Cure: `task --background` → job-id immediately; `sd_codex_wait` polls
`status --json` (default `--poll 45`s) with a **stall heuristic** (job-log mtime unchanged for
`--stall 300`s → hung) and a **wall-cap** (`--cap 1200`s); on stall/cap → `cancel` + one confirming
`status` read. Job states: `queued`/`running`/`done`/`failed`/`cancelled`.

**Gaps-mode unification (the key reuse).** SS-4 settled: *a Mode-B implementer has no inline
user-interaction channel; its only escalation is the gaps-mode return; the orchestrator decides +
re-dispatches.* Codex run with `approval=never` **is** a Mode-B implementer with no interactive
channel. So "Codex can't proceed / needs clarification" → it ends its turn with
`{mode:"gaps-surfaced",gaps:[…]}` → caught on the next poll → the orchestrator decides → re-dispatches
via `task --resume-last` (continue) or fresh. The poll/stall/cap legs are mechanical (`sd_codex_wait`);
the clarification *decision* is agent-owned prose.

### 3.4 Return contract — reuse the Claude shape (settled)
`task` exposes **no** `--output-schema` (only `review` bakes one), so the contract is
**prompt-instructed, not schema-enforced**: the dispatch prompt tells Codex to end its turn with a
fenced `{mode, report_path, summary, stage_status, gaps}` JSON block — the **exact** shape the Claude
implementer returns. `sd_codex_result` reads `result <job-id> --json`, extracts the **last** fenced
JSON block (the rawOutput may carry leading reasoning prose), and echoes the object. A turn that emits
no parseable block → routed to the existing §8.4 "malformed return" menu, not a crash.

### 3.5 No-commit — prompt-carried + orchestrator-verified (settled)
The `executing-work-item` contract already forbids `git commit/push/pull/fetch`; for Codex it is
**prompt-carried** (embedded in the dispatch prompt) **plus orchestrator post-verify**:
`sd_codex_verify_nocommit` asserts `HEAD == baseline` **always** (the real no-commit invariant). The
"working-tree/stage non-empty" assertion is evaluated at the **call site** only for `mode:complete` — a
legitimate zero-change `gaps-surfaced` return (`stage_status:none`) must **not** be flagged. On a
commit-violation, surface loudly; the orchestrator decides remediation.

### 3.6 Config — manifest default + per-invocation override (settled: Option 1)
`sd_backend_resolve [--backend <override>]` resolves precedence **override > `.workspace/pairing.json`
`.implementer_backend` > `claude_subagent`**. The absent-field read returns rc=1 and must **not** abort
under the dispatcher's `set -e` (the default is total). **Read-with-default only — zero workspace-init
touch** (the field is optional; seeding it into the manifest schema is a separate workspace-init change,
out of SS-5 scope). Backward-compatible: existing manifests lacking the field resolve to
`claude_subagent`.

### 3.7 Unavailable — hard-fail + remediation (settled: Option 1)
`sd_codex_preflight` runs **before** dispatch; if Codex is unresolvable / not installed / not authed /
worktree untrusted → **hard-fail with an actionable remediation string** naming the failed gate
(install / `codex login` / `SCAFFOLD_CODEX_COMPANION` override / move worktree under a trusted root).
**No silent fallback to Claude** — the user explicitly chose Codex; quietly running Claude would violate
intent. This matches the program's fail-loud / no-silent-skip discipline.

### 3.8 The §8.3 seam rewrite
Replace the proto-typed Codex branch with: `sd backend_resolve` → if `codex`: `sd codex_preflight`
(hard-fail) → **assemble the dispatch prompt-file** = the full `executing-work-item` contract (read from
the installed SKILL.md — single source of truth; Codex does not auto-load the skill) + the handoff path
+ the worktree path + the no-commit prohibition + the fenced-`{mode,…}` return instruction → record
`baseline = git -C <worktree> rev-parse HEAD` → `sd codex_dispatch` → `sd codex_wait` → on done
`sd codex_result` → `sd codex_verify_nocommit` → **join the existing Claude downstream unchanged**.
Within a round, Codex work items dispatch **sequentially** (the companion's `--resume-last` resolves the
latest thread for the session; concurrent same-session tasks would race). All snippets use the
`sd codex_*` dispatcher form.

### 3.9 State-coupling invariants (load-bearing)
The companion keys job state by `sha256(realpath(git-toplevel-of-cwd))` under `${CLAUDE_PLUGIN_DATA}`
(or `os.tmpdir()/codex-companion` when unset). Two invariants follow: **(a)** every helper `cd`s into
`<worktree>` before any `node` call (so `status`/`result`/`cancel` find the job dispatched there);
**(b)** `CLAUDE_PLUGIN_DATA` must be stable across dispatch and all poll calls (never mutated
mid-sequence). Tests pin it (the `_helpers.sh` `setup_tmp_*` already export a stable one).

## 4. Build sequence (5 work items, 3 rounds)

```
Round 1 (∥, disjoint files):  W1 lib/codex.sh (resolve+preflight)     W2 codex-shim fixture + test skeleton
Round 2 (∥, disjoint files):  W3 lib/codex.sh (dispatch/wait/result/verify)   W4 lib/backend.sh (resolve)
Round 3:                       W5 wire §8.3 + prompt assembly + v0.5.0 bump + dual-publish parity
```
Hard serial edges: W1→W3 (same file), W1→W4 (lib conventions), W3→W5, W4→W5. To keep Round 2 race-free,
W4 lives in its own `lib/backend.sh` with its own tests in a separate file.

- **W1** — `sd_codex_resolve_companion`, `sd_codex_preflight`. *(R1)*
- **W2** — `tests/fixtures/codex-shim/codex-companion.mjs` (env-driven fake, modeled on `gh-shim/gh`) + canned JSON fixtures (setup-ready/unauthed, status-running/done/failed, result-complete/gaps) + `tests/test-codex.sh` skeleton (auto-discovered). *(R1)*
- **W3** — `sd_codex_dispatch`, `sd_codex_wait`, `sd_codex_result`, `sd_codex_verify_nocommit`. **All tested through `bin/sd`.** *(R2)*
- **W4** — `sd_backend_resolve` + `tests/test-backend.sh`. *(R2)*
- **W5** — §8.3 rewrite + prompt assembly + bump both `plugin.json` 0.4.0→0.5.0 + CHANGELOG. *(R3)*

## 5. Verification

- **Mocked companion, always.** `SCAFFOLD_CODEX_COMPANION` points every test at the fake shim — **no
  real Codex, no network, no `node`-codex in any test.** Argv recorded to `CODEX_SHIM_LOG` so tests
  assert `--write` / `--background` / `--prompt-file <abs>` / `cancel` were passed.
- **Dispatcher-path mandatory.** Every `sd_codex_*` helper is exercised through `bash bin/sd codex_<verb>`
  — not just sourced in-process. `sd_codex_wait` is the highest-risk `set -e` surface (the SS-4
  `sd_redgate_assert_red` class of bug: correct in-process, broken under the dispatcher's `set -e`); it
  gets an explicit dispatcher-path regression test for status=failed (non-throwing) + stuck→cancel.
- **Per-helper cases:** resolve (override / glob-newest / absent-fail+remediation); preflight
  (ready→0, unauthed→1+`codex login`, untrusted-worktree→1); dispatch (job-id echoed, flags logged);
  wait (done→0, failed→0 non-throwing, stuck+tiny-stall/cap→cancel-invoked); result (complete + gaps +
  prose-before-fence + no-fence→malformed); verify_nocommit (HEAD-moved→1, HEAD-unchanged+staged→0,
  HEAD-unchanged+clean handled per call-site); backend_resolve (absent→default, field→codex, override
  beats manifest, no-manifest→default+rc0).
- **§8.3 skill-prose lints:** references `sd codex_*` dispatcher forms; **no bare `sd_codex_*`** calls
  in snippets (SS-4 skill-shell lesson); unavailable/hard-fail path documented.
- **Full scaffold-dev suite green** (`cd scaffold-dev && bash run-tests.sh`) after each round (run the
  whole suite, distrust "pre-existing failure" claims).
- **Dual-publish parity** (`bash tests/test-codex-dual-publish.sh` from repo root) **after** the version
  bump — both `.claude-plugin/` + `.codex-plugin/` plugin.json at 0.5.0.
- **Final whole-implementation review** over the full branch diff that **actually runs the gates** and
  re-exercises `sd codex_wait` through `bin/sd` (the SS-4 lesson — the dispatcher `set -e` bug was
  caught only there).
- **Real-Codex smoke (manual, post-merge, operator-run, NOT in CI):** a throwaway slice with
  `implementer_backend=codex` → confirm non-interactive run (no prompts), an early-stop surfaces as gaps
  within a poll interval (not a 20–30 min block), no-commit verify passes.

## 6. Unavailable behavior & failure modes

Unlike the SS-4 inline seams, the Codex backend dispatches an **external async process** that genuinely
can be absent or hang. Behaviors: **unavailable** → pre-flight hard-fail + remediation (§3.7); **stall**
(no log progress for `--stall`) → cancel + surface as gaps-mode (recoverable via re-dispatch);
**wall-cap** exceeded → cancel + surface; **commit-violation** → surface loudly, orchestrator decides;
**clarification-stop** → gaps-mode → decide + re-dispatch; **malformed/no-JSON return** → existing §8.4
malformed menu. Every mechanical leg **fails loud with actionable remediation**, never silently skips.

## 7. Out of scope (explicit non-goals)

- **Synthesis backend** (scaffold-onboard Codex derivation) → future SS-5.1.
- **Router-file boundary** (CLAUDE.md / settings.json / AGENTS.md mechanical-not-synthesized) → N/A:
  the implementer path synthesizes no router files. The SS-7-handoff §4 boundary is untouched.
- **workspace-init manifest seeding** of `implementer_backend` → read-with-default only; seeding is a
  separate workspace-init change.
- **`danger-full-access` / network sandbox**; **parallel multi-job Codex** (one job per work item,
  sequential within a round); **cross-session job persistence** beyond a single gaps-mode re-dispatch.

## 8. Packaging

One `scaffold-dev` **minor** bump (new optional backend = feature-level): `0.4.0 → 0.5.0` in **both**
`.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` (dual-publish parity). CHANGELOG entry.
Closes **#47**. Program-spec ledger (`SPEC-agent-driven-program.md` §5/§6) updated to mark SS-5 shipped
and #47 closed.
