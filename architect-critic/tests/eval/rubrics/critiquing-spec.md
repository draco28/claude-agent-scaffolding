# Rubric: critiquing-spec

For each fixture, judge the SKILL OUTPUT against this rubric. Score each criterion 1-5. Pass = all criteria ≥4.

## Criteria

1. **Found the deliberate flaw** — Did the critic surface the issue the fixture frontmatter calls out as `expected_finding`?
   - 5: Surfaced exactly that flaw with rationale matching the expected principle.
   - 4: Surfaced the flaw but rationale partially missed the principle frame.
   - 3: Surfaced something related but missed the specific flaw.
   - 2: Surfaced unrelated issues only.
   - 1: Surfaced nothing or hallucinated.

2. **Severity label valid** — Every challenge has `severity` ∈ {premise, gap, alternative}.
   - 5: All challenges correctly labeled.
   - 1: Labels missing or invalid.

3. **CORE tone applied** — At least one challenge opens with curiosity-framing (e.g., "I might be missing something", "is there a reason", "what if").
   - 5: Most/all challenges use curiosity-framing.
   - 4: At least one does.
   - 1: All challenges are blunt/accusatory.

4. **Ghost-notes invoked** — When the fixture's expected_principle is `ghost-notes`, the critic references looking-for-absent-data (explicitly cites the principle name, or describes the heuristic).
   - 5: Explicit reference + applied to the surfaced gap.
   - 4: Applied without naming the principle.
   - 1: Did not look for absent data.

5. **No false positives on the negative-control fixture (04)** — On `04-spec-with-no-gaps.md`, the critic surfaces nothing OR only `alternative`-severity items. Premise/gap challenges on this fixture = score 1.
   - 5: Nothing surfaced, OR only alternatives.
   - 1: Spurious premise/gap challenges.

## Output format

Return one JSON object: `{"scores": {"found_flaw": N, "severity_valid": N, "core_tone": N, "ghost_notes": N, "no_false_positives": N}, "pass": true|false, "notes": "<one sentence>"}`. Pass = all criteria ≥4. JSON only, no prose around it.
