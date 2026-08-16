# Boundary audit — the last finding-producing step of a release close

Depth for SKILL.md §6 step 7. Implements the companion spec (public/private
boundary, 2026-07-12) §6, **re-derived 2026-08-15 under the skill-first
freeze** (the companion's construction note governs): the spec's
"mechanical-first" wording predates the freeze, so this step ships as **prose
driving external tools plus agent judgment** — `git`, `gh` and `gitleaks` do
the enumerating, the agent does the matching and the judging, and no new
deterministic runtime code exists anywhere in it. Two deliberate deltas from
the companion's §6 text are recorded inline (both in §2), each with the reason
it is safe.

**This release ships the audit's core scope: the canonical repo, gated on
observed visibility, running the tracked-file audit and the untracked sweep.**
Every other dimension the companion names — the other repo arms, the semantic
pass, history, submodules, the override record — is deliberately absent, and
§8's table names each one rather than leaving it to read as executed. A
dimension nobody wrote a rule for reporting clean is the one failure shape
this file exists to prevent; scope cuts get the same treatment.

This file is blockless by intent. Every command it names is an existing
external tool invoked as written; there is nothing here for the
executable-prose harness to extract.

---

## 1. When it runs, and what a halt means

At **every release close**, after the feature-map re-groom and next-release
sketch, **before the state writes** — the audit is the last thing that can
refuse the close. A confirmed finding halts the ceremony, and the halt reaches
the close record: `oss release_status <rel> closed` and the `demo_record` line
never run. A release therefore cannot be closed "with a leak noted" — it is
closed after the finding is fixed, or not at all. (The full design's second
unblock, the accepted-disclosure override, is not shipped — §8.)

**A halt here is not free, and saying so is part of the step.** Steps 1-6 ran
already, and two of them wrote state: `oss feature_add` appends
**unconditionally** — no dedupe, no id — and `oss release_set_meta` has stored
a `next_sketch` for a release that is now not closing. So on a re-close after
a boundary-audit halt: read `oss feature_list` first and add only what is
missing, and **amend** the existing `release-retrospective.md` rather than
re-authoring it — the boundary finding and its disposition join its "what is
still standing" section. The full cumulative walkthrough re-runs too, which is
the ceremony's most expensive step; that cost is real and is the price of the
audit being able to run last, which it must, because a fix has to be
re-audited.

---

## 2. The audited repo, and the visibility gate

**This release audits exactly one repository: the canonical**
(`oss repo_root canonical`). The pairing manifest may name others — the AI
workspace, a `private_core`, a `tooling_repo` — and §8's table says what their
absence means: they are not scanned, the report says so in one line, and that
line is scope, not a finding. Their arms land as their own PRs with their own
fixtures; do not improvise them here.

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

**Only an exact, case-insensitive `public` runs the audit arms; an observed
`private` stops them — and the stop is named, not silent.** On an
observed-private canonical, §3 and §4 do not run this release (the private-arm
design is a later PR), and the report says so: observed `private`, arms not
shipped for it, one line. Anything indeterminate — `internal` (GitHub
Enterprise's org-wide visibility, which is on the wrong side of this gate), an
unrecognised value, an empty result, a non-GitHub host, `gh` unauthenticated,
the API unreachable — is audited **as public**, and the inability to determine
visibility is itself recorded as a finding. Fail-closed: a repo you cannot
prove private is treated as public.

**Scanning does not depend on a remote.** §3 and §4 read the index and the
working tree; they need no network beyond the visibility read above. A repo
with no remote today may still have been pushed yesterday — absence of a
remote narrows the *exposure* claim, never the scan. (An earlier draft scoped
the whole step to repos with a remote "because nothing can have left the
machine". That is false for a repo whose remote was removed after a push, and
it is one `git remote remove` from defeating the audit.)

### Intent versus observation

A canonical the manifest calls private that `gh` reports public is a **blocking
finding** — something is wrong at the level of intent, and no scan result makes
it safe. The audit still runs its arms: the repo is observed-public, and a
blocking mismatch does not narrow the sweep.

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

**`PUBLIC_BOUNDARY.md` must exist at the audited repo's root — and be
tracked.** An authored-but-unstaged file is read locally while the public repo
still ships no boundary policy, and its filename matches no sensitive-path
class, so §4 will not catch the omission either. Confirm it appears in
`git -C "<root>" ls-files`; present-but-untracked is the same finding as
absent, named as such. An observed-public repo without one is a **blocking
finding** with the remediation named — author it via `start`'s posture block
(`posture-block.md` §6) — never a silent skip. The v1 draft's defect was
exactly a missing artifact reading as a clean pass.

**Execute the machine-checkable rules block by reading it.** For each
`never-tracked:` pattern in the block, list tracked files
(`git -C "<root>" ls-files`) and match them against the pattern. **Where a
pattern and a path are arguably a match, they match** — an over-match is a
finding the user rejects in one sentence; an under-match is a leak. (Glob
dialects disagree about whether a leading `**/` matches zero segments and
whether a trailing `/**` matches the directory itself; that disagreement is not
worth resolving in prose, and resolving it the safe way costs nothing.)

**An empty or malformed block is INCONCLUSIVE, not clean.** Iterating zero
`never-tracked:` entries performs zero checks and reports nothing, which is
indistinguishable from a repo that passed them — so before matching, confirm
the block parses and still carries the standard secrets rules; a block that is
empty, unparseable, or missing a rule the template ships is a recorded
degradation with the same weight as a failed scan.

Any tracked match is a finding: the file, the rule it violates, and — because
the file is already tracked — the note that removal alone does not untrack
history; a leaked *secret* must be rotated, and a leaked *document* assessed as
already disclosed.

`fixtures-must-be: synthetic` is not pattern-matchable. **It is asked wherever
this step reads a `PUBLIC_BOUNDARY.md` at all** — non-synthetic fixture data is
a privacy leak independent of any moat, by the same reasoning that makes even
a fully-private project author the file (`posture-block.md` §6). A fixture
directory that looks like real user data, prices, or prompts is a finding the
same way a tracked credential is.

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
`gh api --hostname "<host>" "repos/<owner>/<name>" --jq .security_and_analysis`
and report what the host enforces. Unknown or unreadable is a note, not a
finding — this is the host's rail, not ours, and the audit does not depend on
it.

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
are exactly what an untracked sweep of a public working tree exists to find.

So after the pattern pass, **read the remaining untracked set for what the
files are**, the same direction of judgment as the tracked-file rules: a name
or a peek that reads like downstream strategy, planning, credentials, or
private-inventory material is a **finding**, and where it is arguable it is a
finding.

**Bounded, or it collides with the paragraph above.** The judgment read does
not open every file a working tree can hold. Dependency and build trees —
`node_modules/`, `target/`, `dist/`, `vendor/`, a package manager's cache —
collapse to one entry each, the directory's name read in place of its
contents; the pattern pass still matches paths inside them, which is what
keeps this compatible with "matched, not read". **Every other ignored or
untracked directory keeps its file names in the read.** A generically named
`cache/` or `notes/` is not a dependency tree, and collapsing it to its name
is exactly how a credentials file called `scratch.txt` comes to sit inside an
entry nobody opens — an ignored directory is collapsed only when it is
recognizably a dependency or build tree, and **where that is arguable it is
not one: enumerate it.** Read individual file names in full, and open first
lines only where a name says nothing. Only a narrowing beyond that is a
recorded degradation. (`--exclude-standard` is not the bound: fixture 03's
`NOTES-STRATEGY.md` is gitignored, and excluding ignored files drops exactly
the class this step exists to catch.)

The `PUBLIC_BOUNDARY.md` "Never here" prose rules are the vocabulary for this
judgment: they already say no downstream strategy, no roadmap, no competitive
material, no non-synthetic fixtures. The pattern block is how those rules are
enforced mechanically; this read is how they are enforced at all.

---

## 5. Disposition — high-stakes, never auto

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
not match, the file is not what the name suggests — and the report records the
fact that refutes it. **If the user concedes the fact and accepts the
exposure, that acceptance is not a rejection**, and this release has no record
to write it into: the accepted-disclosure override, its inventory row and the
third verdict it licenses are not shipped (§8). Say so plainly at triage. A
close that proceeds on an acceptance with nowhere to live is exactly the
"closed with a leak noted" this step exists to prevent — the halt stands until
the finding is fixed or the close is abandoned.

A finding the user affirms is **confirmed**, and confirmed findings **block the
close**. The unblock is real work:

- **Fix before close** — untrack and rotate, rewrite the disclosing doc,
  resynthesize the fixture, remove the stray file. Re-run the affected step
  afterward; a fix is verified by the audit that re-examines it, not by the
  intention. **And a fix that changes the repository invalidates the gates
  that ran before it**: steps 2-4 walked a tree this fix has now altered, so
  re-run every gate whose inputs the fix touched — at minimum the cumulative
  walkthrough when the fix went anywhere the product reads (a resynthesized
  fixture, a deleted config, a rewritten doc a demo line opens). Recording the
  release closed on a walkthrough of the pre-fix tree certifies a product
  state that no longer exists. A fix confined to the AI workspace, or to an
  untracked file nothing loads, touches no gate's inputs and needs only this
  step re-run.

**The hygiene allowlist is not editable mid-audit.** An audit that edits its
own inputs passes itself. An allowlist entry added in response to a finding is
a `posture-block.md` edit made deliberately outside the audit — the halt
records the triage, the entry is authored at `start`-time, and the re-close
sees the file as the standing warning it now is. When the override record
ships, that path takes a row like any other acceptance; until then it is the
one honest route from a confirmed hygiene finding to a closeable release, and
it runs through a halt, not around one.

Standing warnings — hygiene-allowlisted files — are recapped at the end of
every audit report. They are the audit's memory, and pruning them is a
posture-block edit made deliberately at `start`-time ceremonies, not something
an audit does to quiet its own output.

**A degradation from *this* run is a finding, not a standing warning.** The
distinction is the whole of it: a gitleaks run that failed today is an
incomplete scan of the release being closed, and §3 sends it to triage. Only
once the user has accepted it does it become memory — and with the override
record not shipped, accepting a degradation ends this close halted exactly as
a confirmed exposure does. Filing this run's failure straight into the recap
would let a current, unaccepted, incomplete secrets scan sit under a heading
described as non-escalating, and the release would close clean without anyone
deciding anything.

---

## 6. The report

One block for the canonical — role, **the audited ref** (§8), **the coverage
line** (below), gate outcome (observed visibility per remote, manifest and
posture agreement, what ran and what was skipped), tracked-file hits, untracked
hits split new-vs-standing, degradations — each finding carrying repo, class,
the path or pattern, why it is a finding, and its remediation. Then the triage
conversation, finding by finding. Then the verdict, one of exactly two:
**clean**, or **blocked** (naming each confirmed finding). The full design's
third verdict, *proceeding with overrides*, is not shipped (§8) — do not
invent it, and do not let a blocked close borrow its shape.

### The coverage line, and why it is not optional

Every report block opens with a **coverage read-out**: each of the three
checks — tracked rules, secrets scan, untracked sweep — marked **ran**,
**skipped** with the observed value that justified it, or **INCONCLUSIVE**
with what failed. Nothing else in the block is trusted until that line
accounts for all three.

**INCONCLUSIVE has a narrow meaning, and widening it breaks the gate the other
way.** A check is **ran** when it completed against the inputs this project
actually has — and a check that ran and found nothing is *ran, clean*, never
"ran, but I could not confirm X". INCONCLUSIVE is for a check that **could not
complete**: a tool that did not run, an artifact that does not exist, an
enumeration that truncated, a rule block that parsed to nothing. It is **not**
for an input you would have liked in more detail, not for a hypothetical, and
not for a condition the procedure never asked about. Do not enumerate gaps the
procedure does not require: a report padded with speculative caveats is a gate
nobody reads, and an audit that marks a complete check INCONCLUSIVE spends the
word that is supposed to stop a release.

**This inverts the step's default, and that is the point.** Every fail-open
this audit family has shipped was the same shape: an arm nobody wrote a rule
for reported clean, because the report only ever said what was *found*, never
what was *looked at*. A verdict is assembled from the coverage line, so a
check with no recorded outcome is INCONCLUSIVE by construction rather than by
someone having anticipated it — and **INCONCLUSIVE is never clean**, at any
scale, for any reason. A tool that changes its flags, a boundary file that
lost a rule: each surfaces as an unaccounted check rather than as silence.

**And the report states its scope.** One line — canonical, observed-public,
the three shipped checks, the not-shipped dimensions named by class (§8) — so
a `clean` verdict is never read as more coverage than this release ships.
Every skip is named in the report with the observed value that justified it.

**The report's home is the close summary** (`close/SKILL.md` §10) — it is the
ceremony's final message, not a file. The durable record this audit writes is
none, this release; the inventory rows arrive with the overrides dimension.

If any part of a finding must be written where the public can read it (a
release note, a public issue), it is described by **pattern and class only**
— the `PUBLIC_BOUNDARY.md` discipline applies to the audit's own output:
naming a moat item in a public artifact is itself the leak.

---

## 7. Anti-patterns

- **Trusting the manifest over observation.** A repo the manifest calls
  private and `gh` reports public gets audited as public and raises the
  mismatch as blocking (§2).
- **Reading only `origin`.** Enumerate every remote and gate on the most
  public (§2).
- **Letting an unset manifest field disable the intent axis.** The posture is
  the second source and is always present (§2).
- **Skipping a scan because the repo has no remote.** The remote decides
  exposure, not whether to look (§2).
- **Reading "gitleaks did not complete" as clean.** Only a completed scan is
  a scan (§3).
- **Treating an empty machine-checkable block as a pass** — zero rules run is
  zero checks, not zero violations (§3).
- **Reading an untracked `PUBLIC_BOUNDARY.md` as present** (§3).
- **Iterating the allowlist instead of scanning the tree.** Scan-first is the
  only order that catches a file the allowlist has not heard of (§4).
- **Reading a truncated enumeration as a clean one** (§4).
- **Classifying the untracked set by pattern alone**, which passes any
  sensitive file nobody thought to name (§4).
- **Collapsing an ignored directory that is not a dependency or build tree**,
  which hides whatever sits inside a generically named `cache/` or `notes/`
  (§4).
- **Auto-dispositioning a finding.** The spine-close triage rule does not
  reach this step; every finding is the user's (§5).
- **Improvising the unshipped override** — proceeding on an acceptance with
  no record, or inventing the third verdict (§5, §6).
- **Editing the hygiene allowlist mid-audit to reclassify a hit.** An audit
  that edits its own inputs passes itself (§5).
- **Filing this run's failed scan as a standing warning.** Only an accepted
  degradation is memory, and accepting one ends this close halted (§5).
- **Auditing whatever happens to be checked out.** Resolve and name the
  audited ref (§8).
- **Naming a moat item in any public-facing record of a finding.** Patterns
  and classes only (§6).
- **Reporting a verdict without a coverage line**, or reading an unaccounted
  check as clean rather than INCONCLUSIVE (§6).
- **Running the state writes after a halt here** (§1, `release-close.md` §9).

---

## 8. What this audit does not cover — the not-shipped table

Stated as a table, because the sibling ceremony's rule is that a step which
silently does nothing is indistinguishable from a missing one
(`release-close.md` §1) — and a scope cut is the same shape of hazard.

| Dimension | Status |
|---|---|
| **The other repo arms** — the AI workspace, a `private_core`, a `tooling_repo` | **not shipped.** This release audits the canonical only. Those repos are not scanned; the report says so in one line — scope, not a finding, not silence. The per-repo iteration lands as its own PR with its own fixtures |
| **The semantic pass** — tracked prose that *describes* a moat item | **not shipped.** A README that discloses a moat item's identity and mechanism passes this audit today. The sweep over the private boundary inventory is a later PR |
| **History, and every branch but the audited ref** | **not shipped.** A private document committed a year ago and later deleted is public forever at its blob URL, and nothing here looks. `gitleaks` still covers *secrets* across history when it completes — the tool's own behavior, not this audit's rule. The recorded History-passes line is a later PR |
| **Submodule contents** | **not shipped.** `ls-files` returns one gitlink, `--others` does not descend, gitleaks does not follow. A tracked submodule is named in the report as outside this audit's coverage — never read as clean by default |
| **Accepted-disclosure overrides** | **not shipped.** The third verdict, the inventory row, and the exact-surface pin arrive with the disposition PR. Until then a confirmed finding has exactly one unblock: the fix (§5) |
| **Everything about the project that is not a git repo** | permanent scope, not a cut: issues, wiki, releases, Pages, Actions artifacts, published packages |

Each row is named by class in the report's scope line (§6), so a `clean`
verdict never implies more coverage than this table ships. The rows leave this
table one PR at a time, each with its own fixtures — never by quiet expansion
inside this file.

**Say which ref you audited, and audit the release's ref.** Everything above
reads the *ambient* checkout, and by the time a release closes — especially a
close resumed in a later session, or one where the operator moved HEAD after
the last spine close — that may not be the branch the release integrated into.
A clean old branch passing while the release branch carries a tracked
violation is the failure.

Resolve it before §3, the way the ceremony already resolves it —
**`base_branch` is not in state**, so do not reach for `oss get`:

- Consult the **`base_branch` recorded in the closing spines' `SPINE.md`**
  spine-context sections (`spine-close.md` §3 recovers it the same way), with
  the manifest's `canonical.default_branch` as a cross-check. Consult only the
  release's `closed` spines: an **`abandoned`** spine may never have run
  `/plan-spine` and so never wrote a `SPINE.md` — it contributes nothing, and
  its silence is not an error. If the recorded bases disagree with each other,
  halt and name them rather than picking one; if no closing spine records a
  base at all, audit the manifest's `default_branch` and name that source in
  the report.

Then assert the checkout matches, or scan that ref directly, and **name the
audited ref in the report**. An audit that cannot say what it read is not
evidence.
