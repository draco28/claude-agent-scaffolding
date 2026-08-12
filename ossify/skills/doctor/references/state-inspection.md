# State inspection

The depth behind `doctor/SKILL.md` §4. `oss doctor` is the mechanical half; the
judgment about what a line *means for this project today* is yours.

---

## 1. The line grammar

Every check prints exactly one line, tagged:

| Tag | Meaning | Touches rc? |
|---|---|---|
| `ok:` | ran, found nothing | no |
| `warn:` | ran, found something advisory | **no** |
| `fail:` | ran, found something broken | **yes — rc 1** |
| `skip:` | could not run, and says so | **no** |

Two properties are load-bearing and are asserted by tests rather than assumed:

- **A check that cannot run still emits a line.** `skip: replay - skipped
  (schema check failed)` and `skip: worktrees - skipped (no resolvable canonical
  root…)` both exist because a *missing* line is indistinguishable from a clean
  one. Never summarise a run in a way that drops a `skip:`.
- **`warn:` never changes the rc.** So `oss doctor` exiting 0 does **not** mean
  "nothing to report" — it means "nothing broken". Read the lines, not the rc.
  A close pre-flight that only checks the rc will happily proceed past four
  outstanding warnings, which is correct behaviour and worth knowing.

---

## 2. The checks, in print order

| Check | Reads | What it catches |
|---|---|---|
| `schema` | state file | a `schema_version` this build cannot handle |
| `lock` | `<state>.lock` dir | a held lock, or a stale one (>30 min) |
| `replay` | journal | live state that disagrees with base + mutations |
| `shape` | state file | any of the 16 required top-level keys missing |
| `ledger` | `demo_ledger` | pending amendments; quarantined lines |
| `fakes` | `fakes` | `active` **or** `renewed` fakes still outstanding |
| `patches` | `patch_records` | out-of-spine work since the last spine close |
| `worktrees` | **the repo** | directories no work item claims (§4) |

`replay` is gated on `schema`, because replaying against a version this build
cannot read produces noise rather than a finding. That gating is why the `skip:`
line exists.

---

## 3. The remedy table

**Echo `doctor`'s own failing line rather than substituting a fixed remedy.**
The remedy differs by line, and the wrong one loops the operator:

| `doctor` line | Remedy |
|---|---|
| `fail: replay` | **`oss state_restore`** — rebuilds live state from base + journal |
| `fail: shape` | **`oss state_restore`** — a required key is missing; same rebuild |
| `fail: schema`, version **below** this build | **`oss migrate`** — the state predates this build |
| `fail: schema`, version **above** this build | **upgrade ossify.** `migrate` accepts v1/v2 only; there is no downgrade |
| `fail: state` | **`oss init <name>`** — this project was never initialised |
| `warn: lock` (stale) | `rmdir '<state>.lock'`, **only** if no ceremony is running |

**The table is a starting point keyed on the tag, and the tag is not the whole
finding.** Read the rest of doctor's line before recommending anything — the
same four tags cover conditions these verbs cannot repair:

- **A schema version *newer* than this build.** `oss migrate` accepts v1/v2; a
  future version is an ossify upgrade, not a migration. doctor already says
  *"requires a newer ossify"* in its own line, which is exactly why you echo it.
- **A corrupt journal, or a missing base snapshot.** `oss state_restore`
  refuses both by name. Recommending it anyway sends the operator around a loop
  whose every lap looks like progress.

Why this is not pedantry: against a v1/v2 state, `oss state_restore` prints
`restore: state is already clean - nothing to do` at **rc 0**, leaves
`schema_version` untouched, and the next `oss doctor` fails identically. A
remedy that exits 0 while changing nothing is the worst kind of wrong answer,
because the operator has no signal that they are stuck.

**You never run these.** Name the verb; the user runs it. The one exception in
this whole skill is rule authoring, and the user asked for that explicitly.

---

## 4. Orphan worktrees

New in v0.3, and the only check that reads the repository rather than the state
file.

```bash
oss worktree_orphans canonical
```

**What it reports:** directories under `<canonical>/.worktrees/` that no work
item claims. A directory is *claimed* when a work item's journaled
`worktree_path` is exactly it, **or** when its basename is a work item's id.

**Why the second arm exists:** `oss worktree_add` names the directory for its
work item but writes nothing to state — `worktree_path` appears only once
`oss work_item_exec` journals it. Matching on the path alone would report every
freshly-spawned worktree as an orphan, i.e. it would be loudest exactly when the
project is behaving correctly.

**Why it matters at all:** spine close removes worktrees by *reading state*
(`close/references/spine-close.md` step 10). A directory state does not know
about is therefore cleaned by no ceremony at all. It accumulates in the canonical
repo whose cleanliness `close` then checks, and the first symptom is a close
failing for a reason that has nothing to do with the spine being closed.

**The rc trap.** This is a **pure selector**: the finding is its OUTPUT.
`rc 0` means the check *ran*, not that the tree is clean. Branch on the rc and
every project reports as orphan-free. This deliberately does **not** copy
`oss touch_check`'s rc-0-is-a-hit polarity — that convention exists for a gate,
and nothing on this surface is a gate.

**The remedy is a judgment call, which is why it is not automated.** An orphan
may be:

- a leftover from an abandoned work item — safe to remove, *after* checking it
  has no uncommitted work: `git -C "<orphan>" status --porcelain`;
- a worktree whose state record was lost — the directory is the *survivor*, and
  deleting it destroys the only copy;
- someone's hand-made scratch directory that happens to live there.

Never remove one on the user's behalf. Report the paths, and note that
`oss worktree_remove` refuses on a dirty worktree by design.

**The inverse drift — a state record whose directory is gone — is not part of
this check.** `oss worktree_resolve canonical <wi-id>` returns rc 1 for exactly
that case, per work item. Reach for it when a close has already failed on a
missing worktree; it is a targeted probe, not part of the sweep.

---

## 5. State-vs-repo drift that no verb can decide

`oss doctor` compares the state file against itself and, for worktrees, against
one directory. The following are drift that only reading can find, and they
belong in the read-out when the sweep gives you reason to look:

- **A spine marked `closed` whose branch never merged.** `close` guards this at
  close time; a state edited by hand does not get that guard.
- **A bones-registry entry with no row in the spec's bones index.** This is the
  spec-validation surface's job — see `references/spec-validation.md` §3 — but
  the *state* half of the comparison lives here.
- **A `complete` work item whose `report.md` is absent.** The harvest sweeps
  reports; a missing one silently narrows the next harvest.

Report these as findings with their evidence. Do not repair them.

---

## 6. The feature map

`oss feature_list` reads it. Inspection only.

**Settled, v0.3: the feature map does not get a persisted rank or a prune
verb.** `plan-release/references/feature-map-grooming.md` §2 left this open —
"if a persisted rank ever earns its keep, that is where the argument belongs" —
and `doctor` is the "there" it named. The argument was had and it does not
earn its keep:

- **The ranking is a grooming conversation's working order**, not an attribute
  of a feature. Its only durable output is *this release's spine selection*, and
  that already persists in `RELEASE.md`.
- **A prune means "not carried into this release"**, recorded as rationale in
  `RELEASE.md`. It does not delete the entry: the map is append-only history,
  and the reason a candidate was passed over is exactly what the next groom
  needs.
- **`doctor` existing changes nothing about that.** It makes the map
  *inspectable*, which was the only thing the deferral was waiting on. An
  inspectable append-only log does not become a ranked queue by being readable.

So the map keeps its two verbs, `oss feature_add` and `oss feature_list`. If the
question returns, it needs new evidence — a groom that demonstrably lost
information the two verbs could have kept — not a second re-litigation of the
same argument.
