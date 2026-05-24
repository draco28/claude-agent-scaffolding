# Eval Runbook (architect-critic)

This runbook is **executed by Claude Code in an interactive session**. There is no API-based runner. Open this repo in Claude Code, say *"run architect-critic evals"* (or paste the prompt below), and follow the procedure.

## Prompt to paste

> Run the architect-critic eval harness per `architect-critic/tests/eval/RUNBOOK.md`. For each skill (`critiquing-spec`, `reviewing-critique-history`, `listing-principles`, `promoting-principle`), iterate fixtures in `tests/eval/fixtures/<skill>/`, dispatch an `Agent` subagent to invoke the skill on each fixture, then dispatch a second `Agent` (the judge) with the rubric + fixture + output and ask it to score 1-5 on each criterion. Write per-fixture results to `tests/eval/results/<skill>/<fixture_id>.json`. When all skills processed, run `bash tests/eval/lib/aggregate-scores.sh` and report the pass/fail summary.

## Procedure (Claude executes these steps)

For each skill in `[critiquing-spec, reviewing-critique-history, listing-principles, promoting-principle]`:

  For each `fixture.md` in `tests/eval/fixtures/<skill>/`:

  1. **Invoke the skill.** Dispatch `Agent` (subagent_type=general-purpose or claude) with this prompt:
     > Read `architect-critic/skills/<skill>/SKILL.md` end-to-end. Then apply the skill to this fixture artifact (paste fixture body). Produce the skill's natural output. Do NOT improvise beyond what the skill body specifies.

     Capture the subagent's final output as `skill_output_<fixture_id>.txt` (a temp file).

  2. **Score via judge.** Dispatch a second `Agent` (fresh context) with this prompt:
     > You are an LLM-as-judge. Score the SKILL OUTPUT below against the RUBRIC. Return a single JSON object: `{"scores": {"criterion_name": N, ...}, "pass": true|false, "notes": "<one-sentence reason>"}`. Pass = all criteria ≥4. JSON only, no prose around it.
     >
     > RUBRIC: <paste rubric markdown>
     >
     > FIXTURE INPUT: <paste fixture>
     >
     > SKILL OUTPUT: <paste skill_output_<fixture_id>.txt>

     Capture the judge's JSON. Write it to `tests/eval/results/<skill>/<fixture_id>.json`.

  3. **Cleanup.** Remove the temp skill_output file. Move to next fixture.

After all fixtures processed:

  4. Run `bash architect-critic/tests/eval/lib/aggregate-scores.sh`. It reads all per-fixture JSON results and prints a pass/fail summary by skill + overall.

## Why this shape

- Claude Code subscription covers all Agent dispatches; no metered API.
- The runbook stays in markdown so the orchestration logic is auditable and adjustable without code changes.
- Bash only does what bash is good for: filesystem traversal + JSON aggregation via jq.
- Reruns are easy — delete `tests/eval/results/<skill>/` and re-run the prompt.

## Cost / time

- ~5 fixtures × 4 skills × 2 Agent dispatches = ~40 dispatches per full run.
- Wall time: 5-10 minutes in an interactive session.
- Re-running individual skills is cheap (drop ~10 dispatches).
