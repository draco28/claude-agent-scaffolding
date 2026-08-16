# Boundary audit — the last finding-producing step of a release close

Depth for SKILL.md §6 step 7. Implements the companion spec (public/private
boundary, 2026-07-12) §6, **re-derived 2026-08-15 under the skill-first freeze**
(the companion's construction note governs): the spec's "mechanical-first"
wording predates the freeze, so this step ships as **prose driving external
tools plus agent judgment** — `git`, `gh` and `gitleaks` do the enumerating,
the agent does the matching and the judging, and no new deterministic runtime
code exists anywhere in it. Three deliberate deltas from the companion's §6
text are recorded inline (§2 twice, §6 once), each with the reason it is safe.

This file is blockless by intent. Every command it names is an existing
external tool invoked as written; there is nothing here for the executable-prose
harness to extract.

---

## 1. When it runs, and what a halt means

At **every release close**, after the feature-map re-groom and next-release
sketch, **before the state writes** — the audit is the last thing that can
refuse the close. A confirmed finding halts the ceremony, and the halt reaches
the close record: `oss release_status <rel> closed` and the `demo_record` line
never run. A release therefore cannot be closed "with a leak noted" — it is
closed after the finding is fixed, after the user records an
accepted-disclosure override (§6), or not at all.

**A halt here is not free, and saying so is part of the step.** Steps 1-6 ran
already, and two of them wrote state: `oss feature_add` appends
**unconditionally** — no dedupe, no id — and `oss release_set_meta` has stored a
`next_sketch` for a release that is now not closing. So on a re-close after a
boundary-audit halt: read `oss feature_list` first and add only what is
missing, and **amend** the existing `release-retrospective.md` rather than
re-authoring it — the boundary finding and its disposition join its "what is
still standing" section. The full cumulative walkthrough re-runs too, which is
the ceremony's most expensive step; that cost is real and is the price of the
audit being able to run last, which it must, because a fix has to be
re-audited.

---

## 2. The repo set, and the visibility gate

Build the repo set from **every repository object the pairing manifest
carries**, not from a fixed list of roles — the canonical
(`oss repo_root canonical`), the AI workspace (`oss repo_root ai_workspace`),
any `private_core`, and the optional `tooling_repo` workspace-init emits when a
project volunteers one. Enumerate the manifest's repo objects and audit each;
hard-coding three roles is how a public tooling repo ends up holding tracked
secrets while the release reports clean. A role this file states no policy for
is audited on the `any` row of the table below. **A repo's manifest role is structural** — workspace-init writes it, and
it is not the pending per-repo `visibility` field this section's first delta is
about.

**Read each repo's `git_tracked` first, because not every manifest repo is a
git repo.** workspace-init's Scenario C pairs an AI workspace that is
deliberately untracked (`ai_workspace.git_tracked: false`), and every git
command below would fail against it — turning a supported topology into a
permanently undeterminable audit with no repository fix available. A repo with
`git_tracked: false` gets the **filesystem-only** policy: it has no index, no
remotes and no history, so §2's visibility gate and §3's tracked-file rules do
not apply to it. Run **§3's secrets scan** over its working tree as hygiene
notes — the same thing every `ai_workspace` arm of the table below runs — with
§4 and §5 skipped for the role as they are on every other arm. Say in the
report that it was scanned as an untracked directory, and never raise its lack
of a remote as a finding.

**On that repo the scan needs `--no-git`, and a clean result needs checking.**
`gitleaks detect` defaults to walking git history, and against a directory that
is not a repo it exits **0** with `no leaks found` after `0 commits scanned` and
`~0 bytes` — a pass that read nothing, on the repo that holds the moat by
construction. Use
`gitleaks detect --source "<root>" --no-banner --no-git`, and treat a run
reporting zero bytes scanned against a root that has files as INCONCLUSIVE
(§3): rc 0 and "no leaks found" are not evidence that a scan happened.

**Scanning does not depend on a remote.** §3 and §4 read the index and the
working tree; they need no network and no `gh`, and they run on every repo in
the set. A repo with no remote today may still have been pushed yesterday —
absence of a remote narrows the *exposure* claim, never the scan. (An earlier
draft scoped the whole step to repos with a remote "because nothing can have
left the machine". That is false for a repo whose remote was removed after a
push, and it is one `git remote remove` from defeating the audit.)

What the remote decides is **exposure**: whether a hit is already disclosed, or
is hygiene.

### Determining observed visibility

Enumerate **every** remote (`git -C "<root>" remote -v`), not just `origin` — a
remote may be named `upstream` or `github`, `origin` may be a private fork of a
public upstream, and a repo may push to both. For each remote, derive
**`host/owner/name`** and read
`gh repo view "<host>/<owner>/<name>" --json visibility`. **Gate on the most
public answer**: one public remote makes the repo observed-public, whatever the
others say.

**Carry the host, do not drop it.** `gh`'s repository selector is
`[HOST/]OWNER/REPO`, and with the host omitted it resolves against `GH_HOST` or
its own default — so a GitHub Enterprise remote queried as bare `owner/name`
can answer about a *different* host's repo of the same name. Where that other
repo is private, an observed-public Enterprise repo is misclassified as private
and skips the whole audit. Every path in this file that quotes a root or a
selector quotes it: manifest-resolved paths may contain whitespace, and
`close/SKILL.md` §8 already requires `git -C "<absolute path>"`.

**Only an exact, case-insensitive `private` takes the private arm.** Anything
else — `public`, `internal` (GitHub Enterprise's org-wide visibility, which is
on the wrong side of this gate), an unrecognised value, an empty result, a
non-GitHub host, `gh` unauthenticated, the API unreachable — is audited **as
public**, and the inability to determine visibility is itself recorded as a
finding. Fail-closed: a repo you cannot prove private is treated as public.

### What each outcome runs

| Role | Observed | What runs |
|---|---|---|
| any | public (or undeterminable) | §3, §4, §5 in full; findings are **blocking** |
| `canonical` | private | §3 only, as **non-blocking hygiene notes** — a missing `PUBLIC_BOUNDARY.md` is a hygiene finding here, not a blocking one. §4 and §5 skipped |
| `ai_workspace`, `private_core` | private | §3's secrets scan only, as hygiene notes. §4 and §5 skipped |
| `ai_workspace`, `private_core` | **public** | **blocking finding on its own** — these roles are private by construction. **§3, §4 and §5 all run in full**: the repo is already exposed, and the visibility finding is overridable, so a skipped sweep means an accepted public workspace is never examined again |
| `ai_workspace`, `private_core` | undeterminable | the undeterminable read is a finding, **and the role-appropriate §3 secrets scan still runs** as hygiene notes; §4 and §5 skipped |

**Role-specific rows win over the `any` row.** An undeterminable read is
audited as public (above), so an `ai_workspace` with unreadable visibility
matches three rows at once; the role rows are the answer, and the `any` row
governs `canonical` and anything the manifest adds later.

Every skip is named in the report with the observed value that justified it.

**No arm of this table skips the secrets scan.** Scanning does not depend on a
remote (above), so it cannot depend on being able to *read* a remote either.
The visibility finding and the secrets scan are independent; a repo whose
visibility is unknown gets both.

**Read the inventory's Accepted-disclosures rows before applying any skip in
this table.** They are §5's input, but §5 does not run on every arm, and an
override recorded against a private canonical or a `private_core` would
otherwise vanish the moment its repo took a skip — silently, and from the very
next close. Read the rows once, up front; recap every row relevant to each repo
in the report **whether or not that repo's semantic sweep runs**.

**Why private repos are scanned at all** (and the second delta from the
companion, which scoped the whole audit to public repos): `posture-block.md` §6
requires **even a fully-private project** to author `PUBLIC_BOUNDARY.md`,
because hygiene is independent of visibility and it is what keeps a later flip
to *one* ceremony. A rule block that never executes for the project's entire
private life gets its first run at the flip, when a hit means a history rewrite
instead of a `git rm`. Hygiene notes cost nothing and are the whole point of
authoring the file early.

**Why `ai_workspace` and `private_core` stop at the secrets scan:** they hold
the moat by design. Running §3's `never-tracked:` document rules there would
block on a missing `PUBLIC_BOUNDARY.md` that `start` deliberately never routes
to them (that file goes to *public* repo roots), and running §5 would sweep for
prose describing moat items in the repo that *holds the moat inventory*. Every
finding would be expected, which is indistinguishable from a real one.

### Intent versus observation

A repo the manifest calls private that `gh` reports public is a **blocking
finding** — something is wrong at the level of intent, and no scan result makes
it safe.

**Delta from companion §6, recorded:** the companion also blocks on an *unset*
manifest visibility field. That rule was written for a draft in which the
manifest field *decided which repos got audited* — unset meant skipped, which
is the fail-open the spec names. Here the decision input is **observed**
visibility, so an unset field can no longer cause a skip, and it is recorded as
a **note** ("visibility intent not yet recorded — workspace-init's visibility
fields are pending"), not a block.

**But an unset field must not silently disable the intent axis**, which is the
hole that delta would otherwise open: workspace-init does not write those
fields yet (`posture-block.md` §9 — recorded as intent, written later), so
today the field is unset in every real project and the mismatch rule above
would never fire. **So the posture is the second intent source, and it is
always present:** read `oss get ".project.posture"`. A **`fully-private` or
unset posture over an observed-public repo is the same mismatch** and blocks
identically. Without this, a default-private project whose canonical was
flipped public — the commonest shape there is — passes every scan and closes
`clean` with its entire codebase public.

---

## 3. Step 1 — the tracked-file audit

**`PUBLIC_BOUNDARY.md` must exist at the audited repo's root.** An
observed-public repo without one is a **blocking finding** with the remediation
named — author it via `start`'s posture block (`posture-block.md` §6) — never a
silent skip. The v1 draft's defect was exactly a missing artifact reading as a
clean pass. (On a private repo running hygiene notes, its absence is not a
finding — that file is routed to public repo roots.)

**Execute the machine-checkable rules block by reading it.** For each
`never-tracked:` pattern in the block, list tracked files
(`git -C "<root>" ls-files`) and match them against the pattern. **Where a
pattern and a path are arguably a match, they match** — an over-match is a
finding the user rejects in one sentence; an under-match is a leak. (Glob
dialects disagree about whether a leading `**/` matches zero segments and
whether a trailing `/**` matches the directory itself; that disagreement is not
worth resolving in prose, and resolving it the safe way costs nothing.)

Any tracked match is a finding: the file, the rule it violates, and — because
the file is already tracked — the note that removal alone does not untrack
history; a leaked *secret* must be rotated, and a leaked *document* assessed as
already disclosed.

`fixtures-must-be: synthetic` is not pattern-matchable. **It is asked wherever
this step reads a `PUBLIC_BOUNDARY.md` at all, whatever the posture** —
non-synthetic fixture data is a privacy leak independent of any moat, by the
same reasoning that makes even a fully-private project author the file, and it
is the one part of §5 that the trivially-clean arm does not cover. So it is
asked on a private canonical running hygiene notes, and **not** on the
`ai_workspace` / `private_core` arm, which is the secrets scan alone: no
`PUBLIC_BOUNDARY.md` is routed to those roles, so the rule has no home there.
That is a named skip in the report, not a silent one.

**Secrets scan — external tool, honest degradation.** Run
`gitleaks detect --source "<root>" --no-banner` and fold its findings in (note
whether the repo carries its own gitleaks config). **Only a completed scan
counts as a scan.** Any other outcome — binary absent, invocation rejected or
deprecated away, run aborted, output unreadable — is INCONCLUSIVE and recorded
as a degradation naming what failed. Inconclusive is not clean: a scan that
errors produces no findings, which is byte-identical to a scan that found
nothing. The user may accept a degradation at triage like any other finding;
what is forbidden is the audit *silently* narrowing to pattern rules because a
tool did not run.

**Push protection — best-effort.** Read
`gh api --hostname "<host>" "repos/<owner>/<name>" --jq .security_and_analysis` and report what the
host enforces. Unknown or unreadable is a note, not a finding — this is the
host's rail, not ours, and the audit does not depend on it.

---

## 4. Step 2 — the leak-adjacent scan (untracked files, scan-first)

Enumerate **all** untracked files in the working tree —
`git -C "<root>" ls-files --others`, deliberately **without**
`--exclude-standard`, because gitignored files (`.env`, a private `SPEC.md`)
are exactly the class in play. One `git add -f`, one editor "save all", one
misfired `git commit -a` is the distance between an untracked sensitive file
and a tracked one.

**The enumeration is matched, not read.** Without `--exclude-standard` this
descends into ignored directories, so on a real project it is `node_modules/`
and `target/` by the hundred thousand. Pipe it through the pattern set and
report the hit paths plus a total count; the volume never belongs in the
transcript. **If the enumeration was truncated, filtered or interrupted for any
reason, that is a recorded degradation of the same class as a failed gitleaks
run** — INCONCLUSIVE, not clean. A truncated enumeration and a clean tree
produce the same report otherwise.

**Scan first, classify second.** Match every enumerated path against the
sensitive-pattern set: the repo's own `never-tracked:` patterns plus the
standard secrets classes (`.env*`, `*.pem`, `*.key`, `id_rsa*`, credential
files). Then classify each hit:

- Matches an entry in the `PUBLIC_BOUNDARY.md` **working-tree hygiene
  allowlist** (by pattern) → a **standing warning**: named in every audit
  report, never escalating, never disappearing. It is the recurring reminder
  that a sensitive file lives one `git add -f` from public.
- **Not** in the allowlist → a **new finding** for triage.

The order is the point. Iterating the allowlist and checking whether its
entries exist would never catch a file the allowlist has not heard of — the
new `SPEC.md`-class file is precisely what this step exists to catch, and it
is only ever caught by scanning the tree first.

### Patterns are the floor, not the test

**A pattern set only catches files someone already thought to name.** A
strategy memo called `NOTES-STRATEGY.md`, a credential dump called `scratch.txt`
— neither matches a `never-tracked:` rule or a standard secrets class, and both
are exactly what an untracked sweep of a public working tree exists to find. §5
will not catch them either: it sweeps **tracked** prose.

So after the pattern pass, **read the remaining untracked set for what the
files are**, the same judgment §5 applies to tracked prose and the same
direction: a name or a peek that reads like downstream strategy, planning,
credentials, or private-inventory material is a **finding**, and where it is
arguable it is a finding.

**Bounded, or it collides with the paragraph above.** Collapse each ignored
*directory* to its own path and read the directory name, not its contents — a
dependency or build tree is one entry, which is what keeps this compatible with
"matched, not read". Read individual file names in full, and open first lines
only where a name says nothing. Only a narrowing beyond that is a recorded
degradation. (`--exclude-standard` is not the bound: fixture 03's
`NOTES-STRATEGY.md` is gitignored, and excluding ignored files drops exactly
the class this step exists to catch.)

The `PUBLIC_BOUNDARY.md` "Never here" prose rules are the vocabulary for this
judgment: they already say no downstream strategy, no roadmap, no competitive
material, no non-synthetic fixtures. The pattern block is how those rules are
enforced mechanically; this read is how they are enforced at all.

---

## 5. Step 3 — the semantic pass (agent judgment)

The question no pattern can ask: **does anything tracked in the public repo
*describe* a moat item, even without containing it?**

**Read the inventory first, including its accepted disclosures.** The input is
the **private boundary inventory** (`posture-block.md` §7 — the AI workspace
artifact naming moat items, channels and seams, with a pointer to it in the
memory bank's `08-governance.md`). Read its **Accepted disclosures** rows
before sweeping: a finding matching a row is a **standing warning**, not a
fresh block, and every row is recapped in the report whether or not it matched.
That read is what makes §6's override durable; without it the re-surfacing is
asserted rather than performed.

Then read the posture (`oss get ".project.posture"`):

- Posture implies protected value (`open-core`, `source-available`, a
  `fully-private` project with declared overlay seams) **or is unset/unrecognised**
  → the pass runs. An unset posture is read as moat-bearing (`posture-block.md`
  P1's fail-safe reads an undecided posture as private); a project that never
  completed its posture block is the population most likely to leak, and
  treating "not in the protected list" as "nothing to protect" fails open on
  exactly them. If the inventory **cannot be located**, the pass is
  INCONCLUSIVE — a finding with the remediation pointer, not a clean pass.
- `fully-open` with an explicitly empty inventory → the **moat question** is
  trivially clean; say so and move on rather than inventing findings. (The
  `fixtures-must-be: synthetic` question is asked regardless — §3.)

### The three rules, first match wins

Sweep the tracked doc set — READMEs, docs, design comments, specs, and fixture
directories — against the inventory's moat rows. **If the sweep had to be
narrowed to fit, that narrowing is a recorded degradation**, the same class as
a failed gitleaks run.

- **S1 — the prose names a moat item's identity *and* enough mechanism that a
  reader could reconstruct or evaluate it → finding.** A README explaining the
  rationale and structure of an algorithm whose implementation is
  private-packaged; a roadmap section naming unreleased strategy; a comment
  reconstructing a private spec in miniature; a tracked fixture that looks like
  real user data, prices, or prompts.
- **S2 — it names the identity only, no mechanism → note.** "Ranking is
  handled by a proprietary component" discloses that the component exists,
  which the port already does.
- **S3 — neither → clean.**

**Where S1 and S2 are arguable, it is S1.** An over-raised finding costs the
user one sentence at triage; an unraised disclosure is permanent. This is the
same fail-closed direction `posture-block.md` §2 states for an ambiguous
posture, and it applies at the one step of this audit that is pure judgment.

Describing is disclosing. The test is whether a competent reader of the public
repo alone ends up knowing a thing the inventory says stays private — not
whether any private file is literally present, and not whether the author
intended it.

**Worked example (S1).** Posture `open-core`; the inventory's one row reads
"ranking/decay intelligence — channel `private-package` — the public repo holds
the ranking port, the private crate implements it". The public README gains a
"How ranking works" section containing no code, which walks the decay curve's
shape, names the three signals the ranker weighs and in which order, and
explains why recency is dampened after day 30. **S1**: identity plus mechanism,
reconstructable. "It contains no code" is not the test and does not clear it.

---

## 6. Disposition — high-stakes, never auto

**No finding from this audit is ever auto-dispositioned to pass.** State the
contrast, because the nearest precedent points the other way: spine-close
disposition triage auto-applies spec-aligned recommendations and only
escalates load-bearing conflicts (`close/SKILL.md` §4). This step is the
deliberate opposite — every finding reaches the user, because "this
information is fine to publish" is a call only the owner can make, and it is
irreversible in exactly the way the default-private fail-safe exists for:
public → private is impossible once history is out.

**A rejection disputes the fact, not the risk.** The user may reject a finding
by contradicting what it asserts — the path is not tracked, the pattern does
not match, the prose does not name that item — and the report records the fact
that refutes it. **If the user concedes the fact and accepts the exposure, that
is an accepted-disclosure override, not a rejection**, and it takes the
override's record. Without that line the gate reduces to the user saying "no":
one word, no trace, and a report byte-identical to a close where nothing was
found.

A finding the user affirms is **confirmed**, and confirmed findings **block the
close**. Two unblocks, both real work:

- **Fix before close** — untrack and rotate, rewrite the disclosing doc,
  resynthesize the fixture. Re-run the affected step afterward; a fix is
  verified by the audit that re-examines it, not by the intention. **And a fix
  that changes the repository invalidates the gates that ran before it**:
  steps 2-4 walked a tree this fix has now altered, so re-run every gate whose
  inputs the fix touched — at minimum the cumulative walkthrough when the fix
  went anywhere the product reads (a resynthesized fixture, a deleted config, a
  rewritten doc a demo line opens). Recording the release closed on a
  walkthrough of the pre-fix tree certifies a product state that no longer
  exists. A fix confined to the AI workspace, or to an untracked file nothing
  loads, touches no gate's inputs and needs only this step re-run.
- **Accepted-disclosure override** — the user records, in so many words, that
  this specific disclosure is accepted, with the reason. The close proceeds
  with the override named in the report.

**Where the override is recorded — delta from companion §6, recorded:** the
companion routes overrides to `project-state.json`. No state verb carries such
a record and the freeze forbids adding one, so the record lands in the
**private boundary inventory** as an **Accepted disclosures** row — release id,
the finding *and the surface it covers*, reason, date — creating that section
if the inventory has none. §5 reads those rows every close, which is what makes
the re-surfacing real rather than asserted.

Two bounds on an override, because it is the one thing here that survives a
close:

- **It covers the exact surface recorded, and the row carries whatever makes
  "exact" checkable.** For a tracked file: the path plus a verifiable pin —
  the content hash (`git -C "<root>" hash-object -- "<path>"`) and the commit the
  audit read it at. For a surface that has no file — an untracked path, or an
  accepted degradation — whatever makes it re-identifiable instead: the path
  and its pattern, or the tool and the failure mode. Otherwise an override
  launders later growth of the thing it covered. Any change to the surface is
  a fresh finding, and where it is arguable whether a hit is the covered one,
  it is fresh.
- **It is not an erasure.** From the next close onward the item re-surfaces as
  a standing warning, never silently and never as a fresh block.

**Be honest about what this record is and is not.** `project-state.json` is
verb-written, atomically mutated, journalled and doctor-checked; a row in a
private markdown file is none of those, and deleting it is undetectable by
construction. What the inventory buys instead is *discoverability* — §5 re-reads
it every close — and the close summary carries the second copy. That trade is
the reason for the delta, not a claim to have matched the state field.

**Allowlisting is not a cheaper override.** Adding a pattern to the hygiene
allowlist in response to a finding reclassifies it to a standing warning and
reaches the same place as an override, one ceremony later, with no record. So:
**an allowlist entry added in response to a finding is recorded as an accepted
disclosure like any other.** The friction is the point, not the ceremony
boundary.

Standing warnings — hygiene-allowlisted files, prior accepted disclosures, and
**previously accepted** degradations — are recapped at the end of every audit
report. They are the audit's memory, and pruning them is a posture-block edit
made deliberately at `start`-time ceremonies, not something an audit does to
quiet its own output.

**A degradation from *this* run is a finding, not a standing warning.** The
distinction is the whole of it: a gitleaks run that failed today is an
incomplete scan of the release being closed, and §3 sends it to triage. Only
once the user has accepted it does it become memory. Filing this run's failure
straight into the recap would let a current, unaccepted, incomplete secrets
scan sit under a heading described as non-escalating, and the release would
close clean without anyone overriding anything.

---

## 7. The report

One block per repo in the set — role, **the audited ref**, gate outcome (observed visibility per
remote, manifest and posture agreement, what ran and what was skipped),
tracked-file hits, untracked hits split new-vs-standing, semantic findings,
degradations — each finding carrying repo, class, the path or pattern, why it
is a finding, and its remediation. Then the triage conversation, finding by
finding. Then the verdict, one of exactly three: **clean**, **blocked**
(naming each confirmed finding), or **proceeding with overrides** (naming each
override and its reason).

**The report's home is the close summary** (`close/SKILL.md` §10) — it is the
ceremony's final message, not a file. The durable records are the inventory's
Accepted-disclosures rows.

If any part of a finding must be written where the public can read it (a
release note, a public issue), it is described by **pattern and class only**
— the `PUBLIC_BOUNDARY.md` discipline applies to the audit's own output:
naming a moat item in a public artifact is itself the leak.

---

## 8. What this step does not look at

Stated plainly, because the sibling ceremony's rule is that a step which
silently does nothing is indistinguishable from a missing one
(`release-close.md` §1).

- **History, and every branch but the one being audited.** `git ls-files` is an
  index. A private document committed a year ago and later deleted is public
  forever at its blob URL, and nothing here looks. `gitleaks` covers *secrets*
  across history when it runs; the `never-tracked:` rules that catch
  **documents** have no history pass at all.
- **Submodule contents, unless you audit them.** `ls-files` returns one
  gitlink, `--others` does not descend, gitleaks does not follow. **An
  observed-public repo tracking a submodule is not clean by default**: the
  pinned tree is part of what the public sees, so audit each submodule at its
  pinned commit (§3 and §4 against that checkout), or record the unaudited
  submodule as an INCONCLUSIVE finding. A `clean` verdict over an unexamined
  submodule is the same shape as a `clean` verdict over an unrun scan.
- **Everything about the project that is not a git repo** — issues, wiki,
  releases, Pages, Actions artifacts, published packages.

**Say which ref you audited, and audit the release's ref.** Everything above
reads the *ambient* checkout, and by the time a release closes — especially a
close resumed in a later session, or one where the operator moved HEAD after
the last spine close — that may not be the branch the release integrated into.
A clean old branch passing while the release branch carries a tracked violation
is the failure.

Resolve it per repo before §3, the way the ceremony already resolves it —
**`base_branch` is not in state**, so do not reach for `oss get`:

- **canonical** — the `base_branch` recorded in the closing spines' `SPINE.md`
  spine-context sections (`spine-close.md` §3 recovers it the same way), with
  the manifest's `canonical.default_branch` as a cross-check. If the spines
  disagree with each other, halt and name them rather than picking one.
- **`ai_workspace` / `private_core`** — no spine records a base branch for
  them; audit the checked-out branch and name it as such.
- **a `git_tracked: false` repo** — no ref exists; report it as scanned from
  the working tree.

Then assert the checkout matches, or scan that ref directly, and **name the
audited ref for every repo in the report**. An audit that cannot say what it
read is not evidence.

**One fail-safe follows from the first bullet, and it is scoped to the repos
whose history is actually exposed: the history gap is a standing finding, on
every repo running the full public-audit arm, until a history pass is recorded
*for the current history*.** A repo on a private arm — §3 only, or the secrets
scan alone — owes no history pass: none of its history is public, and demanding
one would block every dual-repo close on a full-history review of the AI
workspace. The
record is a **History passes** line in the private boundary inventory, beside
the accepted disclosures — repo, the **commit it reviewed through**, and the
date, written when the user confirms a full-history review was done.

The reviewed commit is what makes the line expire. **Compare it against the
repo's current tip; if commits have landed since, a new or incremental pass is
owed** — incremental is enough, the range between the two. A line carrying only
a release id and no commit predates this format and is **treated as absent**.

**An absent or outrun line is a finding**: it reaches triage like any other,
the user may dispose of it there, and doing so writes the line for the current
tip.

Phrase it as a recorded pass rather than "on the repo's first audit", because
**nothing tells the audit whether it is the first.** No state field records a
boundary audit, and every release that closed before this step shipped closed
without one — so "is this the first?" is undeterminable exactly where it
matters most, on an adopted-forward project with a deleted `docs/planning/`
tree in its history. An absent or outrun line is determinable, and it fails safe.

---

## 9. Anti-patterns

- **Trusting the manifest over observation.** A repo the manifest calls
  private and `gh` reports public gets audited as public and raises the
  mismatch as blocking (§2).
- **Reading only `origin`.** Enumerate every remote and gate on the most
  public (§2).
- **Letting an unset manifest field disable the intent axis.** The posture is
  the second source and is always present (§2).
- **Skipping a scan because a repo has no remote.** The remote decides
  exposure, not whether to look (§2).
- **Reading "gitleaks did not complete" as clean.** Only a completed scan is a
  scan (§3).
- **Iterating the allowlist instead of scanning the tree.** Scan-first is the
  only order that catches a file the allowlist has not heard of (§4).
- **Reading a truncated enumeration as a clean one** (§4).
- **Treating an unset posture as nothing-to-protect** (§5).
- **Auto-dispositioning a finding.** The spine-close triage rule does not
  reach this step; every finding is the user's (§6).
- **Rejecting a finding whose fact is not disputed.** That is an override, and
  it takes an override's record (§6).
- **Allowlisting a finding instead of overriding it** (§6).
- **Editing the hygiene allowlist mid-audit to reclassify a hit.** An audit
  that edits its own inputs passes itself (§6).
- **Treating an override as an erasure, or as covering more than the surface
  recorded** (§6).
- **Recording an override with no content baseline**, which makes
  "exact surface" unenforceable at the next close (§6).
- **Filing this run's failed scan as a standing warning.** Only an accepted
  degradation is memory (§6).
- **Classifying the untracked set by pattern alone**, which passes any
  sensitive file nobody thought to name (§4).
- **Skipping the secrets scan because a visibility read failed** (§2).
- **Auditing whatever happens to be checked out**, or reading a `History
  passes` line as permanent when commits have landed since (§8).
- **Naming a moat item in any public-facing record of a finding.** Patterns
  and classes only (§7).
- **Running the state writes after a halt here** (§1, `release-close.md` §9).
