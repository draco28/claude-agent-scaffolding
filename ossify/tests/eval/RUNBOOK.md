# Eval Runbook (ossify planning judges)

Executed by Claude Code in an interactive session. No API runner.

## Procedure (Claude executes)

For each `surface` in `[posture-derivation, journey-line-floor, spine-class-declaration, bone-touch-check, critic-veto-interpretation]`:

  For each `fixture.md` in `tests/eval/fixtures/<surface>/`:

  1. **Apply the judgment.** Dispatch `Agent` (general-purpose): "Read the owning skill's SKILL.md + the relevant `references/*.md` for `<surface>` end-to-end. Apply ONLY that skill's documented decision procedure to this fixture scenario (paste body). Output the judgment the skill would produce (e.g. the derived posture+channel, the accept/reject verdict + reason, the declared class, or the veto disposition). Do not improvise beyond the skill body." Capture the output.

  2. **Score.** Dispatch a fresh judge `Agent`: "You are an LLM-as-judge. Score the SKILL OUTPUT against the RUBRIC. Return one JSON object `{\"scores\":{...},\"pass\":true|false,\"notes\":\"<one sentence>\"}`. Pass = all criteria ≥4. JSON only. RUBRIC: <paste rubrics/<surface>.md>  FIXTURE: <paste fixture>  SKILL OUTPUT: <paste>." Write the JSON to `tests/eval/results/<surface>/<fixture_id>.json`.

After all surfaces: run `bash ossify/tests/eval/lib/aggregate-scores.sh` and report the summary.

## Cost

~5 surfaces × ~4 fixtures × 2 dispatches ≈ 40 Agent dispatches per full run; 5-10 min. Re-run a single surface by deleting its `results/<surface>/` and re-running.
