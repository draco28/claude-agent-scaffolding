# Eval Runbook (ossify planning judges)

Executed by Claude Code in an interactive session. No API runner.

## Procedure (Claude executes)

For each `surface` in `[posture-derivation, journey-line-floor, spine-class-declaration, bone-touch-check, critic-veto-interpretation, close-gate-integrity, harvest-apply-integrity, rule-authoring-integrity, boundary-audit-integrity, handoff-compose, handoff-resume, work-pr-disposition]`:

  For each `fixture.md` in `tests/eval/fixtures/<surface>/`:

  1. **Apply the judgment.** Dispatch `Agent` (general-purpose): "Read the owning skill's SKILL.md + the relevant `references/*.md` for `<surface>` end-to-end. Apply ONLY that skill's documented decision procedure to this fixture scenario (paste body). Output the judgment the skill would produce (e.g. the derived posture+channel, the accept/reject verdict + reason, the declared class, the veto disposition, or — for `close-gate-integrity` — what the ceremony does next and what it records). Do not improvise beyond the skill body." Capture the output.

  **The `handoff-*` and `work-pr-*` surfaces have no SKILL.md** — those
  utilities are command-routed, not skill-routed. Their owning prose is
  `ossify/references/handoff/` (`compose.md` + `sections.md` for
  `handoff-compose`; `resume.md` + `sections.md` for `handoff-resume`) and
  `ossify/references/work-pr/loop.md` (for `work-pr-disposition`), plus the
  command wrappers in `ossify/commands/`; point the invoke agent there
  instead.

  **Paste the fixture BODY ONLY — strip the frontmatter.** The frontmatter is the answer key. The judge in step 2 sees the whole fixture; the invoke agent must not. And **whoever authored a surface's fixtures has read its keys and cannot serve as its invoke agent** — dispatch fresh agents for both steps.

  2. **Score.** Dispatch a fresh judge `Agent`: "You are an LLM-as-judge. Score the SKILL OUTPUT against the RUBRIC. Return one JSON object `{\"scores\":{...},\"pass\":true|false,\"notes\":\"<one sentence>\"}`. Pass = all criteria ≥4. JSON only. RUBRIC: <paste rubrics/<surface>.md>  FIXTURE: <paste fixture>  SKILL OUTPUT: <paste>." Write the JSON to `tests/eval/results/<surface>/<fixture_id>.json`.

After all surfaces: run `bash ossify/tests/eval/lib/aggregate-scores.sh` and report the summary.

## Cost

12 surfaces, 62 fixtures × 2 dispatches = 124 Agent dispatches per full run; 5-10 min. Re-run a single surface by deleting its `results/<surface>/*.json` and re-running.

`aggregate-scores.sh` walks `fixtures/` and **fails on any fixture with no result JSON**, so a partial run cannot report a clean total.
