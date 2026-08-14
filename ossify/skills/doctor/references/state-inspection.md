# State inspection

The depth behind `doctor/SKILL.md` §4. **`oss doctor` is now four checks, not
eight** — the ones a close blocks a mutation on. The other four are yours to
read, and this file is how.

---

## 1. What the verb does, and what you do

`oss doctor` emits exactly four lines: `state`, `schema`, `replay`, `shape`.

Those four stayed deterministic on purpose. `close/SKILL.md` §3 refuses to run
until `schema` and `replay` are green, and **replay is not something to eyeball**
— it rebuilds the state from its base snapshot by applying every journaled
mutation in order and compares the result. That is exact-identity work, it is the
only thing that can prove the live file still agrees with its own history, and no
other verb exposes it. A rail in front of a mutation is not a read-out, whatever
it is spelled with.

**Everything else this surface reports, you read yourself** — a lock directory, a
few counts, and a per-repo orphan comparison. Those were ~210 lines of bash that
opened files and described them. They gated nothing: every one emitted `warn:` or
`skip:`, and neither ever set rc.

### The line grammar — use it for your lines too

| Tag | Meaning | Touches rc? |
|---|---|---|
| `ok:` | ran, found nothing | no |
| `warn:` | ran, found something advisory | **no** |
| `fail:` | ran, found something broken | **yes — the verb exits 1** |
| `skip:` | could not run, and says so | **no** |

Two properties are load-bearing:

- **A check that cannot run still emits a line.** The verb prints
  `skip: replay - skipped (schema check failed)` rather than dropping it, because
  a *missing* line is indistinguishable from a clean one. **Hold your own lines to
  the same rule** — if you cannot reach a repo, say `skip:` and why. This is not
  hypothetical: the worktree check shipped in v0.3 asking only about `canonical`,
  so a project with a configured `private_core` got a clean read-out about a repo
  nobody had opened (#156).
- **`warn:` never changes the rc.** `oss doctor` exiting 0 means "nothing broken",
  not "nothing to report" — and it now says nothing at all about the four
  advisory areas. A close pre-flight that checks only the rc is still correct;
  it is deliberately not the whole picture.

---

## 2. The checks

**The verb's four**, in print order:

| Check | Reads | What it catches |
|---|---|---|
| `state` | the file | it is not there at all |
| `schema` | state file | a `schema_version` this build cannot handle |
| `replay` | journal | live state that disagrees with base + mutations |
| `shape` | state file | any of the 16 required top-level keys missing |

`replay` is gated on `schema`, because replaying against a version this build
cannot read produces noise rather than a finding. That gating is why its `skip:`
line exists.

**Yours to read.** Each is a count or a directory check; report one line each in
the same grammar. Run them after the verb, so a broken state fails first:

```bash
oss get '[.demo_ledger[] | select(((.pending_amendments // []) | length) > 0)] | length'
oss get '[.demo_ledger[] | select(.status == "quarantined")] | length'
oss get '[.fakes[] | select(.status == "active" or .status == "renewed")] | length'
oss get '.patch_records | length'
```

| Yours | Reads | Report when |
|---|---|---|
| `lock` | `<state>.lock` dir | it exists — `warn:`, and say whether it is stale. A ceremony may be mid-mutation |
| `ledger` | `demo_ledger` | pending amendments, or quarantined lines — each must be fixed or retired by the next release close |
| `fakes` | `fakes` | any `active` **or** `renewed` fake is still outstanding. `renewed` counts: it is a deferral, not a resolution |
| `worktrees` | **the repos** | see §4 — one line per repo key |

**Check the TYPE before you trust the count — this one bites.** `jq`'s `length`
is defined on strings and objects too, so a corrupt field returns a plausible
number at rc 0 rather than an error:

```bash
oss get '.patch_records | type'     # must be "array"
```

Measured: with `.patch_records` set to the string `"oops"`,
`oss get '.patch_records | length'` returns **4** — the character count — and
exits 0. Take that at face value and you report `warn: patches - 4 out-of-spine
patch record(s)` about a field that holds no records at all. The deleted bash
guarded this with a `def _arr(f): … else error` wrapper on every count; you do it
by asking for the type first.

**A field that will not read as a list is `skip:`, not `ok:`** — and not `warn:`
either. Say the field could not be read as a list. Reporting a count there is the
same lie as omitting the line.

**Where is `<state>.lock`?** Beside the state file: `"$(oss state_path).lock"`.
It is a directory, and its mtime is how you tell stale from held — more than
about half an hour old and no ceremony running means it was left behind. Do not
remove it on a hunch; say what you found and let the operator decide.

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
oss worktree_orphans canonical          # ALWAYS pass the key explicitly
oss worktree_orphans private_core       # doctor runs one of these per repo key
```

**Pass the key every time — the verb does not make you.** Omitting it silently
resolves to `canonical` (`oss_cmd_worktree_orphans` and `oss_worktree_orphans`
both default it), so a bare `oss worktree_orphans` answers a question about the
public repo no matter which one you meant. That defaulting is how #156 happened
in the first place. Making the argument mandatory is a breaking change to a
shipped verb and is tracked separately; until then the discipline is yours, not
the tool's.

**What it reports:** directories under `<repo>/.worktrees/` that no work item
claims. A directory is *claimed* when a work item's journaled `worktree_path` is
exactly it, **or** when its basename is a work item's id — and only when that
work item's `target_repo` is the repo being asked about, so a `private_core`
item cannot claim a same-named directory sitting under the public root.

**You run the selector once per repo key** — `canonical`, `ai_workspace`,
`private_core` — and print `ok:`/`warn:`/`skip: worktrees(<key>)` for each.
`oss doctor` used to do this and no longer does; the verb it called is unchanged
and the keys are `_oss_repo_root`'s enum, so read that enum rather than trusting
this list to stay current. **Every key costs a line**, including the ones this
project does not configure. A key the manifest does not configure gets the `skip:`, as does one
whose root does not exist on this machine **or cannot be traversed** — an
unmounted volume and a checkout whose root denies `x` both land there. So does a
state whose work-item claims could not be inspected, which is a
*state-side* cause wearing the same line: the skip names both families, because
one that listed only the repo-side ones would send you to debug a healthy
manifest while the corrupt state went unnamed. None is ever silently dropped,
because "could not open it" and "opened it and found nothing" are the two states
this check exists to keep apart.

**Traversal, not read, is what the root needs** — the check reaches
`<root>/.worktrees` by composing the path and never lists the root itself. So a
traversal-only root (mode `0111`) is inspected and its orphans reported, not
skipped. `.worktrees` needs **both**, because that directory *is* enumerated.
Requiring read on the root was #162: a guard stricter than the operation, which
turned a usable repo into a skip and cost real detections.

**Two gates come before the per-key loop, and they emit one *unkeyed* line for
the whole surface**: state health being red, and the inspected state not being
this directory's manifest-routed state. Both are properties of the run, not of
any one repository, so a keyed line per repo would repeat the identical reason
three times. Read `skip: worktrees - skipped (…)` with no key as *the surface
did not run at all* — which is why it names its cause. So the contract is: keyed
lines when the comparison runs, one unkeyed line when it could not.

*Why that is worth a paragraph:* the v0.3 shipping build called the selector
with `canonical` hardcoded. The selector itself was already parameterized, so
nothing looked wrong — the read-out simply asserted `ok: worktrees - none
orphaned` for projects whose `private_core` root it had never opened. Private
work accumulating under an unchecked root is the exact failure the public/private
boundary exists to prevent, so a *false clean* here is worse than no check at
all. Fixed as #156; the per-key lines are what make the difference visible.

**Why the second arm exists:** `oss worktree_add` names the directory for its
work item but writes nothing to state — `worktree_path` appears only once
`oss work_item_exec` journals it. Matching on the path alone would report every
freshly-spawned worktree as an orphan, i.e. it would be loudest exactly when the
project is behaving correctly.

**Why it matters at all:** spine close removes worktrees by *reading state*
(`close/references/spine-close.md` step 10). A directory state does not know
about is therefore cleaned by no ceremony at all. It accumulates in the very
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

This surface compares the state file against itself and, for worktrees, against
one `.worktrees/` directory per configured repo. The following are drift that
only reading can find, and they
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
