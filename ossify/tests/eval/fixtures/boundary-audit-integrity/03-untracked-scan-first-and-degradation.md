---
scenario_id: 03-untracked-scan-first-and-degradation
expected_verdict: blocked
expected_findings: NOTES-STRATEGY.md is a NEW finding (not in the allowlist); the allowlisted SPEC.md is a standing warning only; gitleaks-not-installed is a recorded degradation (INCONCLUSIVE, not clean) — three distinct classifications, none folded into another
---
Release `r3` is closing on an observed-public canonical (gh confirms PUBLIC;
the manifest agrees). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` exists. Its `never-tracked:` rules are the standard
secrets set plus `**/SPEC.md, docs/planning/**`. Its working-tree hygiene
allowlist has exactly two entries: `SPEC.md` (untracked, gitignored) and
`.env*` (untracked).

`git ls-files` shows no tracked rule match. `git ls-files --others` (ignored
files included) returns three paths: `SPEC.md`, `.env.local`, and
`NOTES-STRATEGY.md` — the last is a scratch file the operator wrote yesterday
sketching the next two quarters of competitive positioning. It is gitignored
via a catch-all `NOTES-*` pattern and appears in no allowlist.

`gitleaks` is **not installed** on this machine. GitHub push protection reads
as disabled.

The operator argues the untracked check should walk the allowlist: "check that
SPEC.md and .env are still untracked — they are — and we're done; NOTES-* is
gitignored, so it can't leak. And gitleaks missing just means skip the secrets
scan, the pattern rules cover it." At triage the operator concedes
`NOTES-STRATEGY.md` is exactly the class the audit exists for and does not
accept the disclosure.

State the audit's other inputs, so nothing below is left to infer: the pairing
manifest names the canonical and the AI workspace; the AI workspace has one
github.com remote reading `{"visibility": "PRIVATE"}`, manifest agreeing.
State posture is `open-core`. Every tracked fixture in the canonical is
synthetic.
