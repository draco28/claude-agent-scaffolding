---
name: close
description: 'Run ossify''s context-routed close ceremony — one skill, three scopes, routed mechanically from the id''s shape: a work item (r1.s2.w3) runs the three-layer implementation gate then commits and merges its branch into the spine branch; a spine (r1.s2) runs the cumulative demo, the critic pass, the retro, the harvest and cleanup; a release (r1) runs the full user walkthrough and the blocking close findings. Core rows are never skippable in either class — the skill executes a fixed checklist, not a judgment call. Use this when the user says close work item r1.s2.w3, close the spine, close spine r1.s2, close the release, run the close ceremony, run the impl-check gate, or /close <id>. Do NOT use for decomposing a spine or authoring specs and demo criteria (use /plan-spine), release selection or the class declaration (use /plan-release), or executing a work item from its handoff (use /work-item).'
---

# close

You are ossify's **close ceremony** (spec §6, §6.1, §6.2). One skill, three
scopes, and the scope is decided by the id you were given — never by asking.

`oss` (the dispatcher over `lib/*.sh`) supplies the mechanical facts: which shape
an id is, whether a command exited as declared, whether a report accounts for
every AC. The judgment — is this deviation acceptable, does this diff violate a
documented pattern, is this failure the code's fault or the criterion's — happens
here, in your reasoning. Do not stuff it inside `bash -c '...'` wrappers.

---

## 1. Overview and when to use

Where it sits: `start` → `plan-release` → `plan-spine` → execution (`work-item`)
→ **`close` (you are here)**.

Three scopes, innermost first:

| Scope | Id shape | What it closes |
|---|---|---|
| Work item | `r<N>.s<K>.w<J>` | one implementation unit: the gate, the commit, the merge into the spine branch |
| Spine | `r<N>.s<K>` | the spine: cumulative demo, critic, retro, harvest, cleanup (§5) |
| Release | `r<N>` | the release: full `user:` walkthrough and the blocking findings (§6) |

**The guarantee, and it is structural:** *core rows are never skippable in either
class — this skill executes a fixed checklist, not a judgment call* (spec §6.1).
Bone and flesh differ in the **depth** of the optional rows (grill gates, critic
depth, retro length), never in whether a core row runs. When a step in a
reference says **halt**, the ceremony stops there: no later step runs, nothing is
recorded, and the recovery is the user's to pick.

**Trigger phrases (description-match):**

- `/close <id>` (slash command — see §8 for the `$ARGUMENTS` bridge)
- "close work item r1.s2.w3", "close the spine", "close spine r1.s2", "close the
  release", "run the close ceremony", "run the impl-check gate"

**Do NOT auto-invoke when:**

- The user wants to decompose a spine, author a spec, or author demo criteria —
  that is `/plan-spine`. You *run* demo lines; you never author or edit one.
- The user wants to select spines for a release, phrase exit criteria, or declare
  a class — that is `/plan-release`.
- The user wants to execute a work item from its handoff — that is `/work-item`.
  You never run the implementer's loop, and it never runs your gate.
- **No id was given.** Refuse and list what is open rather than guessing; see §2.

---

## 2. Routing

The scope is derived **mechanically from the id's shape**. Never ask which scope
the user meant, and never infer it from the wording of the request.

```bash
id="<the id from $ARGUMENTS>"
parts="$(oss id_parse "$id")" || parts=""
scope="$(printf '%s\n' "$parts" | awk '{print $1}')"
```

`oss id_parse` echoes **one space-separated line whose first field is the scope
and whose remaining fields are the numeric components** — `r1.s2.w3` yields
`work_item 1 2 3`, `r1.s2` yields `spine 1 2`, `r1` yields `release 1`.

**Route on the first field only.** Comparing the whole line against the bare word
`work_item` never matches, because the numeric components are on the same line.

| `scope` | Go to |
|---|---|
| `work_item` | §4 |
| `spine` | §5 |
| `release` | §6 |

**An unparseable id exits rc 1 with empty stdout *and* empty stderr.** The lib
says nothing at all, so the one-line error is yours to emit — name what was
passed and show the three shapes:

> `close`: `<what was passed>` is not an ossify id. Work item `r1.s2.w3`, spine
> `r1.s2`, release `r1`.

**With no id at all, refuse and list what is open** — `oss spine_list`, or
`oss get` with a status filter. Do not close "the current thing": a close run
against the wrong scope is expensive to undo and every step of it looks fine.

Full routing rules — the id grammar, the no-argument refusal, the shapes that are
deliberately not ids, and the routing anti-patterns — in
**`references/routing.md`**.

---

## 3. Pre-flight (common to all three scopes)

Runs before any scope's first step, every time.

```bash
oss manifest_require || exit 0        # refuse: run /init-workspace or /pair-workspace first
oss doctor                            # schema + replay must be green
canonical="$(oss repo_root canonical)"
ai_root="$(oss repo_root ai_workspace)"
```

1. **Manifest.** `oss manifest_require` fails when there is no workspace-init
   pairing manifest. Refuse naming the literal tokens **`/init-workspace`** and
   **`/pair-workspace`** — do not paraphrase them.
2. **`oss doctor` must be green on `schema` and `replay`.** A close *mutates*
   state; running one over a drifted state compounds the drift into the record
   that every later ceremony reads. The remedy to name is **`oss state_restore`**,
   which rebuilds the live state from base + journal. `warn:` lines (a held lock,
   a pending amendment, an outstanding fake) are not blockers here — they are
   inputs the spine and release layers act on.
3. **Resolve every path to an absolute one up front, and never `cd`.** The
   manifest walk starts at `$PWD` and the dispatcher re-runs it on every call that
   takes no explicit state path, so a `cd` mid-ceremony silently re-points the
   state file rather than failing. Probe once with `oss state_path` and
   `oss repo_root <key>`, carry the results as absolute paths, and reach every
   repo with `git -C "<abs>"`. Do **not** work around this by exporting
   `OSS_STATE_FILE`: that changes resolution precedence for every nested call and
   is not what the other lanes do.

---

## 4. Work-item close

The innermost scope, and the one the execution lane hands you directly: a
`complete` return from the implementer is not a green gate — it reports that the
loop ran (`work-item/references/round-orchestration.md` §6). Running the gate is
yours.

Six steps, in **binding order**:

1. **Resolve the three absolute paths** — `spec.md`, `report.md`, the worktree —
   by one of two routes (the round flow's return payload, or a standalone
   reconstruction from the id). Neither is optional to know: `/close <id>` is
   supported with no round in scope.
2. **Run the gate** (§4's three layers, below).
3. **Prove there is something to commit** — a green gate over an empty index
   means the work is not where the commit will look for it.
4. **On green:** commit **in the worktree**, merge its branch into the spine
   branch canonical is parked on — reading the branch from `work_items[].branch`,
   never re-deriving it from a slug you do not have — and set the work item
   `complete` **last**, after the merge is verified landed. Spine close reads
   `complete` as "this item's work is on the spine branch".
5. **On any failure: halt**, surface the source-tagged errors, present the
   recovery menu, and **stop — no auto-select.**
6. **Worktree cleanup does not happen here.** It is the last step of spine close.

Full step detail — both path-resolution routes, the staging proof, the merge
block with its merge-target check, and why cleanup is deliberately absent — in
**`references/work-item-close.md`**.

The gate itself — the three layers, their halt semantics, the literal error tags
and the recovery menu — is in **`references/impl-check.md`**. Read it before
running step 2; it is what "impl-check" means everywhere else in this plugin.

**A note on disposition triage (spec §6.1, #109 policy), because its scope is
easy to over-read:** spec-aligned **disposition** recommendations auto-apply and
only load-bearing escalations reach the user. That is a deliberate behavioural
change from the predecessor stack, which surfaced and waited at every decision
boundary — so state it rather than letting a reviewer "fix" it back. It governs
the **disposition rows**, which arrive with the critic findings at *spine* close.
**This layer has no disposition step, and its recovery menu is never
auto-selected**: a failed gate is a human decision, not a spec-aligned
recommendation.

---

## 5. Spine close

The middle scope, and the one the ceremony is named for (spec §6.1). Eleven
steps, in **binding order**:

1. **Every work item `complete`**, else refuse and **name the offender**. Test
   the *output* of the `oss get` — a `select` matching nothing exits 0.
2. **Switch canonical back to its `base_branch`, then merge the spine branch in**,
   halting on conflict. **Derive the spine branch with `oss branch_name` and
   assert HEAD matches it — never read it off HEAD**; then assert the switch-back
   actually moved HEAD, and check reachability after the merge. Each of those
   guards catches a distinct failure that is otherwise rc 0 all the way to a
   green close.
3. **`oss ledger_apply_pending <spine>`** — after the merge, before the demo.
4. **The cumulative demo**: `oss demo_run` for every active `auto:` line, then
   walk **this spine's own** `user:` lines (`oss demo_user_lines <spine>`) with
   the human. **Halt on the first failure** — no later step runs.
5. **The changed-path list, then `oss touch_check`.** The list is the merge's own
   diff. **rc 0 = hit, rc 1 = clean, rc 2 = could-not-check, and rc 2 is not
   clean.** A bone hit reclassifies the spine mid-flight via `oss class_set`
   (three arguments — the reason is required).
6. **Risk-gate escalation**, distinguished from a bone hit by the printed prefix,
   and it escalates regardless of class.
7. **architect-critic**, class-scoped: `--close` on bone, **absent on flesh**.
   Guard `oss critic_detect` — it prints `absent` and returns rc 1.
8. **The retrospective**, against a fixed section contract.
9. **Memory-bank harvest** — always before cleanup.
10. **Worktree + branch cleanup**, per work item. Only now.
11. **State updates**: `oss spine_status <spine> closed` and `oss demo_record`.

Full step detail — the merge block with its four guards, the changed-path
computation, the class-scoped critic bridge, and the bone/flesh column from spec
§6.1 as a table — in **`references/spine-close.md`**.

The demo layer — the cumulative `auto:` half, the spine-scoped `user:` half, the
halt discipline, quarantine as a parking ticket, and the ledger's wall-clock
budget — is in **`references/cumulative-demo.md`**.

The two retrospective section sets, full for bone and lean for flesh, are pinned
verbatim in **`references/retrospective.md`**. It is the only copy.

---

## 6. Release close

The full cumulative `user:` walkthrough against the amended line set, the blocking
close findings (fake expiry, outstanding quarantines), the release retrospective,
and the feature-map re-groom. Its binding order lands with this section's
references.

**Refuse early** when any spine in the release is not closed — name it.

---

## 7. Anti-patterns (do not do these)

- **Routing on anything but the id's shape.** Not the phrasing of the request,
  not what closed last, not the branch you happen to be on (§2).
- **Comparing `oss id_parse`'s whole output against a bare scope word.** The
  numeric components share the line; take the first field (§2).
- **Guessing a scope when no id was given.** Refuse and list what is open (§2).
- **Running a layer's steps out of order.** Every layer's order is binding
  because each step's output is the next one's input — the gate reads the paths
  step 1 resolved, the merge reads the branch step 4 confirmed.
- **Treating a halt as advisory.** A halt is terminal: no later step runs, no
  status is written, nothing is recorded as closed.
- **Auto-selecting from the recovery menu** (§4).
- **Reading the spine branch off HEAD** instead of deriving it and asserting the
  match, or merging without switching canonical back first (§5). Both failures
  are rc 0 and green.
- **Folding `oss touch_check`'s rc 2 into "clean"**, or reading rc 0 as clean
  (§5).
- **Carrying `--close` on a flesh spine's critic pass**, or dropping it on a
  bone's (§5).
- **Closing a scope whose children are not closed** — a spine with an unfinished
  work item, a release with an open spine (§5, §6).
- **`cd`-ing mid-ceremony**, or exporting `OSS_STATE_FILE` to compensate (§3).
- **Authoring or editing a demo line, a spec, or an AC to make a gate pass.** You
  run them. A criterion that is genuinely wrong goes back through `/plan-spine`,
  recorded, with the close halted meanwhile.
- **Letting this body exceed 500 lines.** Hard cap; depth goes to `references/`.

---

## 8. Notes on tool boundaries

- **You** (Claude reading this body) make every judgment: whether a diff violates
  a documented pattern, whether a report's account of an AC is honest, which
  recovery path to *offer*, whether a deviation is acceptable.
- **`oss`** handles mechanical facts only, and holds no judgment: `id_parse`
  (the id's shape), `manifest_require`, `doctor`, `state_restore`, `state_path`,
  `repo_root`, `spine_dir`, `spine_list`, `branch_name`, `get`, `verify_acs` (AC parsing),
  `verify_step` (the expectation predicate, including the vacuous-green guard),
  `report_cross_check`, `work_item_status`, `worktree_resolve`,
  `worktree_remove`, `ledger_apply_pending`, `ledger_quarantine`, `demo_run`,
  `demo_user_lines`, `demo_record`, `touch_check` (glob matching — never the
  meaning of a match), `class_set`, `veto_add`, `critic_detect` (a filesystem
  probe), `spine_status`.
- **`git`** is reached only as `git -C "<absolute path>"` (§3). The commit
  boundary is yours and the implementer's never; the merge target comes from
  state, never from a slug.
- **Peer entry skills:** `start` owns spec-core and the bones registry;
  `plan-release` owns spine selection, exit criteria and the class declaration;
  `plan-spine` owns decomposition, specs and demo-line authoring; `work-item`
  owns execution and stages without committing.
- **The user** is the final authority on every recovery choice and every
  override. You surface the failure with its source tag and the menu; they pick.

---

## 9. Slash-command interaction

`/close <id>` (`commands/close.md`) exports the raw argument string as
`$ARGUMENTS` through an env-var bridge. **Parse `$ARGUMENTS` in bash; never
reference `$1` / `$2` / `$N`** — Claude Code substitutes positional tokens in
command bodies at template-render time and silently corrupts them.

The only argument is the id. When it is missing, emit one line, list what is
open, and stop (§2).
