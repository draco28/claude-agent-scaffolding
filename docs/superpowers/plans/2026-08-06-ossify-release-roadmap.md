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
| **Tests** | 24 files, 975 assertions, ALL GREEN |
| **Evals** | 6 surfaces, 28 fixtures, 28/28 |
| **plugin.json** | `0.1.0-dev`, deliberately **not** marketplace-registered |

**The gating fact for v1:** ossify is absent from `.claude-plugin/marketplace.json` and ships no
`.codex-plugin` manifest. That is Plan D's ship gate working as designed — but it means **nobody can
install ossify today**. A v1 tag before Plan D would label something unconsumable.

**The second blocker of the same shape:** the round-orchestration execution lane has **no invoking
entry point**. No skill description matches "run the rounds" / "execute the spine". The engine is
built and wired at every seam and a user cannot reach it. That is v0.2 blocking, not a carry.

---

## v0.1.0 — the honest label for what exists (on merge of `feat/ossify-core`)

No new work. Tag what is there: a complete, tested engine that is **dogfoodable from the repo and not
yet installable**. `plugin.json` moves `0.1.0-dev` → `0.1.0`.

Ships with a known-issues note naming the two blockers above, so the gap is recorded rather than
discovered.

---

## v0.2.0 — reachability + the review carries

The theme is *make what exists usable and true*. Nothing new is built.

**Blocking**
1. **An entry point for the execution lane.** Whatever form it takes (a sixth command, a `work-item`
   description that matches the round-driving intent, or a `plan-spine` hand-off), a user must be able
   to say "run the rounds" and land in `round-orchestration.md`.

**7 remaining majors** (4 of the original 11 were fixed in `5c52e91`)
2. Patch-lane records are asserted twice to be `doctor`-visible; `oss doctor` never reports one.
3. The companion-spec release-close boundary audit is absent from release close *and* from its
   "deliberately not shipped" table, while `start` tells the user it executes.
4. `oss migrate` has zero prose consumers, and close's pre-flight names a remedy that cannot fix the
   failure it is offered for.
5. `_oss_worktree_ignore` skips any repo whose `.git` is a file, leaving a `--separate-git-dir` or
   submodule canonical permanently dirty.
6. `retrospective.md` claims the harvest sweeps retrospectives; it does not, and a candidate harvested
   from one is rejected whole-payload.
7. pre-flight Gate 2's malformed-AC detector names three causes that all produce non-empty output, so
   the gate cannot fire for any of them.
8. (Counted with 2-7 above; see the review file for the full text of each.)

**Filed separately, same release** — `task_cab0ee8c`
9. 42 of ~56 dispatcher verbs die with a raw `unbound variable` instead of the taxonomy's rc 2.
10. Lock-acquire conflates "lock held" with "state dir missing", so an uninitialised project is told to
    retry or run `doctor` when the fix is `oss init`.

**13 minors + 3 nits** — batch them here; several are one-line prose corrections.

**Carried from Plan C1's MINOR-FOR-FINAL:** `oss worktree_list` and `oss manifest_get` still have zero
consumers — decide per verb: give it one, or remove it.

Full detail: `docs/superpowers/reviews/2026-08-05-plan-c1-branch-review.md`.

---

## v0.3.0 — Plan C2: records, evolution, utilities (spec §7–§8)

The version where ossify stops needing scaffold-dev alongside it.

- **The `doctor` entry skill** — the 6th and last of §9.1: state inspection, lean-spec validation,
  machine-checkable-rules authoring, interop check, budget check. Several v0.2 findings resolve
  *into* this skill rather than beside it (patch-lane visibility, the migrate remedy), so sequencing
  matters: fix them in v0.2 where they are wrong, and let `doctor` absorb them here.
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

---

## v1.0.0 — Plan D: boundary + ship gate (companion §4–§6; main §10, §13.4)

v1 means **installable and proven on a real project**. The pilots earn the number, not the feature count.

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
