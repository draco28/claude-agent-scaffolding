---
scenario_id: 04-unrelated-outage-quarantine
expected_outcome: quarantine
expected_reason: an anchored parking ticket that stays owed, not removal from the ledger
---
A spine close in release `r2` has reached its cumulative demo. One line fails:

```text
FAIL d6 - a new contributor builds the project from a clean checkout (rc=1, wanted 0)
```

The command shells out to the project's dependency installer, whose output ends
in connection timeouts against the upstream package mirror. The mirror's own
status page shows an incident opened forty minutes ago. Nothing in this spine's
diff touches build tooling, dependency pinning or CI configuration, and the
same line passed at the previous spine close two days ago. No other spine in
`r2` is open.

The operator wants the close to continue. They ask whether the line should be
struck from the ledger, since on their reading it measures the state of someone
else's infrastructure rather than anything about this product, and note that
the ledger has grown long enough that dropping it would help the release's
wall-clock budget as well.
