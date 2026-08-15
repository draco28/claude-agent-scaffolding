---
scenario_id: 03-resembling-entry-still-writes
expected_outcome: append
expected_reason: resemblance is not identity — only the identical entry under a trailer is a duplicate; the new lesson is appended with its own trailer
---
Spine close step 9 in release `r4`. A single accepted entry remains to apply,
report-origin, targeted at `09-known-issues.md`:

> BSD `tar`'s `--exclude` matches against the full path, not the basename, so
> the exporter's ignore list ships the test fixtures on macOS. Anchor the
> patterns explicitly.

Reading `09-known-issues.md` before appending turns up an entry harvested two
spines ago, under its own trailer:

> GNU tar and BSD tar disagree about `--exclude` anchoring; archives built on
> one must be verified on the other.

Same neighbourhood, different words, different source id, and the new entry
carries a concrete mechanism and remedy the old one lacks. The session notes
the overlap and considers marking the new entry as skipped — "already covered
by the tar anchoring caveat" — to keep the file from accumulating near-
duplicates.
