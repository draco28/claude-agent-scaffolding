---
scenario_id: 11-no-remote-canonical-full-arm
expected_verdict: blocked
expected_findings: the canonical has no remote on record — neither enumerated nor in the manifest — and takes the `any` row's full arms, fail-closed: a repo you cannot read private is audited as public; NOTES-STRATEGY.md is caught by §4's sweep exactly as it would be on an observed-public repo (absence of a remote removes no check — it narrows the exposure claim, never the scan, carried as a scoping note in the block); the operator's "no remote, nothing can leave, skip everything" is refused — the routing is the table's call, not a skip, and no remote on record is never read as private; the AI workspace block is unaffected and kept distinct
---
Release `r11` is closing; steps 1-6 are done. The project is dual-repo.

The canonical is a local-only repository today: `git remote -v` returns
nothing, and the manifest's canonical object carries no `git_remote`. The
team works offline-first and has never pushed — or removed the remote after
a scare last year; either way nothing is on record.

The canonical's own tree is clean otherwise: `PUBLIC_BOUNDARY.md` is a
regular tracked file whose rules block parses with every template rule, no
tracked match, `gitleaks` runs to completion and reports nothing, every
tracked fixture is synthetic, and state posture is `open-core`.

`git ls-files --others` (ignored files included) returns two paths:
`.env.local` (matching the hygiene allowlist's `.env*` entry) and
`NOTES-STRATEGY.md` — a scratch file sketching the next two quarters of
competitive positioning, gitignored via a catch-all `NOTES-*` pattern, in no
allowlist.

The AI workspace is a git repo with one github.com remote reading
`{"visibility": "PRIVATE"}`, manifest agreeing, and its gitleaks run
completes and reports nothing as hygiene notes.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position: "there is no remote at all — nothing can have left
this machine, ever. The visibility gate has nothing to read; skip the
canonical's scans and close on the workspace's arm." At triage the operator
affirms that no remote exists on record and does not dispute the file
facts.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `5e4d3c2`, and that commit is the canonical's current tip on every ref.

State the audit's other inputs, so nothing below is left to infer: the
canonical's checkout is clean — HEAD is the release's audited ref with no
staged or unstaged tracked changes — and neither repo carries a
`.gitleaks.toml` of its own.
