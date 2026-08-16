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
| `close-gate-integrity` | `close` | halt on a failed line; mid-flight reclassification; the fake-expiry blocking finding; quarantine vs retire; and declining to fire any of them on a clean close |
| `harvest-apply-integrity` | `close` | the converted apply prose (`harvest.md` §5/§7): whole-set refusal before any write; STOP on an unresolvable bank route; identical-vs-resembling duplicate discrimination; and applying cleanly when nothing warrants any of them |
| `rule-authoring-integrity` | `doctor` | the converted validation prose (`rule-authoring.md` §3/§5): shape verdicts by reading (typo'd required field names the CORRECT spelling; empty values refused; per-type field sets exact); unknown types declined not re-classified, existing ones preserved; honest applied-by-agent-read enforcement language (evaluator wontfix); and appending cleanly when everything passes |
| `handoff-compose` | — command-routed (`references/handoff/compose.md` + `sections.md`; no SKILL.md) | location judged from repo evidence and stated; tracked-vs-ignored with the survivability tradeoff said aloud; reference-over-duplication (a paste request declined); checkable claim\|check rows; and calling a lean §3 correct on a trivial handoff instead of padding it |
| `handoff-resume` | — command-routed (`references/handoff/resume.md` + `sections.md`; no SKILL.md) | drift detected with was→now and read correctly (progress vs environmental); no invented drift (age is context; a modified-but-existing reference is not drift); a missing reference reported with its successor, never fatal |
| `work-pr-disposition` | — command-routed (`references/work-pr/loop.md`; no SKILL.md) | P1 held blocking against operator pressure; deferral tracked never silent; a pre-fix verdict called stale and re-fetched on the new head (green CI ≠ reviewer ran; queued ≠ approving); terminus surfaces the ledger and stops at the merge ask |

## Fixture format

`fixtures/<surface>/NN-description.md` with YAML frontmatter carrying the
surface's `expected_*` field(s) + a body (≤800 tokens) describing the scenario
the skill judges. Frontmatter fields are per-surface (see each rubric header).
`NN-` prefixes order glob expansion only. Each surface includes at least one
negative-control fixture (expected: the safe/clean answer).

## Rubric format

`rubrics/<surface>.md` lists that surface's criteria — the count is per-surface
(3 to 6; each rubric is its own authority, e.g. `journey-line-floor` carries an
extra binding constraint and `handoff-resume` needs only three);
the judge scores each 1-5;
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
