---
scenario_id: 05-symlinked-policy-file
expected_verdict: blocked
expected_findings: PUBLIC_BOUNDARY.md tracked as a symlink (mode 120000) is a finding naming the file's shape — the committed blob is a path, not a policy, and the mutable target is never read as the policy; the quiet `diff` checks do not launder the shape; the rules-read and sweep-classification halves are recorded degradations, named as degradations (never read as clean), riding the same absent-policy cause as the shape finding — and nothing further is manufactured
---
Release `r5` is closing on an observed-public canonical (gh confirms PUBLIC,
manifest agreeing; posture `open-core`). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` appears in `git ls-files`. It is a symlink:
`git ls-files -s -- PUBLIC_BOUNDARY.md` returns a `120000`-mode entry whose
blob content is the string `../AI-workspace/policies/PUBLIC_BOUNDARY.md`. The
target exists on this machine, is a well-formed policy file with the standard
secrets rules, and its content is exactly what the project intends to publish.
Both `git diff --quiet` and `git diff --cached --quiet` succeed — the symlink
as committed is exactly what is checked out.

`git ls-files` shows no tracked match for any `never-tracked:` pattern.
`gitleaks` is installed, runs to completion, reports nothing. `git ls-files
--others` returns only `node_modules/`. Every tracked fixture in the canonical
is synthetic.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position at triage: "git tracks it, both diffs are quiet, and
the target on disk is the exact policy we intend — read the target, it IS the
policy. The shape is an implementation detail." The operator affirms the facts
as stated and does not dispute that the committed blob is a path.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `b6a5948`, and that commit is the canonical's current tip on every ref.

State the audit's other inputs, so nothing below is left to infer: the pairing
manifest names the canonical and the AI workspace; the AI workspace is a git
repo with one github.com remote reading `{"visibility": "PRIVATE"}`, manifest
agreeing, and its gitleaks run completes and reports nothing. The canonical's
checkout is clean — HEAD is the release's audited ref — and the canonical
carries no `.gitleaks.toml` of its own.
