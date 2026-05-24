# Rubric: reviewing-critique-history

For each fixture, judge the SKILL OUTPUT against this rubric. Score each criterion 1-5. Pass = all criteria >=4.

This skill reads state.json and renders recent_runs[] as a formatted table. Default limit is 10 runs, most-recent first. An empty recent_runs array must produce a human-readable empty-state message, not a blank table.

## Criteria

1. **Table shape correct** — When recent_runs is non-empty, the skill emits a table with one data row per rendered run. No phantom rows, no merged rows.
   - 5: Exactly N rows for N rendered runs; table borders/separators consistent.
   - 4: Correct row count but minor formatting inconsistency (extra blank line, trailing space).
   - 3: Row count off by 1 due to parsing edge case.
   - 2: Multiple rows missing or duplicated.
   - 1: No table rendered when runs exist, or table completely malformed.

2. **Correct columns present** — Table includes at minimum: timestamp/completed_at, depth, adversaries_used, challenge_count. Additional columns (elapsed, cost, request_id) are acceptable; missing required columns fail this criterion.
   - 5: All required columns present and correctly populated from state.json data.
   - 4: All required columns present; one value has minor formatting difference (e.g. "claude,codex" vs ["claude","codex"]).
   - 3: One required column missing but remaining columns correct.
   - 2: Two or more required columns absent.
   - 1: No required columns, or columns present but populated with wrong data.

3. **Default limit honored and no in_flight column** — With 12 runs and no explicit --limit, exactly 10 rows render (oldest 2 omitted). No "in_flight" column or in_flight section appears in v0.2 output (in_flight field dropped from v0.2 schema rendering).
   - 5: Exactly 10 rows shown; no in_flight column or section; omitted runs are the 2 oldest.
   - 4: Limit correct; in_flight column absent; ordering off (e.g. ascending instead of descending).
   - 3: Limit off by 1 (11 or 9 rows shown).
   - 2: Limit ignored (all 12 rows shown).
   - 1: Limit criterion not applicable to this fixture (score 5 automatically for fixtures 01/02/04/05).

4. **Empty state handled** — On fixture 01 (recent_runs: []), skill outputs a human-readable empty-state message ("No critique runs yet.", "(no runs yet)", or equivalent) instead of an empty table with headers.
   - 5: Clear empty-state message; no table structure rendered.
   - 4: Empty-state message present but also renders an empty table skeleton.
   - 3: No message; just an empty table skeleton.
   - 1: Crashes or outputs nothing.
   - Note: For non-empty fixtures, auto-score 5 on this criterion.

5. **codex_timeout flagged** — On fixture 05, the run with codex_timeout: true is visually distinguished in the table (asterisk suffix, "(timeout)" label, footnote, or separate warning line). Runs with codex_timeout: false must NOT be flagged.
   - 5: Timed-out run clearly marked; clean runs unmarked.
   - 4: Timed-out run marked but marker style ambiguous (could be confused with another column).
   - 3: A note about the timeout appears somewhere in output but not inline with the run row.
   - 2: No marking of the timed-out run.
   - 1: Clean runs erroneously flagged as timed-out.
   - Note: For fixtures 01-04, auto-score 5 on this criterion.

## Output format

Return one JSON object: `{"scores": {"table_shape": N, "columns_present": N, "limit_honored": N, "empty_state": N, "timeout_flagged": N}, "pass": true|false, "notes": "<one sentence>"}`. Pass = all criteria >=4. JSON only, no prose around it.
