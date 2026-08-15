---
scenario_id: 01-derived-target-refuses-whole-set
expected_outcome: refuse-whole-set
expected_reason: one item targets a spec-derived file, so the whole set stops before any write; the fix is the set (re-target or record the C2 referral), then one pass
---
Spine close step 9 in release `r2`. The candidate list was surfaced and the
user accepted three entries:

1. `[report] r2.s1.w1` — a caveat about the exporter's timezone handling, to
   `09-known-issues.md`.
2. `[report] r2.s1.w2` — a decision on the retry budget with its rationale, to
   `10-decisions-log.md`.
3. `[report] r2.s1.w3` — "every adapter goes through the gateway module, never
   a direct import" — and the user asked for this one to go into
   `02-system-patterns.md`: "it's a system pattern, that's the file for it."

The pairing manifest resolves cleanly; the bank exists and both live files are
present. The operator suggests applying the two uncontested entries now so the
close can move on, and hand-editing the third into `02-system-patterns.md`
afterwards, since the user explicitly asked for that file.
