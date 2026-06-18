# #39 — architect-critic async external adversary + readiness doctor (+ scaffold-dev review gate)

**Date:** 2026-06-18 · **Type:** additive (new async lifecycle behind opt-in flags; existing sync path untouched) · **Depends on:** SS-5 / SS-5.1 (reuses the proven `lib/codex.sh` async-dispatch spine — this is its **third** use)
**Ledger:** `#39` (SS-6) · **Plugins touched:** `architect-critic` (Phase A) + `scaffold-dev` (Phase B) · **Release:** `architect-critic` minor `0.2.2 → 0.3.0`, then `scaffold-dev` minor `0.7.0 → 0.8.0`
**Design settled with user 2026-06-18:** full scope (all six #39 improvements, incl. #3 size-guidance + #6 gate) · async model = **defer-to-resume (unified)** · **one spec, two release phases** · surfaces = **dedicated job-manager skill** (Option 2) + separate doctor skill · the **sync path stays the default and is untouched**.

---

## 1. Decision

Make architect-critic's external adversary (Codex, the independent fresh-frame second reviewer invoked at **close-depth**) **runnable as a managed background job**, while leaving the existing synchronous path as the unchanged default. When the user passes `--async` to a close-depth critique, the adversary is dispatched to the externally-installed `codex-plugin-cc` companion via a new async section of `lib/codex.sh` (the same spine SS-5/SS-5.1 wrap), tracked durably in `state.json`, and consumed later via an explicit **resume**.

Six improvements, all in scope:

1. **Async lifecycle** — dispatch / status / result / cancel for background close-depth audits (#1).
2. **Readiness doctor** — pre-flight "is Codex/Claude installed, authed, schema-capable?" with fix-it guidance (#2).
3. **Size-aware guidance** — recommend foreground (small spec) vs background (large/unclear) at dispatch (#3).
4. **Durable job memory** — `state.json` v2→v3 records each external run for history, resume, and troubleshooting (#4).
5. **Resume/continue** — fold a finished background run into the formal critique **without silently mutating prior conclusions** (#5).
6. **Optional scaffold-dev review gate** — opt-in monitored architect-critic audit at slice/spec close (#6), a **consumer** of 1–5.

**The async model is "defer-to-resume (unified)."** Turn 1 (`--async`): run the host self-audit as a **read-only preview** (shown, not concluded), **persist** that challenge set, dispatch Codex in the background, record the run, and return a job handle. Turn N (`resume`): fetch the Codex result, run the **existing** `consolidator.sh` over *both* adversaries (so the both-flagged cross-confirmation that justifies a second reviewer is preserved), then run the **one** unified sequential rebuttal and append the run. Because turn 1 reaches **no conclusions**, resume mutates nothing — AC #5 is satisfied structurally, reinforced by a **re-resume idempotency guard** (a concluded run resumes inspect-only).

**The unifying realization (same as SS-5.1):** the spine is **agnostic to the prompt source and the return shape**. `ac codex_dispatch` takes a prompt-file and returns a job; `ac codex_result` extracts the fenced JSON tail. Architect-critic's *only* backend-specific pieces are (a) the **return contract** it embeds in the prompt-file — `{challenges[], gaps[]}` instead of synthesis's `{mode,…}` — and (b) the **consumer** (consolidator + rebuttal) it routes the result into. Everything that builds the adversarial prompt and everything that validates/merges challenges **already exists and is reused unchanged**.

**Two delivery phases, one design.** Phase A builds 1–5 in architect-critic (ships v0.3.0). Phase B builds the gate (#6) in scaffold-dev (ships v0.8.0), consuming Phase A's async API. Designing together lets the gate's needs shape the API; shipping separately keeps each a clean per-plugin release.

---

## 2. The unifying spine — agent authority vs mechanical legs

Per the SS-4 disposition rule (`feedback_agent_review_over_deterministic_gates`): semantic judgment is agent-owned; deterministic bash survives only as real-command-execution legs.

| Concern | Mechanical leg (deterministic) | Agent authority (skill prose) |
|---|---|---|
| **Locate Codex** | `ac_codex_resolve_companion` — glob newest companion / `ARCHITECT_CRITIC_CODEX_COMPANION` override / fail-loud | — |
| **Readiness (doctor)** | `ac_codex_preflight` — companion `setup --json` parse + `command -v codex/claude` + version probes + target-root trust | decide remediation (install / `codex login` / trust); **user-approved**, never auto-install |
| **Dispatch** | `ac_codex_dispatch` — `task --background --prompt-file --json` → echo job-id | build the adversarial prompt + embed the `{challenges,gaps}` return contract (prompt assembly already exists) |
| **Liveness** | `ac_codex_status` — one-shot non-mutating status; `ac_codex_wait` — bounded poll on `status`; stall heuristic; cancel on stall/cap; normalize `done`→`completed`; fixed tokens `completed\|failed\|cancelled\|stalled\|capped\|error`; **always rc=0** | — |
| **Read return** | `ac_codex_result` — extract the last fenced ```json block; validate `.challenges` is an array with severity `premise\|gap\|alternative` | judge a `failed`/empty return; decide re-dispatch-once vs abort |
| **Consolidate** | *(existing, unchanged)* `consolidator.sh` — dedup + both-flagged cross-confirmation + `adversaries_used` | — |
| **Rebuttal** | — | the **sequential rebuttal cycle** with T=4 concession scoring (critiquing-spec Steps 7–9) |
| **Job memory** | `ac_state_external_run_add/set_status/get` (CRUD on `external_runs[]`) + `migration` v2→v3 | — |
| **Size-guidance** | `wc -l` / rough token estimate vs threshold | recommend foreground vs background (advisory only) |
| **Idempotency** | `resolved_run_request_id` set-once guard | — |

---

## 3. Per-component design (Phase A — architect-critic)

### 3.1 Readiness doctor (#2) — new skill `checking-adversary-readiness` + `/critique-doctor`
A standalone-invocable gerund skill (architect-critic convention) that reports adversary readiness **before** a deep audit, so close-depth reviews don't fail mid-run. Checks, each with an actionable line:
- `codex` + `claude` binaries present (+ `--version`); companion resolvable (`ac_codex_resolve_companion`).
- Codex auth + schema-output support via companion `setup --json` (`{ready, codex.available, auth.loggedIn}`).
- Timeout/poll config (`ARCHITECT_CRITIC_CODEX_TIMEOUT_S`, async `--poll/--stall/--cap` defaults).
- Async target-root trust (the audited artifact's repo root, if applicable).

**Fail-soft + advisory:** the doctor never blocks; it prints ready / missing / how-to-fix. Install + `codex login` actions are surfaced as guidance, **explicit and user-approved** (non-goal: auto-install/login). Reuses the `command -v` + version capture already in `critiquing-spec` Step 3 — extracted into a shared probe so both the doctor and Step 3 call one source of truth.

### 3.2 Async spine in `lib/codex.sh` (#1) — add, do not replace
The existing **sync** path (`ac_codex_run_audit`, `_ac_codex_run_with_timeout`, `_ac_codex_validate_json`, `_ac_codex_schema_path`) stays intact and remains the default for foreground close-depth audits. **Add** an async section by porting SS-5.1's spine to the `ac_` prefix: `ac_codex_resolve_companion`, `ac_codex_preflight`, `ac_codex_target_root`, `ac_codex_dispatch`, `ac_codex_status` (one-shot, non-mutating), `ac_codex_wait` (terminal tokens `completed|failed|cancelled|stalled|capped|error`; `--poll 45` / `--stall 300` / `--cap 1200`; **always returns rc=0** under `set -e` — the highest-risk surface, ported intact), `ac_codex_cancel` (terminal-aware public cancel), `ac_codex_result`, plus `_ac_codex_version_gt`/`_ac_codex_mtime`/`_ac_codex_cancel`.

**Key switch (sync→async):** the sync adversary uses `codex exec --output-schema` directly; the async adversary uses the companion's `task --background --prompt-file --json`, which exposes **no** `--output-schema`. So the schema contract becomes **prompt-instructed** (§3.3). **Read-only refinement:** unlike the SS-5 implementer / SS-5.1 synthesizer (both `--write`), the architect-critic adversary **only reads the embedded artifact and returns JSON challenges** — it writes nothing. Async dispatch therefore runs **without `--write`** (read-only) where the companion supports it, a strictly safer sandbox than the scaffold paths; `ac_codex_target_root` is still resolved (the audited artifact's repo root) for companion **state-keying** and trust. *(Open: confirm companion read-only `task` support during W-spine; fall back to `--write` + target-root trust if absent.)*

### 3.3 Return contract — `{challenges[], gaps[]}`, prompt-instructed (the SS-5.1 lesson)
The companion runs a **bare prompt-file and never sees the skill/system prompt** (`feedback_codex_companion_no_auto_load_contract`). So the dispatch prompt-file = the existing adversarial prompt **+ an appended `## Return contract`** instructing Codex to end its turn with a fenced ```json `{"challenges":[{"text","severity":"premise|gap|alternative","rationale"}], "gaps":[]}` ``` block — the **exact** shape the sync path's `--output-schema` enforces and `consolidator.sh` already reads. `ac_codex_result` extracts the last fenced JSON block from `storedJob.result.rawOutput` (leading reasoning prose tolerated) and validates `.challenges` is an array and `.gaps`, when present, is an array of objects via the (extended) `_ac_codex_validate_json`. No parseable block → re-dispatch-once → abort to claude-only (the run is recorded `failed`, never silently dropped).

### 3.4 Durable job memory — `state.json` v2 → v3 (#4)
Add `external_runs[]`, each: `{ run_id (= companion jobId), host_agent, adversary, artifact_path, depth, status, started_at, completed_at, result_path, codex_session_id, resolved_run_request_id }`.
- `status` ∈ `running|completed|failed|cancelled|stalled|capped`.
- `result_path` → where the fetched Codex result lands; the **turn-1 persisted host self-audit** lives adjacently at `${data_dir}/async/<run_id>/claude-audit.json`.
- `codex_session_id` — best-effort (only if the companion `result` payload exposes it; lets the user reopen in Codex directly).
- `resolved_run_request_id` — set once, when resume appends to `recent_runs`; **this is the re-resume idempotency guard** (§3.5).
- New CRUD in `lib/state.sh` (`ac_state_external_run_add/set_status/get/list`), lock-guarded via the existing `ac_lock_acquire`/`ac_guarded_jq_write`. Cap the array like `recent_runs` (keep last N).
- `lib/migration.sh` gains a v2→v3 step (mirrors the existing v1→v2: add empty `external_runs`, bump `schema_version=3`; idempotent, preserves all v2 fields).
- `hooks-handlers/session-start.sh` surfaces a **read-only in-flight count** ("architect-critic: N background audit(s) in flight — `/critique-jobs` to inspect"). This is a **deliberate, durable reversal** of v2's `in_flight` removal: v2 dropped a *stale per-request marker* that caused trouble; these are *durable job records* the user explicitly created — the failure mode that justified the removal does not apply.

### 3.5 Resume (#5) — owned by the job-manager, reuses critiquing-spec Steps 7–9
`resume [id]` (default: latest `running`/`completed` run for the current artifact):
1. Read `external_runs[id]`. **If `resolved_run_request_id` is set → inspect-only** (print the prior conclusion + status; append nothing).
2. Else fetch the Codex result (`ac_codex_result`, or read `result_path`); if the job is not yet terminal, report status and stop (no partial consolidation).
3. Load the persisted host self-audit (`claude-audit.json`) + the Codex challenges → run the **existing** `consolidator.sh` (both adversaries present → `agreed_by_both` cross-confirmation surfaces first).
4. Run the **shared** sequential rebuttal cycle (critiquing-spec Steps 7–9, invoked identically to the sync path), then use `ac_state_external_run_finalize_resume` to append the `recent_runs[]` record and set `resolved_run_request_id` under one lock.

The rebuttal/consolidation/append is a **single shared procedure** (Steps 7–9 of critiquing-spec); both the sync path and `resume` enter it with a `{claude_audit, codex_audit, artifact, depth}` tuple — no logic duplicated across skills.

### 3.6 Size-aware guidance (#3) — advisory, at dispatch
At `/critique --close`, before dispatching the adversary, a mechanical heuristic (`wc -l` + a rough token estimate of the artifact) compares against a configurable threshold (`ARCHITECT_CRITIC_ASYNC_HINT_LINES`, default ~400) and **recommends** foreground (small) vs `--async` (large/unclear). Advisory only — it prints the recommendation and proceeds with whatever flag the user passed; it never forces a mode.

### 3.7 Surfaces (Option 2 — dedicated job-manager skill)
- **`critiquing-spec` / `/critique`** — sync path unchanged. Gains `--async`: run host self-audit preview, persist it, `ac_codex_preflight` (hard-fail with remediation if unready — **no silent foreground fallback**; the user chose async), `ac_codex_dispatch`, record the run, print the job handle + the size hint.
- **New `managing-async-critique` skill + `/critique-jobs` command** — owns `status [id]`, `result [id]`, `cancel [id]`, `resume [id]`. `resume` re-enters critiquing-spec Steps 7–9 (§3.5); `status` uses `ac_codex_status` (never the wait loop), `cancel` uses terminal-aware `ac_codex_cancel`, and resume finalizes with `ac_state_external_run_finalize_resume`.
- **`reviewing-critique-history`** — also lists in-flight `external_runs` alongside `recent_runs`.
- **`checking-adversary-readiness` skill + `/critique-doctor`** — §3.1.

### 3.8 Dual-publish constraint
The async spine is **companion-specific** → it implements **Claude-host → Codex-adversary** async only. When hosted **in Codex** (Codex-host → Claude-adversary) there is no proven async companion, so the **existing sync path is retained** for that direction. All skills/commands **ship on both surfaces** (parity enforced by repo-root `tests/test-codex-dual-publish.sh`); async *execution* is Claude-host-only. AC "dual-publish preserved" = ships-on-both, not symmetric-async — documented as a known constraint in the skills and CHANGELOG.

### 3.9 State-coupling invariants (load-bearing, from SS-5.1 §3.10)
The companion keys job state by `sha256(realpath(git-toplevel-of-cwd))` under `${CLAUDE_PLUGIN_DATA}` (or `os.tmpdir()/codex-companion`). Two invariants: **(a)** every helper `cd`s into the artifact's `target_root` before any `node` call (so `status`/`result`/`cancel` find the job); **(b)** `CLAUDE_PLUGIN_DATA` is stable across dispatch + all poll/resume calls (never mutated mid-sequence). The dispatch prompt-file lives **outside** any repo output tree and is removed after dispatch. Because resume can happen in a **later session**, the run_id + target_root + paths recorded in `external_runs[]` are the only state the spine relies on to re-find the job — no in-memory handles.

---

## 4. Phase B — scaffold-dev review gate (#6) (ships scaffold-dev v0.8.0)

An **opt-in, bounded** monitored architect-critic audit at slice/spec close, consuming Phase A's async API.
- **Opt-in config** `review_gate ∈ {off, slice_close, spec_close, both}` (manifest/setting; default `off`). Off = today's behavior exactly.
- **Attach points:** `closing-vertical-slice` (already runs architect-critic at close depth) and `planning-vertical-slice` spec gates.
- **Behavior when on:** dispatch an `--async` close-depth architect-critic audit of the slice/spec artifact via the Phase A spine, then **monitor (babysit) bounded** by `--cap`/`--stall`, surfacing status, with an explicit **usage-consumption warning** and a bound on monitoring iterations. On terminal-but-not-completed (stalled/capped/failed) → surface + let the operator decide (never block the close indefinitely).
- **Non-goals:** unbounded loops; making the gate default-on; collapsing architect-critic's mediator role (Codex/Claude output feeds consolidation+rebuttal, never direct final judgment).

---

## 5. Build sequence (inline TDD — RED→GREEN per unit)

Inline TDD (single coherent authorship centred on one ported `lib/codex.sh` async section with the known `set -e` sharp edge), per `feedback_subagent_vs_inline_threshold` + the SS-5/SS-5.1 precedent.

**Phase A — architect-critic v0.3.0**
- **A-W1** — `tests/fixtures/codex-shim/codex-companion.mjs` (port SS-5.1's env-driven fake; canned `result.rawOutput` = a `{challenges,gaps}` block) + `tests/unit/test-codex-async.sh` skeleton.
- **A-W2** — async spine in `lib/codex.sh` (`resolve_companion`, `target_root`, `preflight`, `dispatch`, `wait`, `result`, `_cancel`, `_version_gt`, `_mtime`) — **all tested through `bin/arc`**, incl. the `wait` non-throwing + stall/cap→cancel regression.
- **A-W3** — `state.json` v3: `external_runs[]` CRUD in `lib/state.sh` + `lib/migration.sh` v2→v3 + tests (migration idempotency, preserves v2 fields, no `in_flight`).
- **A-W4** — readiness doctor: `checking-adversary-readiness` skill + `/critique-doctor` + extract the shared binary/version/auth probe; tests (present/absent/unauthed/untrusted states via shim).
- **A-W5** — `critiquing-spec` `--async` dispatch branch (preview + persist + preflight-hardfail + dispatch + record + size hint) + size-guidance heuristic; seam-prose lint tests.
- **A-W6** — `managing-async-critique` skill + `/critique-jobs` (status/result/cancel/**resume**) — resume reuses Steps 7–9; idempotency guard test; `reviewing-critique-history` in-flight listing; `session-start.sh` count.
- **A-W7** — bump both `plugin.json` 0.2.2→0.3.0 + CHANGELOG + README table + dual-publish parity; file/close #39 (Phase A); update SPEC-agent-driven-program §5/§6; tag `architect-critic-v0.3.0`.

Serial edges: A-W1→A-W2→A-W3→(A-W4,A-W5)→A-W6→A-W7.

**Phase B — scaffold-dev v0.8.0** (after Phase A ships)
- **B-W1** — `review_gate` config read (+ default `off`) + tests.
- **B-W2** — gate attach in `closing-vertical-slice` + `planning-vertical-slice` (dispatch via Phase A spine + bounded monitor + usage warning) + tests through the shim.
- **B-W3** — bump both `plugin.json` 0.7.0→0.8.0 + CHANGELOG + README + dual-publish parity; tag `scaffold-dev-v0.8.0`.

## 6. Verification

- **Mocked companion, always.** `ARCHITECT_CRITIC_CODEX_COMPANION` → the fake shim; **no real Codex, no network.** Argv recorded so tests assert `--background` / `--prompt-file <abs>` / read-only (no `--write` when used) / `cancel`. `codex_*` tests skip-guard (loud) when `node` absent.
- **Dispatcher-path mandatory.** Every `ac_codex_*` helper exercised through `bash bin/arc codex_<verb>`. Explicit `ac_codex_wait` regression: status=failed (non-throwing rc=0) + stuck→cancel (the `set -e` class).
- **Per-helper cases:** resolve (override / glob-newest / absent-fail+remediation); preflight (ready→0, unauthed→1+`codex login`, untrusted→1); dispatch (job-id echoed, flags logged, prompt-file outside any repo tree); wait (`completed`→0, legacy `done`→`completed`, failed→0 non-throwing, bad opts→`error`+rc0, stuck+tiny-stall/cap→cancel, BSD/GNU `stat` order); result (valid block + empty + prose-before-fence + multi-fence→last + no-fence→fail + non-array `.challenges`→fail).
- **State v3:** migration v2→v3 idempotent + preserves all v2 fields + no `in_flight`; `external_runs` CRUD lock-guarded; cap honored; `resolved_run_request_id` set-once; resume append+resolve is one locked finalizer transaction.
- **Resume semantics:** persisted-claude + fetched-codex → consolidate (cross-confirmation) → rebuttal → atomic finalize; **re-resume = inspect-only** (no duplicate `recent_runs`); resume of a non-terminal job reports status and appends nothing.
- **Doctor:** each readiness state yields the correct actionable line; fail-soft (never non-zero-blocks the session).
- **Seam-prose lints:** `critiquing-spec` carries the `--async` branch + size hint + hard-fail (no silent foreground fallback); `managing-async-critique` resume re-enters Steps 7–9; sync path unchanged.
- **Full architect-critic suite green** (`cd architect-critic && bash run-tests.sh` — whole suite, distrust "pre-existing failure" claims) after each work item.
- **Dual-publish parity** (`bash tests/test-codex-dual-publish.sh` from repo root) **after** the version bump.
- **CI green on Linux** (portability pre-scan for BSD/GNU divergence — `stat`, `date`, `mktemp`, bare `$TMPDIR` — before pushing).
- **3-bot review** (Codex + CodeRabbit + Devin) clean; merge on clean verdicts + green suite + 0 unresolved threads (`feedback_bot_review_convergence_judgment`).
- **Real-Codex smoke (manual, post-merge, operator-run, NOT in CI):** a throwaway repo, real Codex authed + trusted → `/critique --close --async` a large spec; confirm the job dispatches and returns a handle without blocking, `resume` consolidates both adversaries into one rebuttal, an early failure surfaces within a poll interval, and the sync path still works foreground.

## 7. Failure modes & unavailable behavior

The async adversary dispatches an **external process** that can be absent or hang. **Unavailable** (`--async` with Codex unresolvable/uninstalled/unauthed/untrusted) → `ac_codex_preflight` **hard-fails with remediation**; **no silent fall-back to foreground/claude-only** (the user chose async — quietly degrading violates intent; the *sync* `/critique --close` path is the explicit foreground choice and is always available). **Stall** (no log progress for `--stall`) → cancel → run recorded `stalled`. **Wall-cap** → cancel → `capped`. **`failed`/malformed/no-JSON return** → re-dispatch-once → record `failed`; `resume` of a `failed`/`stalled`/`capped` run reports the terminal status and the still-available host self-audit preview, and appends nothing. Every mechanical leg **fails loud with actionable remediation** and never silently skips. The doctor is the **only** fail-soft surface (advisory by design).

## 8. Out of scope (explicit non-goals)

- **Symmetric async** (Codex-host → Claude-adversary async) — no proven companion; Codex-host keeps the sync path (§3.8).
- **Codex-only collapse** — architect-critic stays the mediator; external output feeds consolidation+rebuttal, never direct final judgment (#39 non-goals).
- **Inheriting user Codex config for the adversary** — the isolation defaults (`--ignore-user-config --ignore-rules` on the sync path; read-only async sandbox) remain the safer default.
- **Auto-install / auto-login** — the doctor advises; the user runs install/login.
- **Cross-session job persistence beyond a single re-dispatch-once**; **parallel multi-adversary jobs** (one job per audit).
- **Default-on gate** — Phase B is opt-in, bounded; `off` is the default and preserves today's behavior exactly.

## 9. Packaging

Two minor bumps, two releases. **Phase A:** `architect-critic` `0.2.2 → 0.3.0` in **both** `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` (dual-publish parity) + CHANGELOG + README version table; tag `architect-critic-v0.3.0`; file/close #39 (Phase A) and update `SPEC-agent-driven-program.md` §5/§6. **Phase B:** `scaffold-dev` `0.7.0 → 0.8.0` (both plugin.json) + CHANGELOG + README; tag `scaffold-dev-v0.8.0`. Develop with the plain superpowers flow (this is the plugin **source** repo — no pairing manifest; handoffs are manual, committed to `main`).
