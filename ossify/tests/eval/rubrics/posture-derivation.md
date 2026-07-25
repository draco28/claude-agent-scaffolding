# Rubric: posture-derivation

Score each criterion 1-5. Pass = all ≥4.

1. **Posture correct** — the derived posture equals `expected_posture`.
   - 5: exact match. 1: wrong posture.
2. **Intent over facts** — where observable facts and intent conflict (pulse-trader reads source-available by facts but intent is fully-private), the derivation follows the stated intent signal, not the facts alone.
   - 5: intent correctly overrides facts. 1: derived from facts, ignoring intent.
3. **Channel correct** — the moat channel equals `expected_channel`, one of the companion §3.2 channels (`data-overlay` | `private-package` | `repo-private`) or `none` (the sentinel for a fully-open posture with no moat channel).
   - 5: exact. 1: wrong channel.
4. **Undecided → private** — an undecided/ambiguous posture resolves to fully-private (fail-safe), never to a public posture.
   - 5: resolves private. 1: resolves public.
5. **Moat mapped to channel** — each named moat item is correctly mapped to its channel (e.g. pulse-trader's prompt corpus → data-overlay; PulseDB's decay intelligence → private-package); a fully-open project is correctly identified as having no moat channel.
   - 5: correct mapping. 1: wrong/absent mapping.

## Output format
Return one JSON object: `{"scores":{"posture_correct":N,"intent_over_facts":N,"channel_correct":N,"undecided_private":N,"moat_mapped":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
