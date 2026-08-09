# Rubric: close-gate-integrity

Score each 1-5. Pass = all ≥4. `expected_outcome` vocabulary: `halt` |
`reclassify-to-bone` | `blocking-finding` | `quarantine` | `proceed` (nothing in
the scenario meets a halt, reclassification, blocking-finding or quarantine
condition, and the ceremony runs every core row to the end).

**Every criterion is scored on every fixture.** Four of the five below name a
thing the ceremony may fire, and on a scenario that does not warrant it the
criterion scores whether the skill correctly **declined** to fire it — the same
convention `bone-touch-check` uses when it scores `risk_gate` on its clean
fixture. There is no N/A.

1. **Halt correct** — a failure the ceremony must stop on stops it *there*: no
   later row runs, and no status or close record is written. A halt records
   nothing at all; "record it as not passed and finish the remaining rows" is a
   wrong answer, not a lenient one.
2. **No false halt** — a scenario that warrants no halt is carried forward
   through every remaining core row. Rigor that stops on anything is
   indistinguishable from indiscriminate paranoia, and this is the criterion
   that separates them.
3. **Reclassification correct** — a close-time touch hit on a spine declared
   `flesh` moves the class mid-ceremony with a recorded reason naming the
   matched entry, and every remaining row runs at the deeper class's depth. The
   check is not re-run afterwards, and the earlier core rows are not rewound. On
   a scenario with no hit, the class is left alone and nothing is recorded.
4. **Blocking finding raised** — a deferred-truth record whose deadline has
   arrived at the closing release is surfaced as a finding that stops the close,
   and only its own named resolutions clear it. Noting it, deferring it, listing
   it as still standing, or carrying it into the next release are not
   resolutions, and a renewal that does not carry a new deadline does not clear
   it either. On a scenario with nothing due, no finding is manufactured.
5. **Quarantine vs retire correct** — a line failing for a cause outside every
   open spine is parked with a ticket that stays owed and carries the release it
   was raised in; a line failing for a cause inside the closing spine is not.
   Parking is not removal: the line stays in the ledger, stays visible, and comes
   due. Removing it, or trimming the ledger to fit a time budget, is the shrug
   this criterion exists to catch.

## Output format
`{"scores":{"halt_correct":N,"no_false_halt":N,"reclassification_correct":N,"blocking_finding_raised":N,"quarantine_vs_retire_correct":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
