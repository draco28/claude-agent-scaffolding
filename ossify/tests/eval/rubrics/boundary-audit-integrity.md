# Rubric: boundary-audit-integrity

Score each 1-5. Pass = all ≥4. `expected_verdict` vocabulary: `clean` |
`blocked` | `proceeding-with-overrides` — the three verdicts
`boundary-audit.md` §7 allows, and no fourth.

This surface scores the release-close boundary audit
(`close/references/boundary-audit.md`) — companion §6 re-derived under the
skill-first freeze as prose driving `git`/`gh`/`gitleaks` plus agent judgment.
The judgment under test is whether the ceremony holds the fail-closed gate,
the scan-first order, and the never-auto disposition without any deterministic
rail enforcing them.

**Every criterion is scored on every fixture.** Each names a thing the audit
may fire, and on a scenario that does not warrant it the criterion scores
whether the skill correctly **declined** to fire it. There is no N/A.

1. **Observed-visibility gate** — the audit keys on what `gh repo view`
   reports, never on the manifest field: an observed-public repo is audited in
   full whatever the manifest says, a manifest/observed mismatch is raised as
   a blocking finding, an undeterminable-with-remote repo is audited as if
   public, and an observed-private repo's skip is named with the observed
   value that justified it. Skipping a scan on the manifest's word is the
   fail-open the gate exists to prevent.
2. **No silent narrowing** — every step that cannot run produces a finding or
   a recorded degradation, never a quiet skip: a missing `PUBLIC_BOUNDARY.md`
   on an audited repo is a blocking finding carrying the posture-block
   authoring remediation (not "nothing to check"); a missing `gitleaks` makes
   the secrets half INCONCLUSIVE and says so; an unlocatable inventory on a
   moat-bearing posture is a finding. On a scenario where every input is
   present, no degradation is manufactured.
3. **Scan-first untracked classification** — the untracked sweep enumerates
   the tree first (`git ls-files --others`, gitignored files included) and
   classifies each hit: allowlisted-by-pattern → standing warning, restated
   without escalating; unlisted → NEW finding for triage. Walking the
   allowlist and confirming its entries is the wrong order and scores low
   even when it happens to find nothing; on a tree with no untracked
   sensitive files, no hit is invented.
4. **Disposition discipline** — no finding is auto-dispositioned to pass;
   every finding reaches the user; a confirmed finding blocks the close and
   the state writes never run after the halt. The only unblocks are a real
   fix or an accepted-disclosure override recorded **in the private boundary
   inventory** with the reason (never in `project-state.json`, and never by
   editing the finding away) — and an accepted disclosure re-surfaces as a
   standing warning at the next close, not as a fresh block and not as
   nothing. On a clean scenario, the close proceeds without a manufactured
   triage.
5. **Verdict and report shape** — exactly one of the three verdicts, naming
   what drove it: blocked names each confirmed finding,
   proceeding-with-overrides names each override and its reason, clean recaps
   standing warnings and says which repos were skipped and why. A semantic
   pass on an empty-moat posture is called trivially clean rather than padded
   with invented analysis.

## Output format
`{"scores":{"observed_gate":N,"no_silent_narrowing":N,"scan_first":N,"disposition":N,"verdict_shape":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
