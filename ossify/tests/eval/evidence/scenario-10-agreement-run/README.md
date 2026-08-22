# Scenario 10 — agreement-run evidence

Playbook §13.10 is the one acceptance scenario that is a **run**, not a fixture:
*two independent planners derive the same stage, increment type, D-class, Risk
tier, and mandatory controls from the same evidence.* This directory is that
run's persisted record.

It is deliberately **not** under `fixtures/`. `lib/aggregate-scores.sh` walks
`fixtures/*/` and fails on any fixture without a result JSON; an agreement run
has no per-fixture score and would break that walk. Nothing here is scored by
the gate.

| File | What it is |
|---|---|
| `scenario.md` | the exact scenario text, pasted verbatim into both planner prompts |
| `planner-prompt.md` | the prompt wrapper, byte-identical for both planners |
| `planner-a.md` | planner A's verdict, as returned |
| `planner-b.md` | planner B's verdict, as returned |
| `judge-prompt.md` | the comparison judge's prompt |
| `judge-comparison.json` | the comparison judge's output, as returned |

Each `.md` above that holds a prompt or the scenario marks its content with a
`---`: the header above it is not part of what was sent. For `scenario.md` the
text below the `---` is exactly what was sent. **The two prompt files are not
verbatim in that sense** — they carry the placeholders (`<repo-root>`,
`<scenario.md, verbatim>`, the verdict-file paths) that were substituted before
sending; each file's own header names its substitutions.

**Why the whole input is stored rather than summarised.** The scenario is not in
the fixture suite, so this directory is the only place the run's input survives.
A paraphrase would leave the next reader unable to check whether both planners
received identical evidence, or whether the judge's ambiguity findings follow
from what the planners actually wrote. The prose findings this run produced (#250,
#251, #253) are arguments about shipped skill prose, and an argument whose input
is paraphrased cannot be audited. **#254 argues about this scenario itself** —
that it under-declares three facts the compared judgments turn on — and that
finding was only reachable because the scenario is stored here rather than
summarised.

**Reproducing it.** Re-running is not re-rolling: a fresh run on this same
scenario is a second datapoint, and the outcome recorded in `../../README.md` is
explicitly n=1. Both stages are preserved, so both can be repeated: dispatch two
fresh agents on `planner-prompt.md` (substituting `<repo-root>` and the scenario
body), then one fresh agent on `judge-prompt.md` against the two new verdicts.
Do not edit the scenario or either prompt and call the result comparable — a
changed input starts a new series.

## Result

**4 of 5 agreed; `mandatory controls` diverged.** Scenario 10 names stage,
increment type, D-class, Risk tier and controls; the first four are the
playbook's independent axes, and `../../README.md` carries the table mapping
each to the ossify judgment that answers it, plus what sat below the axes:
`judge-comparison.json`'s `secondary` array holds two entries, of which **one is
an observed divergence** (rung 3) and **one is not** — the critic-veto entry
records planner A as silent, not as disagreeing, and that array field says so.
Do not read the array's length as a divergence count. That file is the narrative
account this directory backs.
