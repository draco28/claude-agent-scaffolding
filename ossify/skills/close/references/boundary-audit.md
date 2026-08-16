# Boundary audit — the last finding-producing step of a release close

Depth for SKILL.md §6 step 7. Implements the companion spec (public/private
boundary, 2026-07-12) §6, **re-derived 2026-08-15 under the skill-first freeze**
(the companion's construction note governs): the spec's "mechanical-first"
wording predates the freeze, so this step ships as **prose driving external
tools plus agent judgment** — `git`, `gh` and `gitleaks` do the enumerating,
the agent does the matching and the judging, and no new deterministic runtime
code exists anywhere in it. Two deliberate deltas from the companion's §6 text
are recorded inline (§2 and §6 below), each with the reason it is safe.

This file is blockless by intent. Every command it names is an existing
external tool invoked as written; there is nothing here for the executable-prose
harness to extract.

---

## 1. When it runs, and what a halt means

At **every release close**, after the feature-map re-groom and next-release
sketch, **before the state writes** — the audit is the last thing that can
refuse the close. A confirmed finding halts the ceremony, and a halt records
nothing: `oss release_status <rel> closed` and the `demo_record` line never run
(release-close.md §9's rule, unchanged). A release therefore cannot be closed
"with a leak noted" — it is closed after the finding is fixed, or after the
user records an accepted-disclosure override (§6), or not at all.

The audit is per-repo. Build the repo set from the pairing manifest — the
canonical (`oss repo_root canonical`), the AI workspace
(`oss repo_root ai_workspace`), and any `private_core` the manifest names —
and audit each repo **that has a remote**. A repo with no remote is out of
scope for this step (nothing can have left the machine) and is said so in the
report, not silently dropped.

---

## 2. The visibility gate — observed, fail-closed

For each repo with a remote, determine **observed** visibility: derive
`owner/name` from `git -C <root> remote get-url origin` and read
`gh repo view <owner>/<name> --json visibility`. Then:

- **Observed public** → the full audit (§3-§5) runs on this repo.
- **Visibility undeterminable while a remote exists** — `gh` unauthenticated,
  the API unreachable, the host not github.com — → the full audit runs
  **anyway**, and the inability to determine visibility is itself recorded as
  a finding. Fail-closed: a repo you cannot prove private is audited as if
  public.
- **Observed private** → §3-§5 are skipped for this repo, and the skip is
  named in the report with the observed value that justified it.
- **The manifest disagrees with observation** — a manifest visibility field
  says `private` while `gh` reports public (or the reverse) — → **blocking
  finding**. Something is wrong at the level of intent, and no scan result
  makes that safe.

**Delta from companion §6, recorded:** the companion also blocks on an *unset*
manifest visibility field. That rule was written for a draft in which the
manifest field *decided which repos got audited* — unset meant skipped, which
is the fail-open the spec names. Under this re-derivation the decision input
is **observed** visibility, so an unset field can no longer cause a skip.
It is therefore recorded as a **note** ("visibility intent not yet recorded —
workspace-init's visibility fields are pending"), not a block. Blocking every
close of every project until a different plugin ships a schema extension would
gate releases on a field that protects nothing here.

---

## 3. Step 1 — the tracked-file audit

**`PUBLIC_BOUNDARY.md` must exist at the audited repo's root.** An
observed-public repo without one is a **blocking finding** with the remediation
named — author it via `start`'s posture block (posture-block.md §6) — never a
silent skip. The v1 draft's defect was exactly a missing artifact reading as a
clean pass.

**Execute the machine-checkable rules block by reading it.** For each
`never-tracked:` pattern in the block, list tracked files
(`git -C <root> ls-files`) and match them against the pattern with the glob
semantics the block was authored in (`**` crosses directories). Any tracked
match is a finding: the file, the rule it violates, and — because the file is
already tracked — the note that removal alone does not untrack history; a
leaked *secret* must be rotated, and a leaked *document* assessed as already
disclosed.

`fixtures-must-be: synthetic` is not pattern-matchable; it routes to the
semantic pass (§5), which asks it as a judgment question.

**Secrets scan — external tool, honest degradation.** If `gitleaks` is
installed, run `gitleaks detect --source <root> --no-banner` and fold its
findings in (note whether the repo carries its own gitleaks config). If it is
**not** installed, the secrets half of this step is INCONCLUSIVE, and
inconclusive is not clean: record a degradation finding naming the missing
tool. The user may accept it at triage like any other finding — what is
forbidden is the audit *silently* narrowing to pattern rules because a binary
was absent.

**Push protection — best-effort.** Read
`gh api repos/<owner>/<name> --jq .security_and_analysis` and report what the
host enforces. Unknown or unreadable is a note, not a finding — this is the
host's rail, not ours, and the audit does not depend on it.

---

## 4. Step 2 — the leak-adjacent scan (untracked files, scan-first)

Enumerate **all** untracked files in the public working tree —
`git -C <root> ls-files --others`, deliberately **without**
`--exclude-standard`, because gitignored files (`.env`, a private `SPEC.md`)
are exactly the class in play. One `git add -f`, one editor "save all", one
misfired `git commit -a` is the distance between an untracked sensitive file
and a tracked one.

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

---

## 5. Step 3 — the semantic pass (agent judgment)

The question no pattern can ask: **does anything tracked in the public repo
*describe* a moat item, even without containing it?**

Its input is the **private boundary inventory** (posture-block.md §7 — the AI
workspace artifact that names moat items, channels and seams). Locate it in
the AI workspace's docs tree; read the posture first
(`oss get ".project.posture"`). If the posture implies protected value
(`open-core`, `source-available`, a `fully-private` project with declared
overlay seams) and the inventory **cannot be located**, the semantic pass is
INCONCLUSIVE — a finding with the remediation pointer (author it per
posture-block.md §7), not a clean pass. A `fully-open` posture with an empty
inventory makes this pass trivially clean; say so and move on rather than
inventing findings.

With the inventory in hand, sweep what the public repo *tracks* — READMEs,
docs, design comments, specs — for prose that discloses a moat item:

- a README explaining the *rationale and structure* of an algorithm whose
  implementation is private-packaged;
- a roadmap or planning section naming unreleased strategy;
- a comment or doc linking a private spec by title and summary, reconstructing
  its content in miniature;
- non-synthetic fixture data (`fixtures-must-be: synthetic` lands here): does
  any tracked fixture look like real user data, real prices, real prompts?

Describing is disclosing. The test is whether a competent reader of the public
repo alone ends up knowing a thing the inventory says stays private — not
whether any private file is literally present.

---

## 6. Disposition — high-stakes, never auto

**No finding from this audit is ever auto-dispositioned to pass.** State the
contrast, because the nearest precedent points the other way: spine-close
disposition triage auto-applies spec-aligned recommendations and only
escalates load-bearing conflicts (close/SKILL.md §4). This step is the
deliberate opposite — every finding reaches the user, because "this
information is fine to publish" is a call only the owner can make, and it is
irreversible in exactly the way the default-private fail-safe exists for:
public → private is impossible once history is out.

At triage the user affirms or rejects each finding. A finding the user
affirms is **confirmed**, and confirmed findings **block the close**. Two
unblocks, both real work:

- **Fix before close** — untrack and rotate, rewrite the disclosing doc,
  resynthesize the fixture. Re-run the affected step afterward; a fix is
  verified by the audit that re-examines it, not by the intention.
- **Accepted-disclosure override** — the user records, in so many words, that
  this specific disclosure is accepted, with the reason. The close proceeds
  with the override named in the report.

**Where the override is recorded — delta from companion §6, recorded:** the
companion routes overrides to `project-state.json`. No state verb carries such
a record and the freeze forbids adding one, so the record lands in the
**private boundary inventory** as an "Accepted disclosures" row — release id,
finding, reason, date — and the release retrospective names it. The inventory
is already the artifact the semantic pass reads every close, which gives the
override exactly the durability the state field was for: the **next** audit
re-reads it and re-surfaces the item as a **standing warning**, never as a
fresh blocking finding, and never silently.

Standing warnings (hygiene-allowlisted files, prior accepted disclosures, a
still-missing gitleaks) are recapped at the end of every audit report. They
are the audit's memory, and pruning them is a posture-block edit made
deliberately at `start`-time ceremonies — not something an audit does to
quiet its own output.

---

## 7. The report

One block per audited repo — gate outcome (observed visibility, manifest
agreement), tracked-file hits, untracked hits split new-vs-standing, semantic
findings, degradations — each finding carrying repo, class, the path or
pattern, why it is a finding, and its remediation. Then the triage
conversation, finding by finding. Then the verdict, one of exactly three:
**clean**, **blocked** (naming each confirmed finding), or **proceeding with
overrides** (naming each override and its reason).

If any part of a finding must be written where the public can read it (a
release note, a public issue), it is described by **pattern and class only**
— the PUBLIC_BOUNDARY.md discipline applies to the audit's own output:
naming a moat item in a public artifact is itself the leak.

---

## 8. Anti-patterns

- **Trusting the manifest over observation.** A repo the manifest calls
  private and `gh` reports public gets audited as public and raises the
  mismatch as blocking (§2).
- **Reading "gitleaks not installed" as clean.** INCONCLUSIVE is a recorded
  degradation, never a silent skip (§3).
- **Iterating the allowlist instead of scanning the tree.** Scan-first is the
  only order that catches a file the allowlist has not heard of (§4).
- **Auto-dispositioning a finding.** The spine-close triage rule does not
  reach this step; every finding is the user's (§6).
- **Editing the hygiene allowlist mid-audit to reclassify a hit.** An audit
  that edits its own inputs passes itself; allowlist changes are
  posture-block edits made outside the audit (§6).
- **Treating an override as an erasure.** An accepted disclosure is a
  standing warning from the next close onward, not a removed finding (§6).
- **Naming a moat item in any public-facing record of a finding.** Patterns
  and classes only (§7).
- **Running the state writes after a halt here.** Nothing is recorded for a
  release the audit blocked (§1, release-close.md §9).
