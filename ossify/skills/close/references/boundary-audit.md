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

**This release ships the audit's core scope — the tracked-file audit and the
untracked sweep — over the full repo set: every repository object the pairing
manifest carries, each gated on its observed visibility with per-role arms
(§2).** Every other dimension the companion names — the semantic pass, history,
uncommitted tracked modifications, submodules, the override record — is
deliberately absent, and §8's table names each one rather than leaving it to
read as executed. A dimension nobody wrote a rule for reporting clean is the
one failure shape this file exists to prevent; scope cuts get the same
treatment.

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

**A halt here is not free, and saying so is part of the step.** The re-close is
not free and steps 1-6 are not free to repeat — `release-close.md` §8 owns that
accounting (the unconditional `feature_add`, the stored `next_sketch`, the
amended-not-re-authored retro, the re-run walkthrough); read it before you halt.

---

## 2. The repo set, and the visibility gate

**Build the repo set from every repository object the pairing manifest
carries, not from a fixed list of roles** — walk up from the cwd to
`.workspace/pairing.json` (`references/harvest.md` §7 resolves it the same
way) and take every top-level object that carries a `root`: the canonical
(`oss repo_root canonical`), the AI workspace (`oss repo_root ai_workspace`),
a `private_core`, and the optional `tooling_repo` workspace-init emits when a
project volunteers one. Hard-coding three role names is how a public tooling
repo ends up holding tracked secrets while the release reports clean. A role
this file states no row for in the table below is audited on the
canonical-policy row — never skipped. **A repo's manifest role is
structural** — workspace-init writes it, and it is not the pending per-repo
`visibility` field (§2's intent note below).

**Read each repo's `git_tracked` before anything else, because not every
manifest repo is a git repo.** workspace-init's Scenario C pairs an AI
workspace that is deliberately untracked (`ai_workspace.git_tracked: false`),
and every git command in this file would fail against it — turning a supported
topology into a permanently undeterminable audit with no repository fix
available. **The field is a hint, not the determination:** workspace-init
writes `git_tracked: false` for a workspace nested inside a parent repo, a
bare repo, or a linked worktree as well as a plain non-repo, the optional
`tooling_repo` object carries no `git_tracked` field, and a stale `true` can
outlive
a de-gitted directory — so wherever the field reads `true`, `false` **or**
is absent, determine the root directly — `git -C "<root>" rev-parse
--show-toplevel`, which must print the root itself: a bare
is-inside-work-tree probe answers a different question (a directory nested
inside any parent repo passes it, and every later `git -C` would then audit
the parent) — and record which you did. `git` resolves symlinks in the
output, so resolve the manifest root the same way before comparing, and
reject only when the output is a strict ancestor of the root — a directory
nested inside a
parent repo, which is neither a repo root nor a standalone tree: its content
sits in the PARENT's index, on the parent's remotes, and no arm in this file
audits the nested path as itself. Its disposition depends on the parent: **a
blocking finding naming the topology when the parent is outside the repo
set** (the manifest names a root whose content the parent may track and
expose, and nothing audits the parent); **a scope note when the parent is
itself a manifest repo in the set** — the nested paths sit inside the
parent's tree and are audited as part of its block; the nested entry adds no
arm of its own, and the note says the paths were audited as parent content,
not as a root. A linked
worktree is identified not by the toplevel but by
`git -C "<root>" rev-parse --git-dir` differing from
`git -C "<root>" rev-parse --git-common-dir` — its root is its own worktree
of another repository's git dir, the filesystem-only premise (no index, no
history) is false, and it halts and names its shape. A root where
`--show-toplevel` fails splits on
`git -C "<root>" rev-parse --is-bare-repository`: a refusal there too means
no git directory at all — the plain non-repo, the flagship Scenario-C shape —
which gets the **filesystem-only** policy; a printed `true` is a bare repo
(index and history exist, no working tree this policy assumes) and halts and
names its shape; a printed `false` after a `--show-toplevel` refusal is a
shape this tree does not otherwise name — halt and name it rather than
guess. **The field records intent; the probe records topology; and topology
governs.** A `true` over a plain directory halts and names the drift (the
manifest records the project's belief; a directory contradicting it is
drift). A `false` over a repo root resolves by the probe outcome — the
shapes workspace-init labels `false` are exactly the shapes the probe
distinguishes — with a note naming the disagreement. Otherwise — the field
absent or agreeing with the
probe — a repo
that is not a git
repo gets the **filesystem-only**
policy — except the canonical itself, where §8 halts the close instead: the
product repository has nothing to audit. The policy means: no index, no
remotes and no history, so this section's
visibility gate and §3's tracked-file rules do not apply to it. **An
exposure question survives any untracking:** the manifest object itself may
carry a `git_remote` alongside a `false` or absent tracking field
(workspace-init's remote and tracking flags are independent) — a repo that
was pushed and later
untracked. Read that recorded remote with `gh repo view` (a `gh` read needs
no local git): public or undeterminable is a **blocking finding** naming the
recorded remote — the content may sit on a host regardless of what the
directory is now, and this one finding blocks the close on its own, outside
the §5-skip that otherwise governs the filesystem-only arm; private is a
note. And the recorded-remote read is not only for plain non-repo roots: for
**every** repo in the set, any `git_remote` the manifest carries that the
local enumeration did not list is read the same way — a removed local remote
is one `git remote remove` from an unaudited exposure, and the manifest
remembers it. A repo with no remote on record anywhere
— no manifest `git_remote`, no local remotes to enumerate — raises no remote
finding, and the report says so as a scoping note ("no remote on record"),
never as an impossibility claim: a de-gitted workspace can have been pushed
before pairing, and the filesystem-only arm's limits are what the coverage
line names. Run **§3's
secrets scan** over its working tree as hygiene notes — with
`gitleaks detect --source "<root>" --no-banner --redact --no-git`. **The
`--no-git` flag is load-bearing:** `gitleaks detect` defaults to walking git
history, and against a directory that is not a repo the default invocation
exits **0** with `no leaks found` after `0 commits scanned` and
`~0 bytes` — a pass that read nothing, on the repo that holds the moat by
construction; `--no-git` is what makes the scan read the working tree.
(`--redact` for the same reason §3 states it: an unredacted hit
quotes the matched secret into the transcript on the exact leak-handling
path.) And whichever invocation produced it, a run reporting zero bytes
scanned against a root that has files is INCONCLUSIVE (§3): rc 0 and
"no leaks found" are not evidence that a scan happened. §4 and §5 are skipped
for the role — §4 because an untracked sweep enumerates the complement of an
index this repo does not have (a directory-tree judgment read over an
untracked workspace is named future scope in the report, never silently
clean), §5 with it. Say in the report that it
was scanned as an untracked directory. Its lack of a *local* remote is never
a finding — the exposure question for this repo is the recorded
`git_remote` above, where one exists.

### Determining observed visibility

Enumerate **every** remote, redacted — `git -C "<root>" remote -v | sed -E 's#(https?://)[^/@]+@#\1***@#g'` — not just
`origin`: a remote may be named `upstream` or `github`, `origin` may be a
private fork of a public upstream, and a repo may push to both. The redaction
is not cosmetic: an HTTPS remote can carry its credential inline
(`https://<token>@github.com/...`), and printing that bare puts the token
into the transcript before the audit has even started — the §3 rule reaches
the enumeration too. For each remote, derive
**`host/owner/name`** from the redacted form and read
`gh repo view "<host>/<owner>/<name>" --json visibility`. **Gate on the most
public answer**: one public remote makes the repo observed-public, whatever the
others say.

**Carry the host, do not drop it.** `gh`'s repository selector is
`[HOST/]OWNER/REPO`, and with the host omitted it resolves against `GH_HOST` or
its own default — so a GitHub Enterprise remote queried as bare `owner/name`
can answer about a *different* host's repo of the same name. Where that other
repo is private, an observed-public Enterprise repo is misclassified as private
and takes a private row's lighter arm. Every path in this file that quotes a
root or a
selector quotes it: manifest-resolved paths may contain whitespace, and
`close/SKILL.md` §8 already requires `git -C "<absolute path>"`.

**The gate's answer decides which row of the arms table a repo takes — and
the `any` row's full §3-§5 runs on an exact, case-insensitive `public` or an
indeterminate read; the role rows govern their roles as written below.**
Anything indeterminate — `internal` (GitHub Enterprise's
org-wide visibility, which is on the wrong side of this gate), an
unrecognised value, an empty result, a non-GitHub host, `gh` unauthenticated,
the API unreachable — is audited **as public**, and the inability to determine
visibility is itself recorded as a finding. Fail-closed: a repo you cannot
prove private is treated as public.

### What each outcome runs

| Role | Observed | What runs |
|---|---|---|
| any | public (or undeterminable) | §3, §4, §5 in full; findings are **blocking** |
| `canonical` | private | §3 only, as **non-blocking hygiene notes for the document and strategy classes** — a missing `PUBLIC_BOUNDARY.md` is a hygiene finding here, not a blocking one. **A secrets-class hit blocks on every arm:** a tracked credential or a live secret the scan found is a rotation question, not a visibility question. §4 and §5 skipped |
| `ai_workspace`, `private_core` | private | §3's secrets scan only, as hygiene notes — with the same secrets-class carve-out: a secrets hit blocks. §4 and §5 skipped |
| `ai_workspace`, `private_core` | **public** | **blocking finding on its own** — these roles are private by construction. **The secrets scan and §4's sweep run in full, and §5 runs** (the tracked-rules half degrades on the never-expected policy input — §3): the repo is already exposed, and a skipped sweep means an exposed workspace is never examined |
| `ai_workspace`, `private_core` | undeterminable | the undeterminable read of an **on-record** remote is a **blocking finding on its own** — a repo you cannot prove private is treated as public, so this row is the public row above: the scan and the sweep run in full (the tracked-rules half degrades on the never-expected policy input — §3), and §5 runs. A moat-holder with **no remote on record at all** cannot be read undeterminable — it takes the private row's arm with the no-remote rule below |

**No remote on record — enumerated or recorded (§2) — changes no arm's
checks.** The row still runs its secrets scan and, where the row runs it,
§4's sweep: absence of a remote narrows the *exposure* claim, never the
scan, and the scoping note says so in the block.

**A role with no row of its own takes the `canonical` policy.** The optional
`tooling_repo` is the live case: observed private, it matches neither the `any`
row (public/undeterminable only) nor the two private-by-construction role
rows, and would otherwise have no defined checks at all despite this section
claiming every manifest repo is audited. It is a product-adjacent repo, not a
moat holder, so it audits like a canonical — §3 as hygiene notes when private,
the full §3-§5 when public.

**Role-specific rows win over the `any` row.** An undeterminable read is
audited as public (above), so an `ai_workspace` with unreadable visibility
matches three rows at once; the role rows are the answer, and the `any` row
governs `canonical` and anything the manifest adds later.

Every skip is named in the report with the observed value that justified it.

**No arm of this table skips the secrets scan.** Scanning does not depend on a
remote (below), so it cannot depend on being able to *read* a remote either.
The visibility finding and the secrets scan are independent; a repo whose
visibility is unknown gets both.

**Why private repos are scanned at all** (and the second delta from the
companion, which scoped the whole audit to public repos):
`start/references/posture-block.md` §6 requires **even a fully-private
project** to author `PUBLIC_BOUNDARY.md`, because hygiene is independent of
visibility and it is what keeps a later flip to *one* ceremony. A rule block
that never executes for the project's entire private life gets its first run
at the flip, when a hit means a history rewrite instead of a `git rm`. Hygiene
notes cost nothing and are the whole point of authoring the file early.

**Why `ai_workspace` and `private_core` stop at the secrets scan:** they hold
the moat by design. §3's `never-tracked:` document rules have nothing to read
there — `start` routes `PUBLIC_BOUNDARY.md` to public-facing repo roots only,
so on these roles the rules half degrades on the never-expected input (public
arm) or is skipped outright (private arm), never a missing-file block — and
the semantic pass, when
it ships (§8), will not run against the repo that holds the moat inventory
either — every finding there would be expected, which is indistinguishable
from a real one.

**Scanning does not depend on a remote.** §3 and §4 read the index and the
working tree; they need no network beyond the visibility read above. A repo
with no remote today may still have been pushed yesterday — absence of a
remote narrows the *exposure* claim, never the scan. (An earlier draft scoped
the whole step to repos with a remote "because nothing can have left the
machine". That is false for a repo whose remote was removed after a push, and
it is one `git remote remove` from defeating the audit.)

### Intent versus observation

A repo the manifest calls private that `gh` reports public is a **blocking
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
fields yet (`start/references/posture-block.md` §9 — recorded as intent, written later), so
today the field is unset in every real project and the mismatch rule above
would never fire. **So the posture is the second intent source, and it is
always present:** read `oss get ".project.posture"`. A **`fully-private` or
unset posture over an observed-public repo is the same mismatch** and blocks
identically. **And a posture that is not one of the four values reads as
unset** — `posture_set` does not validate its argument, so a slip like
`private` must not silently re-enable the hole this rule closes. Without
this, a default-private project whose canonical was flipped public — the
commonest shape there is — passes every scan and closes `clean` with its
entire codebase public.

---

## 3. Step 1 — the tracked-file audit

**`PUBLIC_BOUNDARY.md` must exist at the audited repo's root — and be
tracked, and be a regular file.** An authored-but-unstaged file is read locally
while the public repo still ships no boundary policy, and its filename matches
no sensitive-path class, so §4 will not catch the omission either. Confirm it
appears in `git -C "<root>" ls-files`; present-but-untracked is the same
finding as absent, named as such. And confirm the tracked entry's mode in
`git -C "<root>" ls-files -s -- PUBLIC_BOUNDARY.md` is a regular file's —
`100644` or `100755`. A `120000` entry is a symlink, and a `160000` entry is
a gitlink: each passes `ls-files` and both of §8's `diff --quiet` checks
while committing a path or a commit pointer instead of the policy itself. A
gitlink is always a **finding naming its shape**, with the same
`start/references/posture-block.md` §6 authoring
remediation as an absent one — the target is never read as the policy. A
symlink is a finding of the same shape **when its target is not itself a
regular tracked file of this repo** — an out-of-repo or untracked target is
material the release does not ship, and the read would follow it; a symlink
whose target IS a regular tracked file in the same repo ships a working
policy at the root, and is a **note** naming the shape (the policy is
doubly-addressed), not a block. An observed-public
repo without the file is a **blocking finding** with the remediation named —
author it via `start`'s posture block (`start/references/posture-block.md`
§6) — never a silent skip. The v1 draft's defect was exactly a missing
artifact reading as a clean pass. **Where the document rules run at all is
role-scoped:** on a private canonical running §3 as hygiene notes, a missing
file is a hygiene finding, not a blocking one (§2's table). `start`'s posture
block routes `PUBLIC_BOUNDARY.md` to public-facing repo roots — the canonical
always, a product-adjacent repo at its own root
(`start/references/posture-block.md` §6) — so on the
`ai_workspace`/`private_core` roles no policy file is ever expected, and its
absence is not
a finding on any arm: when those roles are observed public, §3's secrets scan
and §4's sweep run in full with blocking findings (§2's table), and the
tracked-rules and classification halves degrade on the absent policy input
exactly as §4 prescribes — named, never silent.

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
empty, unparseable, **carrying a directive this step cannot execute**, or
missing a rule the template ships is a recorded degradation with the same
weight as a failed scan.

Any tracked match is a finding: the file, the rule it violates, and — because
the file is already tracked — the note that removal alone does not untrack
history; a leaked *secret* must be rotated, and a leaked *document* assessed as
already disclosed.

`fixtures-must-be: synthetic` is not pattern-matchable. **It is asked wherever
this step reads a `PUBLIC_BOUNDARY.md` at all** — non-synthetic fixture data is
a privacy leak independent of any moat, by the same reasoning that makes even
a fully-private project author the file (`start/references/posture-block.md`
§6). That includes a private canonical running
hygiene notes; it excludes the `ai_workspace`/`private_core` roles, where no
`PUBLIC_BOUNDARY.md` is ever read on any arm — a named skip, not a silent one.
A fixture
directory that looks like real user data, prices, or prompts is a finding the
same way a tracked credential is.

**Secrets scan — external tool, honest degradation.** Run
`gitleaks detect --source "<root>" --no-banner --redact` and fold its findings
in. **`--redact`, always:** when the scan finds a real credential, unredacted
output quotes the matched secret, and folding that into the transcript or the
close summary duplicates the credential into the session log on exactly the
leak-handling path. Carry rule, path and location into the report — never the
matched text. **And read the repo's own `.gitleaks.toml` before trusting a
clean result** — gitleaks auto-loads it from the scanned source, so an
allowlist entry broad enough to cover ordinary source files, or the default
rules switched off, is a **finding in its own right**: the scan completed
against rules the repo itself weakened, and that is not a clean scan of the
release. **Only a completed scan counts as a scan.** Any other outcome —
binary absent, invocation rejected or deprecated away, run aborted, output
unreadable — is INCONCLUSIVE and recorded as a degradation naming what failed.
Inconclusive is not clean: a scan that errors produces no findings, which is
byte-identical to
a scan that found nothing. **And a run that completes but read nothing it was
pointed at is the same evidence shape:** rc 0 with `no leaks found` after
`~0 bytes` against a root that has files is a pass that read nothing —
INCONCLUSIVE (§2's filesystem-only arm is where this shape lives). The user may accept a degradation at triage like
any other finding; what is forbidden is the audit *silently* narrowing to
pattern rules because a tool did not run.

**Push protection — best-effort.** Read
`gh api --hostname "<host>" "repos/<owner>/<name>" --jq .security_and_analysis`
and report what the host enforces. Unknown or unreadable is a note, not a
finding — this is the host's rail, not ours, and the audit does not depend on
it.

---

## 4. Step 2 — the leak-adjacent scan (untracked files, scan-first)

This step runs on every repo whose §2 row runs it — the observed-public and
undeterminable repos on the `any` row (including a no-row repo on the
canonical policy), and a public or undeterminable `ai_workspace`/
`private_core` on its role row (the exposed-workspace arm) — and on no
other.

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

**When the policy input is absent, the classification half is degraded, not
clean.** On the canonical (and any canonical-policy repo), §3 has already
raised the missing `PUBLIC_BOUNDARY.md` as its own finding; on the
`ai_workspace`/`private_core` public arm no policy file is ever expected (§3),
and the degradation rides the exposure finding instead. Either way the sweep
still enumerates and still pattern-matches against the
standard secrets classes, but with no allowlist to classify against, "no
allowlisted hits" is not a classification this run produced — the coverage
line records the sweep's classification half as **degraded on the absent
policy input**, so a later reader cannot mistake a pattern-only pass for a
classified one. The judgment read below still runs; it never depended on the
allowlist.

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
not one: enumerate it.** Read individual file names in full, and where a name
says nothing, open the file and read it — a stray working note is small, and
a file too large to read is itself the recorded degradation. **But if what it
holds is a credential or a secret, the finding is the file's PRESENCE, never
its content**: name the class, close the file, and quote nothing — the §3
redaction rule reaches this read too, and a transcript that acquires the
secret while hunting it is the leak happening twice.
(`--exclude-standard` is not the bound: the untracked-sweep fixture's
`NOTES-STRATEGY.md` is
gitignored, and excluding ignored files drops exactly the class this step
exists to catch.)

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
close** — on every arm whose row runs §5. The arms that skip §5 never reach
this paragraph — every private row and the
plain non-repo policy; their
findings are recorded as the non-blocking notes or the degradations their
rows name — with the exceptions §2 carves: the recorded-`git_remote`
exposure finding blocks on its own wherever it fires, and a secrets-class
hit blocks on every arm. And a degradation on a
§5-skipping arm, while never a §5 confirmed finding, still governs the
verdict through §6: INCONCLUSIVE is never clean, so an unaccepted
degradation halts the close exactly as an acceptance here would. The unblock
is real work:

- **Fix before close** — untrack and rotate, rewrite the disclosing doc,
  resynthesize the fixture, remove the stray file. **And a fix that changes
  the repository invalidates the gates
  that ran before it**: the cumulative walkthrough (step 2) exercised a
  product this fix has now altered, so re-run every gate whose inputs the fix
  touched — at minimum the cumulative walkthrough when the fix went anywhere
  the product reads (a resynthesized
  fixture, a deleted config, a rewritten doc a demo line opens). Recording the
  release closed on a walkthrough of the pre-fix tree certifies a product
  state that no longer exists. A fix confined to the AI workspace, or to an
  untracked file nothing loads, touches no gate's inputs — but it still
  re-enters through the §1 re-close, because the halt was terminal and no
  gate is skipped by shortcut: what such a fix buys is that the re-run gates
  re-verify an unchanged input, not that they are bypassed. The audit itself
  always re-runs — a fix is verified by the audit that re-examines it.

**The hygiene allowlist is not editable mid-audit.** An audit that edits its
own inputs passes itself. An allowlist entry added in response to a finding is
a `start/references/posture-block.md` edit made deliberately outside the audit — the halt
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

One block per repo in the set — role, **the audited ref** (§8), **the coverage
line** (below), gate outcome (observed visibility per
remote, manifest and posture agreement, what ran and what was skipped),
tracked-file hits, untracked hits split new-vs-standing, degradations — each
finding carrying repo, class,
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
complete**: a tool that did not run, a tool that completed but read nothing it
was pointed at, an artifact that does not exist, an enumeration that
truncated, a rule block that parsed to nothing. It is **not**
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

**And the report states its scope.** One line — the repo set with each repo's
observed visibility and arm, the three shipped checks, the not-shipped
dimensions named by class (§8) — so
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
- **Reading a non-enum posture as carrying intent.** A posture that is not
  one of the four values reads as unset — `posture_set` does not validate its
  argument (§2).
- **Skipping a scan because the repo has no remote.** The remote decides
  exposure, not whether to look (§2).
- **Hard-coding the role list.** Every manifest repo object gets a row — a
  public `tooling_repo` skipped because it is not one of three names is the
  failure (§2).
- **Skipping the secrets scan on an arm whose visibility read failed.** The
  scan and the visibility finding are independent; no arm of the table skips
  the scan (§2).
- **Running git commands against a plain non-repo root.** The
  filesystem-only policy exists because no index, remotes, or history exist
  there — `--no-git` is the scan, and a zero-byte clean read against a root
  that has files is INCONCLUSIVE (§2).
- **Reading a symlinked policy file's unshipped target.** The committed blob
  is a path, not a policy — the shape is the finding wherever the target is
  not a regular tracked file of the same repo (§3).
- **Reading a policy-absent sweep's pattern pass as a classified one.** No
  allowlist, no classification — the half is degraded (§4).
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
- **Auditing whatever happens to be checked out on the canonical, or a dirty
  checkout.** Resolve the release's ref per §8, verify HEAD matches it with no
  staged or unstaged tracked changes, and name it. (The role repos' audited
  ref IS their checked-out branch, named as such — §8; the anti-pattern is
  auditing an unresolveable ref, not the role rule.)
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
| **The semantic pass** — tracked prose that *describes* a moat item | **not shipped.** A README that discloses a moat item's identity and mechanism passes this audit today. The sweep over the private boundary inventory is a later PR |
| **History, and every branch but the audited ref** | **not shipped.** A private document committed a year ago and later deleted is public forever at its blob URL, and nothing here looks. `gitleaks` still covers *secrets* across history when it completes — the tool's own behavior, not this audit's rule. The recorded History-passes line is a later PR |
| **Uncommitted modifications to tracked files** | **not shipped.** The rules match paths (`ls-files`), gitleaks reads committed history, and the sweep reads untracked paths only — a secret pasted into a tracked file and left uncommitted is never READ by the three checks, though §8's clean-tree gate halts on its presence before they run, wherever that gate reaches the repo (arms that read the index or a tracked policy file; the secrets-scan-only arms are exempt). A working-tree diff pass that reads it is a later PR |
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

**A canonical that determines as a plain non-repo root (§2) is a halt-and-name
of its own:** the ceremony's product repository has no index, no history and
no ref to resolve — no gate in this section can run, and the close stops for
the owner to restore the repository. Nothing else in this tail applies to it.

Resolve it before §3, the way the ceremony already resolves it —
**`base_branch` is not in state**, so do not reach for `oss get`:

- Consult the **`base_branch` the closing spines' handoffs recorded** under
  `## 2. Spine context` (`spine-close.md` §3 resolves it the same way —
  handoff-primary, with `SPINE.md`'s spine-context section as the cross-check,
  halting on disagreement), with
  the manifest's `canonical.default_branch` as a cross-check. Consult only the
  release's `closed` spines: an **`abandoned`** spine may never have run
  `/plan-spine` and so never wrote a `SPINE.md` — it contributes nothing, and
  its silence is not an error. If the recorded bases disagree with each other,
  halt and name them rather than picking one; if they agree with each other
  but contradict the manifest's `default_branch`, halt and name both readings
  — that is drift or a typo, and the audit does not pick silently; if no
  closing spine records a base at all, audit the manifest's `default_branch`
  and name that source in the report.

**The other repos in the set resolve their audited ref differently.** No spine
records a base branch for the `ai_workspace`, a `private_core` or a
`tooling_repo`: audit each one's checked-out branch and name it as such in
its block. A plain non-repo root (determined per §2, whatever the field
says) has no ref at all — its block says it
was scanned from the working tree, which is the whole of its policy (§2).

Then verify the checkout IS that ref, cleanly, before §3 — everything this
audit reads is ambient: `git ls-files` reads the index, the rules are read
from the working-tree file, and the sweep enumerates the index's complement.
**On the
canonical, halt unless `git -C "<root>" rev-parse "$audited_ref"` equals
`git -C "<root>" rev-parse HEAD`** — compare the two RESOLVED object ids,
never a branch name against a commit id, which are never equal — **and on
every repo whose arm reads the index or a tracked policy file — the canonical
always; another repo whenever its arm runs §3's tracked rules or §4's sweep,
in full or as hygiene notes — both
`git -C "<root>" diff --quiet` and `git -C "<root>" diff --cached --quiet`
must succeed** — a staged deletion or an unstaged edit to `PUBLIC_BOUNDARY.md`
can make the committed release tree differ from everything this audit just
read, and a clean verdict over a tree the release does not ship is the
failure. A repo on a
secrets-scan-only arm makes no release-tree claim — on a git repo, gitleaks
reads committed history and neither the index nor the working tree, so an
unstaged edit is invisible to the scan and no divergence claim exists; its
block names what was read; the diff gate does not reach it. (Untracked files are §4's input by
design and do not halt this check anywhere.) **And name the audited ref in
every repo's block.** An audit that cannot say what it read is not evidence.
