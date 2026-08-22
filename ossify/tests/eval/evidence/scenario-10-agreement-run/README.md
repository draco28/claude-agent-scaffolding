# Scenario 10 — agreement-run evidence

Playbook §13.10 is the one acceptance scenario that is a **run**, not a fixture:
*two independent planners derive the same stage, increment type, D-class, Risk
tier, and mandatory controls from the same evidence.* This directory is that
run's persisted record.

**Two runs share this directory.** The scenario and both prompts are the run's
*input* and are byte-identical across runs; only the verdicts and the judge
output differ, so they carry a `-run2` suffix. Run 2 was executed against the
prose as fixed by PR #256, which closed the two ambiguities run 1 exposed.

It is deliberately **not** under `fixtures/`. `lib/aggregate-scores.sh` walks
`fixtures/*/` and fails on any fixture without a result JSON; an agreement run
has no per-fixture score and would break that walk. Nothing here is scored by
the gate.

| File | What it is |
|---|---|
| `scenario.md` | the exact scenario text, pasted verbatim into both planner prompts |
| `planner-prompt.md` | the prompt wrapper, byte-identical for both planners |
| `planner-a.md` · `planner-b.md` | run 1's verdicts, as returned |
| `judge-prompt.md` | the comparison judge's prompt |
| `judge-comparison.json` | run 1's judge output, as returned |
| `planner-a-run2.md` · `planner-b-run2.md` | run 2's verdicts, as returned |
| `judge-comparison-run2.json` | run 2's judge output, as returned |

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
scenario is another datapoint in the same series. Both stages are preserved, so
both can be repeated: dispatch two fresh agents on `planner-prompt.md`
(substituting `<repo-root>` and the scenario body), then one fresh agent on
`judge-prompt.md` against the two new verdicts. Do not edit the scenario or
either prompt and call the result comparable — a changed input starts a new
series. Run 2 followed exactly this procedure, with both substitutions repeated
and nothing else changed.

## Results

| Run | Prose read | Agreement | Divergences | Secondary |
|---|---|---|---|---|
| 1 | before PR #256 | **4 of 5** | 1 (`mandatory controls`) | 2 |
| 2 | after PR #256 | **5 of 5** | **0** | 1 |

### Run 2 — 5 of 5, no divergence

Both planners returned the same four mandatory controls — paper/sandbox env,
human confirm naming the concrete effect, audit trail, progressive exposure —
and both excluded the kill switch on the same reading of the `Applies when`
column, citing §6's own example. That is the axis run 1 diverged on, and the
judge attributes the agreement to the same governing sentence in both verdicts.

Run 1's first secondary is also closed: both planners ran rung 3 after the rung-2
hit and both derived the new-bone ADR obligation, where run 1's planner A had
stopped the ladder at rung 2.

**Run 1's second secondary recurred unchanged.** Both runs split on whether the
§7c critic pass is already discharged when the scenario simply does not mention
it — run 1 read it as a placement ambiguity, run 2 as missing vocabulary for
"the pass has not been run yet". Two independent sightings of one prose gap,
which is why it is now filed rather than left as a note. It moves none of the
five judgments in either run.

**What run 2 does not establish.** It is one more run on the *same* scenario, so
the series is n=2, not a measured property of the prose across scenarios. #254
still stands: the scenario under-declares three facts the compared judgments turn
on, and that confound applies to both runs equally.

### Run 1 — 4 of 5, `mandatory controls` diverged

**4 of 5 agreed; `mandatory controls` diverged.** Scenario 10 names stage,
increment type, D-class, Risk tier and controls; the first four are the
playbook's independent axes, and `../../README.md` carries the table mapping
each to the ossify judgment that answers it, plus what sat below the axes:
`judge-comparison.json`'s `secondary` array holds two entries, of which **one is
an observed divergence** (rung 3) and **one is not** — the critic-veto entry
records planner A as silent, not as disagreeing, and that array field says so.
Do not read the array's length as a divergence count. That file is the narrative
account this directory backs.
