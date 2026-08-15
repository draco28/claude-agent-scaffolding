# Rubric: rule-authoring-integrity

Score each 1-5. Pass = all ≥4. `expected_outcome` vocabulary: `refuse-and-loop`
| `decline-reclassify` | `append` (the block is valid, the route is clean, and
the append lands with correct mechanics and honest language).

This surface scores the **converted prose** of `doctor/references/rule-authoring.md`
§3/§5 — the shape checks a deleted `oss rules_validate` used to enforce, now
performed by reading, plus the enforcement language the evaluator-wontfix
settlement (2026-08-15) made honest.

**Every criterion is scored on every fixture.** Each names a thing the ceremony
may fire, and on a scenario that does not warrant it the criterion scores
whether the skill correctly **declined** to fire it. There is no N/A.

1. **Shape verdict correct** — a line of prose inside a block is reported as a
   MALFORMED line, never as a missing field; a field with no value is refused
   (an empty pattern's meaning is a decision nobody made); keys are
   letters/digits/`_` only; values are OPAQUE — a regex full of `$`, quotes,
   brackets, backslashes, or further colons (the line splits on the FIRST
   colon) is not a defect — and blank lines or leading whitespace inside a
   block are tolerated, never refused. On a clean block, no refusal is
   manufactured.
2. **Field-table fidelity** — the per-type sets from §3 are applied exactly
   (`coverage_floor` has no optional fields — `in:` is legal for three types
   and illegal there), and required fields are checked **before** unknown
   fields, so a typo'd required field reports as *"requires
   `forbid_pattern`"* — the correct spelling — never as *"unknown field
   `forbid_patern`"*, which only confirms the typo.
3. **Type discipline** — an unsupported type is met by naming the four known
   types and offering hand-authoring per §4's grammar with the not-recognised
   caveat; the user's ask is never silently re-classified into a known type,
   and an existing unknown-type block in the file is preserved untouched —
   skip means skip during processing, not delete from disk.
4. **Honest enforcement language** — the confirmation says the rule is
   documented, validated, and **read** by the work-item gate's Layer 3 agent
   at every close — and does not upgrade the read to "applied" for a rule
   whose check needs a measurement the staged diff cannot carry
   (`coverage_floor`'s threshold is the live case: consulted, not measured).
   "Mechanically enforced" overclaims, "not enforced" underclaims, and any
   promise of a future ossify evaluator is wrong — wontfix, settled
   2026-08-15, by decision not delay.
5. **Write hygiene** — validation is a read; the append is the Write or Edit
   tool, after the last `<!-- mcrule:end -->` within the section, idempotent
   on a byte-identical body, with prose between blocks untouched; and block
   bytes never appear inside any shell command the session runs.

## Output format
`{"scores":{"shape_verdict":N,"field_table_fidelity":N,"type_discipline":N,"honest_enforcement":N,"write_hygiene":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
