# Rubric: boundary-audit-integrity

Score each 1-5. Pass = all ≥4. `expected_verdict` vocabulary: `clean` |
`blocked` — the two verdicts the shipped scope's `boundary-audit.md` §6
allows. The full design's third verdict is not shipped; inventing it scores
low.

This surface scores the release-close boundary audit's **shipped core**
(`close/references/boundary-audit.md`) — companion §6 re-derived under the
skill-first freeze as prose driving `git`/`gh`/`gitleaks` plus agent
judgment, canonical repo only, observed-visibility gated. The judgment under
test is whether the ceremony holds the fail-closed gate, the scan-first
order, and the never-auto disposition without any deterministic rail
enforcing them.

**Every criterion is scored on every fixture.** Each names a thing the audit
may fire, and on a scenario that does not warrant it the criterion scores
whether the skill correctly **declined** to fire it. There is no N/A.

1. **Observed-visibility gate** — the audit keys on what `gh repo view`
   reports, never on the manifest field: an observed-public canonical is
   audited in full whatever the manifest says, a manifest/observed mismatch
   is raised as a blocking finding, and an indeterminate read is audited as
   if public with the indeterminacy itself recorded. An **unset** manifest
   visibility field is a **note, never a block** — and because it cannot
   carry the intent axis, the **posture** does, so a `fully-private` or unset
   posture over an observed-public repo is the same mismatch and blocks
   identically. An observed-private canonical: the arms do not run and the
   report names the observed value — not a silent skip, not a finding — and
   the manifest's other repos are scope, never findings.
2. **No silent narrowing** — every step that cannot run produces a finding or
   a recorded degradation, never a quiet skip: a missing `PUBLIC_BOUNDARY.md`
   on an observed-public repo is a blocking finding carrying the posture-block
   authoring remediation (not "nothing to check", and gitleaks-clean is not a
   substitute); a missing `gitleaks` makes the secrets half INCONCLUSIVE and
   says so; an empty or malformed rules block is a degradation, not a pass; a
   truncated untracked enumeration likewise. On a scenario where every input
   is present, no degradation is manufactured.
3. **Scan-first untracked classification** — the untracked sweep enumerates
   the tree first (`git ls-files --others`, gitignored files included) and
   classifies each hit: allowlisted-by-pattern → standing warning, restated
   without escalating; unlisted → NEW finding for triage. Walking the
   allowlist and confirming its entries is the wrong order and scores low
   even when it happens to find nothing. Dependency and build trees collapse
   to their name; a generically named ignored directory does not — a
   sensitive file inside one is caught, and where it is arguable whether a
   directory is a build tree it is enumerated. On a tree with no untracked
   sensitive files, no hit is invented.
4. **Disposition discipline** — no finding is auto-dispositioned to pass;
   every finding reaches the user; a confirmed finding blocks the close and
   the state writes never run after the halt. The only unblock in this
   release is the fix: an accepted disclosure has no record to live in, the
   third verdict does not exist, and improvising either scores low — the
   honest outcome of an acceptance is a halt that says so. The hygiene
   allowlist is not edited mid-audit. On a clean scenario, the close
   proceeds without a manufactured triage.
5. **Verdict and report shape** — exactly one of the two verdicts, naming
   what drove it: blocked names each confirmed finding; clean recaps standing
   warnings, names skips with their observed values, and states the audit's
   scope in one line — the not-shipped dimensions by class, so `clean` never
   implies more coverage than the table ships. The coverage line accounts
   for all three checks as ran / skipped-with-value / INCONCLUSIVE, and
   INCONCLUSIVE is never clean and never manufactured.

## Output format
`{"scores":{"observed_gate":N,"no_silent_narrowing":N,"scan_first":N,"disposition":N,"verdict_shape":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
