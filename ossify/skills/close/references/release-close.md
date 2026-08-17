# Release close — the outer layer

Depth for SKILL.md §6 (spec §6.2, plus the two §6.1 contracts that only become
enforceable at a release boundary). Eight steps in **binding order**: the
walkthrough measures the set the amendments produced, the blocking findings are
read against a product the walkthrough has already exercised, the retro
aggregates artifacts the spine closes wrote, and the boundary audit is the last
refusal before anything is recorded.

This layer is reached as `/close <release-id>` — `r1`, three characters, no dots
(SKILL.md §2). Nothing routes here automatically: a spine close ends at its own
step 11 and never escalates.

---

## 1. What this release ships, and what it deliberately does not

Spec §6.2 lists seven steps; the companion boundary spec appends an eighth.
**This ceremony runs steps 1-4, the two blocking §6.1 findings, and the
companion's boundary audit. Three of the spec's steps are not here**, and each
is named rather than left to read as executed:

| Spec §6.2 step | Status here |
|---|---|
| 1. All spines closed | **built** — §2 |
| 2. Full cumulative walkthrough | **built** — §3 |
| 3. Release retrospective | **built** — §6 |
| 4. Feature-map re-groom + next-release sketch | **built** — §7 |
| **5. Docs increment (spec §8)** | **not shipped.** The trigger table lives in spec §8 and has no executable surface yet |
| **6. Handoff cleanup for the closed release** | **not shipped.** `/ossify:handoff` authors session handoffs as a standalone utility, but it has no retention policy by design — handoffs accumulate and the user prunes — so there is nothing for a close to clean up; the same non-wiring `spine-close.md` §9 records for the spine boundary |
| **7. Release tag / PR gate** | **not shipped.** The spine→release / release→main tier question is unsettled, and a PR gate written before it is settled would harden the wrong tier |
| **8. Boundary audit (companion §6)** | **built — core scope** — §8, full depth in `references/boundary-audit.md`. Re-derived under the skill-first freeze: prose driving `git`/`gh`/`gitleaks` plus agent judgment, **canonical repo only, observed-visibility gated**, fail-closed. Confirmed findings block the close. The dimensions the companion names that this scope omits — the other repo arms, the semantic pass, history, submodules, the override record — are named in that file's own not-shipped table and land as their own PRs |

A missing step and a step that silently does nothing are indistinguishable to
every later reader, which is why they are a table rather than an omission.

**The repo dimension is single-repo for every step.** The companion design
gives a release close a pin/publish step before the walkthrough for open-core
postures, and one PR per touched repo at the gate. Neither is built; both attach
to steps this file does not ship. Nothing below assumes one repo *forever* — the
walkthrough and both blocking gates read state, not a checkout — and the one
step that does read a checkout, the boundary audit, reads **the canonical
only** (`git -C`, never a worktree), with the other repos explicitly outside
its shipped scope.

---

## 2. Step 1 — every spine closed, or refuse and name the offender

`$rel` is the id `/close` was invoked with, carried from SKILL.md §2's routing.

```bash
open_spines="$(oss get "[.spines[] | select(.release==\"$rel\" and .status != \"closed\" and .status != \"abandoned\") | \"\(.id) (\(.status))\"] | join(\", \")")"
abandoned="$(oss get "[.spines[] | select(.release==\"$rel\" and .status == \"abandoned\") | .id] | join(\", \")")"

[ -z "$open_spines" ] \
  || { echo "close: $rel has spines that are not closed: $open_spines - halt"; exit 1; }
[ -z "$abandoned" ] \
  || echo "close: $rel contains abandoned spines: $abandoned - confirm each abandonment was deliberate before continuing"
```

**The abandoned line is `[ -z … ] || echo`, never `[ -n … ] && echo`.** An
`&&` list whose test is false returns **1**, and this is the block's last
command, so under `set -euo pipefail` the clean case — no abandoned spines —
would abort the ceremony at the gate it just passed. The `|| echo` form returns 0
on both arms.

**Test the output, never the rc.** `oss get` is `jq -r` without `-e`: a `select`
matching nothing exits **0** with an empty string, so `oss get … || halt` never
fires and a release with three open spines closes clean. This is the same trap
`spine-close.md` §2 documents for the work-item gate, one scope out.

**The status is printed alongside the id** because `planned` and `active` are
different problems: a `planned` spine was selected into the release and never
started, an `active` one is mid-flight with a worktree still on disk.

### `abandoned` does not satisfy the gate, and does not hard-halt either

The spine enum is `planned|active|closed|abandoned`, and **`abandoned` is not
`closed`**. Reading it as closed would let a release close over work someone
quietly gave up on. Halting on it forever is equally wrong: an abandoned spine by
definition never reaches a close ceremony, so a hard refusal makes the release
uncloseable.

So it is a **third arm**: surfaced by name, with an explicit confirmation from
the user that each abandonment was deliberate and recorded. **Do not
auto-confirm it** — this is the one arm of the one gate in this layer that is
not a mechanical fact, and the user is the authority (SKILL.md §8).

Nothing is dropped by that leniency: an abandoned spine's demo lines and fakes
are still live records, and steps 3 and 4 below pick them up on their own terms.

---

## 3. Step 2 — the full cumulative walkthrough

```bash
oss demo_user_lines            # NO argument - every active user: line, all spines
```

**The no-argument call is the whole difference from spine close.** With a spine
argument the verb filters to `source_spine == <spine>`; without one it returns
the entire active `user:` set (`cumulative-demo.md` §1). Passing a spine here
turns the release gate back into a spine gate and the release stops being the
first place anyone notices a regression in an older journey.

**Against the amended set, and the amendments are already applied.** `supersede`
and `retire` are planning verbs that leave the line live until a spine close runs
`oss ledger_apply_pending` (`spine-close.md` §4). Step 1 above has just proven
every spine closed, so every planned amendment in this release has been applied
by the spine that planned it. **This layer never applies amendments itself** — an
apply here would be applying a spine's intent after that spine closed, and
`oss demo_user_lines` already returns only `status == "active"` lines, so a
superseded line is gone from the walk without any action here.

The `auto:` half runs the same way it does at spine close — `oss demo_run`, every
accumulated line, halt on the first failure. Everything in `cumulative-demo.md`
§2-§5 applies unchanged: never edit a line to make it pass, a `user:` mismatch is
a failure and not a note, the wall-clock budget is surfaced and never silently
pruned.

### Grouping by feature is yours to derive, not a field to sort on

Spec §6.1 groups the release walkthrough by feature. **Demo-ledger lines carry no
feature field** — `oss ledger_add_user` writes
`{type,text,outcome,source_spine,status,status_reason,status_by,at}` and nothing
else (the payload `oss_ledger_add_user` builds in `lib/ledger.sh`). There is no
`.feature` to `group_by`, and a block of
prose implying one would send every reader looking for a lookup that does not
exist.

The grouping is **the agent's, derived**: read the feature map with
`oss feature_list`, read each line's `source_spine`, and map spine → feature
through the map's own entries. Say out loud which grouping you used before you
start the walk, so the human can correct it — a wrong grouping changes the order
of the walk, not its coverage, and every line is walked either way.

Once the walk exceeds the user's tolerance, spec §6.1 allows unchanged features
to rotate through spot-checks. **That is an explicit recorded choice, and the
default is the full walk.** This layer does not make it silently.

**Where "recorded" lands.** There is no verb and no state field for it, so the
record is the **release retrospective's walkthrough section** (§6): name which
feature groups were spot-checked rather than fully walked, and the tolerance that
drove it. Write it at the moment of the decision, not reconstructed at §6 — by
then the walk is over and "which ones did we skip" is a memory test.

Unrecorded, the rotation is indistinguishable from a full walk to every later
reader, and the next release close has no way to rotate *different* features —
which is the entire point of a rotation.

---

## 4. Step 3 — the fake-expiry blocking finding

The gate, its rc contract, both of its arms and the two ways to unblock it are
in **`references/fake-expiry.md`**. The branch this step runs — the shipped
copy (`fake-expiry.md` §2), executed from here:

```bash
ef=0; fakes_due="$(oss expired_fakes "$rel")" || ef=$?
case "$ef" in
  0) echo "fake expiry: clean" ;;
  1) printf '%s\n' "$fakes_due"
     echo "close: $rel has fakes at or past their expiry - replace or explicitly renew each - halt"; exit 1 ;;
  *) echo "close: expired_fakes could not run (rc $ef) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
```

**rc 0 is CLEAN here, and rc 0 is a HIT in `oss touch_check`** — three arms
always, with rc 2 halting rather than degrading to clean. The polarity trap, and
what copying the touch-check branch shape passes: `fake-expiry.md` §2.

---

## 5. Step 4 — the outstanding-quarantine blocking finding

Spec §6.1 makes a quarantine a parking ticket: a quarantined line **must be fixed
or retired by the next release close**. So every line quarantined in a release
**strictly earlier** than this one is a blocking finding.

```bash
eq=0; quarantines_due="$(oss expired_quarantines "$rel")" || eq=$?
case "$eq" in
  0) echo "quarantines: clean" ;;
  1) printf '%s\n' "$quarantines_due"
     echo "close: $rel has quarantines owed from an earlier release - fix or retire each - halt"; exit 1 ;;
  *) echo "close: expired_quarantines could not run (rc $eq) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
```

Same rc contract as the fake gate: **0 = clean, 1 = blocking, 2 =
could-not-check**, one TSV line per finding (`<line-id>`, the release it was
quarantined in, the reason).

**Strictly earlier — `<`, not `<=`.** A line quarantined *during this release*
is a fresh ticket that comes due at the **next** close. Folding it in would make
a close unable to quarantine anything without immediately blocking on it.

**Numerically, for the same reason the fake gate is numeric.** jq compares
strings lexicographically, and `"r2" <= "r10"` is **false**, so a string
comparison silently stops blocking at the tenth release — the release by which a
project has the most owed tickets.

**The two unblocks are fix or retire**, and both are real work:

```bash
oss ledger_retire "<line-id>" "<by-spine>" "<why it is no longer owed>"
```

`retire` is a *planning* verb: it records intent and the line stays live until a
spine close applies it (`spine-close.md` §4). At a release close there is no
spine left to apply it, so retiring here is a **decision recorded for the next
spine**, not an immediate removal — say so when you take that route rather than
reporting the ticket cleared. Fixing the line is the other route: the line goes
back to `active` by the fix landing in a spine, not by an edit here.

A line quarantined with **no release anchor** blocks too, marked
`no-release-anchor`. §6.1's ticket expires against a release, so a ticket
carrying none can never come due — and `oss ledger_quarantine`'s release argument
is optional, so an anchorless ticket is one omitted argument away.

---

## 6. Step 5 — the release retrospective

Aggregates the spine retros. **It refuses if any spine in the release lacks one,
naming the spine** — and the artifact it looks for is the file the spine
ceremony writes:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/retrospective.md
```

That is `retrospective.md`, exactly — the path block `retrospective.md` states
above its §1, and it is the only copy. Stating the
filename matters: a refusal gate that looks for the wrong artifact refuses every
release, forever, and the failure reads as "the spines are not closed" rather
than "this gate is looking in the wrong place".

Resolving it needs the slug, which **nothing persists** — recover it from the
directory name the way the work-item layer does (`work-item-close.md` §1), then:

```bash
ai_root="$(oss repo_root ai_workspace)"
spine_rel="$(oss spine_dir "$rel" "<spine-id>" "<spine-slug>")"   # RELATIVE
[ -f "$ai_root/$spine_rel/retrospective.md" ] \
  || { echo "close: $rel - spine <spine-id> has no retrospective.md - halt"; exit 1; }
```

**`oss spine_dir` returns a relative path**; prefix it with
`oss repo_root ai_workspace`. Feeding the relative path straight to `[ -f ... ]`
resolves it against `$PWD` and answers "absent" for every spine, which is a
refusal that looks exactly like a real finding.

The release retro itself lands beside them, in the release directory — the
**parent** of what `spine_dir` returns:

```bash
rel_dir="$(oss release_dir "$rel")"   # ABSOLUTE, ai_workspace-rooted
# e.g. docs/specs/r0/ — the retro is "$rel_dir/release-retrospective.md"
```

`oss release_dir` resolves the manifest root for you, so the
`docs/specs/r0/` in the comment above is relative to that resolved root —
a workspace **shape** is never something to paste into a command.

**What it aggregates**, drawing on the sections `retrospective.md` pins so this
is a roll-up and not a re-interview: what the release set out to do against what
shipped; the walkthrough outcome from §3, by feature group (**including which
groups were spot-checked rather than fully walked**); every spine's class and any
mid-flight reclassification; **what is still standing** — the fakes, deferrals and
quarantines each spine's own "still standing" section left owed, reconciled
against steps 3 and 4's findings above; the durable lessons; and the
carried-forward items. **Nothing arrives in the carried-forward roll-up that does
not appear above it**, the same rule the spine retro's §9 states.

**"What the release set out to do" has a source — read it, do not recall it:**

```bash
oss get ".releases[] | select(.id==\"$rel\") | {goal, exit_criteria}"
```

The goal is the one recorded at `release_add`; `exit_criteria` is what
`plan-release` phrased as user journeys and `release_set_meta` stored. `RELEASE.md`
in the release directory carries the same, in prose. Writing this section from
memory of the release is how a release quietly grades itself against what it
delivered rather than against what it promised — the one comparison the retro
exists to make.

**Two mechanics the port carried over from the sprint retro, and they are not
optional:**

- **The cross-release pattern round is confirmed with the user, not asserted.**
  When you name a pattern across spines ("every spine in this release
  underestimated the migration surface"), put it to the user before it lands in
  the document. A pattern is an interpretation of their project, and the retro is
  the record others will read; one wrong pattern stated confidently outlives the
  release.
- **Roll up the memory-bank harvest totals — and note they are not persisted.**
  Each spine close ran a harvest (`harvest.md`), which reports its four buckets
  — **applied / applied-with-edit / left-in-handoff / dropped** — **into the
  close summary only**: no state
  field holds them, and `harvest.md` §8 deliberately keeps them out of the spine
  retro. In the same session they are in scrollback; **in a later session they
  are gone**, and the honest entry is then "not recorded per spine — see each
  spine's close summary", not a reconstructed number. If you want the roll-up to
  survive, the place to put it is each spine's retro at the time of that close.
  A release that harvested nothing is a finding about the release, not a blank.

---

## 7. Step 6 — feature-map re-groom and the next-release sketch

The rolling-wave crank, and the reason this ceremony is a planning input rather
than only an accounting one.

```bash
oss feature_list                                    # the map, as JSON
oss feature_add "<name>" "<the value it unlocks>" "<bone|flesh>" release-retro
oss release_set_meta "$rel" '{"next_sketch":{"goal":"<one line>","candidates":["<spine>","<spine>"]}}'
```

Re-groom against what the release actually taught: the walkthrough's friction,
the fakes step 3 forced a decision on (a replacement that got renewed twice is a
feature competing for selection, not a footnote), and the quarantines step 4
surfaced. Write the **value**, never the task.

`next_sketch` is one of the five keys `release_set_meta` allows
(`exit_criteria`, `spine_dag`, `ledger_budget`, `next_sketch`,
`real_use_findings`). **Disallowed keys are dropped, not rejected** — the call
returns rc 0 having written nothing, so a typo'd key is silent. Read it back
before believing it landed.

The sketch is a **sketch**: a goal line and candidate spines. Selection, exit
criteria, the DAG and the class declaration all belong to `/plan-release`, which
reads this key as its starting point.

---

## 8. Step 7 — the boundary audit, the last refusal

**The canonical repo only, gated on observed visibility, fail-closed, and its
confirmed findings block the close.** The whole step — the visibility gate and
its two recorded deltas from the companion spec, the tracked-file audit
against `PUBLIC_BOUNDARY.md`'s machine-checkable rules, the scan-first
untracked sweep, and the high-stakes disposition where **nothing is ever
auto-dispositioned to pass** — is in **`references/boundary-audit.md`**. Read
it before running this step; its triage is a conversation with the user, not a
checklist. The dimensions the companion names that this scope omits are named
in that file's own not-shipped table and land as their own PRs.

What matters for the ceremony's shape: this step runs **after** the
feature-map re-groom, so a blocked close still walked, retro'd and re-groomed
— all of that survives the halt as artifacts and planning input — and
**before** §9, so a blocked release is never recorded closed. The only unblock
this release is the fix; the accepted-disclosure override is not shipped
(`boundary-audit.md` §5, §8).

**A halt here is not free, and steps 1-6 are not free to repeat.** A re-close
re-runs the full cumulative walkthrough — this ceremony's most expensive step —
and two of the steps it re-runs already wrote state. `oss feature_add` appends
**unconditionally**, so re-running §7 blind duplicates every feature it added:
read `oss feature_list` first and add only what is missing. And
`release-retrospective.md` is already on disk with a "what is still standing"
section written before the finding existed — **amend it** so the boundary
finding and its disposition join that section; never silently re-author it.
The audit still has to run last, because a fix has to be re-audited.

---

## 9. Step 8 — the state writes, and only after every step above reached the end

```bash
oss release_status "$rel" closed
oss demo_record release "$rel" "<true|false>" "<line-count>" "<notes>"
```

**`demo_record` takes five arguments after the scope word**, not two: scope, id,
`passed`, the line count, and the notes. `passed` is the literal `true` or
`false` and anything else is rc 2. The scope word here is **`release`**; the same
verb also records **`spine`** closes (`spine-close.md` §9, step 11).

**Its third scope, `work_item`, has no caller in this release.** The lib accepts
`work_item|spine|release`, but no ceremony writes one: the work-item layer's
record of a close is `report.md` plus the item's `status`, and nothing reads a
`work_item` close record. `close_records` is likewise **write-only in v0.2** —
the ceremonies append to it and nothing consumes it. Both are Plan C1 groundwork
for the v0.3 records work, and saying so here is the point: an unread record that
looks read is how a later reader concludes a check exists.

`release_status` accepts `planned|active|closed` — the release enum has **no
`abandoned`**, unlike the spine enum §2 reads.

**A halt anywhere above stops the close record.** Neither of these lines runs
after a refusal, a failed demo line, either blocking finding, or a confirmed
boundary-audit finding — so nothing is ever recorded as closed. It does **not**
mean nothing was written: §7's `feature_add` and `release_set_meta` already
ran, which is what §8's re-close note is about.

---

## 10. What has no executable surface

Stated plainly so nobody infers coverage that does not exist.

**The step order, the walkthrough itself, the abandoned-spine confirmation and
the retro's aggregation are prose contracts.** A bash script that calls the
gates in order asserts nothing about the ceremony; it tests a fixture written to
pass. The harness checks that every `oss` verb this file names resolves.

The mechanical seams **are** covered in `tests/test-close.sh`: both blocking
gates' full rc contracts driven through the dispatcher under real strict mode,
the seven expiry/quarantine fixtures that discriminate a correct selector from a
broken one, and the two shipped branch blocks above extracted from this file and
executed.

---

## 11. Anti-patterns

- **Reading `abandoned` as `closed`** — or hard-halting on it and making the
  release uncloseable (§2).
- **Testing the rc of `oss get` instead of its output.** An empty `select` exits
  0 (§2).
- **Passing a spine id to `oss demo_user_lines` here.** The release walk takes no
  argument (§3).
- **Applying demo amendments at release close.** The spines already did (§3).
- **Implying a `.feature` field on demo lines.** There is none; the grouping is
  derived (§3).
- **Rotating features through spot-checks silently.** Explicit and recorded, or
  walk them all (§3).
- **Copying `touch_check`'s branch shape onto either blocking gate.** rc 0 is a
  hit there and CLEAN here (§4, §5).
- **Folding either gate's rc 2 into clean** (§4, §5).
- **Comparing release ids as strings.** `"r2" <= "r10"` is false (§5, and
  `fake-expiry.md` §3).
- **Blocking on a quarantine raised during this release.** Strictly earlier (§5).
- **Reporting a retired line as cleared.** `retire` records intent; a spine
  applies it (§5).
- **Feeding `oss spine_dir`'s relative path to a file test unprefixed** — every
  spine then looks retro-less (§6).
- **Trusting `release_set_meta` silently.** A disallowed key is dropped at rc 0
  (§7).
- **Writing `release_status closed` after any halt** (§9) — a boundary-audit
  halt included (§8).
- **Auto-dispositioning a boundary-audit finding, or closing "with a leak
  noted."** Every finding reaches the user; a confirmed one blocks until fixed
  — the override is not shipped (§8, `boundary-audit.md` §5).
