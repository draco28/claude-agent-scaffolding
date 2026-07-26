# Spec authoring (per round)

Depth for SKILL.md §6. One spec per work item, authored where the DAG allows
rather than all upfront.

---

## 1. Layout

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<kebab-slug>/
├── SPINE.md                       # the spine plan: items, rounds, demo contribution, fakes
└── work-<work-id>/
    └── spec.md                    # one per work item
```

Ids are used **verbatim**. ossify's ID grammar has one owner (spec §9.2): release
`r<N>`, spine `r<N>.s<K>`, work item `r<N>.s<K>.w<J>`, branch
`spine/<spine-id>-<kebab-slug>`. Directories, branches, worktree paths, and ledger
keys all derive from it without transformation — no re-shaping, no `VS-` forms, no
zero-padding a work-item number to look tidy.

The kebab slug comes from the spine's recorded name
(`oss get '.spines[] | select(.id=="…") | .name'`). If it sanitizes to empty, stop
and fix the spine's name in state rather than inventing a directory slug.

---

## 2. What a work-item spec carries

| Section | Content |
|---|---|
| **Goal** | What this item delivers, in one paragraph, in product vocabulary |
| **Context** | Which bones it rides; which registered touch surfaces (if any) it hits and the controls that came with them |
| **Target repo** | Exactly one (`cross-repo.md`) |
| **Approach** | The intended change, at the level a fresh session could execute |
| **Acceptance criteria** | Machine-checkable `auto:` lines + any `user:` step. These are the item's ACs, distinct from the spine's ledger contribution (§4) |
| **Citations** | Lean MASTER-SPEC sections + bones ADRs it depends on (`citation-foldin.md`) |
| **Out of scope** | What a reader might reasonably assume is included and is not |

Never author a parallel prose AC table beside the machine-checkable lines. One AC
source of truth per item — the split is what produced the predecessor stack's
zero-ACs class of bugs.

---

## 3. Per-round authoring, full-plan visibility

**Author round 1's specs now.** A later round's spec may be authored when its
round starts — by then the rounds ahead of it will have taught you something, and
a spec written before that is a spec written twice.

What is **not** deferred is the **plan**. The user and the critic see the whole
spine at once: every work item, the round structure, the demo contribution, the
fakes, and the amendments. Per-round authoring relaxes *when the spec text is
written*, never *when the spine is understood*.

Two things this buys, and one thing it costs:

- Round *K*'s spec cites what rounds 1…*K-1* actually landed, not what they were
  predicted to land.
- A round that changes the plan (a gap surfaced during execution) re-plans cheaply
  — there is no stale spec text downstream to reconcile.
- The cost: someone must remember to author round *K*'s spec at round *K*'s start.
  That is the execution engine's first step for the round, and it is why the plan
  records the rounds explicitly.

---

## 4. Spine ACs vs ledger lines

They are different artifacts with different lifetimes, and conflating them fills
the cumulative ledger with per-item scaffolding:

| | Work-item ACs | Ledger demo lines |
|---|---|---|
| Scope | One work item | The whole product |
| Lifetime | Until the item merges | Forever, until superseded/retired |
| Run by | `implementation-checking` at the item's gate | The cumulative demo, at every future spine close |
| Authored in | `spec.md` (§2) | `oss ledger_add_auto` / `ledger_add_user` (§8) |

An item AC that asserts an internal helper returns the right shape is a good AC
and a terrible ledger line. Promote to the ledger only what states something
**about the product** that must remain true.

---

## 5. Citation fold-in

A mechanical step of authoring, not a ceremony: every citation resolves, or the
spec does not lock. Full rules — the target set, the Release 0 narrowing, and the
mandatory re-verification after any bone change — in `citation-foldin.md`.

---

## 6. Adversarial pass (optional, at the full plan)

If the user wants the plan audited before build, run architect-critic **against
the spine plan** (`SPINE.md` plus the specs that exist), after the plan settles.

1. **Probe:** `oss critic_detect`. On `absent`, warn once — *"architect-critic not
   installed — skipping the spine-plan audit. Install via `/plugin install
   architect-critic` (v0.2+)."* — and continue. Never block on it.
2. **Invoke** via the env-var bridge. This is architect-critic's **only**
   invocation contract:

   ```bash
   export ARCHITECT_CRITIC_ARGS="--spec \"<absolute path to SPINE.md>\" --close"
   ```

   ```text
   Skill(architect-critic:critiquing-spec)
   ```

   Three details are load-bearing and each fails **silently** when wrong:
   **`export` it** (a bare assignment is invisible to the bash that reads it);
   **one quoted absolute path** after `--spec`, never a list (the CLI path reads
   exactly one artifact); **`--close` inside the args string** — it is the only
   thing that selects close depth, and announcement wording does not.

   There is **no** `target=` / `depth=` / `artifact_path=` parameter. Passing one
   resolves the wrong artifact at the wrong depth without any error.
3. **On return, triage the standing challenges** and fold accepted ones back into
   the plan (§4 decomposition, §5 rounds, §8 demo contribution) before locking.

This is a **planning** audit. The bone spine's full close-depth audit with the
external adversary belongs to `close`, and it is a different moment with a
different artifact.

---

## 7. Anti-patterns

- **Authoring every round's spec upfront** because that is how it used to work
  (§3). The plan is upfront; the spec text is per round.
- **Hiding the plan from the critic** because only round 1's spec exists. The
  critic sees the full spine plan (§3).
- **A parallel prose AC table** beside the machine-checkable lines (§2).
- **Promoting per-item scaffolding ACs into the cumulative ledger** (§4).
- **Passing `target=` / `depth=` / `artifact_path=` to architect-critic**, or
  assigning `ARCHITECT_CRITIC_ARGS` without `export`, or passing more than one
  `--spec` path (§6).
- **Blocking the plan on architect-critic's absence.** Warn once and proceed.
- **Re-shaping an id for a directory name** — verbatim, always (§1).
