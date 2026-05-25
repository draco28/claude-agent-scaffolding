# Gaps-mode return example — work-3.2.01

Concrete shape of the implementer-agent subagent's `gaps-surfaced` return (SPEC §6.2 + §6.3). This is what the orchestrator's Task-tool call receives when pre-flight detects blocking ambiguity.

## When this fires

During pre-flight check (see `pre-flight-check-worked-example.md`). Subagent has:
- Read handoff.md + spec.md
- Verified worktree is clean
- Walked all ACs identifying ambiguity
- Found one or more BLOCKING gaps (or only nice-to-have gaps that still warrant surfacing)

Subagent EXITS without doing work. The return is the entire turn output.

## Return shape (single blocking gap)

```json
{
  "mode": "gaps-surfaced",
  "gaps": [
    {
      "section": "spec §5 AC-3",
      "question": "AC-3 says the endpoint is authenticated; unauthenticated returns 401. Which auth mechanism — session cookie (web pattern) or bearer token (API pattern)? Both exist in the codebase per memory-bank/04-tech-context.md.",
      "severity": "blocking"
    }
  ]
}
```

## Return shape (multiple gaps, mixed severity)

```json
{
  "mode": "gaps-surfaced",
  "gaps": [
    {
      "section": "spec §5 AC-3",
      "question": "Which auth mechanism — session cookie or bearer token?",
      "severity": "blocking"
    },
    {
      "section": "spec §3 Decisions",
      "question": "Spec doesn't pin the JSON response shape. Should ActionNeededRow serialize as a flat object or wrap in `{data: [...]}`?",
      "severity": "blocking"
    },
    {
      "section": "spec §6 Verification",
      "question": "Verification command list includes `mypy db/insights.py` but the repo doesn't currently have mypy configured. Should the subagent install + configure mypy, or skip the type-check verification?",
      "severity": "nice-to-have"
    }
  ]
}
```

## Severity semantics

- **blocking** — Subagent CANNOT proceed without resolution. Pre-flight failed; work cannot start. Orchestrator must surface to user before re-invoking.
- **nice-to-have** — Subagent COULD proceed by making a reasonable default choice, but the spec is unclear enough that explicit user/orchestrator input would improve the work. Orchestrator may surface OR may decide to proceed with a documented assumption.

If ALL gaps are nice-to-have, the subagent may STILL choose to proceed (gas the work) if it can articulate a reasonable default for each — but the conservative path is to surface and let orchestrator decide. v0.1 default: surface all gaps regardless of severity; orchestrator decides whether to clarify or to proceed-with-defaults.

## What the gap fields mean

- **section** — concrete locator into the spec or handoff. Forms: `spec §N`, `spec §N AC-K`, `handoff §N`, `handoff §N item Y`. Lets the orchestrator quote-correct context to the user.
- **question** — a CONCRETE question the user can answer. Not "the spec is unclear" but "which X — A or B?". Yes/no or A/B/C/other framing preferred. If a question is genuinely open-ended (e.g., "what should the empty state look like?"), include known constraints so the user can answer without re-reading the spec.
- **severity** — one of `blocking` | `nice-to-have`. No other values.

## What this is NOT

- Not a place to surface implementation difficulty ("this is hard"). Subagent does the hard work; gaps mode is for ambiguity, not for complexity.
- Not a place to surface architectural disagreement ("I'd design this differently"). The spec is locked at this point (post-audit). Use the orchestrator's normal feedback channel via report.md `notes` section, or surface to orchestrator on `mode: complete` return.
- Not a place to surface tooling problems ("worktree branch is wrong"). Those are pre-flight FAILURES (subagent crash row in §12.2 failure menu), not gaps. Subagent returns an error in that case, not gaps-surfaced.

## Orchestrator processing

Per SPEC §6.3 multi-call protocol:

1. Read all gaps in the return array.
2. Surface to user, formatted:
   ```
   The implementer-agent subagent surfaced 2 blocking gaps on
   work-3.2.01 during pre-flight (it has not started work yet):

     [spec §5 AC-3] Which auth mechanism — session cookie or bearer token?
     [spec §3 Decisions] Which response shape — flat or wrapped?

   And 1 nice-to-have gap:

     [spec §6 Verification] mypy not configured — install or skip?

   Please clarify so I can re-invoke the subagent.
   ```
3. User clarifies in conversation. Multiple gaps -> user answers each.
4. Orchestrator appends a `## Clarifications` section to handoff.md with each answer, attributed and timestamped (see Clarifications pattern in `pre-flight-check-worked-example.md`).
5. Orchestrator re-invokes Task tool with the SAME handoff path. Subagent's new pre-flight reads the Clarifications section and proceeds.

## Loop until resolved

If the re-invoked subagent surfaces NEW gaps (orchestrator's clarification raised follow-on questions), the loop repeats. Each loop appends a new `## Clarifications` block (numbered or timestamped) to keep history. No upper bound on loops in v0.1; in practice 1-2 loops resolves most cases.

If gaps repeatedly fail to resolve (3+ loops with the same gap re-surfacing), the orchestrator should treat this as a spec failure — return to spec authoring per the failure-response menu §12.2 (replan work item).

## Edge — empty gaps array

`{"mode": "gaps-surfaced", "gaps": []}` is INVALID. If pre-flight has no gaps, return `mode: complete` after doing the work — not `gaps-surfaced` with an empty array. Orchestrator treats an empty-gaps response as a subagent-malformed-return failure (§12.2 row 5).
