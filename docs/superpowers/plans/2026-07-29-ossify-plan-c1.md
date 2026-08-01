# ossify Plan C1 — Execution Engine + Close Ceremonies

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the half of ossify that makes *"the product still runs"* a checked fact — the work-item execution port, the per-work-item verification gate, the cumulative-demo runner, and the `close` router (work item → spine bone/flesh → release) — on top of the Plan A/B state engine and planning skills.

**Architecture:** Two new entry skills (`work-item`, `close`) as ceremony prose (SKILL.md ≤~500 lines + `references/*.md` progressive disclosure + thin `commands/*.md` wrappers) over an extended `oss` bash dispatcher. Every close row that is a *mechanical fact* (did the demo pass, is a fake expired, is a pending amendment outstanding, did every work item close) lands in a tested lib function; every close row that is a *judgment* (is this finding veto-grade, is this fake renewal honest, is this retro true) stays in prose and is eval-gated. `_oss_apply_op` remains the single pure-jq transform shared by mutate and replay; every new op lands there and only there.

**Tech Stack:** bash (BSD/macOS-compatible), jq, git. Markdown skills. No new dependencies.

## Global Constraints

*(Plan B's block, carried forward with two corrections marked ⚠, plus Plan C1 additions. Every task's requirements implicitly include this section.)*

- **Specs of record:** `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` — §9.2 state-safety commitments are **BINDING**; **Plan C1 scope = §6, §6.1, §6.2** plus the Plan-C items owed by `.superpowers/sdd/FINAL-REVIEW-2026-07-26.md`. §7–§8 (ADR lifecycle, docs increment, utility commands, `/handoff` v2) are **Plan C2 — out of scope here**. Companion `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` §4.2/§4.3 shape the close ceremony but multi-repo execution is **Plan D**: C1 must leave the repo dimension *extensible* (work items already carry `target_repo`) without building cross-repo worktrees or dependency overrides. Doctrine: `docs/conventions/evolutionary-architecture-playbook.md`.
- **Strict mode.** The dispatcher runs `set -euo pipefail`; every lib function must survive it — guard all no-match greps with `|| true`, guard bare `x="$(cmd)"` that can fail (especially anything between lock-acquire and lock-release: an unguarded failure there leaks the lock permanently), and **test through the dispatcher path, not only by sourcing**. Tests source libs *without* `set -e`, so strict-mode-only faults are structurally invisible to a sourced-only test.
- ⚠ **The `pipeline | { … return N; }` trap — this bit the plan itself, twice, and was caught pre-dispatch.** `lib/id.sh:4-6` and `lib/demo.sh:5,8` write validators as `printf … | { grep -Eq … || return 1; }`. That is safe **only** because the pipeline is the function's *last* command, so the function's exit status is the pipeline's. In any function that has more to do afterwards, the brace group is the last element of a pipeline and runs in a **subshell**: `return N` exits the subshell, execution falls through, and the function returns whatever comes next — typically `return 0`. Two functions drafted for this plan were silently broken this way (a zero-tests guard that reported *every* input as vacuous, and a `contains` check that passed on non-matching output). Use `pipeline || return N` or `if ! pipeline; then … fi`. The same subshell rule loses accumulator variables: never write `cmd | { …; var=x; }` and expect `var` to survive — grep the file directly or use `< <(process substitution)`. **This class is invisible under zsh**, which runs the last pipeline element in the parent shell, so it must be checked under `bash`.
- **BSD/macOS portability:** `date -u +%Y-%m-%dT%H:%M:%SZ` (no GNU flags); `mkdir`-based locks; no `readarray`, no `grep -P`. `run-all.sh` runs each file under `bash` (zsh errexit/NOMATCH differs) — keep it.
- **ID grammar (single owner, `lib/id.sh`):** release `r<N>`, spine `r<N>.s<K>`, work item `r<N>.s<K>.w<J>`; branch `spine/<spine-id>-<kebab-slug>`; release dir `docs/specs/<release-id>/`; demo-line ids `d<N>` from `.counters.demo_line`. No `VS-` shapes.
- **`_oss_apply_op` ops MUST be pure deterministic jq transforms** (both mutate and replay route through them). IDs/timestamps are minted by the caller and baked into the payload *before* journaling so replay reproduces them verbatim. Every new op is added additively as a pure jq case and covered by a replay round-trip test.
- **rc taxonomy (do not introduce overlapping codes):** 1 generic, 2 usage, 3 lock, 4 apply-failure, 5 drift, 6 schema, 7 unknown-ref. **Plan C1 extends it once, deliberately: 8 = git/worktree operation failure** (Task 4). A git failure is not "generic" — the close ceremony has to distinguish "this worktree is dirty, halt and surface" from every other rc 1 — and overloading 1 is exactly the overlap the taxonomy exists to prevent. No further codes without the same justification.
- **All state functions take the state-file path as their FIRST argument.** Skills resolve it via `_oss_resolve_state` (explicit > `$OSS_STATE_FILE` > manifest). Canonical location `<ai_workspace>/.ossify/project-state.json`.
- ⚠ **Skill conventions — CORRECTED from Plan B's block.** Skill directories are **bare-verb, matching the §9.1 entry-skill name** — the shipped tree is `skills/start/`, `skills/plan-release/`, `skills/plan-spine/`, and C1 adds `skills/close/` and `skills/work-item/`. (Plan B's constraint block said "gerund skill dirs (`starting-project`, `planning-release`, …)"; that was overridden during B6–B8 execution per spec §9.1 and **never happened** — do not reintroduce it.) SKILL.md frontmatter is `name` + `description` only, the description embedding trigger phrases + slash token + a negative-scope clause. Depth goes to `references/*.md` behind a "Full X in `references/<f>.md`" pointer. Thin `commands/<short>.md` wrappers use the `ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '...'` env-var bridge (**never** positional `$1`/`$2`) then a bare `Skill(ossify:<name>)`. **SKILL bodies ≤~500 lines** — `plan-spine` is at 499 and `start` at 499, so there is zero headroom in existing files: any edit to them needs a trim in the same commit.
- **ossify is NOT registered** in `.claude-plugin/marketplace.json` and gets **no** `.codex-plugin` manifest in Plan C1 (ship gate is Plan D). Early registration also breaks `tests/test-codex-dual-publish.sh`, which needs a `V0_PLUGINS` entry + a Codex manifest.
- **architect-critic gains no new interface** (§12). The critic veto (§5.2.3) and bone-touch check (§6.1) are implemented plugin-side by interpreting standard findings. **The only supported invocation form** is `export ARCHITECT_CRITIC_ARGS="--spec \"<abs path>\" --close"` followed by a bare, plugin-qualified `Skill(architect-critic:critiquing-spec)`. There is no `target=` / `depth=` / `artifact_path=` parameter and **both failure modes are silent** (wrong artifact via a glob fallback; silent degrade to shallow claude-only). Do **not** copy the parameterized grammar shipped in `scaffold-onboard` — that is issue #116.
- ⚠ **Git.** Work on branch `feat/ossify-core` (stacks on Plan A+B). Commit per task with **explicit paths** (`git add ossify/… docs/…`) — **never** `git add -A`; unrelated files live in the tree (`README.md` is the user's own uncommitted edit, dated 07-11 — do not touch it). The trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` is correct here (no commit-msg hook in this marketplace repo; Plan B's block named an older model). Do **not** `git clean -fdx` — it destroys `.superpowers/sdd/progress.md`.
- **Green before done:** `bash ossify/tests/run-all.sh` (ALL GREEN) **and** the repo-root parity suite (`for t in tests/test-*.sh; do bash "$t" || echo "ROOT-FAIL: $t"; done`) **and** `bash ossify/tests/eval/lib/aggregate-scores.sh` (exit 0) before the final task completes.

### Plan C1 additions

- **§6.1 amendment timing — DECIDED 2026-07-29, do not re-litigate.** Demo-line amendments are **spec-faithful**: `ledger_supersede` / `ledger_retire` write a **`pending_status`** at planning time and leave `status` active; `close` applies the pending flip for the closing spine **after merge, before the cumulative demo**, so the demo runs the amended set against a product where the flow really has been replaced. `ledger_quarantine` stays **immediate** — it is a close/doctor-time verb applied when a line actually fails, not a planned amendment. A new `ledger_unplan` clears a pending amendment, which is the escape hatch immediate semantics never had (a replanned or abandoned spine must not permanently drop coverage; there is no `reactivate`). This supersedes the Plan-B-era prose that says amendments apply immediately — **five** prose sites must end up consistent, including `plan-spine/references/demo-amendments.md:4-5`, which still asserts the close-time version and is the site the `a53d034` fix round missed.
- **Standing named risk in EVERY task-review dispatch: "who calls this?"** The final review's verdict on Plan B was *"this branch verified that mechanisms exist. It did not verify that anything CALLS them."* Six of eight findings were producer/consumer wiring. A reviewer that only asks "does this work?" reproduces the defect.
- **Reachable-at-HEAD trigger before any Critical.** Six of seven Plan-B Criticals were demoted on adversarial verification because the reviewer reasoned from binding spec text to harm without checking the harm path exists yet. Half of ossify's consumers are still Plan C2/D.
- **Any verification the implementer performs that guards a behavior this task introduces MUST be committed as a test.** B1, B3 and B7 each needed a fix round for exactly this omission.
- **Prose is the executable artifact, and it has no CI.** When one skill's reference says "X is what skill Y reads", grep Y for the read before believing it (this is the B8 cross-skill contract break). Task 10 builds the structural fix.
- **De-leakage:** no eval-fixture wording in shipped prose. An eval agent reads SKILL.md + `references/`, so a fixture's own phrasing left in the prose turns the eval into a recall test. Strip and re-domain worked examples.
- **Implementer reports are directionally reliable but their counts are not** — three consecutive Plan B reports had count slips. Verify counts against the tree, not the report.

---

## Series map (Plans C2–D, sketched — detailed after their predecessor ships)

*Plan C was split into C1 + C2 on 2026-07-29. The rolling-wave rule applies to our own plans: detail the current one, sketch the next.*

- **Plan C2 — records, evolution + utilities.** Spec §7–§8. The `doctor` entry skill (state inspection, lean-spec validation, machine-checkable-rules authoring, interop check, budget check — the §9.1 routing target); the docs-increment trigger table at release close; the ADR lifecycle completion (`Superseded-by`, `proposed-then-flip` as the bone default) and the architecture-revision lane in `/amend-spec` with mandatory citation re-verification; the eight utility commands (`/handoff`, `/defer`, `/work-pr`, `/adr`, `/flip-adr`, `/amend-spec`, `/changelog`, `/runbook`); `pr_hierarchical` (spine→release PR). **`/handoff` is a redesign, not a port** — `docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md` (issue #113) is approved and its task set is absorbed, not re-derived; it adds two eval surfaces and forces two amendments to the main spec (§8.1's `handing-off-session` row, §9.1's references-live-under-their-entry-skill rule).
- **Plan D — boundary + ship gate.** Companion §4–§6; main §10, §13.4. workspace-init additive extension (visibility fields, `private_core`, all three resolvers, `add-private-core`); multi-repo worktrees + cross-repo dependency overrides; the release-close boundary audit; the consolidated eval suite (**THE ship gate**); marketplace registration + `.codex-plugin` manifest + `V0_PLUGINS`; Forge3D greenfield + pulse-trader adopt-forward pilots.

---

## Design decisions settled before decomposition

These were settled by a port survey of the scaffold-dev/scaffold-onboard source (2026-07-29, 8 readers + a consolidating pass, all claims re-verified against the code). Each one exists because the naive reading — "§8.1 says port it" — is wrong.

**D1. Demo-line amendments are spec-faithful (`pending_status`).** Settled with the user 2026-07-29. See Global Constraints → Plan C1 additions.

**D2. `implementation-checking` is NOT "Unchanged", and C1 ships it WITHOUT a machine-checkable-rule evaluator.** Spec §8.1:388 marks it Unchanged. Its documented entry point **`sd_rules_apply` does not exist** — `scaffold-dev/lib/rules.sh` defines only `_sd_rules_locate` / `rules_load` / `rules_check`, the phantom name is cited five times including the helper index, and the shipped eval recorded PASS over it. The real function covers **one of four** rule families, and on a canonically-authored `banned_imports` rule it returns no violation for two independent reasons (`where` is applied as a path-substring filter when it is a code-context predicate, and `in` — the actual path glob — is read nowhere; `forbid: [a, b]` is stored as the literal string `"[a, b]"` and interpolated into an ERE where `[…]` degrades to a character class). Porting "unchanged" would import a broken feature *and* a cross-plugin coupling. **C1's gate is therefore: `auto:` AC lines (deterministic, halt-on-first-fail) + report cross-check (deterministic) + zero-tests guard (deterministic) + an agent-judged read of `03-code-patterns.md`.** Mechanical rule evaluation lands in **C2**, next to rule *authoring*, where a correct evaluator can be built and tested against real rule blocks. This is the `agent-review-over-deterministic-gates` principle applied exactly where it belongs: keep deterministic checks for mechanical facts, and do not ship a semantic gate that silently passes.

**D3. Disposition triage auto-applies; the source surfaces-and-waits. The spec governs.** `closing-vertical-slice` surfaces and waits at every decision boundary. Spec §6.1 (and the #109 / PR #110 policy) says spec-aligned recommendations **auto-apply** and only load-bearing escalations reach the user. A close skill that auto-applies is a deliberate **behavioral change** from the source, not a port defect — record it as such so a reviewer does not "fix" it back.

**D4. The worktree layer takes a repo parameter from day one.** `target_repo` is written by `oss_entity_add_spine` / `oss_entity_add_work_item` (entities.sh:20,31) and has **zero consumers** at HEAD. The worktree spawn is its first. Multi-repo execution is Plan D, but retrofitting a repo-root parameter later means changing every call site and every path-shape test — so C1's signatures take it now and resolve it to `canonical` until Plan D adds `private_core`.

**D5. One report section set, and it is the template's.** The source has a three-way drift: `executing-work-item/SKILL.md` §6's nine headings ≠ the shipped `templates/implementation-report.md.tmpl` nine headings ≠ the worked reference example, and the evals repeatedly assert content lands in "item 8" — which is *Blockers* in the SKILL and *Suggestions for memory bank* in the template. the template is the better base — it is the only one of the three that is section-numbered and consumer-shaped. (An earlier draft justified this with "`tests/test-render.sh` enforces the template"; **it does not** — `grep -n implementation-report scaffold-dev/tests/test-render.sh` returns nothing, and no test under `scaffold-dev/tests/` references that template at all.) C1 pins one set (Task 7) and the RED-gate advisory and skip-escape override land in sections that exist.

**D6. ossify has no template engine, and will not grow one.** There is no `lib/render.sh` and no `templates/` directory, and there will be none: documents (report, retrospectives) are **authored by the agent against a section contract stated in prose**, exactly as the approved handoff-v2 design decided. This is not laziness — `sd_render_template` truncates multi-line variables to their first line (#114) and every `{{…_block}}` in these documents is multi-line. A section contract has no substitution step and therefore no truncation bug.

**D7. The spine→release / release→main PR tier question is deferred to C2 with the rest of `pr_hierarchical`.** Spec §6.2 step 7 says "spine→release PR replaces slice→sprint PR", but in the source, slice→sprint PRs open at **slice** close while release close's true analogue is the sprint→main PR — two tiers conflated into one line. C1 builds no PR machinery, so C1 does not have to settle it; **C2 must, before writing a line of it.** Related: `pr_hierarchical` has almost certainly never run in anger — workspace-init never writes or validates `.during_dev.merge_mode`, so the mode is unreachable without hand-editing `pairing.json`.

**D8. `harvest_apply`'s idempotency check is rebuilt, not ported.** Issue #115 reports `sd_harvest_apply` returns rc 0 and writes nothing; the report is half true and its stated cause is wrong (the literal repro does not reproduce). The real mechanism is `grep -Fq "$text"` (harvest.sh:171): text containing a **blank line** makes `grep -F` treat it as alternatives one of which is empty, matching everything, so every item skips at rc 0; multi-line text whose *any* line already exists in the seeded template skips; substring text skips. The **inverse** defect is live too — no `--` terminator, so text starting with `-` is consumed as a grep option and the append fires unconditionally, defeating idempotency. C1 uses an **exact-entry comparison** (hash the text into the provenance trailer and match the hash), returns a written/skipped **count**, and the ceremony asserts it. Separately, `harvest.sh:146` hardcodes `$ai_root/.claude/memory-bank` and ignores `.well_known_paths.memory_bank` — the port honors it.

**D9. Port the *intent* of `sd_worktree_remove`, not its code.** The skill prose says it halts on failure (uncommitted changes); the lib retries with `--force`, **discarding uncommitted work**, and swallows the `branch -D` failure with `|| true` — while `closing-vertical-slice` §10.2 asserts as a post-condition that no work-`*` branch remains. C1's remove surfaces and halts; it never force-discards.

## Live defects at ossify HEAD that Plan C1 fixes in passing

Each is small, each is in a file C1 already opens, and each is the kind of thing that becomes expensive once a consumer exists.

1. **`lib/doctor.sh:53` omits `veto_dispositions`** from the shape key list, though `oss_state_init` creates it (`state.sh:23`). Pre-existing drift — Task 1 fixes it while editing that list, and must not repeat the pattern for the keys it adds.
2. **`lib/demo.sh:53`'s vacuous-green guard is unscoped.** It runs after the `case` block on *every* expectation form, so a demo line that legitimately expects `exit:1` from a recognized runner is failed as vacuous green. The source scopes the guard to `exit 0` only. Task 6.
3. **`oss_cmd_critic_detect` (commands.sh:85) returns on the first cache hit** and globs only `critiquing-spec`, so it can never report `v0.3` and a stale `v0.2` directory wins over a newer install. The source scans **all** directories before deciding. Task 3 (the close ceremony's critic row depends on this probe).
4. **`oss_ledger_quarantine` (ledger.sh:50) hardcodes `by="quarantine"`** and records no release, so §6.1's "a quarantined line must be fixed or retired **by the next release close**" is structurally unenforceable. Task 2.
5. **`plan-spine/references/demo-amendments.md:4-5`** still asserts close-time amendment semantics while the same file's §2 and §6, `plan-spine/SKILL.md:380` and `plan-release/SKILL.md:200` all assert immediate — the `a53d034` fix round corrected four sites and missed the fifth. Task 2 makes all five consistent with D1.

---

## File structure

**Extended:** `lib/state.sh` (status-transition + migration ops, schema v2), `lib/ledger.sh` (pending-amendment lifecycle, quarantine provenance), `lib/demo.sh` (repo-rooted runner, `user:` surfacing, close records), `lib/doctor.sh` (shape list, pending/quarantine/expiry visibility), `lib/commands.sh` (dispatcher wrappers for everything new), `lib/registries.sh` (fake lifecycle), `lib/id.sh` (work-item branch + spine-dir grammar), `lib/entities.sh` (reject-before-mutate guards for the new status ops).

**New libs:** `lib/worktree.sh` (spawn/resolve/remove/list, repo-parameterized per D4), `lib/verify.sh` (per-AC parse+run+check, RED gate, report cross-check, zero-tests guard), `lib/harvest.sh` (memory-bank writes, exact-entry idempotency per D8).

**New skills:** `skills/work-item/` (SKILL.md + 4 references), `skills/close/` (SKILL.md + 8 references — the split is planned up front because `close` is strictly bigger than slice close: it carries class-scoping, bone-touch, risk-gate escalation, the patch lane and release close, and `plan-spine`/`start` are already at 499/500 with zero headroom).

**New commands:** `commands/work-item.md`, `commands/close.md`.

**New agent:** `agents/implementer-agent.md`. **No manifest change** — agent registration is by directory convention (verified 2026-07-30: the two plugins in this repo that ship `agents/` directories declare no `agents` key).

**New tests:** `tests/test-worktree.sh`, `tests/test-verify.sh`, `tests/test-harvest.sh`, `tests/test-close.sh`, `tests/test-migration.sh`, `tests/test-skill-bash-blocks.sh`, plus extensions to the existing suites.

**New eval surface:** `tests/eval/{fixtures,rubrics}/close-gate-integrity/` — 5 fixtures taking the gate from 23 to 28.

## Task DAG

```
Round 1 (state layer — strictly sequential, all three touch state.sh)
  T1 schema v2 + status transitions + migration
   └→ T2 pending-amendment lifecycle + quarantine provenance + fake lifecycle
       └→ T3 state_restore + get/manifest/id dispatcher exposure + doctor growth

Round 2 (new libs)
  T4 lib/worktree.sh   ∥   T5 lib/verify.sh
                            └→ T6 lib/demo.sh hardening + close records
                               (consumes T5's zero-tests guard)

Round 3 (skills — sequential; each consumes the previous one's contract)
  T7 work-item skill + implementer-agent          (the CALLEE)
   └→ T8 round orchestration — spawn, handoff, dispatch, loop   (the CALLER)
       └→ T9 close router + work-item close layer (gate → commit → merge work→spine)
           └→ T10 spine close (bone/flesh, cumulative demo, critic, retro)
               └→ T11 release close (walkthrough, fake expiry, quarantine resolution, budget, patch lane)

Round 4
  T12 lib/harvest.sh + the harvest reference under close

Round 5
  T13 SKILL.md bash-block extraction harness
  T14 integration test + close-gate-integrity eval surface + budget re-measure
```

**The branch lifecycle, stated once because it spans four tasks and the plan review found it broken end to end:**
`spine/<spine-id>-<slug>` is **cut and checked out** in canonical once by **T8** before round 1, and canonical stays parked on it for the duration of the spine. Each work item's `work/<wi-id>-<slug>` is cut from it (T8, via `oss worktree_add`'s base-ref argument), committed by **T9** once its gate passes, and merged **back into the spine branch** by T9 — which works only because canonical is checked out there, and which is what makes the branch delete in `oss_worktree_remove` safe. **T10** switches canonical back to the base branch T8 recorded and merges the spine branch into it *before* running the cumulative demo, so the demo measures a tree that actually received the work.

**Break any one link and the failure is a green demo measuring the wrong tree.** Precisely: `worktree_remove` uses `git branch -d` and refuses an unmerged branch (rc 8), so commits are *not* destroyed — instead spine close halts at step 10, after the cumulative demo has already reported green. And if the merges land on the wrong branch rather than no branch, `-d` succeeds and even the halt disappears. **The checkout in T8 step 1.1 is the load-bearing link**: `git branch` alone creates the ref without moving HEAD, and every downstream merge then targets whatever canonical happened to be on. Verified empirically 2026-08-01 against the real libs — see the boxed note in Task 8.

---

### Task 1 (C1-1): Schema v2 — lifecycle status transitions, execution fields, and the first real migration

**Context:** `_oss_apply_op`'s vocabulary is **create-only**. All 16 ops either set a `project.*` scalar or append to an array; `oss_entity_add_spine` / `add_work_item` / `add_release` stamp `status: "planned"` (entities.sh:8,20,31) and **no op ever changes it**. Close cannot close anything. This task adds the transitions, the execution fields the worktree layer will write, and — because a new top-level array is a schema change and §9.2 binds "an explicit migration policy for every subsequent schema change" — the first real migration. The migration registry at `state.sh:248` is currently an empty comment; leaving it that way is the built-but-unwired shape the final review named.

**Files:**
- Modify: `ossify/lib/state.sh` (schema constant, init skeleton, 5 new ops, version guard, mutate gate)
- Modify: `ossify/lib/entities.sh` (4 reject-before-mutate wrappers)
- Modify: `ossify/lib/commands.sh` (5 dispatcher wrappers)
- Modify: `ossify/lib/doctor.sh:53` (shape list)
- Modify: `ossify/tests/test-state-core.sh:9` (asserts `schema v1` — will break)
- Create: `ossify/tests/test-migration.sh`
- Modify: `ossify/tests/test-entities.sh`, `ossify/tests/test-state-replay.sh`, `ossify/tests/test-dispatcher-ops.sh`

**Interfaces:**
- Produces: `oss_entity_set_spine_status <state> <spine-id> <status>` (`planned|active|closed|abandoned`); `oss_entity_set_work_item_status <state> <wi-id> <status>` (`planned|active|complete`); `oss_entity_set_release_status <state> <rel-id> <status>` (`planned|active|closed`); `oss_entity_set_work_item_exec <state> <wi-id> <branch> <worktree-path> <base-sha>`; `oss_cmd_migrate [state]`. Dispatcher: `oss spine_status`, `oss work_item_status`, `oss release_status`, `oss work_item_exec`, `oss migrate`.
- Consumes: `oss_state_mutate` (4-arg form, no mint spec), `_oss_now`, `_oss_resolve_state`.

- [ ] **Step 1: Write the failing tests** — create `ossify/tests/test-migration.sh`:

```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

# A GENUINE v1 state, hand-built — NOT a fresh `oss init`, which now emits v2.
# Testing migration against a freshly-derived state proves nothing: the
# upgrade-input class of bug only shows up when the input is legacy-shaped.
V1="$TMP/v1.json"
jq -n '{schema_version:1,
  project:{name:"legacy",posture:null,composition_root:null,overlay_wiring:null},
  counters:{demo_line:0},
  releases:[],spines:[],work_items:[],demo_ledger:[],bones:[],risk_gates:[],fakes:[],
  feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],mutations:[]}' > "$V1"
cp "$V1" "$V1.base.json"

# A v1 state is REFUSED for mutation until migrated — never silently upgraded.
export OSS_STATE_FILE="$V1"
t_capture "$OSS" posture_set fully-private
t_assert_rc 6 "dispatcher: mutating a v1 state is refused rc 6"
t_assert_contains "$T_OUT" "oss migrate" "the refusal names the migration command"

# doctor says the same thing rather than reporting ok.
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "fail: schema" "doctor reports the stale schema"

# Migration is explicit, journaled, and idempotent.
t_capture "$OSS" migrate
t_assert_rc 0 "migrate v1 -> v2 ok"
t_capture "$OSS" get '.schema_version'; t_assert_eq "2" "$T_OUT" "schema is v2 after migrate"
t_capture "$OSS" get '.close_records | length'; t_assert_eq "0" "$T_OUT" "close_records seeded empty"
t_capture "$OSS" migrate
t_assert_rc 0 "re-migrating an already-current state is a no-op, not an error"
t_assert_contains "$T_OUT" "already at v2" "no-op migrate says so"

# THE POINT: replay must still be clean. base.json is v1, the journal now ends
# with migrate_schema, and base+journal must rebuild the v2 live state exactly.
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "ok: replay" "replay is clean across the migration boundary"
t_capture oss_state_read "$V1.base.json" '.schema_version'
t_assert_eq "1" "$T_OUT" "the base snapshot is NOT rewritten — the migration is journaled, not retroactive"

# A migrated state accepts normal mutations again.
t_capture "$OSS" posture_set fully-private
t_assert_rc 0 "post-migration mutation ok"

# A FUTURE schema is still refused, and is NOT offered a migration.
FUT="$TMP/fut.json"; cp "$V1" "$FUT"; cp "$V1.base.json" "$FUT.base.json"
jq '.schema_version = 99' "$FUT" > "$FUT.x" && mv "$FUT.x" "$FUT"
export OSS_STATE_FILE="$FUT"
t_capture "$OSS" migrate
t_assert_rc 6 "migrate refuses a state newer than the build"
t_assert_contains "$T_OUT" "newer" "the refusal says the state is newer"

rm -rf "$TMP"
t_summary
```

Run: `bash ossify/tests/test-migration.sh`
Expected: FAIL — `oss: unknown subcommand 'migrate'`, and the v1 state mutates at rc 0.

- [ ] **Step 2: Bump the schema and add the ops** — in `ossify/lib/state.sh`, change line 5 to `OSS_STATE_SCHEMA_VERSION=2`, add `close_records:[]` to the init skeleton (after `patch_records:[]`), and add these cases to `_oss_apply_op` immediately before the `*)` arm:

```bash
    # Status transitions. Each is a pure jq assignment through a select(), which
    # is a NO-OP on a non-matching id (jq assigns to an empty path expression and
    # exits 0). That silent no-op is exactly finding 7's `class_set` bug shape, so
    # the reject-before-mutate guard in entities.sh is load-bearing, not defensive
    # decoration - it is the ONLY thing that turns a typo'd id into rc 7.
    set_spine_status)
      jq --argjson p "$payload" '(.spines[] | select(.id == $p.spine) | .status) = $p.status' ;;
    set_work_item_status)
      jq --argjson p "$payload" '(.work_items[] | select(.id == $p.work_item) | .status) = $p.status' ;;
    set_release_status)
      jq --argjson p "$payload" '(.releases[] | select(.id == $p.release) | .status) = $p.status' ;;
    set_work_item_exec)
      jq --argjson p "$payload" '
        (.work_items[] | select(.id == $p.work_item)) |=
          (.branch = $p.branch | .worktree_path = $p.worktree_path | .base_sha = $p.base_sha)' ;;
    # §9.2's migration registry, realized. Pure and TOTAL: replay re-applies it
    # from the v1 base snapshot, so base+journal still rebuilds live exactly and
    # the base is never rewritten. `has(...)` keeps it idempotent under replay.
    migrate_schema)
      jq --argjson p "$payload" '
        (if has("close_records") then . else . + {close_records:[]} end)
        | .schema_version = $p.to' ;;
```

- [ ] **Step 3: Teach the version guard about stale states** — replace the migration-registry comment block at `state.sh:248-250` (the `return 0` tail of `oss_state_check_version`) with:

```bash
  # A state OLDER than this build is refused too, and told what to run. Silently
  # operating on a v1 state with v2 semantics is the same class of failure as
  # operating on a v99 one - §9.2 binds "an explicit migration policy ... never
  # silent" in both directions. The refusal names the command so the operator's
  # next move is `oss migrate`, not deleting the state file.
  if [ "$v" -lt "$OSS_STATE_SCHEMA_VERSION" ]; then
    echo "state schema v$v predates this build (v$OSS_STATE_SCHEMA_VERSION) - run 'oss migrate' to upgrade it" >&2
    return 6
  fi
  return 0
```

- [ ] **Step 4: Let the migration through its own gate** — in `oss_state_mutate`, replace the schema-guard block (currently `state.sh:124-126`) with:

```bash
  # `migrate_schema` is the ONE op that must run against a state this build's
  # guard would otherwise refuse - gating it would make the migration
  # unreachable and wedge every v1 project permanently. Still placed BEFORE
  # `mkdir "$lock"`: a `return 6` after the lock jumps past the unconditional
  # `rmdir` below and wedges the state file.
  if [ "$op" != "migrate_schema" ] && jq -e . "$sf" >/dev/null 2>&1; then
    oss_state_check_version "$sf" || return 6
  fi
```

- [ ] **Step 5: Add the entity wrappers** — append to `ossify/lib/entities.sh`. Each validates the enum (rc 2) **and** rejects an unknown id before mutating (rc 7), matching `oss_entity_add_veto`'s established shape:

```bash
oss_entity_set_spine_status() { # $1=state $2=spine-id $3=status
  local sf="$1" spine="$2" st="$3"
  case "$st" in planned|active|closed|abandoned) ;; *)
    echo "oss: spine status must be planned|active|closed|abandoned" >&2; return 2;; esac
  jq -e --arg s "$spine" '.spines[] | select(.id == $s)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  oss_state_mutate "$sf" set_spine_status \
    "$(jq -n --arg s "$spine" --arg st "$st" --arg ts "$(_oss_now)" '{spine:$s,status:$st,at:$ts}')"
}

oss_entity_set_work_item_status() { # $1=state $2=work-item-id $3=status
  local sf="$1" wi="$2" st="$3"
  case "$st" in planned|active|complete) ;; *)
    echo "oss: work item status must be planned|active|complete" >&2; return 2;; esac
  jq -e --arg w "$wi" '.work_items[] | select(.id == $w)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown work item '$wi'" >&2; return 7; }
  oss_state_mutate "$sf" set_work_item_status \
    "$(jq -n --arg w "$wi" --arg st "$st" --arg ts "$(_oss_now)" '{work_item:$w,status:$st,at:$ts}')"
}

oss_entity_set_release_status() { # $1=state $2=release-id $3=status
  local sf="$1" rel="$2" st="$3"
  case "$st" in planned|active|closed) ;; *)
    echo "oss: release status must be planned|active|closed" >&2; return 2;; esac
  jq -e --arg r "$rel" '.releases[] | select(.id == $r)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown release '$rel'" >&2; return 7; }
  oss_state_mutate "$sf" set_release_status \
    "$(jq -n --arg r "$rel" --arg st "$st" --arg ts "$(_oss_now)" '{release:$r,status:$st,at:$ts}')"
}

oss_entity_set_work_item_exec() { # $1=state $2=wi-id $3=branch $4=worktree-path $5=base-sha
  local sf="$1" wi="$2"
  jq -e --arg w "$wi" '.work_items[] | select(.id == $w)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown work item '$wi'" >&2; return 7; }
  oss_state_mutate "$sf" set_work_item_exec \
    "$(jq -n --arg w "$wi" --arg b "$3" --arg p "$4" --arg s "$5" \
      '{work_item:$w,branch:$b,worktree_path:$p,base_sha:$s}')"
}
```

- [ ] **Step 6: Add the dispatcher wrappers** — append to `ossify/lib/commands.sh`:

```bash
oss_cmd_spine_status()     { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_spine_status "$sf" "$1" "$2"; }
oss_cmd_work_item_status() { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_work_item_status "$sf" "$1" "$2"; }
oss_cmd_release_status()   { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_release_status "$sf" "$1" "$2"; }
oss_cmd_work_item_exec()   { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_work_item_exec "$sf" "$1" "$2" "$3" "$4"; }

# §9.2's explicit, never-silent migration. Journals a `migrate_schema` op rather
# than rewriting the file in place, so `$sf.base.json` stays v1 and replay still
# rebuilds live from base+journal across the version boundary.
oss_cmd_migrate() { # [$1=state-file]
  local sf v; sf="$(_oss_resolve_state "${1:-}")" || return $?
  v="$(jq -r '.schema_version // empty' "$sf" 2>/dev/null)" || v=""
  case "$v" in ''|*[!0-9]*) echo "oss: state schema missing/invalid - cannot migrate" >&2; return 6 ;; esac
  if [ "$v" -eq "$OSS_STATE_SCHEMA_VERSION" ]; then echo "already at v$v"; return 0; fi
  if [ "$v" -gt "$OSS_STATE_SCHEMA_VERSION" ]; then
    echo "oss: state schema v$v is newer than this build (v$OSS_STATE_SCHEMA_VERSION) - upgrade ossify, do not migrate" >&2
    return 6
  fi
  [ "$v" -eq 1 ] || { echo "oss: no migration path from v$v to v$OSS_STATE_SCHEMA_VERSION" >&2; return 6; }
  oss_state_mutate "$sf" migrate_schema \
    "$(jq -n --argjson to "$OSS_STATE_SCHEMA_VERSION" '{from:1,to:$to}')" || return $?
  echo "migrated v1 -> v$OSS_STATE_SCHEMA_VERSION"
}
```

- [ ] **Step 7: Fix doctor's shape list** — `ossify/lib/doctor.sh:53`. The current list omits `veto_dispositions` even though `oss_state_init` creates it (pre-existing drift, `state.sh:23`). Replace the `for key in …` line with:

```bash
  for key in schema_version project counters releases spines work_items demo_ledger bones risk_gates fakes feature_map patch_records class_overrides veto_dispositions close_records mutations; do
```

- [ ] **Step 8: Fix the tests the bump breaks** — `ossify/tests/test-state-core.sh:9` asserts `schema v1`:

```bash
t_capture oss_state_read "$S" '.schema_version';       t_assert_eq "2" "$T_OUT" "schema v2"
```

Then append to `ossify/tests/test-entities.sh`, before `t_summary` — the reject-before-mutate half, which is the assertion finding 7 showed is the one that actually matters. **`test-entities.sh` defines neither `$SP` nor `$WI`** (verified — its ids are the literals `r0.s1` / `r0.s1.w1`), so the block opens by binding them:

```bash
SP=r0.s1; WI=r0.s1.w1   # this file uses literal ids; bind them once for the block below
# Status transitions: bad enum -> rc 2; unknown id -> rc 7 AND nothing mutated.
# A jq `select()` assignment is a silent NO-OP on a non-matching id, so without
# the entity guard a typo'd id would return 0 and change nothing - green, wrong.
t_capture oss_entity_set_spine_status "$S" "$SP" "shipped"
t_assert_rc 2 "spine status rejects an unknown enum value"
t_capture oss_entity_set_spine_status "$S" "r9.s9" "closed"
t_assert_rc 7 "spine status on an unknown spine is rc 7"
t_capture oss_state_read "$S" '[.mutations[] | select(.op=="set_spine_status")] | length'
t_assert_eq "0" "$T_OUT" "a rejected status change journals NOTHING"
t_capture oss_entity_set_spine_status "$S" "$SP" "closed"
t_assert_rc 0 "spine status accepts a valid transition"
t_capture oss_state_read "$S" ".spines[] | select(.id==\"$SP\") | .status"
t_assert_eq "closed" "$T_OUT" "spine status actually changed"
t_capture oss_entity_set_work_item_status "$S" "r9.s9.w9" "complete"
t_assert_rc 7 "work item status on an unknown id is rc 7"
t_capture oss_entity_set_release_status "$S" "r9" "closed"
t_assert_rc 7 "release status on an unknown id is rc 7"
```

And append the replay round-trip **to `test-entities.sh`, immediately after the block above — NOT to `test-state-replay.sh`**. That file sources only `lib/state.sh` (verified: line 4), so every `oss_entity_*` call in it would be an undefined command; `t_capture` swallows the rc 127, no status op is ever applied, and the trailing replay assertion then passes **vacuously green** over a state nothing mutated. `test-entities.sh` already sources id/state/entities and now binds `$SP`/`$WI`:

```bash
t_capture oss_entity_set_work_item_exec "$S" "$WI" "work/r0.s1.w1-x" "/tmp/wt" "abc123"
t_assert_rc 0 "work item exec fields recorded"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay stays clean across the new status + exec ops"
```

- [ ] **Step 9: Run the suites**

Run: `bash ossify/tests/test-migration.sh && bash ossify/tests/run-all.sh`
Expected: `pass=N fail=0` and `ALL GREEN`.

- [ ] **Step 10: Mutation-test the guard that matters, then commit**

Delete the `|| { echo "oss: unknown spine '$spine'" >&2; return 7; }` line from `oss_entity_set_spine_status` and re-run `test-entities.sh`. Expected: the `rc 7` and `journals NOTHING` assertions both FAIL. Restore, confirm green, and verify `lib/entities.sh` is byte-identical to the pre-mutation version before committing.

```bash
git add ossify/lib/state.sh ossify/lib/entities.sh ossify/lib/commands.sh ossify/lib/doctor.sh \
        ossify/tests/test-migration.sh ossify/tests/test-state-core.sh ossify/tests/test-entities.sh \
        ossify/tests/test-state-replay.sh ossify/tests/test-dispatcher-ops.sh
git commit -m "feat(ossify): schema v2 — lifecycle status transitions + first journaled migration

Close cannot close anything without these: _oss_apply_op's vocabulary was
create-only and nothing ever moved a spine/work-item/release off 'planned'.

Adds set_spine_status / set_work_item_status / set_release_status /
set_work_item_exec, plus migrate_schema — journaled rather than applied in
place, so \$sf.base.json stays v1 and replay still rebuilds live from
base+journal. oss_state_check_version now refuses a state OLDER than the build
and names 'oss migrate'; the mutate gate exempts migrate_schema so the
migration is not locked out by its own guard.

Also fixes pre-existing drift: doctor's shape list omitted veto_dispositions.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks for the task reviewer** *(one focused check each)*:
1. **Who calls this?** Name every producer and consumer of each new op. `set_work_item_exec` has no caller until T4 — is that acceptable staging, or built-but-unwired?
2. Does a typo'd id in each of the four wrappers genuinely return 7 **and** journal nothing? Re-derive from the libs; do not trust the test names.
3. Does replay stay byte-identical across the migration when the base snapshot is v1? Verify `base.json` is *not* rewritten.
4. Is the migration reachable? Prove the mutate gate's `migrate_schema` exemption is required by removing it and observing the wedge.
5. Was the migration tested against a genuine legacy-shaped state, or only a fresh `oss init`? (The fresh-derive-first trap.)
6. Grep for any other test or fixture that assumes `schema_version == 1`.
7. Does `oss migrate` behave under the real dispatcher's `set -euo pipefail`, not only sourced?

---

### Task 2 (C1-2): Pending-amendment lifecycle, quarantine provenance, fake lifecycle

**Context:** This implements design decision **D1**. Today `ledger_supersede` / `ledger_retire` flip `status` on the spot and every reader filters `status == "active"`, so a planned amendment drops coverage immediately — for sibling spines closing in the window, and permanently for a spine that is later replanned or abandoned (there is no reactivate verb). Two more §6.1 contracts are unenforceable for want of a field: `oss_ledger_quarantine` records no release (so "fixed or retired **by the next release close**" has no anchor), and `fakes[]` are `status:"active"` forever (so §5.3's blocking-close finding on a fired trigger or a passed expiry cannot fire).

**Note for the reviewer:** this task **reverts** two prose edits made by `a53d034`. That is correct, not a regression — `a53d034` implemented "option 3" (make the prose describe the lib's immediate behaviour) as a deliberately temporary measure, recording the direction as an explicit Plan C decision. D1 settled it the other way, so the lib moves and the prose returns to the spec's wording.

**Files:**
- Modify: `ossify/lib/state.sh` (3 ops), `ossify/lib/ledger.sh`, `ossify/lib/registries.sh`, `ossify/lib/commands.sh`
- Modify: `ossify/tests/test-ledger.sh`, `ossify/tests/test-spine-planning.sh:104-122`, `ossify/tests/test-registries.sh`
- Modify (prose, all five sites): `ossify/skills/plan-spine/references/demo-amendments.md`, `ossify/skills/plan-spine/SKILL.md:380`, `ossify/skills/plan-release/SKILL.md:200`

**Interfaces:**
- Produces: `oss_ledger_supersede/retire <state> <line-id> <by-spine> <reason>` (now write **pending**); `oss_ledger_apply_pending <state> <spine>`; `oss_ledger_unplan <state> <line-id>`; `oss_ledger_quarantine <state> <line-id> <reason> <release>`; `oss_reg_set_fake_status <state> <boundary> <status> <reason> [new-expiry]`. Dispatcher: `oss ledger_apply_pending`, `oss ledger_unplan`, `oss fake_status`.
- Consumes: `oss_state_mutate`, `_oss_now`.

- [ ] **Step 1: Write the failing tests** — replace `ossify/tests/test-spine-planning.sh:104-122` (the block that pins immediate semantics) with the pending lifecycle. Keep the surrounding `AUTO1`/`AUTO2`/`USER1` setup:

```bash
# --- §8e / D1: amendments are RECORDED at planning time and APPLIED at close.
t_capture "$OSS" get '.demo_ledger | length'; LEDGER_BEFORE="$T_OUT"
t_capture "$OSS" ledger_supersede "$AUTO1" r0.s1 "the order ticket replaced the CLI entry point"
t_assert_rc 0 "dispatcher: supersede by line id ok"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].pending_status"
t_assert_eq "superseded" "$T_OUT" "supersede records a PENDING status"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].status"
t_assert_eq "active" "$T_OUT" "...and leaves the live status ACTIVE until close"
t_capture "$OSS" ledger_active_auto
t_assert_eq "2" "$(printf '%s' "$T_OUT" | jq 'length')" "a pending amendment does NOT drop the line from the live set"

# unplan is the escape hatch immediate semantics never had: a replanned or
# abandoned spine must not permanently drop coverage.
t_capture "$OSS" ledger_unplan "$AUTO1"
t_assert_rc 0 "unplan clears a pending amendment"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].pending_status"
t_assert_eq "null" "$T_OUT" "pending cleared"

# re-plan it, then apply at close.
t_capture "$OSS" ledger_supersede "$AUTO1" r0.s1 "the order ticket replaced the CLI entry point"
t_capture "$OSS" ledger_retire "$USER1" r0.s1 "the CSV export flow was removed by this spine"
t_capture "$OSS" ledger_apply_pending r0.s1
t_assert_rc 0 "apply_pending ok"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].status"
t_assert_eq "superseded" "$T_OUT" "close applied the supersede"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].status_by"
t_assert_eq "r0.s1" "$T_OUT" "superseding spine recorded on apply"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$USER1\")][0].status_reason"
t_assert_eq "the CSV export flow was removed by this spine" "$T_OUT" "retire reason carried through the pending round trip"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].pending_status"
t_assert_eq "null" "$T_OUT" "pending is consumed by apply, not left dangling"
t_capture "$OSS" get '.demo_ledger | length'
t_assert_eq "$LEDGER_BEFORE" "$T_OUT" "amended lines are archived, not deleted"
t_capture "$OSS" ledger_active_auto
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "only the un-amended auto line stays active after close"

# apply_pending for a DIFFERENT spine must not touch this spine's lines.
t_capture "$OSS" ledger_supersede "$AUTO2" r0.s2 "reason"
t_capture "$OSS" ledger_apply_pending r0.s1
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO2\")][0].status"
t_assert_eq "active" "$T_OUT" "apply_pending is scoped to the closing spine only"

# unknown line id is still rc 7 and writes nothing.
t_capture "$OSS" ledger_supersede d999 r0.s1 "typo'd id"
t_assert_rc 7 "dispatcher: amendment against unknown line id is rc 7"
```

Append to `ossify/tests/test-ledger.sh` — quarantine provenance and the fake lifecycle. **That file sources only id/state/ledger and defines no `$L1`** (verified — its ids are the literals `d1`/`d2`), so add `. "$HERE/../lib/registries.sh"` to its source line **and** bind the id:

```bash
L1=d1   # this file uses literal demo-line ids
# Quarantine stays IMMEDIATE (it is a close/doctor-time verb applied when a line
# actually fails, not a planned amendment) and now records WHICH release, so
# §6.1's "fixed or retired by the next release close" has an anchor.
t_capture oss_ledger_quarantine "$S" "$L1" "upstream CI image broken" "r1"
t_assert_rc 0 "quarantine ok"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].status"
t_assert_eq "quarantined" "$T_OUT" "quarantine applies immediately"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].quarantined_in_release"
t_assert_eq "r1" "$T_OUT" "quarantine records the release it was raised in"

# Fake lifecycle: a fake can be replaced or explicitly renewed with a NEW expiry.
t_capture oss_reg_add_fake "$S" "broker" "fake" "no sandbox yet" "the first live order" "r1"
t_capture oss_reg_set_fake_status "$S" "broker" "renewed" "sandbox still unavailable" "r2"
t_assert_rc 0 "fake renew ok"
t_capture oss_state_read "$S" '[.fakes[] | select(.boundary=="broker")][0].expiry_release'
t_assert_eq "r2" "$T_OUT" "renewal moves the expiry"
t_capture oss_reg_set_fake_status "$S" "broker" "bogus" "x"
t_assert_rc 2 "fake status rejects an unknown value"
t_capture oss_reg_set_fake_status "$S" "nosuch" "replaced" "x"
t_assert_rc 7 "fake status on an unknown boundary is rc 7"
```

Run: `bash ossify/tests/test-spine-planning.sh; bash ossify/tests/test-ledger.sh` → both FAIL.

- [ ] **Step 2: Add the three ops** — in `_oss_apply_op`, before the `*)` arm:

```bash
    set_demo_line_pending)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.pending_status = $p.status | .pending_by = $p.by
           | .pending_reason = $p.reason | .pending_at = $p.at)' ;;
    # Applies every pending amendment BELONGING TO ONE SPINE and consumes it.
    # Scoped by `pending_by` so a sibling spine's planned amendment is untouched -
    # that scoping is the whole point of the pending lifecycle. Records lacking
    # the pending_* fields entirely (every line written before this task) read as
    # null and are skipped, so no migration of demo_ledger is needed.
    apply_demo_pending)
      jq --argjson p "$payload" '
        .demo_ledger |= map(
          if (.pending_by // null) == $p.spine and (.pending_status // null) != null
          then .status = .pending_status
             | .status_reason = .pending_reason
             | .status_by = .pending_by
             | .pending_status = null | .pending_by = null
             | .pending_reason = null | .pending_at = null
          else . end)' ;;
    clear_demo_pending)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.pending_status = null | .pending_by = null
           | .pending_reason = null | .pending_at = null)' ;;
    set_fake_status)
      jq --argjson p "$payload" '
        (.fakes[] | select(.boundary == $p.boundary)) |=
          (.status = $p.status | .status_reason = $p.reason | .status_at = $p.at
           | .expiry_release = (if $p.expiry == "" then .expiry_release else $p.expiry end))' ;;
```

Extend the existing `set_demo_line_status` case to carry the release, replacing its body with:

```bash
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.status = $p.status | .status_reason = $p.reason | .status_by = $p.by
           | .quarantined_in_release =
               (if $p.status == "quarantined" then $p.release else .quarantined_in_release end))' ;;
```

- [ ] **Step 3: Rewrite the ledger verbs** — in `ossify/lib/ledger.sh`, replace `_oss_ledger_set_status` and the three verbs beneath it with:

```bash
_oss_ledger_require_line() { # $1=state $2=line-id
  jq -e --arg id "$2" '.demo_ledger[] | select(.id == $id)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown demo line '$2'" >&2; return 7; }
}

# D1: supersede/retire are PLANNING verbs. They record intent and leave the line
# live, so a sibling spine closing before this one still runs the flow, and a
# spine that is replanned or abandoned drops no coverage. `close` applies them.
_oss_ledger_plan_amendment() { # $1=state $2=line-id $3=status $4=by-spine $5=reason
  _oss_ledger_require_line "$1" "$2" || return $?
  # D1 promotes <by-spine> from a provenance STRING into the JOIN KEY that
  # apply_demo_pending matches on. Under the old immediate semantics a typo'd
  # spine was a cosmetic blemish in an audit trail; now it means the amendment
  # is never applied by any close, silently and forever. Validate it like the
  # line id. (demo-amendments.md §3 currently states the opposite - "not
  # validated against known spines, a typo records silently" - and is corrected
  # in Step 6.)
  jq -e --arg s "$4" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$4' - an amendment keyed to a spine that does not exist would never be applied" >&2; return 7; }
  oss_state_mutate "$1" set_demo_line_pending \
    "$(jq -n --arg id "$2" --arg st "$3" --arg by "$4" --arg r "$5" --arg ts "$(_oss_now)" \
      '{id:$id,status:$st,by:$by,reason:$r,at:$ts}')"
}
oss_ledger_supersede() { _oss_ledger_plan_amendment "$1" "$2" superseded "$3" "$4"; }
oss_ledger_retire()    { _oss_ledger_plan_amendment "$1" "$2" retired    "$3" "$4"; }

# The close-time apply. Runs AFTER merge and BEFORE the cumulative demo, so the
# demo measures the amended set against a product where the flow really is gone.
oss_ledger_apply_pending() { # $1=state $2=spine
  oss_state_mutate "$1" apply_demo_pending "$(jq -n --arg s "$2" '{spine:$s}')"
}

# The escape hatch: clears a planned amendment. There is no `reactivate` for an
# APPLIED one by design - once close has applied it the ledger records history.
oss_ledger_unplan() { # $1=state $2=line-id
  _oss_ledger_require_line "$1" "$2" || return $?
  oss_state_mutate "$1" clear_demo_pending "$(jq -n --arg id "$2" '{id:$id}')"
}

# Quarantine is NOT a planned amendment: it is raised at close/doctor time when a
# line actually fails for causes unrelated to any open spine, so it applies at
# once. The release is recorded because §6.1 makes it a parking ticket that
# expires - "fixed or retired by the next release close" needs an anchor.
oss_ledger_quarantine() { # $1=state $2=line-id $3=reason $4=release
  _oss_ledger_require_line "$1" "$2" || return $?
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg st quarantined --arg by quarantine \
        --arg r "$3" --arg rel "${4:-}" \
      '{id:$id,status:$st,by:$by,reason:$r,release:$rel}')"
}
```

- [ ] **Step 4: Add the fake lifecycle verb** — append to `ossify/lib/registries.sh`:

```bash
oss_reg_set_fake_status() { # $1=state $2=boundary $3=status $4=reason [$5=new-expiry]
  local sf="$1" b="$2" st="$3"
  case "$st" in active|replaced|renewed) ;; *)
    echo "oss: fake status must be active|replaced|renewed" >&2; return 2;; esac
  jq -e --arg b "$b" '.fakes[] | select(.boundary == $b)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown fake boundary '$b'" >&2; return 7; }
  oss_state_mutate "$sf" set_fake_status \
    "$(jq -n --arg b "$b" --arg st "$st" --arg r "$4" --arg ex "${5:-}" --arg ts "$(_oss_now)" \
      '{boundary:$b,status:$st,reason:$r,expiry:$ex,at:$ts}')"
}
```

- [ ] **Step 5: Update the dispatcher wrappers** — in `ossify/lib/commands.sh`, extend `oss_cmd_ledger_quarantine` to take the release and add the two new verbs:

```bash
oss_cmd_ledger_quarantine()    { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_quarantine "$sf" "$1" "$2" "${3:-}"; }
oss_cmd_ledger_apply_pending() { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_apply_pending "$sf" "$1"; }
oss_cmd_ledger_unplan()        { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_unplan "$sf" "$1"; }
oss_cmd_fake_status()          { local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_set_fake_status "$sf" "$1" "$2" "$3" "${4:-}"; }
```

- [ ] **Step 6: Make all SIX prose sites consistent with D1** *(the sweep was drafted as five; the plan review found two more and one that needs no change — the count below is the verified set)*

`plan-spine/references/demo-amendments.md:3-5` — **already correct** under D1 ("planned here and applied at that spine's close"). Leave it; it is the site `a53d034` missed, and D1 makes the miss retroactively right.

`demo-amendments.md` §2, replace the first consequence bullet with:

```markdown
- `oss ledger_active_auto` returns only `active` `auto:` lines. A **planned**
  amendment does not change that — the line keeps running until this spine's
  close applies it, so a sibling spine closing in between still exercises the
  flow. Coverage is never dropped for work that has not landed.
```

`demo-amendments.md` §6, replace the "Amending before the replacement is real" anti-pattern with the hazard that actually survives:

```markdown
- **Planning an amendment and never closing the spine.** A pending amendment is
  consumed by `close`. If the spine is replanned or abandoned, clear it with
  `oss ledger_unplan <line-id>` — otherwise it sits in state waiting for a close
  that will never come, and `oss doctor` will keep reporting it. There is no
  `reactivate` for an amendment `close` has already applied: at that point the
  flow really is gone and the ledger is recording history.
```

`plan-spine/SKILL.md:380`, replace "They apply the moment they run:" with:

```markdown
whose flow this spine changes — with a reason. They are **recorded now and
applied at this spine's close**, so a sibling spine closing first still runs the
line. `oss ledger_unplan <line-id>` clears one if the spine is replanned:
```

**Line budget — `plan-spine/SKILL.md` is at 499/500 with zero headroom** and the §8e rewrite above is net +2, taking it to 501. The Global Constraints already bind "any edit to them needs a trim in the same commit"; make it concrete here so it is not discovered at the ceiling: drop the two sentences at SKILL.md:387-390 that restate the archived-never-deleted rule, which `references/demo-amendments.md` §2 carries in full and which this task's §8e block already points at. Re-check `wc -l ossify/skills/plan-spine/SKILL.md` ≤ 500 before committing, and stage the reference file in the same `git add`.

`plan-release/SKILL.md:200`, replace the parenthetical with:

```markdown
  (`plan-spine` records the amendment; `close` applies it);
```

`demo-amendments.md` §3, which currently says `<by-spine>` "is **not validated against known spines** — a typo records silently". Step 3 makes that false and the consequence far worse than cosmetic. Replace with a statement that an unknown spine is now rejected rc 7, and why: the value is the join key `close` matches on, so a typo means the amendment is never applied by any close.

`demo-amendments.md` §4, the quarantine call form. The verb gains a release argument in Step 3, and the shipped fence still teaches the two-argument call:

```markdown
oss ledger_quarantine <line-id> "<reason>" <release>    # NOT a planning action
```

Add one sentence: the release argument is what makes §6.1's "fixed or retired by the next release close" enforceable — omitting it leaves the parking ticket undated and the release close cannot tell which quarantines are overdue.

Then verify the whole file set agrees: `grep -rn "moment it runs\|moment they run\|applies immediately" ossify/skills/` must return **zero** hits, and `grep -rn 'ledger_quarantine' ossify/skills/` must show the three-argument form everywhere.

- [ ] **Step 7: Run the suites, mutation-test, commit**

Run: `bash ossify/tests/run-all.sh` → `ALL GREEN`.

Mutation test: **drop the `(.pending_by // null) == $p.spine` conjunct** from `apply_demo_pending`. Expected RED on "apply_pending is scoped to the closing spine only" — the sibling spine's pending amendment gets applied too. That is the clause named risk 2 actually cares about.

(An earlier draft prescribed dropping the `and (.pending_status // null) != null` clause instead. **That mutation cannot go RED**: `pending_by` is non-null only in lockstep with `pending_status` — both are written by `set_demo_line_pending` and both cleared by `apply_demo_pending`/`clear_demo_pending` — so guarded and unguarded produce byte-identical output, and non-matching records take the `else .` arm rather than getting `status = null`. Verified against a three-line fixture. A mutation that produces no RED is not evidence the guard is sound; it is evidence you mutated the wrong thing.)

```bash
git add ossify/lib/state.sh ossify/lib/ledger.sh ossify/lib/registries.sh ossify/lib/commands.sh \
        ossify/tests/test-ledger.sh ossify/tests/test-spine-planning.sh ossify/tests/test-registries.sh \
        ossify/skills/plan-spine/SKILL.md ossify/skills/plan-spine/references/demo-amendments.md \
        ossify/skills/plan-release/SKILL.md
git commit -m "feat(ossify): pending-amendment lifecycle, quarantine provenance, fake lifecycle

Implements the D1 decision (2026-07-29): demo-line amendments are recorded at
planning time and applied by close, per spec §5.3. Immediate semantics dropped
coverage the moment an amendment was planned — for sibling spines closing in
the window, and permanently for a spine later replanned or abandoned, since no
reactivate verb exists. ledger_unplan is that escape hatch.

Quarantine stays immediate (a close-time verb, not a planned amendment) and now
records its release, so §6.1's 'fixed or retired by the next release close' has
an anchor. Fakes gain replaced/renewed so §5.3's expiry finding can fire.

Reverts two a53d034 prose edits: that commit deliberately described the lib's
immediate behaviour pending this decision, which has now gone the other way.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks for the task reviewer:**
1. **Who calls this?** `apply_demo_pending` has no caller until T9 — confirm that is staged, not stranded, and that T9's brief names it.
2. Is `apply_demo_pending` genuinely scoped to one spine? Construct two spines with pending amendments and prove the sibling's is untouched.
3. Do demo lines written **before** this task (no `pending_*` keys at all) survive `apply_demo_pending` unchanged? This is the upgrade-input class.
4. Does replay stay clean across all four new ops?
5. Are all five prose sites consistent, and does the file no longer contradict itself? Re-read `demo-amendments.md` end to end, not just the diff.
6. Quarantine must NOT have become pending — verify it still applies on the spot.
7. Does `oss_reg_set_fake_status` leave `expiry_release` alone when the fifth argument is omitted?

---

### Task 3 (C1-3): `oss state_restore`, dispatcher exposure for manifest/id, and doctor growth

**Context:** Three items owed to Plan C by the final review, plus the dispatcher gaps the close skills will hit. `oss_state_replay` computes the recovered state and discards it (`state.sh:193-197`); §9.2 binds "corruption recovery = replay from last good snapshot" and only the comparator half is built. `oss get` takes no explicit state-file argument, so `plan-release`'s bones-count pre-flight probe can be hijacked by a stale exported `$OSS_STATE_FILE`. `oss_manifest_get` / `_require` / `_discover` exist but have **no `oss_cmd_` wrapper**, so a skill cannot reach them through `bin/oss` at all — and `bin/oss` dispatches only `oss_cmd_*` (bin/oss:14), unlike `bin/sd` which dispatches any `sd_*`. Finally `oss_cmd_critic_detect` returns on the first cache hit and can never report `v0.3`.

**Files:**
- Modify: `ossify/lib/state.sh` (`oss_state_restore`), `ossify/lib/commands.sh`, `ossify/lib/id.sh`, `ossify/lib/doctor.sh`
- Modify: `ossify/tests/test-state-replay.sh`, `ossify/tests/test-doctor.sh`, `ossify/tests/test-dispatcher-ops.sh`, `ossify/tests/test-manifest.sh`

**Interfaces:**
- Produces: `oss_state_restore <state>`; `oss_id_spine_dir <release-id> <spine-id> <slug>`; `oss_id_work_item_branch <wi-id> <slug>`. Dispatcher: `oss state_restore`, `oss get <expr> [state-file]`, `oss manifest_get <jq-expr>`, `oss manifest_require`, `oss spine_dir`, `oss work_item_branch`, and a corrected `oss critic_detect`.
- Consumes: `oss_state_replay`, `oss_manifest_get`, `_oss_resolve_state`.

- [ ] **Step 1: Write the failing tests** — insert into `ossify/tests/test-state-replay.sh` **between the last drift-message assertion (line 33, `base.json`) and the `# Fix 5 (test coverage)` comment at line 35**.

> **Insertion point corrected 2026-07-31 — the earlier wording ("append … before the base-snapshot deletion at the file tail") was wrong twice and would have broken this block.** The base-snapshot deletion is `rm -f "$S.base.json"` at **line 37, mid-file** — not at the tail; the tail (lines 42-100) holds the G1/G2 hand-built fixtures and ends `rm -rf "$TMP"` / `t_summary`. Insert anywhere at or after line 37 and `$S.base.json` no longer exists, so `oss_state_restore` takes its `[ -f "$base" ] ||` guard and returns **rc 1**, failing `t_assert_rc 0 "state_restore repairs a drifted state"`. At line 34 the preconditions this block needs both hold: `$S` was tampered at line 15 and never repaired (so replay is still rc 5), and `$S.base.json` is still present. Restoring `$S` there is safe for what follows — lines 38-40 assert the **missing-base** rc-1 path after line 37 deletes the base, which holds whether or not `$S` is drifted.

```bash
# state_restore: replay detects drift AND can now repair it. The recovered state
# is written through the same temp+rename path every other write uses, under the
# lock - NOT from inside oss_state_replay, which is deliberately lock-free so
# doctor can call it freely.
t_capture oss_state_replay "$S"; t_assert_rc 5 "replay still reports drift before restore"
t_capture oss_state_restore "$S"
t_assert_rc 0 "state_restore repairs a drifted state"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay is clean after restore"
# -d, NOT -f: the lock is a DIRECTORY (mkdir-based, state.sh:127). `[ -f ]` on it
# is always false, so an -f assertion passes unconditionally and can never detect
# the leak it exists to detect.
[ -d "$S.lock" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: state_restore leaked the lock"; } || T_PASS=$((T_PASS+1))
ls "$S".tmp.* >/dev/null 2>&1 && { T_FAIL=$((T_FAIL+1)); echo "FAIL: state_restore orphaned a temp"; } || T_PASS=$((T_PASS+1))

# Restoring a state that is ALREADY clean is a no-op, not a rewrite.
t_capture oss_state_restore "$S"
t_assert_rc 0 "restore on a clean state is a no-op"
t_assert_contains "$T_OUT" "clean" "...and says so"
```

Insert into `ossify/tests/test-dispatcher-ops.sh` **between the replay assertion at line 48 and the `# --- Dispatcher-path regression` comment block at line 50.**

> **Insertion point corrected 2026-07-31 — the earlier wording ("before its `unset OSS_STATE_FILE` / `rm -rf \"$TMP\"` teardown (~line 79-82)") named the wrong teardown and the wrong region.** The file has **three** isolated temp-dir regions, not one: `$TMP` (line 6, project `wrapper-demo`), `$DTMP` (line 59, project `dispatcher-demo`), `$FTMP` (line 89) — and it runs to line 125, so lines 79-83 are mid-file, not a tail. Lines 79-80 tear down **`$DTMP`**; the `$TMP` teardown is lines **82-83**. The block below needs `OSS_STATE_FILE` to still point at `$TMP/state.json`, because it asserts the no-argument `get` resolves to **`wrapper-demo`**. Line 59 re-exports `OSS_STATE_FILE="$DTMP/state.json"`, so inserting anywhere at or after line 59 yields `dispatcher-demo` and fails the assertion; inserting after line 79 leaves the variable **unset**, so `get` falls through to the manifest walk-up and cannot resolve at all. Line 49 is the last point where the `wrapper-demo` state is the live one.

```bash
# `oss get` takes an explicit state file, so a pre-flight probe cannot be
# hijacked by a stale exported $OSS_STATE_FILE.
OTHER="$TMP/other.json"; OSS_STATE_FILE="$OTHER" "$OSS" init "other-project" >/dev/null 2>&1
t_capture "$OSS" get '.project.name' "$OTHER"
t_assert_eq "other-project" "$T_OUT" "get honors an explicit state-file argument over the env"
t_capture "$OSS" get '.project.name'
t_assert_eq "wrapper-demo" "$T_OUT" "get with no argument still resolves via the env/manifest"

# manifest verbs are reachable through the dispatcher at all.
t_capture "$OSS" manifest_require
t_assert_rc 1 "manifest_require refuses with no manifest on the walk-up path"

# id grammar verbs are reachable, and the work-item branch is DISTINCT from the
# spine branch (oss_id_branch_name) - a work item must not share its spine's ref.
t_capture "$OSS" work_item_branch r0.s1.w2 "add-ticket"
t_assert_eq "work/r0.s1.w2-add-ticket" "$T_OUT" "work-item branch grammar"
t_capture "$OSS" spine_dir r0 r0.s1 "order-ticket"
t_assert_eq "docs/specs/r0/r0.s1-order-ticket" "$T_OUT" "spine dir grammar"
```

Run both → FAIL.

- [ ] **Step 2: Implement `oss_state_restore`** — append to `ossify/lib/state.sh`. It re-derives `$rebuilt` rather than reaching into `oss_state_replay`, keeping that function lock-free:

```bash
# §9.2: "corruption recovery = replay from last good snapshot". oss_state_replay
# is the comparator and is deliberately lock-free (doctor calls it freely), so it
# must NOT write. This is the writer: it takes the lock, rebuilds from
# base+journal through the SAME pure transform, and commits via temp+rename.
oss_state_restore() { # $1=state-file ; rc 0 restored-or-already-clean, 1 no base, 4 apply, 3 lock
  local sf="$1" base="$1.base.json" lock="$1.lock" rc=0
  [ -f "$base" ] || { echo "oss: no base snapshot ($base) - nothing to restore from" >&2; return 1; }
  if oss_state_replay "$sf" >/dev/null 2>&1; then
    echo "restore: state is already clean - nothing to do"
    return 0
  fi
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating; retry or run 'oss doctor'" >&2
    return 3
  fi
  _oss_state_restore_body "$sf" "$base" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  [ "$rc" -eq 0 ] && echo "restore: rebuilt from base + $(jq '.mutations | length' "$sf" 2>/dev/null || echo '?') journaled mutations"
  return "$rc"
}

# Critical section. Same `|| rc=$?` body-function pattern as oss_state_mutate:
# errexit is suspended for the whole body, so no bare command substitution in
# here can hard-exit between lock-acquire and lock-release and leak the lock.
_oss_state_restore_body() { # $1=state-file $2=base
  local sf="$1" base="$2" rebuilt n i seq_json op payload tmp
  rebuilt="$(cat "$base")" || return 4
  n="$(jq '.mutations | length' "$sf" 2>/dev/null)" || return 4
  i=0
  while [ "$i" -lt "$n" ]; do
    seq_json="$(jq -c ".mutations[$i]" "$sf" 2>/dev/null)" || return 4
    op="$(printf '%s' "$seq_json" | jq -r '.op' 2>/dev/null)" || return 4
    payload="$(printf '%s' "$seq_json" | jq -c '.payload' 2>/dev/null)" || return 4
    rebuilt="$(printf '%s' "$rebuilt" \
      | jq --argjson m "$seq_json" '.mutations += [$m]' \
      | _oss_apply_op "$op" "$payload")" || return 4
    i=$((i+1))
  done
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 4
  printf '%s' "$rebuilt" > "$tmp" || { rm -f "$tmp"; return 4; }
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; echo "oss: restore produced invalid state; aborted (original untouched)" >&2; return 4
  fi
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 4; }
}
```

Update the drift message at **`state.sh:334`** (inside `oss_state_replay`, which opens at line 306) — it currently says "This build has no automated restore verb". **`ossify/tests/test-state-replay.sh:31` asserts that exact phrase and MUST be updated in the same commit** to `t_assert_contains "$T_OUT" "oss state_restore" "drift message names the verb that can actually repair it"`; leave the `Do NOT delete` and `base.json` assertions at lines **32-33** unchanged.

> **Line numbers corrected 2026-07-31** — the earlier text said `state.sh:211` (that line is inside `_oss_apply_op`, nowhere near the message) and `test-state-replay.sh:30` with "lines 31-32" to leave alone. Line 30 is the `esac` of the `repair from journal` guard; **31** is the assertion to change and **32-33** are the two to leave. Following the old numbers edits the `esac` and leaves the failing assertion in place.
>
> The `case` guard at lines 27-30 fails the suite if the message ever contains `repair from journal`; the replacement below does not, and it still satisfies the two retained assertions (`Do NOT delete` literally, and `base.json` because `$base` expands to `<state>.base.json`). Verify all three after the edit rather than assuming.

Replacement text:

```bash
    echo "  Recover with 'oss state_restore', which rebuilds the state from '$base' plus the journal under the state lock. Do NOT delete $sf - the journal lives inside it." >&2
```

- [ ] **Step 3: Add the id grammar and dispatcher wrappers** — append to `ossify/lib/id.sh`:

```bash
# Work items get their OWN branch namespace. Sharing `spine/<id>-<slug>` would
# make N concurrent work-item worktrees fight over one ref.
oss_id_work_item_branch() { echo "work/$1-$2"; }
oss_id_spine_dir()        { echo "docs/specs/$1/$2-$3"; }
```

In `ossify/lib/commands.sh`, replace `oss_cmd_get` and `oss_cmd_critic_detect`, and add the rest:

```bash
# Explicit state file beats the environment. Without this argument a pre-flight
# probe in one project silently reads another project's state via a stale
# exported $OSS_STATE_FILE (final review, Minor 1).
oss_cmd_get() { # $1=jq-expr [$2=state-file]
  local sf; sf="$(_oss_resolve_state "${2:-}")" || return $?
  oss_state_read "$sf" "$1"
}

oss_cmd_state_restore()  { local sf; sf="$(_oss_resolve_state "${1:-}")" || return $?; oss_state_restore "$sf"; }
oss_cmd_manifest_get()   { oss_manifest_get "$1"; }
oss_cmd_manifest_require(){ oss_manifest_require; }
oss_cmd_work_item_branch(){ oss_id_work_item_branch "$1" "$2"; }
oss_cmd_spine_dir()      { oss_id_spine_dir "$1" "$2" "$3"; }
oss_cmd_branch_name()    { oss_id_branch_name "$1" "$2"; }
# The close router (Task 9) derives its scope from the id SHAPE, so it needs this
# through the dispatcher - oss_id_parse has no wrapper today, and skill prose
# cannot reach a bare lib function (bin/oss dispatches only oss_cmd_*).
oss_cmd_id_parse()       { oss_id_parse "$1"; }

# Scan EVERY cache before deciding, and report the highest version found. The
# previous form returned on the first hit and globbed only critiquing-spec, so a
# stale v0.2 directory won over a newer v0.3 install and v0.3 was unreportable.
oss_cmd_critic_detect() {
  local cache skill_md found="absent"
  for cache in "${HOME}/.claude/plugins/cache" "${CLAUDE_PLUGINS_DIR:-}"; do
    { [ -z "$cache" ] || [ ! -d "$cache" ]; } && continue
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [ -f "$skill_md" ] || continue
      if [ -f "${skill_md%/skills/critiquing-spec/SKILL.md}/skills/managing-async-critique/SKILL.md" ]; then
        found="v0.3"
      elif [ "$found" = "absent" ]; then
        found="v0.2"
      fi
    done
  done
  echo "$found"
  [ "$found" = "absent" ] && return 1
  return 0
}
```

**Also update the two assertions the rewrite breaks.** `ossify/tests/test-dispatcher-ops.sh` accepts only `v0.2|absent` in two places; on a machine with architect-critic >=0.3 installed the rewrite returns `v0.3` and both fail. Widen them to `v0.2|v0.3|absent`, and add a hermetic positive case that builds both directory shapes under a temporary `CLAUDE_PLUGINS_DIR` so the assertion does not depend on the developer's own install:

```bash
CTMP="$(mktemp -d)"
mkdir -p "$CTMP/mk/architect-critic/0.6.0/skills/critiquing-spec" "$CTMP/mk/architect-critic/0.6.0/skills/managing-async-critique"
: > "$CTMP/mk/architect-critic/0.6.0/skills/critiquing-spec/SKILL.md"
: > "$CTMP/mk/architect-critic/0.6.0/skills/managing-async-critique/SKILL.md"
t_capture env HOME=/nonexistent CLAUDE_PLUGINS_DIR="$CTMP" bash "$OSS" critic_detect
t_assert_eq "v0.3" "$T_OUT" "a cache carrying managing-async-critique reports v0.3"
rm -rf "$CTMP"
```

(The emitted tokens stay `v0.2`/`v0.3`/`absent` rather than becoming capability names: `start/references/critic-moment.md` already documents this contract and that prose is eval-gated. Renaming is a C2 cleanup, not a C1 side-effect.)

- [ ] **Step 4: Grow doctor** — append to `oss_cmd_doctor` in `ossify/lib/doctor.sh`, immediately before `return "$rc"`. All three are **advisory** (`warn:` never sets `rc`) except a pending amendment on a closed spine, which is genuine inconsistency:

```bash
  # §6.1 operator visibility: the three things that rot silently.
  local pend quar fexp
  pend="$(jq -r '[.demo_ledger[] | select(((.pending_amendments // []) | length) > 0)] | length' "$sf" 2>/dev/null || echo 0)"
  [ "$pend" -gt 0 ] 2>/dev/null && echo "warn: ledger - $pend demo line(s) carry a pending amendment awaiting a spine close ('oss ledger_unplan <line-id> <spine>' to drop one)"
  quar="$(jq -r '[.demo_ledger[] | select(.status == "quarantined")] | length' "$sf" 2>/dev/null || echo 0)"
  [ "$quar" -gt 0 ] 2>/dev/null && echo "warn: ledger - $quar quarantined line(s); each must be fixed or retired by the next release close"
  fexp="$(jq -r '[.fakes[] | select(.status == "active" or .status == "renewed")] | length' "$sf" 2>/dev/null || echo 0)"
  [ "$fexp" -gt 0 ] 2>/dev/null && echo "warn: fakes - $fexp outstanding fake(s) carrying a replacement trigger and expiry release"
```

> **Corrected 2026-07-31, after Task 2's fix round — do NOT restore the earlier form.** All three
> selectors above were stale against the shape Task 2 actually shipped, and each failed *silently
> green* rather than loudly:
> 1. `select((.pending_status // null) != null)` — the scalar `pending_status` no longer exists.
>    Task 2's F1 fix round replaced it with the per-spine list `pending_amendments[]` (schema v3).
>    The old selector matches nothing, so `pend` is always `0` and the warning **can never fire** —
>    a vacuous check that reads as "no pending amendments" forever.
> 2. `'oss ledger_unplan <id>'` — `unplan` now requires `<line-id> <spine>`; the one-argument form
>    the message teaches is rejected rc 7.
> 3. `select(.status == "active")` — Task 2 gave fakes the `active|replaced|renewed` vocabulary.
>    A **`renewed`** fake is still outstanding and still carries an expiry (its deadline was pushed,
>    which is precisely when an operator wants to see it); only `replaced` is resolved. The old
>    selector silently under-counts exactly the fakes most worth warning about.
>
> Task 3's Step 5 mutation test must therefore prove each warning can actually **fire** — seed a
> state carrying a pending amendment, a quarantined line and a renewed fake, and assert all three
> `warn:` lines appear. A doctor check that counts zero forever passes every "is doctor green?" test.

- [ ] **Step 5: Write the doctor-fires test, run, mutation-test, commit**

**5a — the doctor warnings must be proven to FIRE, and this is a committed test, not a manual check.** Append to `ossify/tests/test-doctor.sh`. A doctor check that counts zero forever passes every "is doctor green?" assertion ever written — all three of Step 4's selectors were stale in exactly that silently-green way, and a fixture that seeds none of the three conditions cannot tell a correct selector from a dead one. Seed **all three** conditions on one state and assert **all three** `warn:` lines, then assert doctor's **rc is unchanged** (they are advisory):

**`test-doctor.sh` sources only `state.sh` and `doctor.sh` today** (lines 4-5). This block calls into the ledger, entity and registry layers, so add the three missing source lines in the same commit — a test file that hardcodes its lib source list is the exact breakage the Global Constraints flag for T6:

```bash
. "$HERE/../lib/entities.sh"
. "$HERE/../lib/ledger.sh"
. "$HERE/../lib/registries.sh"
```

```bash
# --- Step 4 doctor visibility: each warn: line must be provably reachable.
# Seed a state carrying all three rot conditions: a pending amendment, a
# quarantined line, and a RENEWED fake (not merely active - `renewed` is the
# case the stale selector under-counted, and the one whose deadline already
# moved once). IDs are captured from the minting calls rather than hardcoded,
# so a counter change upstream cannot silently point an assertion at nothing.
WTMP="$(mktemp -d)"; W="$WTMP/state.json"
oss_state_init "$W" doctor-warn >/dev/null
REL="$(oss_entity_add_release "$W" "mvp" "ship the core loop")"
SP="$(oss_entity_add_spine "$W" "$REL" "order flow" flesh canonical)"
L1="$(oss_ledger_add_auto "$W" "$SP" "line one" "bash -c 'exit 0'" "exit:0")"
L2="$(oss_ledger_add_auto "$W" "$SP" "line two" "bash -c 'exit 0'" "exit:0")"

# Assert the fixture actually seeded BEFORE asserting on doctor's output. A
# seeding call that rc's nonzero creates no condition, and the warn: assertion
# below then fails for a reason that has nothing to do with the selector under
# test. This is the Task 2 trap verbatim: its scoping fixture amended against a
# spine the file never created, the call rc-7'd, and the assertion passed while
# testing nothing.
if [ -n "$REL" ] && [ -n "$SP" ] && [ -n "$L1" ] && [ -n "$L2" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: doctor-warn fixture did not seed (REL=$REL SP=$SP L1=$L1 L2=$L2)"
fi

oss_ledger_retire       "$W" "$L1" "$SP" "replaced by the new flow"        # -> pending_amendments[]
oss_ledger_quarantine   "$W" "$L2" "flaky under load" "$REL"               # -> status quarantined
oss_reg_add_fake        "$W" "payment-gateway" "http" "no vendor sandbox" "sandbox ships" "$REL" >/dev/null
oss_reg_set_fake_status "$W" "payment-gateway" renewed "vendor slipped a quarter" "r2"

t_capture oss_cmd_doctor "$W"
t_assert_contains "$T_OUT" "warn: ledger - 1 demo line(s) carry a pending amendment" "doctor surfaces a pending amendment"
t_assert_contains "$T_OUT" "warn: ledger - 1 quarantined line(s)" "doctor surfaces a quarantined line"
t_assert_contains "$T_OUT" "warn: fakes - 1 outstanding fake(s)" "doctor surfaces a RENEWED fake, not just an active one"
t_assert_rc 0 "the three warn: lines are advisory - they must not change doctor's rc"
rm -rf "$WTMP"
```

Signatures above were reconciled against the tree on 2026-07-31 — `oss_reg_add_fake` (`$1=state $2=boundary $3=channel $4=reason $5=trigger $6=expiry-release`) and `oss_reg_set_fake_status` (`$1=state $2=boundary $3=status $4=reason [$5=new-expiry]`) are the real names; an earlier draft of this block invented `oss_registry_fake_add` / `oss_registry_fake_status`, which do not exist. **Re-verify them anyway** rather than trusting this note, and fix the *test* to match the shipped signature if either has moved.

**5b — Run:** `bash ossify/tests/run-all.sh` → `ALL GREEN`.

**5c — Mutation-test every guard this task adds. Four mutations, each must produce a NAMED RED:**

| # | Mutation | Must go RED |
|---|---|---|
| 1 | `mv "$tmp" "$sf"` → `cp "$tmp" "$sf"` in `_oss_state_restore_body` | the orphaned-temp assertion |
| 2 | Step 4's `pend` selector → `select(((.pending_amendments // []) \| length) > 99)` | "doctor surfaces a pending amendment" |
| 3 | Step 4's `quar` selector → `select(.status == "retired")` | "doctor surfaces a quarantined line" |
| 4 | Step 4's `fexp` selector → `select(.status == "active")` (the pre-correction form) | "doctor surfaces a RENEWED fake" |

Mutation 4 is the load-bearing one: it reproduces exactly the stale selector this task exists to fix, so if it does **not** go RED, the fixture is not seeding a `renewed` fake and the test is worthless.

**Before believing any mutation result, confirm the mutated code still RUNS on its happy path** — `bash ossify/bin/oss doctor <state>` must still exit cleanly and emit its normal `ok:` lines. A mutation that breaks jq *syntax* fails the op outright and throws unrelated assertions RED, which reads as coverage and is not; that false refutation was published once already in Task 2. Equally, a mutation with **no** RED means the guard is untested — not that it is correct. Restore each mutation and re-confirm `ALL GREEN` before the next.

```bash
git add ossify/lib/state.sh ossify/lib/commands.sh ossify/lib/id.sh ossify/lib/doctor.sh ossify/tests/
git commit -m "feat(ossify): oss state_restore, explicit get target, manifest/id dispatcher verbs

state_restore closes §9.2's 'recovery = replay from last good snapshot': replay
computed the recovered state and discarded it, and the drift message named no
command that could repair. The writer takes the lock and commits via
temp+rename; oss_state_replay stays lock-free so doctor can keep calling it.

oss get gains an explicit state-file argument (final review Minor 1 — a stale
exported OSS_STATE_FILE could hijack a pre-flight probe). manifest_get/require
and the id grammar get dispatcher wrappers: bin/oss dispatches only oss_cmd_*,
so lib functions without one are unreachable from skill prose.

critic_detect now scans all caches and can report v0.3; it previously returned
on the first hit, so a stale v0.2 dir beat a newer install.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks for the task reviewer:**
1. **Who calls this?** `state_restore` is an operator verb — is it reachable and named anywhere a stuck operator will actually look (the drift message, doctor, the close skill)?
2. Does `_oss_state_restore_body` leak the lock under real `set -euo pipefail` at each of its failure points? Test through `bin/oss`, not sourced.
3. Does restore write from inside `oss_state_replay`? It must not — prove replay is still lock-free.
4. Does `oss get` with an explicit path bypass `$OSS_STATE_FILE` in **both** directions (explicit wins; omitted still falls back)?
5. Is the `critic_detect` v0.3 probe correct? Verify the `managing-async-critique` marker against the real installed plugin rather than assuming.
6. Are the new doctor lines advisory-only? A `warn:` must never change `rc`.
7. **Can each doctor `warn:` actually FIRE?** Do not accept "doctor is green" or "the suite passes" as evidence. Confirm the Step 5a fixture really creates all three conditions (`jq '.demo_ledger, .fakes'` on the seeded state), then run all four Step 5c mutations yourself — mutation 4 especially, which restores the pre-correction `status == "active"` selector. A selector that counts zero forever satisfies every existing assertion in this suite.
8. **Was every guard this task adds actually committed as a test?** `grep` the tree for each test the report names — do not take the report's word for it. Task 2's fix report claimed a regression test that did not exist in the tree, and three of its four guards had zero coverage. And when you mutate, confirm the mutated code still runs on its happy path before reading the suite result: a mutation that breaks jq *syntax* throws unrelated assertions RED, which reads as coverage and is not.
9. **Strict mode on the new doctor lines and `critic_detect`.** All three `warn:` lines use the `[ "$n" -gt 0 ] && echo …` shape, and `critic_detect` uses `{ [ -z … ] || [ ! -d … ]; } && continue`. Both are exempt from `errexit` only because the failing test is not the command following the final `&&` — verify through `bin/oss` under real `set -euo pipefail`, not by sourcing. Also confirm an *empty* `$pend`/`$quar`/`$fexp` (jq emitting nothing) does not abort the dispatcher.

---

### Task 4 (C1-4): `lib/worktree.sh` — repo-parameterized spawn, resolve, remove, list

**Context:** There is no worktree layer at all. This is also the **first consumer of `target_repo`** (D4): `oss_entity_add_spine` / `add_work_item` have written it since B4 with zero readers, and retrofitting a repo parameter after the close ceremony is built means touching every call site and every path-shape test. So the signatures take a repo key now, resolve only `canonical` today, and refuse an unknown key rather than silently defaulting — Plan D adds `private_core` by extending one resolver.

**Port the intent, not the code (D9):** `sd_worktree_remove` retries with `--force`, which **discards uncommitted work**, and swallows the `branch -D` failure with `|| true`, while the skill prose claims it halts on failure and the close ceremony asserts as a post-condition that no work-`*` branch remains. C1's remove surfaces and halts.

**Files:**
- Create: `ossify/lib/worktree.sh`, `ossify/tests/test-worktree.sh`
- Modify: `ossify/lib/commands.sh`, `ossify/lib/manifest.sh` (repo-root resolver)

**Interfaces:**
- Produces: `_oss_repo_root <repo-key>`; `oss_worktree_dir <repo-key>`; `oss_worktree_add <repo-key> <wi-id> <slug> <base-ref>` (echoes the abs path); `oss_worktree_resolve <repo-key> <wi-id>`; `oss_worktree_remove <repo-key> <wi-id>`; `oss_worktree_list <repo-key>`. Dispatcher: `oss worktree_add|worktree_resolve|worktree_remove|worktree_list|repo_root`.
- Consumes: `oss_manifest_get` (T3 exposed it), `oss_id_work_item_branch` (T3).

- [ ] **Step 1: Write the failing test** — create `ossify/tests/test-worktree.sh`. It builds a real git repo and a real manifest, because a worktree layer tested against mocks proves nothing:

```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor worktree; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
git -C "$TMP/canon" init -q
git -C "$TMP/canon" config user.email t@t; git -C "$TMP/canon" config user.name t
echo seed > "$TMP/canon/f.txt"
# A TRACKED .gitignore, because that is the realistic case and it is what makes
# the "does not touch the project's own file" assertion below able to fail.
printf 'node_modules/\n' > "$TMP/canon/.gitignore"
git -C "$TMP/canon" add .; git -C "$TMP/canon" commit -qm seed
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP/ws"

t_capture _oss_repo_root canonical
t_assert_eq "$TMP/canon" "$T_OUT" "canonical repo root resolves"
t_capture _oss_repo_root private_core
t_assert_rc 2 "an unconfigured repo key is rc 2, never a silent canonical default"
t_capture _oss_repo_root nonsense
t_assert_rc 2 "an unknown repo key is rc 2"

# spawn
t_capture oss_worktree_add canonical r0.s1.w1 "add-ticket" "HEAD"
t_assert_rc 0 "worktree_add ok"
WT="$T_OUT"
[ -d "$WT" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir not created"; }
t_assert_eq "$TMP/canon/.worktrees/r0.s1.w1" "$WT" "worktree path convention"
t_assert_eq "work/r0.s1.w1-add-ticket" "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" "work-item branch checked out"

# The worktree root lives inside the repo, so spawning must not leave the repo
# reporting itself dirty. Assert the OUTCOME - a fully empty status - not merely
# that an ignore line was written: a line in the wrong file or with the wrong
# pattern still passes a grep and still leaves `?? .worktrees/` behind. The
# seeded .gitignore below is TRACKED, which is what makes this assertion
# meaningful: an implementation that appends to it instead of to
# .git/info/exclude leaves ` M .gitignore` and fails right here.
t_assert_eq "" "$(git -C "$TMP/canon" status --porcelain)" "spawning leaves the repo status completely clean"
t_assert_eq "node_modules/" "$(cat "$TMP/canon/.gitignore")" "spawning does not touch the .gitignore the PROJECT owns"
t_capture oss_worktree_add canonical r0.s1.w1 "add-ticket" "HEAD"
t_assert_rc 8 "spawning onto an existing worktree path is refused rc 8"
# Idempotent: repeated spawns must not append a duplicate ignore entry.
t_assert_eq "1" "$(grep -cxF '.worktrees/' "$TMP/canon/.git/info/exclude")" "the ignore entry is written exactly once"

# resolve + list
t_capture oss_worktree_resolve canonical r0.s1.w1
t_assert_eq "$WT" "$T_OUT" "worktree_resolve finds it"
t_capture oss_worktree_resolve canonical r0.s1.w9
t_assert_rc 1 "resolve on an unknown work item is rc 1"
t_capture oss_worktree_list canonical
t_assert_contains "$T_OUT" "r0.s1.w1" "worktree_list names it"

# D9: a DIRTY worktree must halt, never be force-discarded.
echo scratch > "$WT/uncommitted.txt"
t_capture oss_worktree_remove canonical r0.s1.w1
t_assert_rc 8 "removing a dirty worktree is refused rc 8"
t_assert_contains "$T_OUT" "uncommitted" "the refusal names the reason"
[ -f "$WT/uncommitted.txt" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: remove DISCARDED uncommitted work"; }

# clean removal takes the branch with it (the close ceremony asserts no work-* branch remains).
rm "$WT/uncommitted.txt"
t_capture oss_worktree_remove canonical r0.s1.w1
t_assert_rc 0 "clean worktree removes"
[ -d "$WT" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir survived removal"; } || T_PASS=$((T_PASS+1))
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s1.w1-add-ticket \
  && { T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item branch survived removal"; } || T_PASS=$((T_PASS+1))

cd /; rm -rf "$TMP"
t_summary
```

Run: `bash ossify/tests/test-worktree.sh` → FAIL (no such file).

- [ ] **Step 2: Implement** — create `ossify/lib/worktree.sh`:

```bash
#!/usr/bin/env bash
# Per-work-item worktrees. rc 8 = git/worktree operation failure (see the plan's
# rc-taxonomy note); rc 2 = usage / unknown repo key; rc 1 = not found.
#
# D4: every entry point takes a REPO KEY as its first argument, even though only
# `canonical` resolves today. `target_repo` has been written into state since B4
# with no reader; this is its first. Plan D adds `private_core` by extending
# _oss_repo_root alone - retrofitting the parameter later would mean changing
# every call site and every path-shape assertion in this file.

_oss_repo_root() { # $1=repo-key
  local key="${1:-canonical}" root
  case "$key" in
    canonical|ai_workspace|private_core) ;;
    *) echo "oss: unknown repo key '$key' (canonical|ai_workspace|private_core)" >&2; return 2 ;;
  esac
  root="$(oss_manifest_get ".${key}.root" 2>/dev/null)" || root=""
  # An unconfigured key must NOT fall back to canonical: silently building a
  # private_core worktree inside the public repo is precisely the leak the
  # companion spec exists to prevent.
  [ -n "$root" ] && [ "$root" != "null" ] \
    || { echo "oss: repo '$key' is not configured in the pairing manifest" >&2; return 2; }
  printf '%s\n' "$root"
}

oss_worktree_dir() { # $1=repo-key
  local root; root="$(_oss_repo_root "$1")" || return $?
  printf '%s\n' "$root/.worktrees"
}

oss_worktree_add() { # $1=repo-key $2=work-item-id $3=slug $4=base-ref ; echoes abs path
  local key="$1" wi="$2" slug="$3" base="${4:-HEAD}" root dir path branch
  root="$(_oss_repo_root "$key")" || return $?
  dir="$root/.worktrees"; path="$dir/$wi"
  branch="$(oss_id_work_item_branch "$wi" "$slug")"
  [ -e "$path" ] && { echo "oss: worktree already exists at $path" >&2; return 8; }
  mkdir -p "$dir" || return 8
  _oss_worktree_ignore "$root" || true
  # NOT `2>&1`: this function's STDOUT IS ITS RETURN VALUE (the abs path), so
  # merging git's stderr into stdout makes any warning git decides to emit become
  # part of the path the caller captures. `-q` is silent on success today, which
  # is exactly what makes this the kind of latent bug that surfaces years later
  # on someone else's git version or with a chatty hook installed. Let stderr be
  # stderr.
  if ! git -C "$root" worktree add -q -b "$branch" "$path" "$base"; then
    echo "oss: git worktree add failed for $wi (branch $branch, base $base)" >&2
    return 8
  fi
  printf '%s\n' "$path"
}

# The worktree root lives INSIDE the repo, so without this every spawn leaves
# `?? .worktrees/` in the canonical repo's status - a dirty tree ossify itself
# created, in the very repo whose cleanliness the close ceremony checks. The
# leading dot already keeps most test runners out (pytest's default
# `norecursedirs` includes `.*`; `go test ./...` skips dirs beginning with `.`
# or `_`), so this closes the reporting half, not a demo-integrity hole.
#
# `.git/info/exclude`, NOT `.gitignore` - and this was verified empirically, not
# reasoned about. `.gitignore` is TRACKED in any real project, so appending to it
# leaves ` M .gitignore` and produces exactly the dirty tree this exists to
# prevent (measured: appending to a tracked .gitignore yields ` M .gitignore`;
# writing to .git/info/exclude yields an EMPTY status). `info/exclude` is
# repo-local, never tracked, never pushed, and is the idiomatic place for an
# ignore the tool owns rather than the project. Never edit a file the project
# owns to make a tool's own artifact disappear.
_oss_worktree_ignore() { # $1=repo-root ; best-effort, never fatal
  local ex="$1/.git/info/exclude"
  # A repo whose `.git` is a FILE is itself a worktree; it has no info/ of its
  # own and inherits the parent's excludes, so there is nothing to do.
  [ -d "$1/.git" ] || return 0
  mkdir -p "$1/.git/info" || return 1
  [ -f "$ex" ] && grep -qxF '.worktrees/' "$ex" && return 0
  printf '%s\n' '.worktrees/' >> "$ex" 2>/dev/null || return 1
}

oss_worktree_resolve() { # $1=repo-key $2=work-item-id
  local root path; root="$(_oss_repo_root "$1")" || return $?
  path="$root/.worktrees/$2"
  [ -d "$path" ] || { echo "oss: no worktree for '$2' under $root/.worktrees" >&2; return 1; }
  printf '%s\n' "$path"
}

oss_worktree_list() { # $1=repo-key
  local root; root="$(_oss_repo_root "$1")" || return $?
  [ -d "$root/.worktrees" ] || return 0
  { ls -1 "$root/.worktrees" 2>/dev/null || true; }
}

# D9: HALT on a dirty worktree; never `--force`. The source retries with --force
# (discarding uncommitted work) and swallows the branch delete with `|| true`,
# while its own skill prose promises a halt and the close ceremony asserts no
# work-* branch survives. Both halves are fixed here.
oss_worktree_remove() { # $1=repo-key $2=work-item-id
  local key="$1" wi="$2" root path branch dirty
  root="$(_oss_repo_root "$key")" || return $?
  path="$(oss_worktree_resolve "$key" "$wi")" || return $?
  dirty="$(git -C "$path" status --porcelain 2>/dev/null)" || dirty=""
  if [ -n "$dirty" ]; then
    echo "oss: worktree $path has uncommitted changes - refusing to remove it" >&2
    printf '%s\n' "$dirty" >&2
    return 8
  fi
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=""
  git -C "$root" worktree remove "$path" || { echo "oss: git worktree remove failed for $path" >&2; return 8; }
  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    # `-d`, NOT `-D`. -D force-deletes an UNMERGED branch, destroying every
    # commit the implementer made. The close ceremony merges work/<wi> back into
    # the spine branch first (T9), so by the time remove runs the branch IS
    # merged and -d succeeds. If it does not, that is the signal that something
    # upstream failed to merge - surface it, never force past it.
    git -C "$root" branch -d "$branch" >/dev/null 2>&1 \
      || { echo "oss: worktree removed but branch '$branch' is not merged - refusing to force-delete it; merge or abandon it explicitly" >&2; return 8; }
  fi
}
```

Add the dispatcher wrappers to `ossify/lib/commands.sh`:

```bash
oss_cmd_repo_root()        { _oss_repo_root "${1:-canonical}"; }
oss_cmd_worktree_add()     { oss_worktree_add "$1" "$2" "$3" "${4:-HEAD}"; }
oss_cmd_worktree_resolve() { oss_worktree_resolve "$1" "$2"; }
oss_cmd_worktree_remove()  { oss_worktree_remove "$1" "$2"; }
oss_cmd_worktree_list()    { oss_worktree_list "${1:-canonical}"; }
```

- [ ] **Step 3: Run, mutation-test, commit**

Run: `bash ossify/tests/test-worktree.sh && bash ossify/tests/run-all.sh` → green.

Mutation test — **four mutations, each must produce its own named RED**, and line-address every one (a global `sed` that also hits an identical line elsewhere produces a meaningless result):

| # | Mutation | Must go RED |
|---|---|---|
| 1 | dirty guard → `if false; then` | `removing a dirty worktree is refused rc 8` **and** `remove DISCARDED uncommitted work` |
| 2 | `branch -d` → `branch -D` | `work-item branch survived removal` must stay green, so instead assert the refusal: make the branch unmerged (commit in the worktree, then remove) and confirm `-D` silently destroys it while `-d` refuses. If no assertion distinguishes them, the D9 half of this task is untested. |
| 3 | `_oss_worktree_ignore` → `return 0` immediately | `spawning leaves the repo status completely clean` |
| 4 | `_oss_worktree_ignore` writes to `$1/.gitignore` instead of `$1/.git/info/exclude` | `spawning does not touch the .gitignore the PROJECT owns` **and** `spawning leaves the repo status completely clean` |

Mutation 1's second assertion is the one that matters — it asserts a *behaviour* (uncommitted work survived), not a return code. Mutation 2 is the one most likely to be skipped and is exactly the D9 defect this task exists to fix.

**Before believing any mutation result, confirm the mutated code still RUNS on its happy path.** A mutation that breaks bash syntax fails the unit outright and throws unrelated assertions RED, which reads as coverage and is not; and no RED at all means the guard is untested, not that it is correct. Restore each and re-confirm green before the next.

```bash
git add ossify/lib/worktree.sh ossify/lib/commands.sh ossify/tests/test-worktree.sh
git commit -m "feat(ossify): repo-parameterized worktree layer

First consumer of target_repo, which has been written into state since B4 with
no reader. Every entry point takes a repo key now even though only canonical
resolves — Plan D adds private_core by extending _oss_repo_root alone, whereas
retrofitting the parameter later would touch every call site and path assertion.
An unconfigured key is rc 2, never a silent canonical fallback: building a
private_core worktree inside the public repo is the leak the companion spec
exists to prevent.

remove() halts on a dirty worktree and reports a failed branch delete. The
source force-removes (discarding uncommitted work) and swallows branch -D,
contradicting both its own prose and the close ceremony's post-condition.

rc 8 = git/worktree failure, a deliberate one-time taxonomy extension.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks for the task reviewer:**
1. **Who calls this?** Nothing calls the worktree layer until T7/T9. Confirm the staging is named in those tasks' briefs.
2. Does an unconfigured `private_core` genuinely refuse rather than fall back? This is a leak-shaped failure, so test it directly.
3. Does `remove` ever discard uncommitted work on any path, including a `git worktree remove` that partially succeeds?
4. Is the work-item branch namespace genuinely distinct from the spine branch? Two work items in one spine must not collide.
5. Strict mode: does every `git` call survive `set -euo pipefail` through `bin/oss`? Note `oss_worktree_list`'s guarded `ls`.
6. Does rc 8 collide with anything in the existing taxonomy? Grep the libs for `return 8`.
7. **Does `oss_worktree_add`'s stdout stay clean?** Its stdout *is* its return value — the caller captures the path. Any git chatter merged into stdout corrupts it. Verify no redirection puts stderr on stdout, and check what the function returns when git emits a warning (simulate one with a `post-checkout` hook that echoes).
8. **Does spawning leave the repo dirty?** `git -C <canonical> status --porcelain` must not report `.worktrees/` after a spawn, and the ignore entry must be written exactly once across repeated spawns. Confirm the entry is appended, never rewriting a `.gitignore` the project already owns.
9. **Is the D9 refusal actually tested?** `-d` vs `-D` only differ on an **unmerged** branch. A test that removes a worktree whose branch has no new commits passes with either, so it proves nothing. Confirm an unmerged-branch case exists and that `remove` refuses rather than destroying commits.

---

### Task 5 (C1-5): `lib/verify.sh` — per-AC verification, RED gate, report cross-check, zero-tests guard

**Context:** The per-work-item gate (spec §6, third bullet) has no ossify counterpart. **Per D2 this task deliberately excludes machine-checkable-rule evaluation** — the source's entry point `sd_rules_apply` does not exist, three of four rule families have no evaluator, and the one that does returns no violation on a canonically-authored `banned_imports` rule. C1's rule check is agent judgment against `03-code-patterns.md`; a correct mechanical evaluator lands in C2 beside rule authoring.

This task also owns the canonical **zero-tests guard**, superseding the weaker private one in `demo.sh` (which T6 rewires).

**AC grammar** — work-item `auto:` AC lines live as markdown in `spec.md` and are a *different* surface from the demo ledger's structured JSON. Keep them different; do not unify:

```
- [ ] AC-1 auto: `pytest tests/test_x.py::test_y -x` → expected: exit 0
- [ ] AC-2 auto: `grep -q "banned" src/x.py` → expected: exit 1
- [ ] AC-3 auto: `cargo test --lib` → expected: output contains 42 passed
```

The arrow is the literal U+2192 `→`, **not** ASCII `->`; the command is backtick-wrapped and the backticks are stripped before execution (leaving them in makes the shell run the command as a command substitution); the `contains` operand is unquoted and matched with `grep -F`.

**Files:** Create `ossify/lib/verify.sh`, `ossify/tests/test-verify.sh`. Modify `ossify/lib/commands.sh`.

**Interfaces:**
- Produces: `oss_verify_parse_acs <spec-file>` (TSV: `label<TAB>command<TAB>expectation`); `oss_verify_auto_step <workdir> <command> <expectation>` (rc 0 pass, 1 fail, 2 malformed); `oss_verify_zero_tests_guard <command>` reading output on **stdin** (rc 0 vacuous, 1 not); `oss_verify_redgate <workdir> <command> <expectation>` (rc 0 RED, 1 already-GREEN, 2 errored/uninvocable); `oss_verify_report_cross_check <report-file> <spec-file>`. Dispatcher: `oss verify_acs|verify_step|redgate|zero_tests_guard|report_cross_check`.

- [ ] **Step 1: Write the failing test** — create `ossify/tests/test-verify.sh`:

```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor verify; do . "$HERE/../lib/$lib.sh"; done
TMP="$(mktemp -d)"; SPEC="$TMP/spec.md"

cat > "$SPEC" <<'EOF'
## 5. Acceptance criteria
- [ ] AC-1 auto: `true` → expected: exit 0
- [ ] AC-2 auto: `false` → expected: exit 1
- [ ] AC-3 auto: `echo 42 passed` → expected: output contains 42 passed
- [X] AC-10 auto: `true` → expected: exit 0
- [ ] AC-4 user: open the dashboard and see the new card
EOF

t_capture oss_verify_parse_acs "$SPEC"
t_assert_eq "4" "$(printf '%s\n' "$T_OUT" | grep -c .)" "parses 4 auto ACs and skips the user: row"
t_assert_contains "$T_OUT" "AC-1" "labels captured"
# A checked, UPPERCASE-X checkbox must still yield a bare label. Anchoring the
# extraction on a case class instead of the checkbox silently emits the whole
# line as the label, which report_cross_check then fails to find.
t_assert_contains "$T_OUT" "AC-10	true	exit 0" "an uppercase [X] checkbox still yields a bare label"
# Backticks MUST be stripped: an unstripped command is run as a command
# substitution by the caller's eval, executing something entirely different.
case "$T_OUT" in *'`'*) T_FAIL=$((T_FAIL+1)); echo "FAIL: backticks survived the parse";; *) T_PASS=$((T_PASS+1));; esac

t_capture oss_verify_auto_step "$TMP" "true" "exit 0";           t_assert_rc 0 "exit 0 expectation passes"
t_capture oss_verify_auto_step "$TMP" "false" "exit 0";          t_assert_rc 1 "exit 0 expectation fails on rc 1"
t_capture oss_verify_auto_step "$TMP" "false" "exit 1";          t_assert_rc 0 "exit 1 expectation passes on rc 1"
t_capture oss_verify_auto_step "$TMP" "echo 42 passed" "output contains 42 passed"; t_assert_rc 0 "contains expectation passes"
t_capture oss_verify_auto_step "$TMP" "echo nope" "output contains 42 passed";      t_assert_rc 1 "contains expectation fails"
t_capture oss_verify_auto_step "$TMP" "true" "exit banana";      t_assert_rc 2 "a malformed expectation is rc 2, never a silent pass"
t_capture oss_verify_auto_step "$TMP" "true" "whatever";         t_assert_rc 2 "an unrecognized expectation form is rc 2"

# zero-tests guard: BOTH conditions required (recognized runner AND zero-tests output).
printf 'collected 0 items\n' | oss_verify_zero_tests_guard "pytest tests/"; t_assert_eq "0" "$?" "vacuous green detected"
printf 'collected 9 items\n' | oss_verify_zero_tests_guard "pytest tests/"; t_assert_eq "1" "$?" "a real run is not vacuous"
printf 'collected 0 items\n' | oss_verify_zero_tests_guard "echo hi";       t_assert_eq "1" "$?" "a non-runner merely MENTIONING a zero-tests phrase is not vacuous"

# RED gate: rc 1 (already GREEN) is the ONLY hard block; rc 2 (errored) is advisory.
t_capture oss_verify_redgate "$TMP" "false" "exit 0";            t_assert_rc 0 "a failing command is RED"
t_capture oss_verify_redgate "$TMP" "true" "exit 0";             t_assert_rc 1 "an already-passing command is already-GREEN"
t_capture oss_verify_redgate "$TMP" "nosuchcommand_xyz" "exit 0";t_assert_rc 2 "an uninvocable command is errored, not already-GREEN"

# report cross-check: every auto AC in the spec must appear in the report.
cat > "$TMP/report.md" <<'EOF'
## 3. ACs — verification status
| AC | Status |
|---|---|
| AC-1 | pass |
| AC-2 | pass |
EOF
t_capture oss_verify_report_cross_check "$TMP/report.md" "$SPEC"
t_assert_rc 1 "cross-check fails when the report omits an AC"
t_assert_contains "$T_OUT" "AC-3" "...and names the missing one"
printf '| AC-3 | fail |\n' >> "$TMP/report.md"
t_capture oss_verify_report_cross_check "$TMP/report.md" "$SPEC"
t_assert_rc 0 "cross-check passes when every auto AC is accounted for"

rm -rf "$TMP"; t_summary
```

**And a dispatcher-path block — this is not optional here.** The plan's Global Constraints require testing through `bin/oss`, and this task is the one where a sourced-only suite is actively misleading: sourced tests run *without* `set -e`, so the errexit-abort described above is **structurally invisible** to every assertion above. Append, driving the real binary:

```bash
OSSB="$HERE/../bin/oss"
t_capture bash "$OSSB" verify_step "$TMP" "false" "exit 1"
t_assert_rc 0 "dispatcher: a command that exits 1 against 'exit 1' PASSES (does not abort under set -e)"
t_capture bash "$OSSB" verify_step "$TMP" "false" "exit 0"
t_assert_rc 1 "dispatcher: a failing AC returns 1 with a diagnostic, not a strict-mode abort"
t_assert_contains "$T_OUT" "wanted" "dispatcher: the failing arm emitted its rc diagnostic rather than dying silently"
t_capture bash "$OSSB" verify_step "$TMP" "true" "whatever"
t_assert_rc 2 "dispatcher: malformed expectation is rc 2"
t_capture bash "$OSSB" redgate "$TMP" "false" "exit 0"
t_assert_rc 0 "dispatcher: a genuinely failing command is RED (rc 0), not an abort"
t_capture bash "$OSSB" redgate "$TMP" "true" "exit 0"
t_assert_rc 1 "dispatcher: already-GREEN is the hard block"
t_capture bash "$OSSB" redgate "$TMP" "nosuchcommand_xyz" "exit 0"
t_assert_rc 2 "dispatcher: an uninvocable command is advisory rc 2, not 127"
```

Run → FAIL.

- [ ] **Step 2: Implement** — create `ossify/lib/verify.sh`:

```bash
#!/usr/bin/env bash
# Per-work-item verification (spec §6). Deterministic mechanical facts only:
# did a command exit as declared, did the report account for every AC, did a
# recognized runner execute zero tests. Judgment - is this deviation acceptable,
# does this change violate a code pattern - stays in skill prose (D2).

# Extract `auto:` AC rows. `user:` rows belong to the close ceremony, not here.
# Backticks are stripped: an unstripped command reaches the caller as a command
# substitution and executes something other than what the spec declares.
oss_verify_parse_acs() { # $1=spec-file ; TSV label \t command \t expectation
  [ -f "$1" ] || { echo "oss: spec not found: $1" >&2; return 2; }
  { grep -E '^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*AC-[0-9]+[[:space:]]+auto:' "$1" || true; } \
  | while IFS= read -r line; do
      local label cmd exp rest
      # Anchor the label extraction on the CHECKBOX, not on a case class. An
      # earlier form used `^[^A-Z]*(AC-[0-9]+)`, which silently breaks on the
      # `- [X]` checkbox this function's own grep accepts: [^A-Z]* halts at the
      # uppercase X, the anchored match fails, and sed passes the WHOLE LINE
      # through as the label - which report_cross_check then hunts for in the
      # report and never finds, failing a correct report.
      label="$(printf '%s' "$line" | sed -E 's/^.*\[[ xX]\][[:space:]]*(AC-[0-9]+).*/\1/')"
      rest="${line#*auto:}"
      cmd="$(printf '%s' "$rest" | sed -E 's/^[^`]*`([^`]*)`.*/\1/')"
      exp="$(printf '%s' "$rest" | sed -E 's/.*→[[:space:]]*expected:[[:space:]]*//')"
      exp="${exp#"${exp%%[![:space:]]*}"}"; exp="${exp%"${exp##*[![:space:]]}"}"
      [ -n "$cmd" ] && printf '%s\t%s\t%s\n' "$label" "$cmd" "$exp"
    done
}

# Run one AC in $1 and check it. EVERY arm fails closed: an unrecognized or
# malformed expectation is rc 2, never a pass. This is the ledger.sh lesson -
# a `case` with no default arm counted an unknown expectation as green.
oss_verify_auto_step() { # $1=workdir $2=command $3=expectation ; 0 pass, 1 fail, 2 malformed
  local dir="$1" cmd="$2" exp="$3" out rc want
  case "$exp" in
    exit\ *)
      want="${exp#exit }"
      case "$want" in ''|*[!0-9]*)
        echo "oss: malformed expectation '$exp' ('exit' takes digits only)" >&2; return 2;; esac ;;
    output\ contains\ ?*) ;;
    *) echo "oss: unrecognized expectation '$exp' (grammar: 'exit <n>' | 'output contains <str>')" >&2; return 2 ;;
  esac
  # errexit guard, and it is on the NORMAL path — this function exists to run
  # commands that are EXPECTED to exit nonzero (a failing AC is the ordinary
  # case). Unguarded, `out="$(…)"` under bin/oss's `set -euo pipefail` aborts
  # the dispatcher before this function can return its documented rc, so a
  # failing AC produces no diagnostic at all. Verified by repro. The `if`
  # form is used rather than demo.sh's `set +e; …; set -e` toggle, which the
  # A→B handoff's gotcha list explicitly warns against as fragile.
  if out="$(cd "$dir" && bash -c "$cmd" 2>&1)"; then rc=0; else rc=$?; fi
  case "$exp" in
    exit\ *)
      [ "$rc" -eq "$want" ] || { printf '%s\n' "$out" | tail -5; return 1; } ;;
    output\ contains\ ?*)
      # `if ! pipeline` — NOT `pipeline | { … return 1; }`. See the idiom note
      # below: a `return` inside the brace group would exit only the subshell,
      # and this function would fall through to `return 0`, passing a demo line
      # whose output does not contain the expected string.
      if ! printf '%s' "$out" | grep -Fq -- "${exp#output contains }"; then
        printf '%s\n' "$out" | tail -5; return 1
      fi ;;
  esac
  # Vacuous green: only meaningful for a success expectation. Scoping matters -
  # a line legitimately expecting `exit 1` from a recognized runner is not
  # vacuous, and the unscoped form in demo.sh fails exactly that case.
  if [ "$exp" = "exit 0" ] && printf '%s' "$out" | oss_verify_zero_tests_guard "$cmd"; then
    echo "vacuous green: '$cmd' is a recognized test runner and executed zero tests" >&2
    return 1
  fi
  return 0
}

# rc 0 = vacuous. BOTH conditions required: the command must name a recognized
# runner AND the output must show a zero-tests result. Dropping the runner check
# would fail a legitimate demo line that merely prints a zero-tests phrase.
#
# IDIOM WARNING, and it is load-bearing here. `lib/id.sh:4-6` and the old
# `demo.sh:5,8` write this as `printf … | { grep -Eq … || return 1; }`, which is
# SAFE there only because the pipeline is the function's LAST command, so the
# function's exit status IS the pipeline's. It is NOT safe here: this function
# has two checks and a trailing `return 0`. The brace group is the last element
# of a pipeline and therefore runs in a SUBSHELL, so `return 1` exits the
# subshell, execution falls through, and the function returns 0 — reporting
# EVERY input as vacuous green and failing every `exit:0` demo line. Verified
# empirically. Use `pipeline || return 1` (the `||` binds outside the subshell).
oss_verify_zero_tests_guard() { # $1=command ; output on STDIN
  local out; out="$(cat)"
  printf '%s' "$1" | grep -Eq 'pytest|cargo test|npm test|npm run test|go test|jest|vitest|bash .*test|ctest|dotnet test' || return 1
  printf '%s' "$out" | grep -Eq 'collected 0 items|running 0 tests|0 passing|no tests to run|0 tests? ran|No tests found|testing: warning: no tests to run' || return 1
  return 0
}

# rc 0 RED (proceed) | rc 1 already-GREEN (the ONLY hard block) | rc 2 errored
# (ADVISORY - usually the test file is not authored yet, which is the expected
# starting state, so blocking on it would make the gate unusable).
oss_verify_redgate() { # $1=workdir $2=command $3=expectation
  local dir="$1" cmd="$2" exp="$3" rc
  # Same errexit guard, same reason — a RED gate probe expects failure, so the
  # nonzero exit IS the success case and must not kill the dispatcher.
  if ( cd "$dir" && bash -c "$cmd" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
  case "$rc" in 126|127) echo "red-gate: '$cmd' is not invocable here (rc $rc) - advisory, not a block" >&2; return 2 ;; esac
  if oss_verify_auto_step "$dir" "$cmd" "$exp" >/dev/null 2>&1; then
    echo "red-gate: '$cmd' ALREADY satisfies '$exp' before any implementation" >&2
    return 1
  fi
  return 0
}

# Every `auto:` AC in the spec must be accounted for in the report. Names the
# missing ones - "the report is incomplete" is not actionable.
oss_verify_report_cross_check() { # $1=report-file $2=spec-file
  [ -f "$1" ] || { echo "oss: report not found: $1" >&2; return 2; }
  local missing="" label
  while IFS="$(printf '\t')" read -r label _ _; do
    [ -n "$label" ] || continue
    # grep the file DIRECTLY. An earlier form piped the report into a `{ … }`
    # group - in bash the last element of a pipeline runs in a SUBSHELL, so
    # `missing` was mutated in a child and every accumulated label was lost:
    # the check reported "all ACs accounted for" no matter what the report said.
    # (Verified empirically: under bash the piped form yields missing=[]; under
    # zsh it yields the right answer, because zsh runs the last pipeline element
    # in the parent - which is exactly why run-all.sh forces `bash`.)
    # The trailing `|| assignment` is an OR-list and therefore errexit-exempt.
    grep -Eq "(^|[^A-Za-z0-9-])${label}([^0-9]|$)" "$1" || missing="$missing $label"
  done < <(oss_verify_parse_acs "$2")
  [ -z "$missing" ] || { echo "oss: report does not account for:$missing" >&2; return 1; }
  return 0
}
```

Dispatcher wrappers in `ossify/lib/commands.sh`:

```bash
oss_cmd_verify_acs()          { oss_verify_parse_acs "$1"; }
oss_cmd_verify_step()         { oss_verify_auto_step "$1" "$2" "$3"; }
oss_cmd_redgate()             { oss_verify_redgate "$1" "$2" "$3"; }
oss_cmd_zero_tests_guard()    { oss_verify_zero_tests_guard "$1"; }
oss_cmd_report_cross_check()  { oss_verify_report_cross_check "$1" "$2"; }
```

- [ ] **Step 3: Run, mutation-test, commit**

Run: `bash ossify/tests/test-verify.sh && bash ossify/tests/run-all.sh` → green.

Mutation test: delete the `*)` default arm from `oss_verify_auto_step`'s validation `case`. Expected RED on both malformed-expectation assertions. Restore, confirm green.

```bash
git add ossify/lib/verify.sh ossify/lib/commands.sh ossify/tests/test-verify.sh
git commit -m "feat(ossify): per-AC verification, RED gate, report cross-check, zero-tests guard

The per-work-item gate (spec §6). Deliberately EXCLUDES machine-checkable-rule
evaluation (plan decision D2): the source's documented entry point
sd_rules_apply does not exist, three of four rule families have no evaluator,
and the one that does returns no violation on a canonical banned_imports rule.
Rule checking is agent judgment against 03-code-patterns.md until C2 can build
a correct evaluator beside rule authoring.

Every expectation arm fails closed — the ledger.sh lesson. The zero-tests guard
is scoped to success expectations, so a line legitimately expecting exit 1 from
a recognized runner is not flagged vacuous (the unscoped form in demo.sh does
flag it; T6 rewires demo.sh to this one).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks for the task reviewer:**
1. **Who calls this?** Nothing until T7/T8 — verify the staging is named there.
2. Does `oss_verify_parse_acs` survive a `| while read` subshell? It uses a pipe deliberately (it only *emits*, accumulating nothing), but confirm no variable is expected to escape — this is handoff gotcha #4 and the shape is easy to get wrong on the next edit.
3. Are the backticks genuinely stripped, and does a command containing an embedded `→` or backtick parse correctly?
4. Is the zero-tests guard's scoping right in **both** directions — vacuous `exit 0` caught, legitimate `exit 1` from a runner not caught?
5. Is `rc 2` from the RED gate genuinely non-blocking, and `rc 1` genuinely blocking? Getting these backwards inverts the gate.
6. Does `oss_verify_report_cross_check` produce a false pass when the report mentions `AC-1` inside `AC-10`? Check the word-boundary regex.
7. Strict mode through `bin/oss` for every guarded `grep`.

---

### Task 6 (C1-6): Demo runner — composition root, `user:` surfacing, close records

**Context:** Three defects and two gaps. `oss_demo_run_auto` runs `bash -c "$cmd"` in **the caller's cwd** (demo.sh:26); §6.1 binds the demo to the canonical post-merge state and companion §4.3 binds it to the composition root, so a demo run from the AI workspace measures the wrong tree. The vacuous-green guard at demo.sh:53 is **unscoped** — it fires after the `case` on every expectation form, so a line legitimately expecting `exit:1` from a recognized runner is failed as vacuous. `oss demo_run` executes only `type=="auto"` lines, so nothing surfaces the `user:` journey lines the close ceremony must walk. And the run writes **nothing** to state, so there is no durable per-close record.

**The CWD trap, which is why the `cd` is in a subshell:** `oss_manifest_discover` walks up from `$PWD` (manifest.sh:21-30), so any `oss` call made after the process has `cd`-ed into a target repo silently resolves a different manifest — or none. scaffold-dev hit exactly this with `review_gate_resolve` defaulting to `off` and skipping an opted-in gate. Every path is resolved **before** the first `cd`, and each command runs in `( cd … && … )` so the process cwd is never mutated.

**Files:** Modify `ossify/lib/demo.sh`, `ossify/lib/state.sh` (one op), `ossify/lib/commands.sh`, `ossify/tests/test-demo-runner.sh`.

⚠ **Cross-task hazard 1 — `oss demo_run` now needs a manifest where it never did.** The explicit-workdir argument covers callers that can pass one, but the **dispatcher path cannot**: `test-integration-planning.sh:88` (`oss_cmd_demo_run`) and `:158` (`"$OSS" demo_run`) both deliberately omit every argument — that file exists to prove the arg-omitted `$OSS_STATE_FILE` resolution works — and both assert `PASS 1 lines`. With no manifest on the walk-up path, `_oss_repo_root canonical` refuses and both go red. **No test in the repo has a pairing manifest** (verified).

So this task must **add a manifest fixture** to the three affected files, exactly as `test-worktree.sh` builds one:

```bash
mkdir -p "$TMP/.workspace" "$TMP/canon"
cat > "$TMP/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP"
```

> **Fixture corrected 2026-08-01 — the manifest goes at `$TMP/.workspace/`, NOT `$TMP/ws/.workspace/`, and the `cd` must come EARLY.** Measured: `run-all.sh` does not `cd`, so every test inherits the caller's cwd (the repo root), and `oss_manifest_require` there is rc 1 — no manifest on the walk-up path. `oss_manifest_discover` walks **up** from `$PWD`, so a manifest under `$TMP/ws/` is invisible from `$TMP`, which directly contradicts Step 1's own `cd "$TMP"`. Rooting the workspace at `$TMP` makes the manifest discoverable from `$TMP` and everything beneath it, so both work.
>
> **The `cd` must happen immediately after `TMP="$(mktemp -d)"`, before the first runner call.** In `test-demo-runner.sh` **all eight** existing `oss_demo_run_auto "$S"` calls (lines 10, 14, 18, 22, 38, 60, 69) omit the workdir argument and run long before Step 1's new block; without an early `cd` into the fixture they resolve no manifest, `_oss_repo_root canonical` refuses rc 2, and all eight go red. `$TMP/canon` must also exist before the first call — the runner refuses a non-existent workdir.
>
> End these files with `cd /` before `rm -rf "$TMP"` (the shape `test-worktree.sh` already uses); deleting the cwd out from under the shell is avoidable.

This *preserves* each file's intent — the state-file argument stays omitted, so the `$OSS_STATE_FILE` precedence assertions still prove what they were written to prove; only the **workdir** now resolves through the manifest. Affected: `tests/test-integration-planning.sh` (both sections), `tests/test-integration.sh:19`, `tests/test-demo-runner.sh`. **Add all three to this task's Files list**, and say plainly in the commit message that `oss demo_run` now requires a manifest — that is a behavioural change, not a refactor.

⚠ **Cross-task hazard 2 — the lib source lists.** `demo.sh` gains calls into `verify.sh` (T5) and `worktree.sh` (T4). `bin/oss` globs `lib/*.sh` so the dispatcher is fine, but test files hardcode their source lists and will die with `command not found`.

> **List re-measured 2026-08-01 — the earlier five-file list was both too long and too short, and the criterion was wrong.** It is not "sources `demo.sh`" (eight files do now) but **"CALLS the demo runner"**: shell function bodies are not evaluated at source time, so a file that sources `demo.sh` and never invokes it cannot break. Exactly **three** files call it, and they are the same three that need the manifest fixture above:
>
> | File | Runner calls | Needs `verify` + `worktree` |
> |---|---|---|
> | `tests/test-demo-runner.sh:4` (explicit dotted list) | 8 | **yes** |
> | `tests/test-integration-planning.sh:50` (`for lib in …`) | 3 | **yes** |
> | `tests/test-integration.sh:5` (explicit dotted list) | 1 | **yes** |
>
> **No change needed**, despite sourcing `demo.sh`: `test-migration.sh:4` (which the earlier list omitted entirely), `test-dispatcher-ops.sh:4` and `test-spine-planning.sh:15` (both of which it wrongly included), plus `test-worktree.sh:4` and `test-verify.sh:4` — the two files T4 and T5 added after that list was written, which is precisely the drift the note below predicted. `test-release-planning.sh:4` does not source `demo` at all.
>
> Leave the five alone rather than adding libs they never use, but **any new test that calls the runner must source `verify` and `worktree`** — say so in a comment beside each of the three lists you do edit, so the next author does not have to rediscover the criterion.

Verify with `grep -rn 'for lib in\|lib/demo.sh' ossify/tests/` **before** editing, not after — and cross-check it against which files actually *call* the runner, because that grep over-reports. A new caller added between now and execution fails the same way.

**Interfaces:**
- Produces: `oss_demo_workdir <state>`; `oss_demo_run_auto <state>` (now repo-rooted, records); `oss_demo_user_lines <state> [spine]`; `oss_demo_record_close <state> <scope> <id> <passed> <count> <notes>`. Dispatcher: `oss demo_run`, `oss demo_user_lines`, `oss demo_record`.
- Consumes: `oss_verify_zero_tests_guard` (T5), `_oss_repo_root` (T4).

- [ ] **Step 1: Write the failing tests** — append to `ossify/tests/test-demo-runner.sh`:

```bash
# The runner executes in the COMPOSITION ROOT (canonical when unset), not the
# caller's cwd. A relative-path demo command is the whole point of the ledger.
mkdir -p "$TMP/canon"; echo marker > "$TMP/canon/marker.txt"
t_capture oss_ledger_add_auto "$S" r0.s1 "marker present" "test -f marker.txt" "exit:0"
cd "$TMP"   # deliberately NOT the demo working dir
# Explicit workdir: this suite has no pairing manifest, so the manifest leg
# cannot resolve. That is the whole reason oss_demo_workdir takes an explicit
# argument — see the note on its precedence.
t_capture oss_demo_run_auto "$S" "$TMP/canon"
t_assert_rc 0 "a relative-path demo command resolves against the given workdir, not \$PWD"
t_assert_eq "$TMP" "$PWD" "the runner's subshell cd did NOT mutate the process cwd"

# The unscoped vacuous-green guard used to fail this: a recognized runner that
# legitimately exits 1 is NOT vacuous green.
t_capture oss_ledger_add_auto "$S" r0.s1 "suite fails as expected" "bash -c 'echo 0 passing; exit 1'" "exit:1"
t_capture oss_demo_run_auto "$S" "$TMP/canon"
t_assert_rc 0 "a recognized runner legitimately expecting exit:1 is not flagged vacuous"

# user: lines are surfaceable, and scopeable to one spine.
t_capture oss_ledger_add_user "$S" r0.s1 "reschedule a delivery and see the new window" "the slot moves"
t_capture oss_ledger_add_user "$S" r0.s2 "cancel an order from the ticket" "the order clears"
t_capture oss_demo_user_lines "$S" r0.s1
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "user lines scope to one spine (the §6.1 spine-close set)"
t_capture oss_demo_user_lines "$S"
t_assert_eq "2" "$(printf '%s' "$T_OUT" | jq 'length')" "unscoped returns every accumulated user line (the §6.2 walkthrough set)"

# a close leaves a durable record.
t_capture oss_demo_record_close "$S" spine r0.s1 true 2 "clean"
t_assert_rc 0 "close record written"
t_capture oss_state_read "$S" '.close_records[-1].scope'; t_assert_eq "spine" "$T_OUT" "scope recorded"
t_capture oss_state_read "$S" '.close_records[-1].demo_passed'; t_assert_eq "true" "$T_OUT" "demo outcome recorded"
```

- [ ] **Step 2: Add the op** — in `_oss_apply_op`, before `*)`:

```bash
    add_close_record) jq --argjson p "$payload" '.close_records += [$p]' ;;
```

- [ ] **Step 3: Rewrite the runner** — in `ossify/lib/demo.sh`, delete the private `_oss_demo_zero_tests` / `_oss_demo_is_runner` pair (superseded by T5's guard) and replace `oss_demo_run_auto` with:

```bash
# §6.1 + companion §4.3: the demo runs against the real product build — the
# composition root when one is declared, canonical otherwise. Resolved ONCE,
# BEFORE any cd, because oss_manifest_discover walks up from $PWD and every
# manifest/state read after a cd would otherwise resolve somewhere else.
# Precedence is EXPLICIT > composition_root > canonical root — the same
# explicit-beats-derived shape as _oss_resolve_state. The explicit leg is not a
# convenience: without it this function would require a pairing manifest, and
# every existing demo test (test-demo-runner.sh, test-integration.sh) runs
# against a bare temp state with no manifest on the walk-up path. A
# manifest-only resolver would break them all, and "fall back to $PWD when there
# is no manifest" would silently reinstate the very bug this task fixes.
oss_demo_workdir() { # $1=state-file [$2=explicit-workdir]
  local sf="$1" explicit="${2:-}" root comp
  [ -n "$explicit" ] && { printf '%s\n' "$explicit"; return 0; }
  comp="$(jq -r '.project.composition_root // empty' "$sf" 2>/dev/null)" || comp=""
  root="$(_oss_repo_root canonical)" || return $?
  if [ -n "$comp" ]; then
    case "$comp" in /*) printf '%s\n' "$comp" ;; *) printf '%s\n' "$root/$comp" ;; esac
  else
    printf '%s\n' "$root"
  fi
}

oss_demo_run_auto() { # $1=state-file [$2=explicit-workdir]
  local sf="$1" wd n i line id text cmd expected want out rc passed=0
  wd="$(oss_demo_workdir "$sf" "${2:-}")" || return 1
  [ -d "$wd" ] || { echo "oss: demo working dir does not exist: $wd" >&2; return 1; }
  n="$(jq '[.demo_ledger[] | select(.type=="auto" and (.status=="active" or .status=="quarantined"))] | length' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read state $sf" >&2; return 1; }
  i=0
  while [ "$i" -lt "$n" ]; do
    line="$(jq -c "[.demo_ledger[] | select(.type==\"auto\" and (.status==\"active\" or .status==\"quarantined\"))][$i]" "$sf")"
    id="$(printf '%s' "$line" | jq -r '.id')"
    text="$(printf '%s' "$line" | jq -r '.text')"
    if [ "$(printf '%s' "$line" | jq -r '.status')" = "quarantined" ]; then
      echo "SKIP $id (quarantined) - $text"; i=$((i+1)); continue
    fi
    cmd="$(printf '%s' "$line" | jq -r '.command')"
    expected="$(printf '%s' "$line" | jq -r '.expected')"
    # Subshell cd: the process cwd is never mutated, so the NEXT iteration's
    # jq reads and any later manifest resolution still see the original $PWD.
    set +e; out="$( cd "$wd" && bash -c "$cmd" 2>&1 )"; rc=$?; set -e 2>/dev/null || true
    case "$expected" in
      exit:*)
        want="${expected#exit:}"
        case "$want" in ''|*[!0-9]*)
          echo "FAIL $id - $text (malformed expected '$expected': 'exit:' takes digits only)"; return 1;; esac
        if [ "$rc" -ne "$want" ]; then
          echo "FAIL $id - $text (rc=$rc, wanted $want)"; printf '%s\n' "$out" | tail -5; return 1
        fi
        # Vacuous-green is checked ONLY for a success expectation. The previous
        # unscoped placement ran after every arm, so a line legitimately
        # expecting exit:1 from a recognized runner was failed as vacuous.
        if [ "$want" = "0" ] && printf '%s' "$out" | oss_verify_zero_tests_guard "$cmd"; then
          echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
        fi ;;
      contains:?*)
        case "$out" in *"${expected#contains:}"*) ;; *)
          echo "FAIL $id - $text (output missing '${expected#contains:}')"; printf '%s\n' "$out" | tail -5; return 1;; esac ;;
      *)
        echo "FAIL $id - $text (unrecognized expected '$expected'; the grammar is exit:<n> | contains:<str>)"; return 1 ;;
    esac
    passed=$((passed+1)); i=$((i+1))
  done
  echo "PASS $passed lines"
}

# §6.1 spine close walks the CLOSING SPINE'S OWN user lines; §6.2 release close
# walks EVERY accumulated one. One verb, scoped by an optional spine argument.
oss_demo_user_lines() { # $1=state-file [$2=spine]
  if [ -n "${2:-}" ]; then
    jq --arg s "$2" '[.demo_ledger[] | select(.type=="user" and .status=="active" and .source_spine==$s)]' "$1"
  else
    jq '[.demo_ledger[] | select(.type=="user" and .status=="active")]' "$1"
  fi
}

oss_demo_record_close() { # $1=state $2=scope $3=id $4=passed(true|false) $5=line-count $6=notes
  case "$2" in work_item|spine|release) ;; *)
    echo "oss: close scope must be work_item|spine|release" >&2; return 2;; esac
  case "$4" in true|false) ;; *) echo "oss: passed must be true|false" >&2; return 2;; esac
  oss_state_mutate "$1" add_close_record \
    "$(jq -n --arg sc "$2" --arg id "$3" --argjson ok "$4" --argjson n "${5:-0}" \
        --arg notes "${6:-}" --arg ts "$(_oss_now)" \
      '{scope:$sc,id:$id,demo_passed:$ok,demo_lines:$n,notes:$notes,at:$ts}')"
}
```

Update the dispatcher wrappers:

```bash
oss_cmd_demo_user_lines() { local sf; sf="$(_oss_resolve_state)" || return $?; oss_demo_user_lines "$sf" "${1:-}"; }
oss_cmd_demo_record()     { local sf; sf="$(_oss_resolve_state)" || return $?; oss_demo_record_close "$sf" "$1" "$2" "$3" "$4" "${5:-}"; }
```

And extend the existing `oss_cmd_demo_run` to forward the optional workdir (its current body drops everything after `$1`):

```bash
oss_cmd_demo_run() { # [$1=state-file] [$2=workdir]
  local sf; sf="$(_oss_resolve_state "${1:-}")" || return $?
  oss_demo_run_auto "$sf" "${2:-}"
}
```

- [ ] **Step 4: Run, mutation-test, commit**

Run: `bash ossify/tests/run-all.sh` → `ALL GREEN`.

Mutation test: move the vacuous-green check back outside the `exit:` arm (its pre-task position). Expected RED on "a recognized runner legitimately expecting exit:1 is not flagged vacuous". Restore, confirm green.

```bash
git add ossify/lib/demo.sh ossify/lib/state.sh ossify/lib/commands.sh ossify/tests/test-demo-runner.sh
git commit -m "fix(ossify): demo runner runs in the composition root; scope the vacuous-green guard

Three defects. The runner executed bash -c in the CALLER's cwd, so a
relative-path demo line measured whatever tree the session happened to be in —
§6.1 binds it to canonical post-merge state and companion §4.3 to the
composition root. The cd is a subshell because oss_manifest_discover walks up
from \$PWD: mutating the process cwd silently repoints every later manifest
read (scaffold-dev shipped exactly that bug in review_gate_resolve).

The vacuous-green guard ran after every expectation arm, failing a line that
legitimately expects exit:1 from a recognized runner. Now scoped to exit:0 and
delegated to lib/verify.sh's guard, which has a wider runner set.

Adds user-line surfacing (spine-scoped for §6.1, unscoped for §6.2) and a
durable close record — demo_run previously wrote nothing to state.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks:** (1) **who calls this?** — `demo_record_close` has no caller until T10/T11. (2) Does the subshell `cd` genuinely leave the process cwd untouched across a multi-line ledger? (3) Is `composition_root` handled for both absolute and canonical-relative values? (4) Does the quarantine SKIP branch still work now the loop body moved? (5) Does removing `_oss_demo_is_runner`/`_oss_demo_zero_tests` break any other caller — grep before deleting. (6) Strict mode through `bin/oss`.

---

### Task 7 (C1-7): `work-item` entry skill + `implementer-agent` registration

**Context:** Spec §6's first bullet, and §9.1's fifth entry skill. The behavioural contract is ported **verbatim where it is a contract** and re-anchored where it is vocabulary. `.claude-plugin/plugin.json` has no `agents` key today (it is five lines), so the subagent needs registering.

**D5 applies:** the source's report section set drifts three ways (SKILL §6 ≠ template ≠ worked example) and the evals assert content lands in "item 8", which is *Blockers* in one and *Suggestions for memory bank* in the other. C1 pins **one** set, and the RED-gate advisory and skip-escape override land in sections that exist.

**Files:**
- Create: `ossify/skills/work-item/SKILL.md` (≤~450 lines — leave headroom, unlike `plan-spine` at 499)
- Create: `ossify/skills/work-item/references/{pre-flight,tdd-loop,returns,report-contract}.md`
- Create: `ossify/commands/work-item.md`, `ossify/agents/implementer-agent.md`
- **No manifest change.** `ossify/.claude-plugin/plugin.json` is NOT modified.

> **Files list corrected 2026-08-01 — it contradicted this task's own Step 4.** It previously read
> "Modify: `ossify/.claude-plugin/plugin.json` (add the `agents` key)", while Step 4 says in bold to
> do exactly the opposite, and the Step 5 `git add` staged the file. Re-verified against the tree:
> **no plugin in this repo declares an `agents` key** (`ai-mentor`, `architect-critic`,
> `claude-security-audit`, `ossify`, `scaffold-dev`, `scaffold-onboard`, `scaffold`,
> `workspace-init` — all checked), yet `scaffold-dev` and `scaffold-onboard` both ship working
> `agents/` directories. Registration is by directory convention. Step 4 governs; adding the key
> invents an unsupported manifest field.

- [ ] **Step 1: Author `SKILL.md`.** Frontmatter `name: work-item`; the description embeds the trigger phrases (`execute work item`, `implement the work item`, `/work-item <handoff-path>`), the tri-mode note, and a negative-scope clause routing planning to `/plan-spine` and closing to `/close`. Body sections:

1. **Overview + the mode invariant.** Three modes — A: direct `/work-item <abs handoff path>`; B: the verbatim system prompt of the `ossify:implementer-agent` subagent dispatched by `plan-spine`; C: a Codex worker prompt. **The behavioural contract is invariant across all three and the body never branches on mode.** For mode C, every return and behavioural contract must be embedded *in the prompt file verbatim* — the Codex companion runs a bare prompt and never sees this skill.
2. **Pre-flight (mandatory first action, re-run from scratch on every re-dispatch).** Read the handoff **with the Read tool, not `cat`** (the tool-call log is the evidence). Extract the worktree abs path, declared branch, spec path, verification commands, and Constraints — Constraints must carry `git_policy: STAGE-not-commit` and the return JSON shape, or the handoff is malformed and that is itself a gap. Read the spec end to end and extract ordered `auto:` ACs via `oss verify_acs <spec>`. Probe the worktree: `git -C "<abs>" status --porcelain` (must be **empty**) and `git -C "<abs>" rev-parse --abbrev-ref HEAD` (must equal the declared branch). Ambiguity scan against the bar *"can a competent implementer pick a unique correct implementation from this spec alone?"*.
3. **The RED gate.** Per command-bearing AC, `oss redgate "<worktree-abs>" "<cmd>" "<expectation>"`. **rc 0 = RED, proceed. rc 1 = already GREEN — the only hard block. rc 2 = errored/uninvocable — ADVISORY, record it and proceed** (the test file usually is not authored yet, which is the expected starting state; blocking would make the gate unusable). A legitimately-already-GREEN AC is **never** decided inline: return gaps-mode with a concrete skip-escape question, honour the orchestrator's recorded override on re-dispatch, and record it in the report. Never auto-skip.
4. **The TDD loop**, per AC in declared order: failing test whose failure mode matches the AC → run and watch it fail → minimum implementation → run and watch it pass → next. Absolute paths only (the cwd is the orchestrator's, never the worktree). Never combine ACs — implementing AC-1 and AC-2 before verifying AC-1 makes the gate opaque.
5. **Verification.** Run every embedded command in the worktree. **Explicitly NOT halt-on-first-fail** — the opposite of the orchestrator-side gate in `close` — because the orchestrator needs the full picture to pick a recovery row, and partial output forces a second dispatch.
6. **Report**, per `references/report-contract.md`.
7. **Stage:** `git -C "<worktree-abs>" add -A`, then classify `stage_status`.
8. **Return**, per `references/returns.md`.
9. **NEVER list** (verbatim, and wider than it looks): `git commit` / `push` / `pull` / `fetch` anywhere in the tool-call log *including inside a comment, a heredoc body, or a piped subcommand*; the `Task` tool (no subagent nesting); any handoff-authoring skill; memory-bank writes (write-conflict lane separation — note it in the report instead); mutating `spec.md` mid-run; relative paths to worktree files; `cat`-ing the handoff or spec instead of Read; returning gaps-mode **after** pre-flight has passed; auto-cleaning a dirty worktree (`git stash` / `reset` / `checkout --` are all forbidden).

- [ ] **Step 2: Author the four references.**

- `pre-flight.md` — the four hard gates with their exact probes; the four gap archetypes (undefined contract, conflicting dependency, stale worktree, missing referenced file); the note that a clean pre-flight emits **no** "pre-flight passed" message, it just continues. **Blocker-recall is deliberately omitted in C1** — it depends on a `tech-debt.md` written by `/defer`, which is Plan C2. Say so explicitly rather than describing a read that resolves to nothing.
- `tdd-loop.md` — a worked RED→GREEN walk across 3-4 ACs in a re-domained example; the two legitimate "GREEN on first run" cases and the requirement that each be noted in the report; the pitfall list (skipping RED, over-implementing, combining ACs, forgetting the full-suite re-run).
- `returns.md` — **both JSON shapes verbatim.** These are exact-string structural contracts, not paraphrase targets: wrong key names, a missing required key, a non-enum value, or a prose return without the JSON envelope are each a contract violation.

  ```
  {"mode": "complete", "report_path": "<abs path to report.md>", "summary": "<one-line>", "stage_status": "all_staged | partial | none"}
  {"mode": "gaps-surfaced", "gaps": [{"section": "<ref>", "question": "<concrete question>", "severity": "blocking | nice-to-have"}, ...]}
  ```

  `mode` is the literal `"complete"` or `"gaps-surfaced"` — not `complete-with-fail`, `failed`, `blocked`, or `clarification-needed`. `severity` is exactly `blocking` or `nice-to-have` — not `high`/`low`/`critical`. `gaps` must be non-empty. `report_path` is absolute and ends in `report.md`. Also carry the three NOT-uses of gaps-mode: not implementation *difficulty*, not architectural *disagreement* (the spec is locked post-audit — use the report), and not tooling failures.
- `report-contract.md` — **the single pinned section set (D5)**, authored directly by the agent with no template rendering (D6): `## 1. Work item` · `## 2. Summary` · `## 3. ACs — verification status` (a table; a deferred or partial AC must be named explicitly with severity, because the close gate halts on a missing AC) · `## 4. Files changed` · `## 5. Verification commands run` · `## 6. Decisions during execution` · `## 7. Deviations from spec` · `## 8. Blockers and advisories` (**where the RED-gate rc-2 advisory and any skip-escape override land**) · `## 9. Suggestions for memory bank` (**the harvest source — T12 reads exactly this heading**) · `## 10. Notes for orchestrator`. State the MUST-NOTs: never omit the AC table; never conflate §6 (in-band judgement) with §7 (spec divergence) — they have different review consequences; never promise more than was done, since the summary, AC table and files-changed list are all cross-checked and inflation is the top cause of cross-check failures.

- [ ] **Step 3: Author `commands/work-item.md` and `agents/implementer-agent.md`.** The command wrapper uses the `ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '…'` bridge (never `$1`/`$2` — Claude Code substitutes those at template-render time and silently corrupts the positionals) and pins `allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep` — the same closed set as the subagent, minus `Task`. The agent file pins `name: implementer-agent`, `tools: Bash, Read, Write, Edit, Glob, Grep`, `model: inherit`, restates the whole contract inline in its `description` (a Task-dispatch consumer may see only the description), and points at `${CLAUDE_PLUGIN_ROOT}/skills/work-item/SKILL.md` as the binding system prompt. Note explicitly that the no-commit guarantee is **prompt-enforced and audit-detected, never mechanically blocked** — the Bash tool can reach git.

- [ ] **Step 4: Do NOT add an `agents` key.** Agents are discovered **by directory convention** from `<plugin>/agents/*.md`. Verified 2026-07-30 across all eight plugins in this repo: `scaffold-dev` and `scaffold-onboard` both ship working `agents/` directories and **neither** has an `agents` key in its `plugin.json` (`for f in */.claude-plugin/plugin.json; do jq -r 'keys|join(",")' "$f"; done` — no plugin declares one). An earlier draft of this step told the implementer to copy the key's shape from `scaffold-dev/.claude-plugin/plugin.json`, which has no such key to copy. Verify registration by confirming `ossify:implementer-agent` appears in the available-agent list after a plugin reload, not by inspecting the manifest.

- [ ] **Step 5: Verify and commit.** Confirm every `oss <subcommand>` named in the prose exists in the dispatcher (`bash ossify/bin/oss help`); confirm the body is ≤~450 lines; confirm zero eval-fixture wording appears in the prose. Run `bash ossify/tests/run-all.sh`.

```bash
git add ossify/skills/work-item ossify/commands/work-item.md ossify/agents
git commit -m "feat(ossify): work-item entry skill + implementer-agent registration

Spec §6 first bullet, §9.1's fifth entry skill. Return-contract JSON shapes and
the NEVER list are carried verbatim — they are exact-string structural
contracts, and a paraphrase is a defect.

Pins ONE report section set (plan decision D5): the source drifts three ways
between SKILL §6, its template and its worked example, while its evals assert
content lands in 'item 8' — Blockers in one, memory-bank suggestions in the
other. The RED-gate advisory and skip-escape override now land in sections that
exist. No template rendering (D6): the agent authors against a section contract.

Blocker-recall is deliberately omitted and said to be omitted — it reads a
tech-debt.md that /defer writes, and /defer is Plan C2.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**Named risks:** (1) **who calls this?** — the caller is **Task 8**, not `plan-spine`. `plan-spine/SKILL.md:36-37` explicitly disclaims dispatch (*"This skill plans; it does not execute"*) and has **no §8.3** — its sections run §1-§12 with §8 being demo authoring. Confirm the skill's mode-B prose names Task 8's lane and cites nothing that does not exist; a phantom section reference is the exact B6 defect class. (2) Are both JSON shapes byte-faithful? (3) Does every `oss` call in the prose exist? (4) Was `plugin.json` left **unmodified**? No plugin in this repo declares an `agents` key and two ship working `agents/` directories, so a manifest diff here is a defect, not registration. (Named risk corrected 2026-08-01 — it previously said "check a shipped plugin.json for the key's shape", which is the very instruction Step 4 exists to retract: there is no such key to copy.) (5) Does the report contract's §9 heading match what T11's harvest will grep for? (6) Is the RED-gate rc semantics stated the right way round (1 blocks, 2 advises)? (7) Any eval-fixture wording leaked into the prose?

---

### Task 8 (C1-8): Round orchestration — the execution lane that actually drives a work item

**Context — this task exists because the adversarial plan review found the engine had no producer.** Spec §6 names two halves: the *callee* (handoff doc in → implementer in an isolated worktree → staged-never-committed) and the *orchestrator* (DAG rounds, strict-order verification, merge halt-on-conflict, "orchestrator owns commits"). Task 7 builds the callee. Nothing built the caller, and the consequences compounded:

- `plan-spine/SKILL.md:35-39` says, in one sentence: *"**This skill plans; it does not execute:** worktree spin-up, implementer dispatch, verification, and merge belong to the execution engine (`work-item`); the cumulative-demo run, the harvest, and the retro belong to `close`."* **Plan C1 is that execution engine**, and as drafted it never built the lane. (An earlier draft of Task 7 cited "plan-spine §8.3" as the dispatcher — **there is no §8.3**; plan-spine runs §1-§12 with §8 being demo authoring. That phantom citation is the same defect class B6 shipped, caught here before dispatch.)
- Consequently `oss_worktree_add` and `oss work_item_exec` would have ended C1 with **zero callers** — the exact built-but-unwired pattern the final review named as this branch's systemic weakness.
- And work-item commits would have landed on `work/<wi-id>-<slug>` branches that **nothing merges**. `oss_worktree_remove` uses `git branch -d` and *refuses* rc 8 on an unmerged branch (worktree.sh:112-113, asserted at `tests/test-worktree.sh:113-119`), so the commits are not destroyed — but spine close **halts at step 10, after the cumulative demo has already reported green** against a canonical tree that never received the work. The loss is not silent data loss; it is a green demo measuring the wrong tree, then a halt with no clean recovery.

> **Context corrected 2026-08-01 (pre-dispatch sweep).** Three claims above were wrong as first written.
> (a) The `plan-spine` quote was cited as `:36-37` and closed with a fabricated period; the sentence spans **35-39**, and line 38 **already names `(`work-item`)`** — committed in `a53d034` on 2026-07-26, three days *before* this plan was written. The truncation is what created the false premise that plan-spine does not name its successor. Step 3 is rewritten accordingly.
> (b) `oss_worktree_resolve` and `oss_worktree_list` were named as gaining their first callers here. **They do not** — no step in this task calls either, and no step in T9-T14 does either (`worktree_list` appears in this task exactly once: in the claim itself). See named risk 1.
> (c) The "destroying the commits" claim contradicted T4's shipped `-d`-not-`-D` guard and the test that asserts it.

**No new entry skill** — §9.1's six are allocated. The lane lives as a reference under `work-item`, which Task 7 authors with deliberate headroom.

**Files:**
- Create: `ossify/skills/work-item/references/round-orchestration.md`, `ossify/skills/work-item/references/handoff-contract.md`
- Modify: `ossify/skills/work-item/SKILL.md` (**two** §-pointers, one per new reference — see Step 5), `ossify/skills/plan-spine/SKILL.md:38` (**line-neutral** in-place edit — see Step 3), `ossify/tests/test-worktree.sh`

> **Files list corrected 2026-08-01 (pre-dispatch sweep).** It said "one §-pointer" while Steps 1-2 create **two** reference files, and no step instructed the `SKILL.md` edit at all — it existed only in this header and in Step 5's commit set. **Task 13 check 5 (line 2141) fails the suite on any `references/*.md` not pointed at from its own `SKILL.md`**, and all 31 references at HEAD satisfy that invariant today (`work-item/SKILL.md` points at its four at :139, :197/:218, :250, :307). One pointer for two new files orphans `handoff-contract.md` and reds T13's harness. The `plan-spine` target was also wrong — see Step 3.

**Interfaces:**
- Consumes: `oss worktree_add` (T4), `oss work_item_exec|work_item_status` (T1), `oss repo_root|spine_dir|branch_name` (T3/T4), the return contract in `work-item/references/returns.md` (T7).
- Produces: the spine integration branch `spine/<spine-id>-<slug>`, **checked out in canonical** (Step 1.1); per-work-item worktrees and `work/<wi-id>-<slug>` branches; the `branch` + `worktree_path` + `base_sha` recorded in state per work item; a `handoff.md` per work item. Consumed by Task 9's work-item close layer (gate → commit → merge) and Task 10's binding-order step 2 (spine branch → canonical).

> **Interfaces corrected 2026-08-01.** `worktree_resolve`, `worktree_list` and `worktree_remove` were listed as consumed here; **this task calls none of them** (T10's step 10 calls `worktree_remove`). `work_item_branch` was listed but is not called either — Step 1.2's `oss worktree_add` derives the work-item branch internally (`worktree.sh:35`). `oss repo_root` was **missing** and is the verb that resolves `<canonical>`. The zero-consumer audit at the end of this plan pinned `oss_id_spine_dir` to "T8 step 3 (handoff paths)" — Step 3 is a prose edit with no `oss` call; `spine_dir` belongs to **Step 1.3**, which is where the handoff's directory is now specified.

- [ ] **Step 1: Author `round-orchestration.md`** — the ordered lane, per **work-item** round.

> **Round source corrected 2026-08-01.** This step previously read "per round of the DAG `plan-spine` already recorded in `releases[].spine_dag`". Both halves are wrong, and ossify's own shipped prose forbids the conflation: `releases[].spine_dag` is the **inter-spine** DAG, written by **`plan-release`** (`oss release_set_meta`; `plan-release/SKILL.md:217`), and `plan-spine/references/dag-rounds.md:6-8` says verbatim *"Not to be confused with `plan-release`'s inter-spine DAG… Same idea, finer altitude, different owner"*, with §7 listing "Spine-level edges here" as an anti-pattern. Reading `spine_dag` yields **spine** ids where **work-item** ids are needed.
>
> **The work-item round structure is recorded in no state field at all.** `oss_entity_add_work_item` writes `{spine,title,target_repo,status,created_at}` (entities.sh:24-33) — no dependency key, no round key. Per `dag-rounds.md:21` the rounds are *"planning output… what the execution engine walks"*, and §7 forbids re-deriving them at execution time. So the lane **reads the rounds from the spine plan document** `plan-spine` authored under `oss spine_dir "$rel" "$spine" "$slug"`, and says so. Persisting rounds as state is a **Plan C2** item — name the deferral in the prose rather than leaving the read looking machine-backed.

1. **Create AND CHECK OUT the spine integration branch once, before round 1.** Resolve the repo root with `oss repo_root canonical` (never a bare `<canonical>` placeholder — the verb exists, reads `.canonical.root` from the manifest, and hard-fails rc 2 rather than defaulting). Then:

   ```bash
   canonical="$(oss repo_root canonical)"
   [ -z "$(git -C "$canonical" status --porcelain)" ] || { echo "canonical is dirty - halt"; exit 1; }
   base_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"   # T10 step 2 returns to this
   git -C "$canonical" checkout -q -b "$(oss branch_name "$spine" "$slug")"
   ```

   **`checkout -b`, not `branch`.** This is the correction that makes the whole T8→T9→T10 lifecycle work; see the boxed note below. Canonical stays parked on the spine branch for the duration of the spine, which is what makes T9's merge land on the spine branch and T10's step 2 a real merge rather than a no-op. Record `base_branch` in the spine plan doc — T10 step 2 needs it to switch back, and nothing in state holds it.

2. **Per work item in the round** (in declared decomposition order, not return order): spawn the worktree off the spine branch — `oss worktree_add "$target_repo" "$wi" "$slug" "$spine_branch"` (it derives and cuts `work/<wi>-<slug>` internally and echoes the abs path); record it — `oss work_item_exec "$wi" "$branch" "$path" "$(git -C "$path" rev-parse HEAD)"`; mark it active — `oss work_item_status "$wi" active`. **The `work_item_exec` call is load-bearing beyond bookkeeping:** it persists the branch name into state, which is how Task 9 recovers the merge target without re-deriving a slug it does not have.
3. **Author the work-item `handoff.md`** per `references/handoff-contract.md`, into the work item's own directory under `oss spine_dir "$rel" "$spine" "$slug"` — i.e. beside the `spec.md` that `plan-spine/SKILL.md:210` places at `<ai-workspace>/docs/specs/<release-id>/<spine-id>-<slug>/work-<work-id>/spec.md`. **Do not pre-place a `report.md`.**

> **Pre-placement removed 2026-08-01.** This step said to "pre-place an **empty `report.md`** beside it (the callee writes into a placeholder it does not create)". The already-shipped callee says the opposite in three places: `report-contract.md` declares itself the single copy with **no placeholder to fill**, `work-item/SKILL.md:247` tells the implementer to author `report.md` itself, and `SKILL.md:211` says *"Prefer Edit over Write on a file that already exists. Write is for new files."* — so an orchestrator-created empty file puts the callee in conflict with its own binding prose at the moment it writes the report. Nothing in the callee's pre-flight expects the file to exist.
4. **Dispatch** `Task(subagent_type="ossify:implementer-agent", …)` with the handoff's absolute path. **Do not use the Task tool's `isolation: "worktree"`** — the worktree already exists, in a different repo, and letting the harness make its own would silently discard the work.
5. **Handle the return** by its `mode`:
   - `gaps-surfaced` → surface the gaps grouped blocking-first, capture the user's clarifications, append a `## Clarifications` section **to the handoff doc** (the callee re-reads it end-to-end on re-dispatch), and re-dispatch. **3-iteration cap, orchestrator-side and binding (spec §6):** after three total dispatches with no `complete` return, stop, surface the accumulated gap list, and escalate. The callee never counts iterations.
   - `complete` → hand off to the work-item close layer (Task 9), which runs the gate, commits, and merges.
6. **Round barrier:** every work item in a round reaches `complete` before the next round starts. A work item still `active` at the barrier halts the round — strict-order verification, spec §6.

> ### The `checkout -b` correction — the P0 this sweep found (2026-08-01)
>
> Step 1.1 previously read `git -C "<canonical>" branch "$(oss branch_name …)" <base>`. **`git branch` creates a ref without checking it out**, and no step in T8, T9 or T10 ever checked the spine branch out (a `checkout`/`switch` grep across the whole plan returned only a `post-checkout` hook mention at :1333 and a forbidden-command listing at :1884). Reproduced in a sandbox against the real libs: with canonical left on `master`, T9's `git -C "<canonical>" merge --no-ff work/…` returns **rc 0** and lands the commit on **master**, and `git merge-base --is-ancestor "$work_branch" "$spine_branch"` reports **not reachable**.
>
> The consequences chain exactly as the plan's own line 129 warns, by a different mechanism than it names:
> - T9's per-work-item merge lands on canonical's pre-existing branch, not the spine branch.
> - T10's step 2 `merge --no-ff "$spine_branch"` is then a **no-op** — the spine branch never received anything.
> - `oss_worktree_remove`'s `git branch -d` *succeeds* (the branch is merged — into the wrong target), so cleanup is silent.
> - The cumulative demo reports green against a tree assembled by accident rather than by the lifecycle.
>
> **There is no single value of canonical's HEAD that makes both T9:2005 and T10:2036 correct as first written**, which is why this is fixed in all three tasks together rather than in T8 alone. Parking canonical on the spine branch (Step 1.1) makes T9 correct; T10 step 2 gains an explicit switch back to `base_branch` before its merge. Both edits are made below and in T9/T10 respectively.

- [ ] **Step 2: Author `handoff-contract.md`** — the section contract the orchestrator authors against (**no template rendering, D6**). Sections: `## 1. How to use this handoff` · `## 2. Spine context` (including the `base_branch` recorded at Step 1.1) · `## 3. Work item identifiers` (id, `target_repo`, worktree abs path, declared branch, **absolute spec path**) · `## 4. Pre-flight calibration` · `## 5. What's already merged` · `## 6. Memory bank pointers` · `## 7. Requirement traceability` · `## 8. Acceptance criteria (reference copy — non-binding)` · `## 9. Verification commands` · `## 10. Constraints` · `## 11. When done` · `## 12. Report contract`.

  **§10 MUST carry `git_policy: STAGE-not-commit` and the return JSON shape verbatim** — Task 7's pre-flight treats a handoff missing either as malformed, which is itself a gap. That is a contract between two tasks in this plan: if this file and `returns.md` drift, the engine deadlocks on its own pre-flight.

  **§3 MUST carry the absolute spec path.** Task 7's shipped `pre-flight.md:22-30` lists **five** fields that must resolve — worktree abs path, declared branch, **spec path**, verification commands, Constraints — and Gate 2 runs `oss verify_acs "<abs spec path>"` against it. §3's field list previously enumerated only four and no other section carried a spec path, so a handoff authored exactly to this contract is **malformed at Gate 1** and every dispatch returns `gaps-surfaced` — the self-deadlock the paragraph above warns about, live in the contract that warns about it.

  **§8 is a reference copy and the prose must say so.** The callee never reads ACs from the handoff: it reads the spec end to end and parses the ordered `auto:` ACs out of it with `oss verify_acs`, and *that* TSV order is the binding working order for the RED gate and the TDD loop. Titling §8 as if it were authoritative creates a second source of truth that nothing reads and that silently drifts from the spec. Keep it as an orientation aid, labelled non-binding, or omit it.

- [ ] **Step 3: Point `plan-spine` at the lane file — line-neutral, line 38 only.** `plan-spine/SKILL.md` lines **35-39 are a single sentence**, and **line 38 already names `` (`work-item`) `` as the execution engine** (since `a53d034`, 2026-07-26). The successor is named; what is missing is the reference file. Edit **line 38 in place** — e.g. `` (`work-item`, lane in `references/round-orchestration.md`); the cumulative-demo *run*, the harvest, and the retro belong to `` — and do **not** replace lines 36-37: a 36-37-only rewrite that terminates in a period orphans line 38's fragment and duplicates the `work-item` mention. Long lines are fine; this file already carries lines over 90 chars and nothing lints width. **Line-neutrality check:** record `wc -l` before and after, require them equal and the result **≤ 500** (do not hard-code 499 — Task 2 also edits this file), then read lines 35-39 back as one intact sentence.

- [ ] **Step 4: Test the mechanical half.** Extend `tests/test-worktree.sh`: a worktree spawned off a spine branch has the spine branch as its merge base; two work items in one spine get distinct branches and distinct worktrees; and — **with canonical checked out on the spine branch per Step 1.1** — after a commit in the worktree, `git -C "$canonical" merge --no-ff "$work_branch"` succeeds **and `git -C "$canonical" merge-base --is-ancestor "$work_branch" "$spine_branch"` passes**. Assert reachability explicitly; a bare rc-0 on the merge is exactly what passed while the commit went to the wrong branch. The fixture's `canon` repo is seeded on `master` (`tests/test-worktree.sh:9-15`), so a test written without the checkout **fails** — that is the regression this assertion locks in.

  State plainly in the task that the dispatch loop, the 3-iteration cap and the round barrier are **prose contracts with no executable surface**: Task 13's bash-block harness checks that every `oss` verb they name resolves, and beyond that they have **no automated coverage in C1**. (The earlier claim that "the `close-gate-integrity` eval covers the judgment" is false — that surface is authored by **Task 14**, not T13, and its five fixtures are all close-ceremony scenarios: demo halt, bone reclassification, fake expiry, quarantine-vs-retire, and a clean-flesh negative control. None exercises dispatch, the cap, or the barrier.) A bash test asserting agent behaviour would be testing a fixture, not the contract — but say the coverage is absent rather than implying it exists.

- [ ] **Step 5: Wire both references, run the suite, commit.** Add **two** pointers to `work-item/SKILL.md` — one per new reference, matching the shipped one-pointer-per-reference convention (:139, :197/:218, :250, :307). `round-orchestration.md` belongs at the Mode B paragraph (:26-27), which currently names the round-orchestration lane **by role**; T7 deliberately left it role-named because this file did not exist yet, and naming it now is the point of this task. `handoff-contract.md` needs its own pointer — a file referenced only from inside `round-orchestration.md` is an orphan under **Task 13 check 5**. Confirm `work-item/SKILL.md` stays ≤~450 lines (382 at HEAD, 68 of headroom reserved for exactly this). Then `bash ossify/tests/run-all.sh` and commit (`ossify/skills/work-item/references/ ossify/skills/work-item/SKILL.md ossify/skills/plan-spine/SKILL.md ossify/tests/test-worktree.sh`).

**Named risks for the task reviewer:**
1. **Who calls this?** — and the reverse. After this task, `oss_worktree_add`, `work_item_exec` and `work_item_status` must each have a real caller: **name the line**. `worktree_resolve` and `worktree_list` are **expected to still have none** — that is recorded, not discovered, and the C1-close review decides whether `worktree_list` earns its keep. A reviewer who "fixes" this by inventing a call site is adding a caller to satisfy an audit, which is the failure the audit exists to prevent.
2. **The lifecycle, end to end.** Is canonical actually *checked out* on the spine branch (not merely `git branch`-ed) before any work-item branch is cut? Does the Step 4 test assert **reachability from the spine branch**, not just merge rc 0? Run it against a fixture where canonical starts on `master` — it must fail without the checkout.
3. Does `handoff-contract.md` §10 match `returns.md` **exactly**, and does §3 carry the **absolute spec path**? Either drift deadlocks the engine on its own pre-flight gate.
4. Is the 3-iteration cap orchestrator-side only, with the callee explicitly not counting?
5. Did the `plan-spine` edit stay line-neutral and ≤500? Check `wc -l` **and** read lines 35-39 back as one intact sentence — a line-neutral diff can still leave a dangling fragment.
6. Is `isolation: "worktree"` explicitly forbidden in the dispatch step?
7. Does the prose name where the **work-item rounds** are read from (the spine plan doc), and does it avoid citing `releases[].spine_dag`? Does it state that persisting rounds to state is deferred to C2?
8. Is `report.md` left for the callee to author — no orchestrator-side pre-placement?

---

### Task 9 (C1-9): `close` router + the work-item close layer

**Context:** §9.1's `close` is **context-routed**: work item → spine → release. This task builds the router and the innermost layer; T10 and T11 add the outer two. The router is what makes "core rows are never skippable" structural — it executes a fixed checklist, not a judgment call.

**Design note (D3), state it in the prose so a reviewer does not "fix" it back:** the source surfaces-and-waits at every decision boundary. Spec §6.1 and the #109 policy say spec-aligned recommendations **auto-apply** and only load-bearing escalations reach the user. `close` auto-applies. This is a deliberate behavioural change from the source, not a port defect.

**Files:** Create `ossify/skills/close/SKILL.md`, `references/{routing,work-item-close,impl-check}.md`, `ossify/commands/close.md`, `ossify/tests/test-close.sh`.

- [ ] **Step 1: Author the router.** `SKILL.md` frontmatter `name: close`; description embeds `close work item`, `close spine`, `close release`, `/close <id>`, and a negative-scope clause (planning → `/plan-spine`, release selection → `/plan-release`). Body:

1. **Overview** — one ceremony, three scopes, and the guarantee: *core rows are never skippable in either class; the skill executes a fixed checklist.*
2. **Routing.** The scope is derived **mechanically from the id's shape**, never asked: `oss_id_parse` returns `work_item` / `spine` / `release` for `r<N>.s<K>.w<J>` / `r<N>.s<K>` / `r<N>`. An unparseable id is a one-line error and stop. With no argument, refuse and list the open ids rather than guessing — a close run against the wrong scope is expensive and silent.
3. **Pre-flight, common to all three scopes.** `oss manifest_require` (refuse naming `/init-workspace` and `/pair-workspace`); `oss doctor` must be green on schema and replay — a close that mutates a drifted state compounds the drift, and `oss state_restore` is the remedy to name; resolve the state path **once, before anything `cd`s** (the manifest walks up from `$PWD`).
4. **Work-item close** → `references/work-item-close.md`.
5. **Spine close** → T9's references.
6. **Release close** → T11's references.
7. **Anti-patterns** — routing on anything but the id shape; running any layer's steps out of order; treating a halt as advisory; closing a scope whose children are not closed.

- [ ] **Step 2: Author `work-item-close.md`** — the innermost layer, in binding order:

1. Read `report.md` off disk (it is deliberately not in the return payload).
2. **The gate**, per `references/impl-check.md`.
3. On green: `oss work_item_status <id> complete`, then the orchestrator commits **in the worktree** (the implementer stages; the orchestrator owns the commit boundary), **then merges `work/<wi-id>-<slug>` back into the spine branch Task 8 checked out**:

   ```bash
   canonical="$(oss repo_root canonical)"
   wi_branch="$(oss get ".work_items[] | select(.id==\"$wi\") | .branch")"   # written by T8's work_item_exec
   git -C "<worktree-abs>" commit -m "<message>"
   git -C "$canonical" rev-parse --abbrev-ref HEAD                          # MUST be the spine branch
   git -C "$canonical" merge --no-ff "$wi_branch" -m "merge <wi-id>"
   git -C "$canonical" merge-base --is-ancestor "$wi_branch" HEAD           # verify it landed
   ```

   **Read the branch from state; never re-derive it from a slug.** `close` is invoked with an id only and derives its scope "mechanically from the id's shape, never asked" — it has no slug, and no slug is persisted anywhere (`oss_entity_add_spine` stores `name`, `oss_entity_add_work_item` stores `title`). Task 8's `oss work_item_exec` writes the branch it actually created into `work_items[].branch` precisely so this step can read it back. `oss work_item_branch "$wi" "$slug"` was the original instruction here and it cannot be executed as written.

   **Verify the merge target before merging.** `git -C "$canonical" merge` lands on whatever canonical has checked out. Task 8 step 1.1 parks canonical on the spine branch; if `rev-parse --abbrev-ref HEAD` is anything else, **halt** — merging is how the work reaches the spine branch, and a merge onto the wrong branch succeeds silently at rc 0.

   **This merge is not optional bookkeeping.** Without it the commits live only on a branch that spine close then cannot delete (`worktree_remove` refuses an unmerged branch rc 8), so the round halts at cleanup — *after* the cumulative demo has already reported green against a canonical tree that never received the work. A merge conflict **halts** — surface the conflicted paths and stop; never auto-resolve.
4. On any failure: **halt**, surface the source-tagged errors, present the recovery menu, and **stop — no auto-select**.
5. Worktree cleanup does **not** happen here. It happens at spine close, **after** harvest — harvest reads `report.md` out of the worktree, so removing it first destroys the harvest source.

- [ ] **Step 3: Author `impl-check.md`** — the gate itself:

- **Layer 1, `auto:` ACs, halt-on-first-fail** (the opposite of the implementer's own non-halting verification, and for the opposite reason: the orchestrator gate stops at the first real failure because there is a human to route to). `oss verify_acs <spec>` then `oss verify_step "<worktree>" "<cmd>" "<expectation>"` per row.
- **Layer 2, report cross-check:** `oss report_cross_check <report> <spec>`. A missing AC halts — an unreported AC is indistinguishable from an unimplemented one.
- **Layer 3, code patterns:** read `03-code-patterns.md` and **judge** whether the diff violates a documented pattern. **This is agent judgment in C1, and the prose says so and says why** (D2): the predecessor's mechanical evaluator is a phantom entry point over three unimplemented rule families, and a mechanical gate that silently passes is worse than an honest judgment call. A correct evaluator arrives in C2 with rule authoring.
- **Source-tagged errors**, literal prefixes: `[AC]`, `[report cross-check]`, `[rule]`.
- **The recovery menu**, surfaced and never auto-selected: re-dispatch the implementer with the failure; accept with a recorded deferral; re-author the AC (only when the AC is wrong, never when the code is).

- [ ] **Step 4: Test + commit.** `tests/test-close.sh` drives the router through `bin/oss`-backed fixtures and asserts: an unparseable id errors; each id shape routes to its own scope; a work item whose report omits an AC halts with `[report cross-check]`; a green work item reaches `complete`. Run `bash ossify/tests/run-all.sh`, then commit `ossify/skills/close ossify/commands/close.md ossify/tests/test-close.sh`.

**Named risks:** (1) **who calls this?** — does anything route *into* `close`, and does `plan-spine`'s prose already promise a close contract this task must honour? Grep it. (2) Is routing genuinely mechanical from the id, with no ask-the-user fallback that could pick the wrong scope? (3) Does the pre-flight resolve the state path before any `cd`? (4) Is the halt genuinely terminal — no subsequent step runs? (5) Does the prose state the D3 auto-apply divergence explicitly? (6) Is worktree cleanup correctly *absent* from this layer?

---

### Task 10 (C1-10): Spine close — cumulative demo, class-scoped ceremony, critic, retrospective

**Context:** Spec §6.1. **A premise correction the survey caught and the plan carries:** the spine-close demo row runs *all accumulated `auto:` lines plus only the closing spine's own `user:` contribution* (spec:271). The full `user:` walkthrough is release close (spec:318-319), not here.

**Binding order** — each step's output is the next one's input, and cleanup is last for a reason:

1. All work items `complete`, else refuse naming the offender.
2. **Switch canonical back to its base branch, then** merge the spine branch to it, **halting on conflict** (spec §6, "merge halt-on-conflict"):

   ```bash
   canonical="$(oss repo_root canonical)"
   spine_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"   # T8 parked us here
   git -C "$canonical" checkout -q "$base_branch"                      # recorded by T8 step 1.1
   git -C "$canonical" merge --no-ff "$spine_branch" -m "merge <spine-id>"
   ```

   **The switch-back is what makes this a real merge.** Task 8 step 1.1 checks the spine branch out in canonical and leaves it there for the duration of the spine, which is what makes T9's per-work-item merges land on it. Without switching back first, this step merges the spine branch **into itself** — "Already up to date", rc 0, and the release branch never receives the spine. `base_branch` is the branch canonical was on when T8 cut the spine branch; T8 records it in the spine plan doc's `## 2. Spine context` because no state field holds it. **If `base_branch` cannot be resolved, halt** — guessing the default branch here merges a spine into the wrong line of development. (Persisting it as state is a Plan C2 item, with the round structure.)

   A non-zero rc halts the close with rc-8 semantics: surface the conflicted paths verbatim, leave the merge in progress for the human, and run **no** later step. Never `--abort` on the user's behalf and never auto-resolve.
3. **`oss ledger_apply_pending <spine>`** (D1) — after merge, before the demo, so the demo measures the amended set against a product where the flow really is replaced.
4. **Cumulative demo:** `oss demo_run` (all active `auto:`) then walk `oss demo_user_lines <spine>` (this spine's own `user:` lines only) with the human. **Halt on first fail** — no further step runs: no critic, no retro, no harvest, no cleanup.
5. **Bone-touch check (mandatory on flesh, core on bone):** `oss touch_check <changed paths>`. **rc 0 = HIT, rc 1 = clean, rc 2 = could-not-check.** Reading this backwards is the single most consequential mistake available here. A hit reclassifies the spine mid-flight to bone via `oss class_set` and switches to the bone close path. rc 2 is **not** clean — halt and say why.
6. **Risk-gate escalation:** a touch of a recorded risk gate's surface escalates to the bone path **plus that gate's control checklist**, regardless of class. Harm is orthogonal to reversibility.
7. **architect-critic:** bone → full audit with the external Codex adversary at close depth; flesh → one light host-only pass. `oss critic_detect`; **absent → exactly ONE warning, then proceed** (a silent skip and a blocking error are both wrong). Invocation is `export ARCHITECT_CRITIC_ARGS="--spec \"<abs bundle path>\" --close"` then a bare `Skill(architect-critic:critiquing-spec)` — no parameters, both failure modes silent.
8. **Retrospective** — authored against a section contract (D6), full for bone / lean for flesh.
9. **Harvest** (T12) — before cleanup, always.
10. **Worktree + branch cleanup**, per work item, `oss worktree_remove <repo> <wi>`. Only now.
11. **Handoff / state updates** (§6.1 core row): `oss spine_status <spine> closed` and `oss demo_record spine <spine> <passed> <n> "<notes>"`. The *session*-handoff half of that row — offering `/handoff` at the boundary — is **Plan C2**, because `/handoff` is a redesign there (issue #113) and C1 ships no handoff authoring. State the deferral in the prose rather than leaving the row looking complete.

**Files:** Modify `skills/close/SKILL.md` (§5); create `references/{spine-close,cumulative-demo,retrospective}.md`; extend `tests/test-close.sh`.

- [ ] **Step 1** Author `spine-close.md` (the ordered checklist above, with the bone/flesh column from spec §6.1 rendered as a table and the "core rows are never skippable in either class" guarantee stated). **Step 2** Author `cumulative-demo.md` — the auto/user split with the §6.1-vs-§6.2 scoping made explicit, the halt discipline, quarantine handling (skipped by the runner, still owed by the next release close), and the ledger wall-clock budget read from `releases[].ledger_budget`. **Step 3** Author `retrospective.md` — the bone and flesh section contracts. **Step 4** Extend `tests/test-close.sh`: apply-pending runs before the demo; a failing demo halts before critic/harvest/cleanup; `touch_check` rc 2 halts rather than reading as clean. **Step 5** Run the suite and commit.

**Named risks:** (1) **who calls this?** — is `apply_pending` actually invoked, and *before* the demo? Trace it; T2 built it with no caller. (2) Is `touch_check`'s rc read correctly in all three cases, and is rc 2 genuinely non-clean? (3) Does the demo scope match spec:271 (this spine's own `user:` lines) rather than all of them? (4) Is the halt genuinely terminal at every layer? (5) Is cleanup strictly after harvest? (6) Is the architect-critic bridge the exported-args form with no parameters? (7) Does any prose reuse eval-fixture wording?

---

### Task 11 (C1-11): Release close — walkthrough, fake expiry, quarantine resolution, patch lane

**Context:** Spec §6.2, plus the two §6.1 contracts that only become enforceable at a release boundary. **Out of scope, deliberately:** §6.2 **step 5** (the docs-increment trigger table, §8), **step 6** (handoff cleanup for the closed release — it depends on the `/handoff` v2 redesign, which is C2 by the approved design) and **step 7** (the PR gate — C2 must settle the spine→release / release→main tier question, D7, before a line of it is written) are all **Plan C2**. This task builds §6.2 **steps 1-4** plus the two blocking findings and the feature-map re-groom. An earlier draft claimed it built step 6; it does not, and nothing in C1 does.

**Binding order:**

1. **All spines closed** — refusal gate, naming any that are not.
2. **Full cumulative walkthrough** — the human drives **every** accumulated `user:` line (`oss demo_user_lines`, unscoped), grouped by feature, against the **amended** set.
3. **Blocking finding — fake expiry:** every **outstanding** `fakes[]` entry — `status == "active"` **or** `status == "renewed"` — whose `expiry_release` is this release, or whose replacement trigger has fired, is a **blocking close finding**. Resolve by replacing it (`oss fake_status <b> replaced "<reason>"`) or **explicitly renewing** it with a new expiry and a stated reason (`oss fake_status <b> renewed "<reason>" <new-expiry>`). It cannot be ignored — deferred truth never becomes permanent silently.

   > **`renewed` MUST be in the selector — corrected 2026-07-31 after Task 2.** Task 2 gave fakes the
   > `active|replaced|renewed` vocabulary; only **`replaced`** is resolved. Selecting on `active` alone
   > lets a renewal escape its own deadline: a fake renewed at r1 with a new expiry of r2 arrives at r2's
   > close carrying `status == "renewed"`, is skipped by the gate, and is never asked about again — which
   > is precisely the "deferred truth becomes permanent silently" outcome this row exists to prevent, and
   > it would fail *silently green*. The renewal is the thing most in need of the check, because someone
   > already pushed that deadline once. T11's test must seed a **renewed** fake at its expiry release and
   > assert the close is blocked; an `active`-only fixture passes either way and proves nothing.
4. **Blocking finding — quarantine:** every line quarantined in a release **before** this one must now be fixed or retired. A parking ticket, not a shrug.
5. **Release retrospective** (aggregates spine retros; refuses if any spine lacks one, naming it).
6. **Feature-map re-groom + next-release sketch** — the rolling-wave crank.
7. `oss release_status <rel> closed`; `oss demo_record release <rel> …`.

**Patch lane** (§6.1, out-of-spine work) gets its own reference: changes touching no bone, no risk surface and no demo-relevant behaviour may commit directly with a one-line `oss patch_add <commit> "<text>"` record — **the verb already exists**; what is missing is the routing judgment. Anything heavier is a flesh spine, however small. The next spine close's cumulative demo re-validates the product regardless, which is what bounds the drift window.

**Files:** Modify `skills/close/SKILL.md` (§6); create `references/{release-close,fake-expiry,patch-lane}.md`; extend `tests/test-close.sh`.

- [ ] **Steps:** author the three references; add a mechanical helper `oss_reg_expired_fakes <state> <release>` in `registries.sh` returning the blocking set (with a dispatcher wrapper) so the finding is a **checked fact, not a judgment**; extend `test-close.sh` to assert an unresolved expired fake blocks the close and a renewed one does not, and that an older quarantine blocks; run the suite; commit.

**Named risks:** (1) **who calls this?** — `fake_status` and the expiry helper must actually be driven here; T2 built the verb with no caller. (2) Does the walkthrough use the **amended** active set? (3) Is the expiry finding genuinely blocking, with the only unblocks being replace or explicit renew? (4) Is the release-scope quarantine comparison right (quarantined in an *earlier* release, not this one)? (5) Are the C2 deferrals (docs increment, PR gate) stated rather than silently missing? (6) Does the patch lane avoid inventing a new verb?

---

### Task 12 (C1-12): `lib/harvest.sh` + the harvest ceremony

**Context:** Spec §6.1 core row and §8's memory-bank contract. **D8 applies — the idempotency check is rebuilt, not ported.** Issue #115 reports the source returns rc 0 and writes nothing; the report is half true and its stated cause is wrong (the literal repro does not reproduce; strict mode and per-item jq re-parse are both innocent). The real mechanism is `grep -Fq "$text"` at harvest.sh:171 — text containing a **blank line** makes `grep -F` treat it as alternatives one of which is empty, so it matches everything and every item skips at rc 0; multi-line text whose *any* line already exists skips; substring text skips. The **inverse** defect is live too: no `--` terminator, so text starting `-` is consumed as an option and the append fires unconditionally, defeating idempotency in the other direction. An 8-item close payload hits these with near-certainty.

**Files:** Create `ossify/lib/harvest.sh`, `ossify/tests/test-harvest.sh`, `skills/close/references/harvest.md`. Modify `ossify/lib/commands.sh`, **and `skills/close/SKILL.md`** — the harvest reference must be wired in from the spine-close section or it lands orphaned (Task 13's check 5 flags unreferenced references, so an unwired file fails the suite).

**Interfaces:**
- Produces: `oss_harvest_memory_bank_dir <state>` — echoes the memory-bank directory, honouring `.well_known_paths.memory_bank` with a `<ai_workspace.root>/.claude/memory-bank` convention fallback; rc 1 if unresolvable. `oss_harvest_apply <state> <payload-json>` — rc 0 on any write or clean no-op, rc 1 if the payload was non-empty and nothing was written, **rc 2 if the payload is rejected**; echoes `harvest: wrote <N>, skipped <M>` on stdout. Dispatcher: `oss harvest_dir`, `oss harvest_apply`.
- **Payload shape** (pinned here because the ceremony in Task 10 step 9 authors it and a drift between the two is undetectable at runtime):

  ```json
  [{"source": "report|handoff",
    "source_id": "<work-item id or handoff filename>",
    "target_file": "09-known-issues.md|10-decisions-log.md",
    "text": "<markdown, may be multi-line>"}]
  ```

  Any item naming a target outside that two-file allowlist rejects the **entire** payload before a single filesystem write. `source` must be exactly `report` or `handoff`.
- Consumes: `oss_manifest_get` (T3 exposed it through the dispatcher).

- [ ] **Step 1: Write the failing test** covering exactly the defect class: an item whose text contains a blank line; an item whose text is multi-line with one line already present; an item whose text is a substring of existing content; an item whose text starts with `-`; applying the same payload twice. Assert the written/skipped **counts**, not just rc.

- [ ] **Step 2: Implement.** Key decisions, each a direct answer to a named defect:

- **Memory-bank dir honours `.well_known_paths.memory_bank`** with a `<ai_workspace.root>/.claude/memory-bank` convention fallback. The source hardcodes the path and ignores the manifest key its own sibling honours — a second, independent "rc 0 and nothing where you are looking" path.
- **Idempotency is an exact-entry match on a content hash carried in the provenance trailer**, never a `grep -F` over the text: `h="$(printf '%s' "$text" | cksum | awk '{print $1}')"`, trailer `<!-- ossify harvest: <source-id>, <date>; source: report|handoff; h:<hash> -->`, and the skip test is `grep -q "h:${h}"`. A hash has no blank lines, no leading dash, and no substring ambiguity — the entire defect class is designed out rather than patched.
- **Return a count.** `echo "harvest: wrote $w, skipped $s"` and rc 1 if the payload was non-empty and nothing was written. The source returns 0 unconditionally whether it wrote N or 0, which is the one part of #115 that is correct.
- **Reject the WHOLE payload before any filesystem mutation** if any item names a spec-derived target. Allowed targets are `09-known-issues.md` and `10-decisions-log.md` only; everything else is derived from the spec and must not be hand-appended. `source` must be exactly `report` or `handoff`.

- [ ] **Step 3: Author `harvest.md`** — the ceremony: read every work item's `report.md` §9 and every spine-scoped handoff; extract candidates; categorize (caveats → `09-known-issues.md`, decisions → `10-decisions-log.md`; an *enforceable* pattern is never a raw append — it is a C2 rule-authoring referral, and say that it is deferred); surface a numbered list where **every first line starts with the literal `[report]` or `[handoff]`** (the tag is a trust-calibration signal: report-origin is grounded in just-written code, handoff-origin in conversational context); consume accept/edit/reject; apply the accepted array in **one** call; record outcomes in the retrospective distinguishing applied / applied-with-edit / left-in-handoff / dropped. **Harvest never removes handoffs**, and it runs **before** worktree cleanup because it reads `report.md` out of the worktree.

- [ ] **Step 4:** Run, mutation-test (replace the hash match with the source's `grep -Fq "$text"` and confirm the blank-line and leading-dash fixtures both go RED), commit.

**Named risks:** (1) **who calls this?** — T9 step 9 must drive it; confirm the ceremony and the lib agree on the payload shape. (2) Does the blank-line fixture genuinely reproduce the source's bug before the fix? Prove the RED. (3) Is the whole-payload rejection genuinely before any write? (4) Does the count-return distinguish "wrote 0 because all duplicates" from "wrote 0 because rejected"? (5) Does the manifest key take precedence over the convention path? (6) Does §9's heading in T7's report contract match what this greps for — exactly?

---

### Task 13 (C1-13): SKILL.md bash-block harness — prose gets CI

**Context:** The final review called this *"the single highest-leverage test investment in the series"*, and the handoff owes it an explicit scope rather than an inheritance. No test anywhere extracts or checks a `SKILL.md` bash block, so a skill can document a contract another skill never implements and nothing catches it — this branch has already shipped that bug twice (B8's `[internal]` marker; B6's phantom `Skill(…, target=…)` parameters), and the port survey found a third live instance in a neighbouring plugin: a five-times-cited entry point, `sd_rules_apply`, that does not exist and passed an eval.

**Scope decision — check, do not execute.** The harness verifies **parse-validity and symbol resolution**, not behaviour. Executing arbitrary skill prose would need fixtures for every ceremony, would have side effects, and would test the fixture rather than the contract. Every check below is a mechanical fact, which is exactly the deterministic/agent-judgment line the repo's own principle draws.

**Files:** Create `ossify/tests/test-skill-bash-blocks.sh`.

- [ ] **Checks, each failing with the offending file, line and token:**
1. Every ```` ```bash ```` block in `ossify/skills/**` and `ossify/commands/**` parses under `bash -n`.
2. Every `oss <subcommand>` token appearing in any block or inline-code span resolves to a real `oss_cmd_*` in the dispatcher. **This is the check that catches the `sd_rules_apply` class.**
3. No parameterized `Skill(architect-critic:critiquing-spec,` form anywhere — the only supported invocation is the exported-args bridge.
4. No positional `$1` / `$2` / `$N` in `commands/*.md` — Claude Code substitutes those at template-render time and silently corrupts the bridge.
5. Every `references/*.md` under a skill is pointed at by that skill's `SKILL.md` (no orphans), and every pointer resolves (no dangling).
6. Every SKILL.md body is ≤500 lines, reported with its current count so the headroom is visible before an edit hits the ceiling.

- [ ] **Steps:** write the harness; run it against HEAD and **expect real findings** — if it reports nothing on a codebase this size, the extraction is broken, so verify by planting a known-bad token and confirming it is caught; fix whatever it legitimately finds; add it to `run-all.sh`'s glob (it already matches `test-*.sh`); commit.

**Named risks:** (1) Does check 2 handle multi-word and quoted invocations without false positives? (2) Does it produce findings at HEAD — and if not, is that because the codebase is clean or because the extractor is? Plant a bad token and prove it. (3) Does it catch the *historical* bugs? Re-introduce B8's contract break in a scratch copy and confirm a red. (4) Is it fast enough not to dominate `run-all.sh`?

---

### Task 14 (C1-14): Integration test, `close-gate-integrity` eval surface, budget re-measure

**Context:** The final task. One end-to-end integration test through the real dispatcher, one new LLM-judge surface for the judgment `close` introduces, and the §9.1 budget claim re-verified now that two entry skills have been added.

- [ ] **Step 1: Integration test** — `ossify/tests/test-integration-close.sh`, driving the whole arc through `bin/oss` under real strict mode: init → release → spine → work items → exec fields → demo lines → a planned amendment → work-item close → apply-pending → spine close → a second spine → release close with an expired fake → resolve it → release closed. Assert replay stays clean at the end (this is the de-facto full-op replay guard) and that `close_records` holds one record per close. Scope the header honestly to what it actually exercises and name where the un-exercised ops are covered — the B9 overclaim lesson.

- [ ] **Step 2: New eval surface `close-gate-integrity`** — 5 fixtures under `tests/eval/{fixtures,rubrics}/close-gate-integrity/`, following the established protocol (**invoke agent receives the fixture BODY ONLY, frontmatter stripped — the frontmatter is the answer key; the judge sees the full fixture**; run as a Workflow by the controller, never inline by anyone who has read the keys):
  1. A demo line fails at spine close → the ceremony **halts** and no later row runs.
  2. A flesh spine whose diff touches a bones touch surface → reclassified to bone mid-flight, bone close path taken.
  3. A fake whose expiry release is closing, unresolved → **blocking** finding; only replace or explicit-renew unblocks.
  4. A line failing for an unrelated upstream outage → **quarantine**, not retire (the parking-ticket-vs-shrug distinction).
  5. **Negative control** — a clean flesh spine where the correct behaviour is to proceed through every core row without raising anything. Per the B5 lesson, a surface where every fixture halts cannot distinguish rigor from indiscriminate paranoia; this is the fixture the surface lives or dies on.

  Rubric criteria: `halt_correct`, `no_false_halt`, `reclassification_correct`, `blocking_finding_raised`, `quarantine_vs_retire_correct`. Gate goes **23 → 28**.

- [ ] **Step 3: De-leakage pass** — grep the shipped `close`/`work-item` prose for every distinctive phrase in the five new fixtures; strip and re-domain any worked example that would turn the eval into a recall test. Record the phrases checked.

- [ ] **Step 4: Budget re-measure** — re-run the `/doctor` skill-listing measurement with `close` and `work-item` added. §9.1 targets ≈0.3-0.4% of a 200k window; ossify's three entry skills measured 2,474 chars ≈ 619 est. tokens ≈ **0.31%** on 2026-07-26. **Quote the window with the percentage** — the same listing is 0.76% on the 1M model in use, and the stack is inside budget because of the window plus the raised `skillListingBudgetFraction`, not because the listing is small. If five entry skills exceed the target, trim descriptions before shipping — do not silently accept the overshoot.

- [ ] **Step 5: Full green + close the plan.** `bash ossify/tests/run-all.sh` (ALL GREEN) · the repo-root parity suite (clean) · `bash ossify/tests/eval/lib/aggregate-scores.sh` (**28/28**, exit 0). Commit, then write the Plan C1 ledger's closing block.

**Named risks:** (1) Did the invoke agent see any frontmatter? If the controller has read the keys, the controller **cannot** serve as the invoke agent. (2) Is the negative control genuinely benign, or does it smuggle a reason to halt? (3) Does any fixture state its own answer in its body? (4) Is the integration header scoped to what it exercises, or does it overclaim? (5) Is the budget figure quoted with its window? (6) Does `close-gate-integrity` share wording with the shipped prose?

---

## Self-review

Run before dispatching Task 1.

**Spec coverage (§6, §6.1, §6.2):** work-item execution (callee) → T7; **round orchestration, dispatch, 3-iteration cap → T8**; DAG rounds + strict-order verification → T8 (round barrier); **merge halt-on-conflict → T9 (work→spine) and T10 step 2 (spine→canonical)**; impl-check → T9; cumulative demo → T6/T10; harvest → T12; §6.1 handoff/state-updates row → T10 step 11, **with the `/handoff` half explicitly deferred to C2**; worktree cleanup after harvest → T10; grill gates → already shipped in `plan-spine`; architect-critic bone/flesh split → T10; retrospective → T10; ADR check → **C2** (the ADR lifecycle is §7); ledger operations contract → T2/T6/T11; patch lane → T11; risk-gate escalation → T10; §6.2 steps 1-4 → T11; §6.2 **steps 5, 6 and 7 → C2, stated** (docs increment; handoff cleanup, which depends on the `/handoff` v2 redesign; PR gate, which needs D7 settled first).

**Owed-to-Plan-C items:** `state_restore` → T3 ✅ · bash-block harness → T13 ✅ · `oss get` state-file argument → T3 ✅ · untested wrappers driven where close uses them → T9-T11 + T14 ✅ · `test-concurrency.sh` sequential → **deferred to Plan D**, where parallel spine execution first becomes reachable; recorded rather than silently dropped.

**Placeholder scan:** no "TBD", no "similar to Task N", no "add error handling". Every lib task carries complete code; every skill task carries the exact section contract, the exact frontmatter, and the exact `oss` calls.

**Type consistency:** `oss_id_work_item_branch` (T3) is consumed by `oss_worktree_add` (T4) and `oss work_item_branch` (T9's merge) — names match. `oss_verify_zero_tests_guard` (T5) is consumed by `oss_demo_run_auto` (T6) — signature is `(command)` with output on stdin in both. `apply_demo_pending` (T2) is driven by T10 step 3. `oss_id_parse` (T3's new wrapper) is what T9's router calls. The report `## 9. Suggestions for memory bank` heading (T7) is exactly what T12's harvest greps, and T12's payload `target_file` allowlist matches the two files T10 step 9's ceremony proposes. **`demo_record_close`'s scope enum is `work_item|spine|release` (T6) but C1 only ever records `spine` and `release`** — T9's work-item close does not write one. That is deliberate (a per-work-item close record buys nothing the spine record does not carry), and T14's integration assertion is scoped to spine and release closes accordingly.

**Zero-consumer audit — run after the plan review found the engine had no caller, and re-run 2026-08-01 during Task 8's pre-dispatch sweep.** Most deliverables have a named consumer inside C1: `oss_worktree_add` → T8 step 1.2; `oss_worktree_remove` → T10 step 10; `set_work_item_exec` → T8 step 1.2 (and read back by T9 step 2.3); `apply_demo_pending` → T10 step 3; `ledger_unplan` → operator verb, surfaced by T3's doctor warning; `demo_record_close` → T10 step 11 and T11 step 7; `oss_id_parse` → T9 step 1 routing; `oss_id_spine_dir` → **T8 step 1.3** (the handoff's directory); `oss_cmd_repo_root` → T8 step 1.1, T9 step 2.3, T10 step 2; `state_restore` → T9's pre-flight remediation and T3's drift message; `fake_status` + the expiry helper → T11 step 3; `harvest_apply` → T10 step 9.

**Three deliberate exceptions, named rather than papered over.** `oss_worktree_dir` is a helper of `_add`/`_resolve`, not a lane of its own. **`oss_worktree_resolve` and `oss_worktree_list` end Plan C1 with no consumer** — the earlier version of this audit pinned both to "T8 step 2" and that was wrong: T8 spawns with `_add` and holds the returned path, T9 reads the worktree path back from state, and T10 cleans up with `_remove`. `_resolve` is a plausible recovery verb for a lost path and `_list` for a doctor row, but **neither is called in C1 and neither should acquire a call site invented to satisfy this audit**. Revisit both at Plan C1 close: either a C2 consumer is named, or they are candidates for removal.

