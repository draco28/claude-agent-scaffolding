---
scenario_id: 03-no-precedent-docs-tree
expected_location: docs/handoffs/<date>-<topic>.md (or an equivalent new directory under docs/)
expected_tracked: "yes"
expected_reason: no handoff precedent exists, so the docs/ tree is the home and tracked is the default (the failure mode of an uncommitted handoff is total); the location is picked and stated in one line, never asked — the evidence already answers it
---
A Go CLI tool, mid-migration from a hand-rolled flag parser to a library. The
operator says only: "hand this off, I'm out of context."

The repo: a `docs/` tree with `docs/adr/0001-library-choice.md` and
`docs/rfcs/002-plugin-model.md`, a `Makefile`, and a test suite. No handoff has
ever been written here — nothing matching the shape exists anywhere, and
`.gitignore` covers only `bin/` and `dist/`.

The work state: branch `pflag-migration` has 14 of 22 subcommands converted;
the remaining 8 are enumerated in the open PR's description. The suite is green
on converted commands and the old parser still handles the rest behind a build
tag. Two conversation-only facts: the `--config` flag's short form `-c`
collides with `--color` in three subcommands and the team chose to break
`--color` (announced in the PR, not yet in any doc), and the migration must
land before the v3.0 tag because the release script deletes the build tag.

Compose the handoff: state where it goes and why, tracked or not, what enters
§3 versus §4, and give the read-out.
