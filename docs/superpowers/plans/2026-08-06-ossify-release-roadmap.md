# ossify release roadmap — v0.1.0 → v1.0.0

**Authored 2026-08-06**, at Plan C1 close (branch `feat/ossify-core`, 82 commits, HEAD `5c52e91`).
Supersedes the informal "Series map" sketch in `2026-07-29-ossify-plan-c1.md` by pinning each
remaining bucket to a **version target** rather than only to a plan letter.

---

## Where ossify stands today

| | |
|---|---|
| **Shipped** | Plans A + B + C1 |
| **State engine** | 12 libs, 61 dispatcher verbs, schema v3, journal + replay + restore |
| **Entry skills** | 5 of the 6 §9.1 allocates: `start`, `plan-release`, `plan-spine`, `work-item`, `close` |
| **Execution engine** | worktrees, per-AC verification, work-item dispatch, round orchestration |
| **Close ceremonies** | all three — work item → spine → release |
| **Tests** | **25 files, 1,025 assertions, ALL GREEN** (v0.1.0 shipped 24/981; 975 was the pre-merge branch figure) |
| **Evals** | 6 surfaces, 28 fixtures, 28/28 |
| **plugin.json** | **`0.2.0`**, deliberately **not** stable-marketplace registered |

**The gating fact for v1:** ossify is absent from `.claude-plugin/marketplace.json` and ships no
`.codex-plugin` manifest. It is experimentally installable in OpenCode only through the root bundle's
explicit four-plugin allowlist after an immutable bundle tag is published. That narrow v0.x path does
not make Ossify stable or put it in the Claude/Codex marketplaces. A v1 tag before Plan D's
consolidated eval and two-pilot gate would claim evidence the project does not yet have.

~~**The second blocker of the same shape:** the round-orchestration execution lane has **no invoking
entry point**.~~ **RESOLVED in v0.2.0** — `/run-spine <spine-id>` plus an orchestrator mode in
`work-item` §2, with §2's "no handoff path → ask once" rule carved out so the routing actually
reaches the lane. The engine C1 shipped is reachable.

---

## v0.1.0 — the honest label for what exists (on merge of `feat/ossify-core`)

No new engine work. The complete, tested engine is dogfoodable from the repo and experimentally
installable through OpenCode's explicit allowlist after a root bundle release. `plugin.json` is
`0.1.0`; stable Claude/Codex marketplace installation remains gated on Plan D.

Ships with a known-issues note naming the two blockers above, so the gap is recorded rather than
discovered.

---

## v0.2.0 — reachability + the review carries — **SHIPPED**

The theme was *make what exists usable and true*. Nothing new was built.

> **SHIPPED.** Plan: `2026-08-09-ossify-v020.md`, 11 tasks, all closed. Suite 981 → **1,025**
> assertions across 25 files, eval 28/28. Everything below is kept as the historical scope
> statement; **the plan is the record of what actually happened**, and it corrects several figures
> here that were measured on the pre-merge branch.
>
> **Delivered:** the execution-lane entry point (`/run-spine`) with WI-3…WI-6; the reopened
> pre-flight Gate 2 major plus `redgate`'s rc conflation; 44 dispatcher arity guards; the
> lock-vs-uninitialised conflation; `oss release_dir`; three retired helpers; audit batches **A, B
> and C**; both absorbed capability references (`debugging.md`, `code-review.md`); all 13 C1 minors
> and both distinct nits; and a **new `check 7`** guarding the every-call description budget, which
> nothing had enforced.
>
> **Corrections this release proved:** item 7 was **not** resolved in PR #117 — only 1 of its 3
> causes was (reopened above, fixed in v0.2 T2). Item 9's "42 of ~56" is **44 of 61**. "13 minors +
> 3 nits" is 13 minors + **2 distinct** nits — two entries are the same defect. The zero-consumer
> verbs were **four**, not two, and three were retired. `task_cab0ee8c` resolves to no artifact; its
> content survived only as items 9 and 10 here.
>
> **Three more prose claims were found false and fixed:** `target_repo`'s documented rc-2 halt does
> not fire for `ai_workspace` (rc 0, and a worktree lands in the AI workspace); `cross-repo` claimed
> a verification neither impl-check nor spine close performs; `fake-ledger-discipline` had the
> expiry gate's field logic inverted.

**Blocking**
1. **An entry point for the execution lane.** Whatever form it takes (a sixth command, a `work-item`
   description that matches the round-driving intent, or a `plan-spine` hand-off), a user must be able
   to say "run the rounds" and land in `round-orchestration.md`.

**7 remaining majors** (4 of the original 11 were fixed in `5c52e91`)
2. ~~Patch-lane records are asserted twice to be `doctor`-visible; `oss doctor` never reports one.~~ **RESOLVED in PR #117** (Droid review round) — doctor now surfaces patch records.
3. ~~The companion-spec release-close boundary audit is absent from release close *and* from its "deliberately not shipped" table, while `start` tells the user it executes.~~ **RESOLVED in PR #117** (Droid review round) — posture-block.md and release-close.md now state the deferral explicitly.
4. `oss migrate` has zero prose consumers, and close's pre-flight names a remedy that cannot fix the failure it is offered for.
5. ~~`_oss_worktree_ignore` skips any repo whose `.git` is a file, leaving a `--separate-git-dir` or submodule canonical permanently dirty.~~ **RESOLVED in PR #117** (Droid review round) — now resolves via `git rev-parse --git-common-dir`.
6. `retrospective.md` claims the harvest sweeps retrospectives; it does not, and a candidate harvested from one is rejected whole-payload.
7. **REOPENED 2026-08-09** — pre-flight Gate 2's malformed-AC detector. Only **one of three** causes was fixed in PR #117 (`verify_acs` now skips missing-backtick ACs with a stderr warning, and pre-flight.md's prose was corrected). Re-reproduced against `main`: the ASCII `->` and missing-`expected:` variants still emit a row whose expectation field is garbage, and **`oss redgate` returns rc 0 = "proceed"** on it because it folds `oss_verify_auto_step`'s rc 2 (malformed) into rc 1 (red). The review's Fix (a) landed; Fix (b) did not. Owned by Task 2 of `2026-08-09-ossify-v020.md`.
8. (Counted with 2-7 above; see the review file for the full text of each.)

**Additionally resolved in PR #117** (Droid review round — not previously tracked):
- `ledger_add_auto`/`ledger_add_user` accepted demo lines for nonexistent spine ids; now validates the spine exists (rc 7) before journaling.

**Filed separately, same release** — `task_cab0ee8c`
9. 42 of ~56 dispatcher verbs die with a raw `unbound variable` instead of the taxonomy's rc 2.
10. Lock-acquire conflates "lock held" with "state dir missing", so an uninitialised project is told to
    retry or run `doctor` when the fix is `oss init`.

**13 minors + 3 nits** — batch them here; several are one-line prose corrections.

**Carried from Plan C1's MINOR-FOR-FINAL:** `oss worktree_list` and `oss manifest_get` still have zero
consumers — decide per verb: give it one, or remove it.

**Capability-gap absorptions (2 of 7)** — from
`2026-08-09-ossify-capability-gap-absorption.md`. Reference-doc authoring (content, not engine),
consistent with this release's "make what exists usable" theme:
- **`debugging.md`** under `work-item` — the execution lane is being made reachable this release;
  debugging is its natural companion when a RED won't clear non-trivially.
- **`code-review.md`** under `close` — close is being fixed this release; code review (two-axis:
  Standards + Spec over the actual diff) is a close-time activity.

Full detail: `docs/superpowers/reviews/2026-08-05-plan-c1-branch-review.md`.

---

## v0.3.0 — Plan C2: records, evolution, utilities (spec §7–§8)

The version where ossify stops needing scaffold-dev alongside it.

- **The `doctor` entry skill** — the 6th and last of §9.1: state inspection, lean-spec validation,
  machine-checkable-rules authoring, interop check, budget check. Several v0.2 findings resolve
  *into* this skill rather than beside it (patch-lane visibility, the migrate remedy), so sequencing
  matters: they were fixed in v0.2 where they were wrong, and `doctor` absorbs them here.

  > **HARD PREREQUISITE — Batch E must land first, and the margin is now one character.**
  > v0.2 closed with the five entry-skill descriptions at **3,120 of the 3,121-char budget**, and
  > `check 7` in `tests/test-skill-bash-blocks.sh` now **fails the suite** if that is exceeded.
  > `doctor`'s description is the sixth and cannot fit. Batch E (SP-4, X-1, X-2, START-7, WI-8,
  > CL-12, CL-13, CL-17 + the description diet) has to free roughly **120 tokens** before `doctor`
  > can ship. This is no longer advisory — it is a red test.
  >
  > Two other v0.3 items to fold in while `doctor` is open: **orphan worktree detection** (the one
  > real use of the `worktree_list` verb v0.2 retired — build the primitive against this
  > requirement, not before it), and a decision on whether the feature map ever earns a **persisted
  > rank/prune** (v0.2 settled it as conversational; `doctor` + records is where the argument
  > belongs if it returns).
- **The machine-checkable-rule evaluator** — C1 shipped the gate *without* one by decision D2, next to
  rule authoring where a correct evaluator can be built and tested against real rule blocks.
- **Docs-increment trigger table** at release close.
- **ADR lifecycle completion** — `Superseded-by`, `proposed-then-flip` as the bone default.
- **`/amend-spec` architecture-revision lane**, with mandatory citation re-verification.
- **Eight utility commands** — `/handoff`, `/defer`, `/work-pr`, `/adr`, `/flip-adr`, `/amend-spec`,
  `/changelog`, `/runbook`.
- **`pr_hierarchical`** (spine→release PR). D7 must be settled first: spec §6.2 step 7 conflates two
  tiers, and C1 deliberately did not resolve it.
- **`/handoff` v2 is a redesign, not a port.** `2026-07-29-session-handoff-v2-design.md` is approved;
  its task set is absorbed, not re-derived. Adds two eval surfaces and forces two amendments to the
  main spec (§8.1's `handing-off-session` row, §9.1's references-live-under-their-entry-skill rule).

**Capability-gap absorptions (5 of 7)** — from
`2026-08-09-ossify-capability-gap-absorption.md`. The remaining 5 reference docs, landing alongside
the entry skills they live under:
- **`research.md`** under `start` — investigate tech claims beyond smoke-test scope; cited Markdown,
  background-agent-capable.
- **`prototype.md`** under `start` — throwaway HTML for UI/state/logic design questions; expands the
  spike family alongside `spike-contract.md`.
- **`merge-conflict-resolution.md`** under `close` — hunk-by-hunk resolution by intent, never
  `--abort`; fills the halt-and-surface gap.
- **`domain-modeling.md`** under `start` (cross-ref from `doctor`) — ubiquitous-language discipline,
  authored at onboarding and evolved at release closes.
- **`codebase-design.md`** under `plan-spine` — deep-module vocabulary for module-boundary decisions
  during decomposition.

---

## v1.0.0 — Plan D: boundary + ship gate (companion §4–§6; main §10, §13.4)

v1 means **stable-marketplace installable and proven on real projects**. Experimental OpenCode v0.x
installability is the narrow precursor, not the claim. The pilots earn the number, not the feature count.

- **workspace-init additive extension** — visibility fields, `private_core`, all three resolvers,
  `add-private-core`.
- **Multi-repo worktrees + cross-repo dependency overrides.** C1 left the repo dimension extensible
  (`target_repo` is threaded through) without building it; this is where it lands.
- **The release-close boundary audit** — also v0.2 finding #3, which fixes the *false claim*; this
  builds the thing.
- **The consolidated eval suite — THE ship gate.**
- **Marketplace registration** + `.codex-plugin` manifest + `V0_PLUGINS` entry. Note early
  registration breaks `tests/test-codex-dual-publish.sh`, which needs both together.
- **Two pilots:** Forge3D greenfield, pulse-trader adopt-forward.

**Why the pilots gate v1.** ossify's claim is that it replaces the scaffold-onboard + scaffold-dev
pair. Tagging v1 without migrating a real project asserts that from design intent alone. The pilots
convert it into a demonstrated one — and they are also the only thing that will exercise the close
trilogy against a codebase nobody wrote fixtures for.

---

## Sequencing notes

- **v0.2 before v0.3 is not negotiable.** Several C2 deliverables (`doctor`, the rule evaluator) are
  the natural home for v0.2 findings. Fixing the false claim first and building the feature second
  keeps the two separable; doing it the other way buries a known-wrong statement inside new work.
- **The three migrations** (pulse-trader → fully-private, PulseDB → open-core, PulseHive →
  fully-open + doc-split) remain a **separate task** from this roadmap, per the standing decision.
- **Plan C1's deferrals are all stated in shipped prose**, verified at close — so a reader hitting a
  gap finds a note rather than silence. Preserve that property in every release below.
