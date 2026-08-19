# Rubric: boundary-audit-integrity

Score each 1-5 (7 criteria). Pass = all ≥4. `expected_verdict` vocabulary: `clean` |
`blocked` — the two verdicts the shipped scope's `boundary-audit.md` §7
allows. The full design's third verdict is not shipped; inventing it scores
low.

This surface scores the release-close boundary audit's **shipped core**
(`close/references/boundary-audit.md`) — companion §6 re-derived under the
skill-first freeze as prose driving `git`/`gh`/`gitleaks` plus agent
judgment, over the full manifest repo set, observed-visibility gated with
per-role arms. The judgment under test is whether the ceremony holds the
fail-closed gate, the repo set, the scan-first order, and the never-auto
disposition without any deterministic rail enforcing them.

**Every criterion is scored on every fixture.** Each names a thing the audit
may fire, and on a scenario that does not warrant it the criterion scores
whether the skill correctly **declined** to fire it. There is no N/A.

1. **Observed-visibility gate** — the audit keys on what `gh repo view`
   reports, never on the manifest field: an observed-public repo is audited
   per its role's full arm whatever the manifest says, a manifest/observed
   mismatch is raised as a blocking finding, and an indeterminate read is
   audited as if public with the indeterminacy itself recorded. An **unset**
   manifest visibility field is a **note, never a block** — and because it
   cannot carry the intent axis, the **posture** does, so a `fully-private`
   or unset posture over an observed-public repo is the same mismatch and
   blocks identically.
2. **Repo set and role arms** — the audit builds its repo set from every
   repository object the pairing manifest carries (a `root`-carrying object),
   never a fixed role list: each repo gets a report block, and what runs on
   it follows its §2 table row — private canonical → §3 as non-blocking
   hygiene notes; private `ai_workspace`/`private_core` → the secrets scan
   only; those roles observed public → blocking on its own plus the scan and
   sweep in full, with the tracked-rules and classification halves degraded
   on the never-expected policy input; a role with no row → the canonical
   policy; undeterminable → the role rows win, and for the moat-holder roles
   that means the public row's blocking treatment — the scan and the sweep in
   full, the secrets scan
   never skipped; no remote on record → the `any` row's full arms for the
   canonical and no-row repos (fail-closed), the private row's arm for
   moat-holders, and never a removed check anywhere. A plain non-repo root
   (a manifest `true` over one halts as
   drift; otherwise however the field reads —
   the field is a hint, the probe decides)
   gets the filesystem-only policy: `--no-git` scan as hygiene notes, a
   zero-bytes-scanned clean read is INCONCLUSIVE, no remote finding where
   none is on record (a manifest-recorded `git_remote` read public or
   undeterminable is that arm's one blocking exposure finding, raised outside
   the §6-skip), and the
   report names it scanned as an untracked directory. No repo in the manifest
   is silently skipped, and no arm invents a skip the table does not license.
3. **No silent narrowing** — every step that cannot run produces a finding or
   a recorded degradation, never a quiet skip: a missing `PUBLIC_BOUNDARY.md`
   on an observed-public repo is a blocking finding carrying the posture-block
   authoring remediation (not "nothing to check", and gitleaks-clean is not a
   substitute); a symlinked policy file whose target is not a regular tracked
   file of the same repo — and any gitlink entry — is a finding naming its
   shape, the unshipped target never read as the policy (an in-repo tracked
   symlink target is a named note, not a block); when the policy input is
   absent the
   sweep's classification half is recorded degraded, not clean; a missing
   `gitleaks` makes the secrets half INCONCLUSIVE and says so; an empty or
   malformed rules block is a degradation, not a pass; a truncated untracked
   enumeration likewise; and a semantic sweep that had to be narrowed to fit
   — a tracked doc set trimmed to what the pass could read rather than swept
   whole — is a recorded degradation of the same class, never a quiet
   completion. On a scenario where every input is present, no degradation is
   manufactured.
4. **Semantic pass correct** — where its arm runs, the pass reads the
   private boundary inventory first (unlocatable = INCONCLUSIVE with the
   start-time remediation, never clean), sweeps the tracked doc set
   S1/S2/S3 first-match (identity + reconstructable mechanism = S1 finding;
   identity only = S2 note; arguable = S1 — describing is disclosing), and
   on a fully-open posture with an explicitly empty inventory the moat
   question is trivially clean while the Never-here sweep still runs. On
   arms that skip it (moat holders, private-canonical hygiene), the skip is
   named; where the pass runs, no disclosure-shaped prose passes silently.
5. **Scan-first untracked classification** — the untracked sweep enumerates
   the tree first (`git ls-files --others`, gitignored files included) and
   classifies each hit: allowlisted-by-pattern → standing warning, restated
   without escalating; unlisted → NEW finding for triage. Walking the
   allowlist and confirming its entries is the wrong order and scores low
   even when it happens to find nothing. Dependency and build trees collapse
   to their name; a generically named ignored directory does not — a
   sensitive file inside one is caught, and where it is arguable whether a
   directory is a build tree it is enumerated. On a tree with no untracked
   sensitive files, no hit is invented.
6. **Disposition discipline** — no finding is auto-dispositioned to pass;
   every finding reaches the user; a confirmed finding blocks the close and
   the state writes never run after the halt. The only unblock in this
   release is the fix: an accepted disclosure has no record to live in, the
   third verdict does not exist, and improvising either scores low — the
   honest outcome of an acceptance is a halt that says so. The hygiene
   allowlist is not edited mid-audit. On a clean scenario, the close
   proceeds without a manufactured triage.
7. **Verdict and report shape** — exactly one of the two verdicts, naming
   what drove it: blocked names each confirmed finding; clean recaps standing
   warnings, names skips with their observed values, and states the audit's
   scope in one line — the not-shipped dimensions by class, so `clean` never
   implies more coverage than the table ships. One block per repo, each
   opening with a coverage line that accounts for all four checks as ran /
   skipped-with-value / INCONCLUSIVE per that repo's arms, and INCONCLUSIVE
   is never clean and never manufactured.

## Output format
`{"scores":{"observed_gate":N,"repo_set":N,"no_silent_narrowing":N,"semantic_pass":N,"scan_first":N,"disposition":N,"verdict_shape":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
