# Rubric: spine-class-declaration

Score each 1-5. Pass = all ≥4.

1. **Class correct** — declared class equals `expected_class`.
2. **Horizontal build caught** — a spine that only builds an architectural layer with no actor-to-outcome journey is NOT accepted as a user-facing spine (it is internal-enabler at best, or rejected).
3. **Flesh-touching-bone reclassified** — a flesh claim whose scope touches a bone reclassifies to bone.
4. **No over-ceremony** — a genuine flesh spine on existing bones is not inflated to bone.
5. **Rationale cites the rule** — the decision references the governing rule (journey requirement / bone-touch / enabler consumer).

## Output format
`{"scores":{"class_correct":N,"horizontal_caught":N,"flesh_bone_reclassified":N,"no_over_ceremony":N,"rationale_cited":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
