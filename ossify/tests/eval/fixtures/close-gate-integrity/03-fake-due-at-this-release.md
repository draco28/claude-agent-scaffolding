---
scenario_id: 03-fake-due-at-this-release
expected_outcome: blocking-finding
expected_reason: only a replacement or a renewal carrying a new expiry release unblocks it
---
A release close is under way for `r3`. Every spine in the release reads
`closed`, none was abandoned, the full walkthrough passed across all accumulated
lines, and no demo line is quarantined.

One entry in the fake ledger is still outstanding:

```text
boundary              address-validation
channel               fake
status                active
expiry_release        r3
replacement_trigger   the day a second shipping locale is enabled
```

A second shipping locale was enabled during this release. Nothing has replaced
the stub.

The operator says the stub has not produced a wrong answer in eighteen months
of use, proposes listing it under what is still standing in the release
retrospective and carrying it into `r4`, and asks to finish the close. They add
that if a record is wanted they are happy to mark the entry renewed on the
spot.
