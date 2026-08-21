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
| `boundary-audit-integrity` | `close` | the release-close boundary audit's shipped core (`boundary-audit.md`): the observed-visibility gate held against the manifest's word with the posture as the intent axis; the repo set and per-role arms (every manifest repo object gets its row, the filesystem-only policy for plain non-repos, the exposed-workspace arm, the recorded-remote exposure); no silent narrowing (missing artifact / missing tool / wrong policy shape / unlocatable inventory = finding or degradation, never skip); scan-first untracked classification with the ignored-directory judgment; the semantic pass over tracked prose (S1/S2/S3 against the private boundary inventory; arguable → S1; the fully-open sweep still runs); never-auto disposition with two unblocks — the fix, or an accepted-disclosure override written to the inventory with its surface pinned, re-surfacing at every later close and never laundering a grown surface; the third verdict that keeps an overridden close out of `clean`; the recorded history pass that closes the document rules' history corpus (owed off the exposure rather than the arm, expiring when the audited ref is no longer reachable from the recorded commit, with the refs that comparison does not cover named as their own not-shipped dimension rather than as a passing check's footnote) and the working-tree pass the release-tree gate reads before it halts; the submodule descent that rides the arm (each pinned tree read by the arm's tracked-content checks under the superproject's policy and matched under both anchorings, §4 descending over the submodule's working tree while the corpus passes do not, an unaudited pin leaving the checks that could not read it INCONCLUSIVE rather than clean, and no new coverage entry); and calling a clean close clean within the stated not-shipped scope |
| `rule-authoring-integrity` | `doctor` | the converted validation prose (`rule-authoring.md` §3/§5): shape verdicts by reading (typo'd required field names the CORRECT spelling; empty values refused; per-type field sets exact); unknown types declined not re-classified, existing ones preserved; honest applied-by-agent-read enforcement language (evaluator wontfix); and appending cleanly when everything passes |
| `handoff-compose` | — command-routed (`references/handoff/compose.md` + `sections.md`; no SKILL.md) | location judged from repo evidence and stated; tracked-vs-ignored with the survivability tradeoff said aloud; reference-over-duplication (a paste request declined); checkable claim\|check rows; and calling a lean §3 correct on a trivial handoff instead of padding it |
| `handoff-resume` | — command-routed (`references/handoff/resume.md` + `sections.md`; no SKILL.md) | drift detected with was→now and read correctly (progress vs environmental); no invented drift (age is context; a modified-but-existing reference is not drift); a missing reference reported with its successor, never fatal |
| `work-pr-disposition` | — command-routed (`references/work-pr/loop.md`; no SKILL.md) | P1 held blocking against operator pressure; every finding dispositioned (fixed / tracked deferral / evidence-shaped `invalid`), never silently; a pre-fix verdict called stale and re-fetched on the new head (green CI ≠ reviewer ran; queued ≠ approving); terminus surfaces the ledger and stops at the merge ask |

## Fixture format

`fixtures/<surface>/NN-description.md` with YAML frontmatter carrying the
surface's `expected_*` field(s) + a body describing the scenario the skill
judges. **Keep the body as short as full input declaration allows, and no
shorter** — the rule below governs its length, not a figure written here. (A
`≤800 tokens` cap used to stand at this spot; `boundary-audit-integrity`'s
fixtures had already outgrown it before the rule below was written down, which
is the drift a number mirrored into prose always takes. If a body runs long
enough to feel wrong, the scenario is carrying too many moving parts — split it;
do not answer by declaring less.) Frontmatter fields are per-surface (see each rubric header).
`NN-` prefixes order glob expansion only. Each surface includes at least one
negative-control fixture (expected: the safe/clean answer).

**A fixture body must declare every input its rubric scores, and the rubric is
the authority on which those are** — read it before authoring, and read it again
whenever it gains a clause, because a clause added there turns something into a
scored input across the whole surface at once. An input the body leaves unstated
does not make the fixture lenient; it makes the criterion measure the invoke
agent's guess, and the two defensible guesses — manufacture the
degradation the prose owes for a check that could not read what it needed, or
quietly assume the benign value — are indistinguishable in the score.
Measured twice on `boundary-audit-integrity`: an undeclared AI-workspace tree
state cost three criteria a point on one fixture (#220), and an undeclared
audited-ref source sat silently in fourteen of twenty-two until a judge named it.

**State inputs as facts about the scenario, never as a check's outcome.** "HEAD
is the release's audited ref" is §9's gate's conclusion wearing an input's
clothes — it hands over the answer and stops measuring the resolution. State
what the recorded base branch says, what the manifest says, and what the two
`rev-parse` calls print, and let the audit do the comparing.

**Derive the input set from the rubric in one pass; do not discover it from
judge notes.** Judges surface these one at a time, and patching one fixture per
note does not converge — the rubric is finite, so read all of its criteria, list
every input each one reads, and check the whole surface against that list at
once. `boundary-audit-integrity` took three reactive rounds before this was done
properly; the derived list came to twenty input classes, and the last two of
them appeared in no judge note at all.

## Rubric format

`rubrics/<surface>.md` lists that surface's criteria — the count is per-surface
and **each rubric is its own authority**; this file states no count and no
range, because one mirrored here drifts from the rubric that owns it, and the
parenthetical that used to stand at this spot had drifted;
the judge scores each 1-5;
**pass = ≥4 on every criterion**; the rubric's last line pins the JSON output
contract — **including the `notes` contract, which is per-surface and is
mirrored nowhere else**, so the dispatch prompt points at that line rather than
restating it. `boundary-audit-integrity` requires a note that names the CAUSE of
any criterion scored below 5 and states no length: a one-sentence cap stood
there while all 22 of its results exceeded it, and a note that names a cause is
what makes a fixture defect findable at all. The surfaces whose results do hold
to one sentence keep it. `lib/aggregate-scores.sh` reads only `.pass`/`.notes`
and validates neither, so it is surface-agnostic and the rubric line is the
whole contract — deliberately, because whether a cause was named is a judgment,
not a shape.

## Run

Session-driven — see `RUNBOOK.md`. Then `bash lib/aggregate-scores.sh`
(exit 0 = all pass, 1 = any fail — the local gate).

## Seed provenance (spec §13.4)

Fixtures seed from the evolutionary-architecture playbook's 10 acceptance
scenarios + the 3 named historical failure modes (a horizontal build dressed as
a spine; an inspector-phrased journey line; a flesh claim touching a bone) + the
3 recorded target postures (pulse-trader→fully-private, PulseDB→open-core,
PulseHive→fully-open). Plan D expands to full 10-scenario coverage.
