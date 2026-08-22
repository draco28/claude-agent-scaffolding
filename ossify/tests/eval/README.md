# ossify planning-judge eval harness

LLM-as-judge harness for ossify's judgment surfaces (spec §13.4). Session-driven
(no API runner); subscription-funded via Agent dispatch. Plan B authors these
fixtures + the local gate; Plan D consolidates them into THE ship gate.

## Surfaces → owning skill

| Surface | Owning skill | The judgment |
|---|---|---|
| `posture-derivation` | `start` | derive posture + moat channel from facts + intent |
| `spike-contract-integrity` | `start` | offer a disposable feasibility spike only on genuine architectural uncertainty, with a six-field contract written before any code (one hypothesis, falsifier first, timebox, `code_fate: discard`, evidence retained, the enabling bone) |
| `risk-gate-registration` | `start` | register a risk gate for an irreversible-harm surface with controls scaled to the harm, a touch surface, the Release-0 minimum, and the downstream bone-reclassification + docs trigger |
| `journey-line-floor` | `plan-spine` | verb+observable-outcome required; inspector phrasing banned; internal spine names its consumer |
| `spine-class-declaration` | `plan-release` | bone vs flesh vs internal-enabler vs reject-as-horizontal |
| `release-ladder-labels` | `plan-release` | the release ladder is evidence-gated not counted: v2 only on a changed promise/journey/breaking contract, MVP on independent usability, no dating, sketch labels are hypotheses |
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
once. `boundary-audit-integrity` took three reactive rounds and two review rounds
before this was done properly. The derivation found ten omission-classes: judges and
reviewers had already named eight of them, and two appeared in no note at all. But
the larger gap was **extent** — a class a note flagged on one or two fixtures ran to
fifteen and sixteen once the whole surface was checked against the rubric at once. A
note names a class from the instance in front of it and cannot size it.

**Where a surface has had that pass run, the result is kept** under
`derived-inputs/<surface>.md` — check a new fixture against that list rather than
re-deriving it. `boundary-audit-integrity`, `spike-contract-integrity`, `risk-gate-registration`, `release-ladder-labels`, and `spine-class-declaration` each have one; the remaining surfaces do not yet,
and for those the pass is still owed. The lists are downstream of the rubrics and go
stale silently, so a criterion edited to read something new owes its list a row.

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
PulseHive→fully-open). Scenarios 1-9 landed as fixtures in PR F2 across
`spike-contract-integrity` (1), `spine-class-declaration` (2, 4, 6),
`close-gate-integrity` + `journey-line-floor` (3, 8, 9),
`risk-gate-registration` (5), and `release-ladder-labels` (7); scenario 10
(two independent planners agree) is a post-merge agreement run — two fresh
invoke agents on one representative **classification scenario**, a judge compares
their verdicts across the playbook's four axes plus controls (§2 + §13.10) —
recorded here as evidence, not a standing fixture. The scenario is authored for
the run and is deliberately **not** a `fixtures/<surface>/NN-*.md` file: see the
record below for why lifting one measures the wrong thing. The run's full
input and both verdicts are preserved under
`evidence/scenario-10-agreement-run/`.

### Scenario 10 — the agreement run (executed 2026-08-22, post-#235)

**Scenario 10 names five things to agree on** — stage, increment type,
D-class, Risk tier, mandatory controls — and the first four are the playbook's
four independent axes (§2). ossify does not carry the playbook's vocabulary, so
the run compares each axis at the ossify judgment that answers it. Two of the
axes are answered at different rungs of the *same* ladder, which is why they are
reported separately rather than folded into one "spine class" line:

| Playbook axis (§2) | ossify judgment that answers it | Outcome |
|---|---|---|
| Product maturity (stage) | the release ladder label | **agree** — `mvp` |
| Increment type | class ladder **rung 1**, the journey gate: enabler or user-facing spine | **agree** — journey gate passes, not an `internal-enabler` |
| Architecture delta (D-class) | class ladder **rungs 2-3**, bone-ness | **agree** — `bone`, both overruling the declared `flesh` on the same rung-2 touch-surface hit |
| Risk tier | the risk gate | **agree** — warranted, family `destructive`, surface `src/retention/**,src/storage/segment.rs`, register now, `src/cli/commands.rs` excluded as entry point not hazard |
| — (mandatory controls) | the control checklist | **diverge** — whether `progressive exposure` is owed |

**Result: 4 of 5 agreed; `mandatory controls` diverged.** That count is the
judge's own, from `evidence/scenario-10-agreement-run/judge-comparison.json` —
the judge was given the five axes and told to score increment type and D-class
separately even though one ossify ladder answers both. The planners were asked
for four judgments, and an earlier judging pass compared those four; under it
increment type was never a scored axis, so "the increment-type axis agreed"
would have been this file's reading of the planners' rung-1 text rather than a
judge verdict. The five-axis prompt is preserved because it is the one that
makes the count above a verdict.

**That one ossify judgment answers two independent playbook axes is a design
fact, not a bookkeeping choice, and it is worth its own question** — §2 says
never use one hierarchy to represent product maturity, work type, architecture
impact and risk, and `class` spans two of those four. The run cannot settle
whether that is a violation or a deliberate compression; it is filed as **#253**.

The fold did not change any axis **verdict**: both planners passed rung 1
explicitly (increment type) and both reached `bone` on the rung-2 hit (D-class).
It is not the case that they agreed at every rung — **rung 3 is where they
split**. That moved no verdict, so the count stands; but a judgment that folds
two axes into one ladder is one that can hide a rung-level disagreement, and
this run contained two.

**Two further divergences sat below the five axes, recorded because they are
findings even though neither moved a verdict.** Both are the same shape: the
class ladder does not say whether a rung that never gets reached still owes its
own obligations.

1. **Whether rung 3 runs once rung 2 has decided the class.** Both reached
   `bone` and both said an ADR is owed, so no axis moved — but under one reading
   rung 3 never runs, and the new bone the spine creates never gets its own
   declared touch surface, the anti-pattern `class-declaration.md` names as "the
   next spine's rung 2 cannot see it, and the registry silently stops working".
   Here the separately registered risk gate happens to cover the same paths, so
   the practical gap *largely* closes by accident rather than by rule — a gate
   over those paths is not the same record as the bone having its own declared
   surface.
2. **Whether the §7c critic-veto pass is still owed after a bone-touch hit.**
   `critic-veto.md` says the pass fires once per release-planning pass, but
   `class-declaration.md` introduces it only inside rung 4 — so a reader who
   short-circuits at rung 2 can read the critic step as unreached. One planner
   said it is still owed and independent; the other did not mention it. Treating
   it as unreached would drop release-level feedback, since non-class critic
   findings still have to be routed.

**The scenario was authored for this run rather than lifted from `fixtures/`.**
The five axes span three surfaces, and no single existing fixture
exercises them all without also stating its own dispositions in the body — the
leakage class tracked in #247. A body that hands the planner its answers would
have measured agreement-on-echo, so the run used an evidence-only scenario: a
release with the independence evidence stated and no label; a spine whose files
include a registered bone's touch surface and whose declared class is a claim,
plus one **new module, registered to nothing**, that is where the destructive
behaviour lands; and a behaviour whose defect character is derivable. That new
unregistered module is what puts rung 3 in play and what #251's consequence
rests on. No disposition appeared in the scenario.

**All three divergences — the compared one and the two secondary ones — were
judgment ambiguities in the shipped prose, not misreads.** The judge checked
that distinction specifically, because a misread is not a finding against the
prose.
Filed as **#250** (`risk-gates.md` §2 gives a floor of three controls and an
applicability column listing a fourth, with no rule deciding
whether an applicable control above the floor is required — and the controls CSV
is what `risk_gate_add` records and what becomes required work) and **#251**
(`class-declaration.md` §1's "an earlier rung's verdict is not revisited by a
later one" does not decide whether later rungs still *run*; only rung 1 carries
an explicit stop, and rung 3 is the sole source of the new-bone obligation, so
one reading leaves a newly created bone unregistered).

**The third has no issue of its own, deliberately.** The critic-veto placement is
the same question as #251 — when the ladder short-circuits, which of the later
rungs' obligations survive? — one rung further on, so it is recorded on #251
rather than filed separately. Answering #251 for rung 3 alone would leave rung 4
with the identical gap.

**This is one run.** Two planners agreeing on four axes is a single
datapoint about inter-planner reliability, not a measured property of the prose;
a second run on a different scenario could move any of them. The preserved input
under `evidence/scenario-10-agreement-run/` exists so a second run is possible
against the same evidence rather than a new one. What the run
establishes is narrower and does not depend on the count: three named
ambiguities, each traced to the sentence that produced it, and the one that
diverged on a compared axis carries an operative cost — the controls CSV becomes
required work.
