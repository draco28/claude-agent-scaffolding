# Derived input set — `boundary-audit-integrity`

**What this is.** The inputs `rubrics/boundary-audit-integrity.md` reads, derived from that
rubric in one pass. A fixture body on this surface must declare every class below, because
**every criterion is scored on every fixture** — including the ones it expects to decline.
An input a criterion reads but the body never states is scored against a guess.

**What this is not.** It is not a second copy of the rubric and states no rule. Each row
points at the criteria that read it; **the rubric is the authority on what those criteria
say**, and where the two disagree the rubric wins. Kept out of
`fixtures/<surface>/` because `lib/aggregate-scores.sh` globs `*.md` inside each surface
directory and treats every one it finds as a fixture owing a result JSON.

**Why it exists.** `README.md` already carries the rule — derive the input set from the
rubric in one pass, do not discover it from judge notes. The rule was written after a
partial pass and then never applied fixture-by-fixture, so the same class kept arriving a
few instances at a time: two consecutive review rounds on PR #226 were dominated by omitted
inputs, 4 findings then 4 again. The full pass (issue #229) found **55 instances across 10
classes** — the four the reviewer had reached were 4 of 55. This file is what a fixture
author checks against so that pass is not owed a third time.

**Re-derive it when the rubric changes.** A criterion edited to read something new adds a
row here; this list is downstream of the rubric and goes stale silently.

| # | Input class | Read by criteria |
|---|---|---|
| I1 | observed visibility per repo (`gh repo view`, including an indeterminate read) | 1, 2, 8 |
| I2 | manifest `visibility` field per repo — its value, or that it is unset | 1 |
| I3 | state posture, including unset and unrecognised | 1, 4 |
| I4 | the manifest's repository-object set, **and that it is exhaustive** | 2, 10 |
| I5 | root shape per object — git repo vs plain non-repo, probe against the `git_tracked` hint | 2 |
| I6 | remotes on record per repo — local enumeration **and** manifest `git_remote` — and each one's observed visibility | 2, 8 |
| I7 | `--no-git` reads: bytes scanned, and the content of every tree the read spans (tracked, untracked, gitignored) | 2, 3, 9 |
| I8 | `PUBLIC_BOUNDARY.md` presence and shape per repo — absent, `100644`, `120000` with its target, `160000` | 3, 10 |
| I9 | rules-block parse state and contents, including non-pattern directives (`fixtures-must-be:`) | 3, 10 |
| I10 | `gitleaks` availability and per-repo run outcome; `.gitleaks.toml` presence | 3 |
| I11 | whether the untracked enumeration completed untruncated | 3 |
| I12 | whether the semantic sweep had to be narrowed to fit | 3 |
| I13 | private boundary inventory — locatable; its moat rows; empty, explicitly empty, or non-empty | 4 |
| I14 | the **whole** tracked doc set's content against each moat row — not only the surfaces the scenario highlights | 4 |
| I15 | the untracked file list (`git ls-files --others`, ignored files included) | 5 |
| I16 | hygiene allowlist entries, and whether one was added in response to a finding | 5, 6 |
| I17 | the character of each untracked hit — dependency/build tree vs generic ignored directory — and its contents | 5 |
| I18 | **Accepted disclosures** section — present or absent, and each row's pinned fields | 6, 7 |
| I19 | the operator's disposition at triage — affirming or disputing the fact, **and accepting or not accepting the exposure** | 6, 7 |
| I20 | content hash and audited commit of any surface an override would have to pin | 6 |
| I21 | **History passes** row per repo — present, its recorded commit, and what the review covered | 8 |
| I22 | reachability of the audited ref from that recorded commit | 8 |
| I23 | clone completeness **per repo**, not once for the set | 8, 3 |
| I24 | audited-ref resolution — the spines' `base_branch`, manifest `default_branch`, the two `rev-parse` ids, and every other repo's checked-out branch | 9 |
| I25 | staged and unstaged tracked modifications per repo, and what each diff carries | 9 |
| I26 | `git ls-files -v` index flags per repo | 9, 10 |
| I27 | submodules tracked per repo — `.gitmodules`, gitlink entries, **and each pinned commit id** | 10 |
| I28 | submodule state — initialized or not, HEAD against the pin, its own two quiet diffs, its own index flags, its own untracked set, whether it pins submodules of its own | 10 |

## The two ways a declaration still fails

**Declared as an outcome rather than a fact.** `README.md` states the rule; the failure it
names is a body that hands over a check's answer ("swept per the semantic pass, names
nothing") instead of the content the check reads. The criterion then cannot fail. Issue
#223 tracks the instances on this surface.

**Declared for one repo and read for several.** I6, I23 and I2 are per-repo inputs that read
naturally as set-wide sentences. Four fixtures declared clone completeness for the canonical
alone while the workspace's arm read it too; a sentence pinning the manifest `git_remote`
set "beyond the remotes enumerated above" appeared in **fifteen** fixtures that never enumerated
the canonical's remotes.
