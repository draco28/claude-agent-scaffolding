# architect-critic eval harness

## Purpose

LLM-as-judge eval harness for the 4 architect-critic skill bodies:

- `critiquing-spec` — the `/critique` skill that runs multi-adversary challenge rounds
- `reviewing-critique-history` — the `/critique-list` skill
- `listing-principles` — the `/principles-list` skill
- `promoting-principle` — the `/promote-principle` skill

Validates skill quality on representative fixtures via dispatch-and-judge pairs. Each eval
scenario invokes the relevant skill with a controlled input, captures the output, then passes
both to an LLM-judge subagent that scores against a rubric. A failing criterion blocks promotion
to a release tag.

---

## Fixture format

Each fixture lives at `fixtures/<skill>/NN-description.md`.

YAML frontmatter is required:

```yaml
---
scenario_id: critiquing-spec/01-happy-path
expected_severity: HIGH          # expected minimum severity in output (LOW | MEDIUM | HIGH)
expected_principle: P-AUTH-01    # principle ID that must appear in critique
expected_finding: "no rate-limit on public endpoint"  # substring match in findings
---
```

The body (below the frontmatter fence) is the markdown content the skill operates on — typically
a spec excerpt, a plan section, or a principles list snapshot. Keep bodies under 800 tokens so
that a full eval run stays within context budget.

Filename numbering (`NN-`) is for deterministic ordering in shell glob expansion, not for
semantic meaning.

---

## Rubric format

Each `rubrics/<skill>.md` lists exactly 5 numbered criteria. The LLM-judge scores 1-5 on each
criterion. **Pass threshold: ≥4 on every criterion.**

Example rubric entry:

```
1. Coverage — All expected_finding substrings appear verbatim in the skill output.
2. Severity calibration — Reported severity matches or exceeds expected_severity.
3. Principle citation — expected_principle appears in the output with correct rationale.
4. No hallucination — No fictitious principle IDs or non-existent file paths cited.
5. Format compliance — Output matches the documented skill output schema (sections, headings).
```

A rubric may add a 6th criterion for skills that have a unique constraint (e.g., promoting-principle
must write to the correct target file). Document that in the rubric header.

---

## How to add fixtures

1. Copy an existing fixture from the same skill folder (or start from the template below).
2. Update `scenario_id`, `expected_severity`, `expected_principle`, and `expected_finding` in the frontmatter.
3. Replace the body with the new spec/plan excerpt the skill should operate on.
4. If the new fixture exercises a criterion not yet in the rubric, add a row to `rubrics/<skill>.md`
   and bump the rubric's version comment at the top of that file.
5. Run `bash run-evals.sh <skill>` to confirm the fixture is picked up (it will show PENDING until
   the orchestrator is wired in Phase 0.2+).

Minimal fixture template:

```markdown
---
scenario_id: <skill>/NN-short-description
expected_severity: MEDIUM
expected_principle: P-???-00
expected_finding: "paste the exact substring you expect here"
---

<!-- body: paste spec or plan excerpt here -->
```

---

## Run flow

```bash
# all skills
bash architect-critic/tests/eval/run-evals.sh all

# single skill
bash architect-critic/tests/eval/run-evals.sh critiquing-spec
```

Exit code 0 = all scenarios passed (or no fixtures present). Exit code 1 = at least one failure.

Phase 0.5 will convert this into a Claude-Code-session runbook (`RUNBOOK.md`). Until the
orchestrator is fully wired (Tasks 0.2+), every scenario prints `PENDING (orchestrator stub)`
and the script exits 0.

---

## Cost estimate

~40 LLM calls per full run:

| Factor | Count |
|--------|-------|
| Skills | 4 |
| Fixtures per skill (target) | 5 |
| LLM calls per fixture | 2 (invoke + judge) |
| **Total** | **40** |

All calls are subscription-funded via Agent subagent dispatch inside a Claude Code session.
No API keys or separate billing required.

---

## Directory layout

```
tests/eval/
├── README.md               # this file
├── run-evals.sh            # orchestrator (stub → full in Phase 0.2+)
├── fixtures/
│   ├── critiquing-spec/
│   ├── reviewing-critique-history/
│   ├── listing-principles/
│   └── promoting-principle/
└── rubrics/
```
