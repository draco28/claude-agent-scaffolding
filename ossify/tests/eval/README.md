# ossify planning-judge eval harness

LLM-as-judge harness for ossify's judgment surfaces (spec §13.4). Session-driven
(no API runner); subscription-funded via Agent dispatch. Plan B authors these
fixtures + the local gate; Plan D consolidates them into THE ship gate.

## Surfaces → owning skill

| Surface | Owning skill | The judgment |
|---|---|---|
| `posture-derivation` | `start` | derive posture + moat channel from facts + intent |
| `journey-line-floor` | `plan-spine` | verb+observable-outcome required; inspector phrasing banned; internal spine names its consumer |
| `spine-class-declaration` | `plan-release` | bone vs flesh vs internal-enabler vs reject-as-horizontal |
| `bone-touch-check` | `plan-release` | a plan touching a registered touch surface auto-reclassifies to bone |
| `critic-veto-interpretation` | `plan-release` | veto→auto-bone; user override recorded; ambiguous/contradictory/stale→ESCALATE (fail-closed) |

## Fixture format

`fixtures/<surface>/NN-description.md` with YAML frontmatter carrying the
surface's `expected_*` field(s) + a body (≤800 tokens) describing the scenario
the skill judges. Frontmatter fields are per-surface (see each rubric header).
`NN-` prefixes order glob expansion only. Each surface includes at least one
negative-control fixture (expected: the safe/clean answer).

## Rubric format

`rubrics/<surface>.md` lists exactly 5 criteria; the judge scores each 1-5;
**pass = ≥4 on every criterion**; the rubric's last line pins the JSON output
contract. `lib/aggregate-scores.sh` reads only `.pass`/`.notes`, so it is
surface-agnostic.

## Run

Session-driven — see `RUNBOOK.md`. Then `bash lib/aggregate-scores.sh`
(exit 0 = all pass, 1 = any fail — the local gate).

## Seed provenance (spec §13.4)

Fixtures seed from the evolutionary-architecture playbook's 10 acceptance
scenarios + the 3 named historical failure modes (a horizontal build dressed as
a spine; an inspector-phrased journey line; a flesh claim touching a bone) + the
3 recorded target postures (pulse-trader→fully-private, PulseDB→open-core,
PulseHive→fully-open). Plan D expands to full 10-scenario coverage.
