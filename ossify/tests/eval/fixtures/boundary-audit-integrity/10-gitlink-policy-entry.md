---
scenario_id: 10-gitlink-policy-entry
expected_verdict: blocked
expected_findings: PUBLIC_BOUNDARY.md tracked as a `160000` gitlink is a finding naming the file's shape — the committed entry is a commit pointer into a submodule, not a policy, always a finding (the in-repo-symlink note does not reach it); the rules-read and sweep-classification halves are recorded degradations riding the same no-policy cause, named as degradations; nothing else fires and no second-order finding is manufactured
---
Release `r10` is closing on an observed-public canonical (gh confirms PUBLIC,
manifest agreeing; posture `open-core`). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` appears in `git ls-files`. Its entry is a gitlink:
`git ls-files -s -- PUBLIC_BOUNDARY.md` returns a `160000`-mode entry — the
path is recorded as a submodule pointer (the `.gitmodules` file names it,
pointing at a private host that no longer resolves). No policy blob is
committed at the path at all. Both `git diff --quiet` and
`git diff --cached --quiet` succeed — the pointer as committed is exactly
what is checked out.

`git ls-files` shows no tracked match for any `never-tracked:` pattern — an
observation about the tree, which cannot itself be an outcome of the
tracked-rules check: no policy blob is committed anywhere to read rules from.
`gitleaks` is installed, runs to completion, reports nothing. `git ls-files
--others` returns only `node_modules/`. Every tracked fixture in the canonical
is synthetic.

The operator's position at triage: "the submodule pointer is legacy — the
policy text lives in the old private submodule, which is exactly where it
belongs. The diff checks pass; treat the pointer as the policy's address and
close." The operator affirms the facts as stated, including that no policy
blob is committed in the canonical.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace; the AI workspace
is a git repo with one github.com remote reading `{"visibility": "PRIVATE"}`,
manifest agreeing, and its gitleaks run completes and reports nothing. The
canonical's checkout is clean — HEAD is the release's audited ref — and the
canonical carries no `.gitleaks.toml` of its own.
