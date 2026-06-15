# SS-5.1 — Optional Codex synthesizer backend (scaffold-onboard)

**Date:** 2026-06-13 · **Type:** additive (optional backend behind a manifest selector) · **Depends on:** SS-5 (reuses the `lib/codex.sh` async-dispatch spine); inherits SS-3/SS-7 tool-agnostic synthesis dispatch
**Ledger:** `#67` · **Plugins touched:** `scaffold-onboard` only · **Release:** `scaffold-onboard` minor bump (v0.8.0 → v0.9.0)
**Design settled with user 2026-06-13:** full scope (all **three** synthesis-dispatch skills — memory-bank, governance, onboarding — **no deferral**) · ports SS-5's `lib/codex.sh` spine **minus** worktree / no-commit / gaps-mode · the **router-file boundary** is the load-bearing constraint · manifest+override config · hard-fail-on-unavailable.

---

## 1. Decision

Add an **optional Codex synthesizer backend** to scaffold-onboard's derivation dispatch. When the resolved
`synthesizer_backend` is `codex`, the three synthesis-dispatch skills (`scaffolding-memory-bank §13`,
`scaffolding-governance-docs §11`, `onboarding-project §8`) dispatch each synthesis artifact to OpenAI's
externally-installed **`codex-plugin-cc`** companion via a new tested adapter `lib/codex.sh`, instead of the
Claude `scaffold-onboard:synthesis-agent` subagent. The default stays `claude_subagent` — **existing
projects are unchanged**.

The synthesizer is **simpler than the SS-5 implementer**: synthesis writes its artifact directly to the
manifest-routed output path (no git worktree), the synthesized artifact *is* the deliverable (no no-commit
boundary), and the synthesis return is `complete | failed` (no `gaps-surfaced` channel). The only genuinely
new conceptual surface is the same **async liveness** SS-5 introduced — Codex is an external process, so the
orchestrator polls for the surface instead of receiving a subagent return.

**The unifying realization:** the adapter is **agnostic to the prompt source**. `sf codex_dispatch` takes a
prompt-file and returns a result; it does not care whether `sf_synth_brief_assemble` (the 13 derivation docs
+ EXEC-SUMMARY) or `sf_synth_master_spec_prompt` (MASTER-SPEC) produced the prompt. **Everything that
assembles a prompt and everything that validates an output already exists and is backend-agnostic** — only
the dispatch mechanism (Task → companion) swaps.

Scope is **all three** synthesis-dispatch skills. `planning-project-roadmap` is excluded as a *class
boundary*, not a deferral: it is interactive user-authoring, not a synthesis dispatch (§7).

## 2. The unifying spine — agent authority vs mechanical legs

Per the SS-4 disposition rule (`feedback_agent_review_over_deterministic_gates`): semantic judgment is
agent-owned; deterministic bash survives only as real-command-execution legs.

| Concern | Mechanical leg (deterministic) | Agent authority (skill prose) |
|---|---|---|
| **Locate Codex** | `sf_codex_resolve_companion` — glob newest companion / override env / fail-loud | — |
| **Availability** | `sf_codex_preflight` — `setup --json` parse + **target-root**-trust path-prefix check | decide remediation vs abort on hard-fail |
| **Dispatch** | `sf_codex_dispatch` — `task --background --write --prompt-file` → echo job-id | — (the prompt is pre-assembled by the existing `sf_synth_*` assemblers) |
| **Liveness** | `sf_codex_wait` — bounded poll on `status`; stall heuristic; `cancel` on stall/cap; normalize companion `done` → `completed` | — (synthesis has **no** clarification channel) |
| **Read return** | `sf_codex_result` — extract the fenced `{mode,…}` JSON tail; validate `.mode` exists | judge a `failed` return; decide re-dispatch |
| **Validate output** | *(existing, backend-agnostic)* `sf_synth_assert_sections`/`_no_markers`/`validate_cited` (derivation) · `sf spec_validate` + backup/restore (MASTER-SPEC) · `sf_render_executive_summary_from_synthesized` write-back guard (EXEC-SUMMARY) | judge re-dispatch on validation fail |
| **Router files** | *(existing, mechanical — NEVER on the Codex path)* `sf_claude_md_generate` · `sf_claude_settings_generate` · `sf_agents_md_generate` | — |
| **Config** | `sf_backend_resolve` (override > manifest `.synthesizer_backend` > `claude_subagent`) + new `sf_manifest_get` | — |
| **Target root** | `sf_codex_target_root` — repo root containing the artifact's output path (so `sandbox=workspace-write` covers the write) | — |

Every synthesis artifact maps to one or more rows; the **Validate output** and **Router files** rows are
unchanged from today and run regardless of backend.

## 3. Per-component design

### 3.1 Invocation — direct call via `lib/codex.sh` (port SS-5's adapter)
A new lib, auto-discovered by `bin/sf` (which runs `set -euo pipefail` and sources every `lib/*.sh`).
Helpers are dispatched as `sf codex_<verb>` in skill prose (a fresh skill shell sources no libs — only
`bin/sf` does; SS-4 lesson). Port `scaffold-dev/lib/codex.sh` verbatim where backend-agnostic
(`_sf_codex_version_gt`, `_sf_codex_mtime`, the resolve/wait/result spine), `sd_`→`sf_`; **drop** the
implementer-only legs (`verify_nocommit`, all worktree management).

**Companion resolution** is identical to SS-5: honor `SCAFFOLD_CODEX_COMPANION` override first; else glob
newest `~/.claude/plugins/{cache,marketplaces}/openai-codex/codex/*/scripts/codex-companion.mjs`
(version-aware via `_sf_codex_version_gt`, **not** `sort -V`); fail-loud + remediation if absent. The
companion is the **same external dependency** SS-5 wraps.

### 3.2 Access — non-interactive full-access; trust targets the artifact's repo root
`task --write` maps to `approval=never` + `sandbox=workspace-write`. Unlike SS-5 (which trusts a *worktree*),
synthesis writes to **manifest-routed output paths**, so `sf_codex_preflight <target-root>` verifies the
artifact's **repo root** against a trusted root in `~/.codex/config.toml` (path-prefix based). **Dual-repo
note:** governance docs route some artifacts to *canonical* (PRD/SRS/BACKLOG) and some to *ai_workspace*
(process ADRs); memory-bank routes to *ai_workspace*; MASTER-SPEC/EXEC-SUMMARY route to *ai_workspace*.
Pre-flight therefore runs **per-artifact against that artifact's `sf_codex_target_root`**, and each target
repo must be Codex-trusted. `workspace-write`, not `danger-full-access` (synthesis is local file authoring,
no network).

### 3.3 Liveness — background + poll, **no gaps-mode**
`task --background` → job-id immediately; `sf_codex_wait` polls `status --json` (default `--poll 45`s) with a
**stall heuristic** (job-log mtime unchanged for `--stall 300`s → hung) and a **wall-cap** (`--cap 1200`s);
on stall/cap → `cancel` + one confirming `status` read. Terminal tokens: `completed`/`failed`/`cancelled`/
`stalled`/`capped`/`error` (`done` from older companion payloads normalized to `completed`). **`sf_codex_wait`
always returns rc=0** (non-throwing — the highest-risk `set -e` surface; ported intact from SS-5).

**No clarification channel.** Synthesis is not a Mode-B implementer with a `gaps-surfaced` return — the
`synthesis-agent` contract is `complete | failed`. A Codex synthesis that cannot satisfy the brief ends with
`{mode:"failed",reason:…}` (or yields a `completed` artifact that fails post-validation). Both route to the
existing **re-dispatch-once → hard-fail** path (§3.5), not to a gaps-mode decision loop.

### 3.4 Return contract — reuse the synthesis-agent shape (prompt-instructed)
`task` exposes no `--output-schema`, so the contract is **prompt-instructed**: the assembled prompt (already
authored by `sf_synth_brief_assemble` / `sf_synth_master_spec_prompt`, both of which end with "return the
ID-ledger JSON described in your agent contract") instructs Codex to end its turn with a fenced
`{mode, output_path, ids_minted, ids_cited, summary}` block — the **exact** shape the Claude `synthesis-agent`
returns. `sf_codex_result` reads `result <job-id> --json`, extracts the **last** fenced JSON block from
`storedJob.result.rawOutput` (leading reasoning prose tolerated), and echoes the object after validating
`.mode` exists. A turn with no parseable block → re-dispatch-once → hard-fail.

### 3.5 Output validation — reuse the existing post-synthesis validators (no no-commit, no worktree)
SS-5's `verify_nocommit` and worktree management are **dropped**: the synthesized artifact is the deliverable,
written in place. Validation is the synthesis path's **existing, backend-agnostic** logic, run by the skill
*after* the dispatch returns, identically for Claude and Codex:

- **Derivation docs (memory-bank §13, governance §11):** `sf_synth_ledger_merge` (thread `ids_minted` into the
  running ledger) → `sf_synth_assert_sections` → `sf_synth_assert_no_markers` → `sf_synth_validate_cited`. On
  `mode:failed` **or** any validator failure → re-dispatch that artifact **once** with a corrective note →
  else `sf_log_error` + stop (no deterministic fallback — SS-7). The `03-code-patterns` mcrules
  `preserve-zone` extract/reinject brackets the dispatch and is backend-agnostic.
- **MASTER-SPEC (onboarding §8):** `sf spec_validate "$master"`; on fail → restore `$master_bak` (or `rm` for
  true first-author) + state-preserved `status=close_pending`; on pass → `architect-critic:critiquing-spec`
  close gate (runs in Claude on the file Codex wrote — applied edits may re-trigger `sf spec_validate`).
- **EXEC-SUMMARY (onboarding §8):** `sf_render_executive_summary_from_synthesized` mechanical write-back guard
  (rejects interior `##`/`---`/phase-markers that would truncate MASTER-SPEC's pinned section).

### 3.6 Router-file boundary — the load-bearing constraint (SS-7 §2/§4)
Three artifacts MUST stay **mechanical** and MUST NEVER be synthesized on the Codex path: **`CLAUDE.md`**
(`sf_claude_md_generate` — composition gates + the conditional Karpathy section per
`phase_10.4.include_karpathy`), **`.claude/settings.json`** (`sf_claude_settings_generate` — security-sensitive
permission seed), **`AGENTS.md` Codex section** (`sf_agents_md_generate` — manifest-routed managed block +
user-content preservation). These are structured router/config files, not prose — they require deterministic
control no synthesis agent (Claude *or* Codex) has. The existing guard
`test_claude_md_mechanically_generated_not_synthesized` enforces this for the Claude path; SS-5.1 keeps it
green and adds a **parallel guard** asserting the Codex branch routes none of the three through
`codex_dispatch` and that the three mechanical generators remain unconditional post-synthesis.

### 3.7 Config — manifest default + per-invocation override
`sf_backend_resolve [--backend <override>]` resolves precedence **override > `.workspace/pairing.json`
`.synthesizer_backend` > `claude_subagent`**. scaffold-onboard has `sf_discover_manifest` (finds the manifest)
but **no field reader** — SS-5.1 adds `sf_manifest_get <jq-filter>` (new `lib/manifest.sh`, mirroring
`scaffold-dev/lib/manifest.sh`): read-with-default, rc=1 on absent field/manifest, **set-e-safe** (the absent
read must not abort under `bin/sf`'s `set -euo pipefail`). **Read-with-default only — zero workspace-init
touch** (the field is optional; seeding it into the manifest schema is a separate change, out of scope).
Backward-compatible: manifests lacking the field resolve to `claude_subagent`. A workspace may set
`.synthesizer_backend` and `.implementer_backend` independently.

### 3.8 Unavailable — hard-fail + remediation
`sf_codex_preflight` runs **before** each dispatch; if Codex is unresolvable / not installed / not authed /
target-root untrusted → **hard-fail with an actionable remediation string** naming the failed gate (install /
`codex login` / `SCAFFOLD_CODEX_COMPANION` override / add the target repo to trusted roots). **No silent
fallback to Claude** — the user explicitly chose Codex; quietly running Claude would violate intent. This
matches the program's fail-loud / no-silent-skip discipline. (Orthogonal: onboarding §8 already documents a
*host-does-it-inline* fallback for the no-Task-tool case — that is a different mechanism and is untouched.)

### 3.9 The seam rewrites — branch the dispatch only
The prompt assembly and the post-validation (§3.5) stay shared and backend-agnostic; only the dispatch is
wrapped:

```bash
backend="$(sf backend_resolve)"
prompt="$(sf synth_brief_assemble …)"   # or sf synth_master_spec_prompt … (MASTER-SPEC) — UNCHANGED
if [[ "$backend" == "codex" ]]; then
  target_root="$(sf codex_target_root "$out")"
  sf codex_preflight "$target_root"                 # hard-fail; NO Claude fallback
  pf="$(mktemp …)"; printf '%s' "$prompt" > "$pf"   # temp OUTSIDE any output tree
  job="$(sf codex_dispatch "$target_root" "$pf")"; rm -f "$pf"
  term="$(sf codex_wait "$target_root" "$job")"
  result="$(sf codex_result "$job")"                # {mode, output_path, ids_minted, ids_cited, summary}
else
  Task(subagent_type="scaffold-onboard:synthesis-agent", model="claude-sonnet-4-5", prompt="$prompt")
fi
# SHARED post-processing (§3.5) — IDENTICAL for both backends; stays OUTSIDE the branch.
```

- **Derivation seam (memory-bank §13 ×8, governance §11 ×5/14):** uniform — one `sf_synth_brief_assemble`
  feeds both branches; the `sf_synth_assert_*` trio + ledger threading run regardless of backend; the
  `03` preserve-zone bracket is unchanged.
- **Onboarding seam (§8, two sites):** bespoke but the same adapter. **MASTER-SPEC** — prompt via
  `sf synth_master_spec_prompt` (file-based digest; the `asm_rc` + digest-failure hard-stop guards stay);
  post = `sf spec_validate` + backup/restore + architect-critic close gate (all outside the branch).
  **EXEC-SUMMARY** — prompt via `sf synth_brief_assemble`; post = the write-back guard.
- Within a wave, Codex artifacts dispatch **sequentially** (governance waves are ID-dependency-ordered
  anyway; the 8 independent memory-bank artifacts dispatch sequentially in v1 to avoid companion
  same-session races; §7). All snippets use the `sf codex_*` dispatcher form — **no bare `sf_codex_*`**.

### 3.10 State-coupling invariants (load-bearing)
The companion keys job state by `sha256(realpath(git-toplevel-of-cwd))` under `${CLAUDE_PLUGIN_DATA}` (or
`os.tmpdir()/codex-companion` when unset). Two invariants follow: **(a)** every helper `cd`s into the
artifact's `target_root` before any `node` call (so `status`/`result`/`cancel` find the job dispatched
there); **(b)** `CLAUDE_PLUGIN_DATA` must be stable across dispatch and all poll calls (never mutated
mid-sequence). Tests pin it (the `_helpers.sh` `setup_tmp_*` already export a stable one). The dispatch
prompt-file lives **outside** any routed output tree and is removed after dispatch (SS-5 lesson: temp inputs
must not pollute the authored output).

## 4. Build sequence (inline TDD — RED→GREEN per unit)

Inline TDD (single coherent authorship — the work centres on one ported `lib/codex.sh` with the known
`set -e` sharp edge), per `feedback_subagent_vs_inline_threshold` and the SS-5 precedent.

- **W1** — `lib/manifest.sh` `sf_manifest_get` + tests (smallest; unblocks backend).
- **W2** — `lib/backend.sh` `sf_backend_resolve` + `tests/test-backend.sh` (incl. the `set -e` regression
  guard through `bin/sf`).
- **W3** — `tests/fixtures/codex-shim/codex-companion.mjs` (port scaffold-dev's env-driven fake; canned
  synthesis-shaped `result.rawOutput` = `{mode:complete, output_path, ids_minted, ids_cited, summary}`;
  knobs `SCAFFOLD_CODEX_COMPANION`/`CODEX_SHIM_FAIL`/`_NO_JOBID`/`_STATUS[_RAW]`/`_RESULT_RAWOUTPUT`) +
  `tests/test-codex.sh` skeleton (auto-discovered).
- **W4** — `lib/codex.sh`: `sf_codex_resolve_companion`, `sf_codex_target_root`, `sf_codex_preflight`,
  `sf_codex_dispatch`, `sf_codex_wait`, `sf_codex_result` (+ ported `_sf_codex_version_gt`/`_mtime`/`_cancel`).
  **All tested through `bin/sf`.**
- **W5** — derivation seam rewrite (`scaffolding-memory-bank §13` + `scaffolding-governance-docs §11`) +
  extend `tests/test-synthesis-dispatch.sh` (backend-branch present, shared-prompt, hard-fail, router-file
  guard).
- **W6** — onboarding seam rewrite (`onboarding-project §8` — MASTER-SPEC + EXEC-SUMMARY sites, each keeping
  its pre/post logic outside the branch) + extend `tests/test-synthesis-dispatch.sh` (onboarding
  post-validation-preserved guard).
- **W7** — bump both `plugin.json` 0.8.0→0.9.0 + CHANGELOG v0.9.0 + dual-publish parity; author this spec's
  ledger updates (SPEC §5/§6) and file the SS-5.1 issue.

Serial edges: W1→W2, (W2,W3)→W4, W4→W5→W6, W6→W7.

## 5. Verification

- **Mocked companion, always.** `SCAFFOLD_CODEX_COMPANION` points every test at the fake shim — **no real
  Codex, no network.** Argv recorded so tests assert `--write` / `--background` / `--prompt-file <abs>` /
  `cancel` were passed. `codex_*` tests skip-guard with a loud notice when `node` is absent.
- **Dispatcher-path mandatory.** Every `sf_codex_*` helper is exercised through `bash bin/sf codex_<verb>`
  — not just sourced in-process. `sf_codex_wait` gets an explicit dispatcher-path regression test for
  status=failed (non-throwing) + stuck→cancel (the SS-4 `set -e` class).
- **Per-helper cases:** resolve (override / glob-newest / absent-fail+remediation); target_root (artifact in
  ai_workspace vs canonical → correct repo root); preflight (ready→0, unauthed→1+`codex login`,
  untrusted-target-root→1); dispatch (job-id echoed, flags logged, prompt-file outside any output tree);
  wait (`completed`→0, legacy `done`→`completed`, failed→0 non-throwing, bad options→`error`+rc0,
  stuck+tiny-stall/cap→cancel-invoked, GNU `stat -c %Y` before BSD `stat -f %m`); result (complete + failed +
  prose-before-fence + multi-fence→last + no-fence→fail + fence-without-`.mode`→fail);
  backend_resolve (absent→default, field→codex, override beats manifest, missing `--backend` value→rc2,
  no-manifest→default+rc0, invalid→rc1 fail-loud, **set -e guard**).
- **Seam-prose lints (test-synthesis-dispatch.sh):** §13/§11/§8 each carry a `sf backend_resolve` branch and
  source `lib/backend.sh`/`lib/codex.sh`; the Codex branch hard-fails (no Claude fallback); **router-file
  guard** (CLAUDE.md/settings.json/AGENTS.md never routed through `codex_dispatch`; the three mechanical
  generators stay unconditional); shared-prompt (one assembler call per site feeds both branches); onboarding
  post-validation (`sf spec_validate` + backup/restore + architect-critic; write-back guard) stays outside the
  branch.
- **Full scaffold-onboard suite green** (`cd scaffold-onboard && bash run-tests.sh`) after each work item —
  run the whole suite; the suites are slow (55–75s+ each — background + generous timeouts), distrust
  "pre-existing failure" claims.
- **Dual-publish parity** (`bash tests/test-codex-dual-publish.sh` from repo root) **after** the version bump.
- **Mock E2E:** with the fake companion + a temp manifest `.synthesizer_backend=codex`, run one
  memory-bank artifact dispatch; assert the artifact lands at the routed path, the validators pass, and
  CLAUDE.md/settings.json/AGENTS.md were emitted by the mechanical generators.
- **Adversarial holistic-review Workflow** over the full diff: lenses for (a) `set -e`-safety through
  `bin/sf`, (b) **router-file-boundary conformance**, (c) **companion-fidelity with one lens running a LIVE
  Codex synthesis** end-to-end (the mock cannot prove field-path fidelity), (d) spec-conformance +
  ledger-threading; skeptic-per-finding filter.
- **Real-Codex smoke (manual, post-merge, operator-run, NOT in CI):** a throwaway workspace,
  `.synthesizer_backend=codex`, real Codex authed + target repo trusted → run `/scaffold-docs` (or
  `/scaffold-project`); confirm a real Codex synthesis writes a valid artifact passing the validators, an
  early failure surfaces within a poll interval (not a 20–30 min block), and the router files stay mechanical.

## 6. Unavailable behavior & failure modes

The Codex synthesizer dispatches an **external async process** that can be absent or hang. Behaviors:
**unavailable** → pre-flight hard-fail + remediation (§3.8); **stall** (no log progress for `--stall`) →
cancel → treated as a failed synthesis → re-dispatch-once → hard-fail; **wall-cap** exceeded → cancel →
same; **`mode:failed` / malformed-or-no-JSON return** → re-dispatch-once → hard-fail; **validation failure**
(missing section, stray marker, uncited ID) → re-dispatch-once → hard-fail; **MASTER-SPEC validation
failure** → restore last-valid backup (or `rm` for first-author) + `status=close_pending`. There is **no
gaps-mode** — synthesis either completes-and-validates or fails. Every mechanical leg **fails loud with
actionable remediation**, never silently skips, and **never falls back to Claude** (the user chose Codex).
No deterministic content fallback exists (SS-7).

## 7. Out of scope (explicit non-goals)

- **`planning-project-roadmap`** — interactive user-authoring, not a synthesis dispatch; a *class boundary*,
  not a deferral (there is no sub-agent to swap).
- **Router-file synthesis** — CLAUDE.md / `.claude/settings.json` / AGENTS.md stay mechanical (§3.6); the
  Codex path authors no router files. The SS-7 §4 boundary is the binding constraint, not a non-goal.
- **workspace-init manifest seeding** of `.synthesizer_backend` → read-with-default only; seeding the field
  into the pairing schema is a separate workspace-init change.
- **Parallel multi-job Codex synthesis** — one job per artifact, sequential within a wave (avoids companion
  same-session races); accept slower wall-clock in v1.
- **`danger-full-access` / network sandbox**; **cross-session job persistence** beyond a single
  re-dispatch-once.

## 8. Packaging

One `scaffold-onboard` **minor** bump (new optional backend = feature-level): `0.8.0 → 0.9.0` in **both**
`.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` (dual-publish parity). CHANGELOG entry. File the
SS-5.1 issue and close it on merge. Program-spec ledger (`SPEC-agent-driven-program.md` §5/§6) updated to add
SS-5.1 and mark it shipped. Tag `scaffold-onboard-v0.9.0` on the merge commit.
