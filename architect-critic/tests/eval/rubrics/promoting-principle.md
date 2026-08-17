# Rubric: promoting-principle

For each fixture, judge the SKILL OUTPUT against this rubric. Score each criterion 1-5. Pass = all criteria >=4.

This skill appends a principle to the user-global or project-scoped principles file, validates uniqueness against active (non-commented) principles, tags the entry with source and timestamp, and records the promotion in state.json. The challenge link the v0.2 design sketched is not shipped: a promotion made during an active critiquing-spec run records no `linked_challenge` and the skill must not claim state-side linking.

## Criteria

1. **Principle appended to correct file (scope honored)** — Without --scope project, the principle goes to the user-global principles.md only. With --scope project, it goes to .claude/architect-critic/principles.md only; user-global is untouched. If the target file does not exist, it is created.
   - 5: Principle written to the correct file; other file unmodified; file created if absent.
   - 4: Correct file written but minor path difference (e.g., absolute vs relative reference in confirmation message).
   - 3: Principle written to correct file but also written to the other file (both files modified).
   - 2: Principle written to the wrong file (user-global when project was requested, or vice versa).
   - 1: Principle not written to any file (failed silently or errored before write).
   - Note: For fixture 05 (empty text), the skill must NOT write to any file — score 5 if nothing is written.

2. **Source tag and timestamp added** — The appended line includes a `[promoted YYYY-MM-DD source:manual]` annotation (or equivalent structured tag). The date must be parseable as an ISO-8601 date. Annotation must appear on the same line as the principle text.
   - 5: Annotation present on the same line; date is ISO-8601; source value is "manual".
   - 4: Annotation present; date correct; "source:" label uses different casing (e.g., "Source:manual").
   - 3: Annotation present but date is missing or malformed.
   - 2: Annotation absent; principle appended as bare text with no metadata.
   - 1: Principle not written, or annotation on a separate line breaking the one-principle-per-line contract.
   - Note: For fixture 05 (empty text), auto-score 5 on this criterion (nothing written = annotation not applicable).

3. **Duplicate validation triggered** — On fixture 02, when the promoted text overlaps with an active shipped-default ("Look for what is absent" vs "Look for what is absent, not just what is present"), the skill must reject the promotion with an error message citing the conflicting existing principle. Nothing must be written.
   - 5: Promotion rejected; error message cites the conflicting principle text; no write occurs.
   - 4: Promotion rejected with generic "duplicate detected" message (does not cite specific conflict).
   - 3: Promotion rejected but error message is confusing or absent from stdout.
   - 2: Promotion accepted despite duplicate — principle appended alongside the existing one.
   - 1: Crash or silent failure with no output.
   - Note: For fixtures 01/03/04/05, auto-score 5 on this criterion (no duplicate present or test is for a different failure mode).

4. **No fabricated challenge link** — The shipped machinery has no challenge link: nothing sets a challenge-fingerprint env var, no lib code reads a `linked_challenge` field, and `arc state_append_promotion` writes only `{timestamp, source, text, scope}`. On fixture 04 (invoked during an active run), the correct behavior is a normal promotion whose state record carries NO `linked_challenge`, with the originating challenge named as prose at most.
   - 5: No `linked_challenge` in the state record; promotion recorded correctly; any challenge provenance is prose in the confirmation, not a claimed state field.
   - 4: No `linked_challenge` in the state record; confirmation wording ambiguously implies state-side linking.
   - 3: `linked_challenge` absent and the promotion record itself missing or malformed.
   - 2: Output claims or hand-rolls a state-side challenge link the shipped machinery cannot produce.
   - 1: Promotion not recorded in state.json at all.
   - Note: For fixtures 01/02/03/05, auto-score 5 on this criterion (no active run context).

5. **Empty-text validation rejects and writes nothing** — On fixture 05, the skill must reject the empty-string invocation before any file I/O, emit a clear error message ("principle text required" or similar), and leave both principles.md and state.json unmodified.
   - 5: Clear error message emitted; no file writes; exit non-zero.
   - 4: Error message emitted; no file writes; exit code not checked or zero.
   - 3: Error message emitted but a blank line or annotation-only line was appended to principles.md.
   - 2: No error message; empty principle silently appended.
   - 1: Crash with no output, or state.json corruption.
   - Note: For fixtures 01-04, auto-score 5 on this criterion (non-empty text provided).

## Output format

Return one JSON object: `{"scores": {"correct_file": N, "source_tag_timestamp": N, "duplicate_validation": N, "link_to_challenge": N, "empty_text_rejected": N}, "pass": true|false, "notes": "<one sentence>"}`. Pass = all criteria >=4. JSON only, no prose around it.
