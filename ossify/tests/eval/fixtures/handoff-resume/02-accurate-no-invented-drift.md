---
scenario_id: 02-accurate-no-invented-drift
expected_verdict: proceed
expected_drifts: none
expected_reason: every claim holds exactly, so the read-out reports clean and proceeds to step 1; the document's 5-day age is surfaced as context for §3, not converted into drift, and the modified-but-existing reference is not drift either — references are verified for existence, not contents
---
Resume from `docs/handoffs/2026-08-11-schema-versioning.md`, written 5 days
ago. Its State section claims, each with a check command: branch
`schema-v2` 8 commits ahead of `main`, 0 behind; HEAD at `f00dcafe`; migration
dry-run green against the staging snapshot; issue #120 open with the rollout
checklist. Its §4 cites `docs/design/versioning.md` ("the compatibility
matrix") and `migrations/0042_add_version_column.sql`. Its Next-actions
sequence: (1) implement the read-path fallback per the compatibility matrix,
(2) run the dry-run against production-sized data, (3) open the rollout PR.

Running the checks today: branch `schema-v2` is exactly 8 ahead, 0 behind;
HEAD is `f00dcafe`; the dry-run passes against the staging snapshot; issue
#120 is open. Both cited files exist — `docs/design/versioning.md` was
modified 2 days ago (a wording fix landed from another branch, the file is
present and readable).

Produce the resume read-out: which claims hold, which drifted, the state of
the cited references, whether step 1 still applies, and the verdict.
