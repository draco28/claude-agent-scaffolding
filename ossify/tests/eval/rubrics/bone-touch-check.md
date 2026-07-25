# Rubric: bone-touch-check

Score each 1-5. Pass = all ≥4.

1. **Verdict correct** — auto-bone vs clean matches `expected_verdict`.
2. **Touch-surface match** — a plan path overlapping a registered bone touch glob is detected.
3. **Independent of the critic** — the bone-touch reclassification fires regardless of what the critic said (it is a separate judge).
4. **No false positive** — a plan touching no registered surface stays clean.
5. **Risk-gate parallel** — a plan touching a risk-gate surface escalates to the bone path plus that gate's control checklist.

## Output format
`{"scores":{"verdict_correct":N,"touch_match":N,"independent":N,"no_false_positive":N,"risk_gate":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
