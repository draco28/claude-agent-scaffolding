# Memory bank harvest worked example — VS-3.2

The harvest step (SPEC §15.2) sweeps slice work-item reports + slice handoffs and surfaces promote-worthy items to the user. This walks through the harvest for VS-3.2's slice-close.

> Routing follows the cadence policy: `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**. Harvested prose goes to dev-authored files (09/10), never spec-derived ones.

## Inputs

The skill body reads:

1. All work-item reports for the slice:
   - `docs/specs/sprint-3/VS-3.2-insights-action-needed-card/work-3.2.0{1,2,3,4,5}-*/report.md`
2. All slice handoffs (per SPEC §6b.7 sweep clause):
   - `<ai-workspace>/.workspace/handoffs/vs-3.2-*.md`

For VS-3.2 the handoffs are:
- `vs-3.2-bugfix-auth-a1b2.md` (forward, from the mid-slice bug-fix detour)
- `vs-3.2-bugfix-auth-a1b2-return.md` (return)

## Step 1 — Extract candidate items

From REPORTS (section 8 "Suggestions for memory bank"):
- (work-3.2.01 report) "API routes that wrap a query function use `Depends(verify_bearer_token)` pattern; query function takes user_id as first arg." -> source: report
- (work-3.2.01 report) "mypy not currently configured; backlog item for introducing it." -> source: report
- (work-3.2.02 report) "Frontend cards take an `empty_state` prop with default rendering." -> source: report
- (work-3.2.03 report) "Dashboard grid layout uses CSS grid with named areas." -> source: report
- (work-3.2.04 report) "Chatbot intents declared in `chatbot/intents/<name>.py` auto-load via `intents/__init__.py` registration." -> source: report

From HANDOFFS (section 4 "What's NOT in memory bank yet"):
- (vs-3.2-bugfix-auth a1b2) "auth dependencies that return None mask failure as 'no data'; always raise the appropriate HTTPException." -> source: handoff
- (vs-3.2-bugfix-auth a1b2) "auth-expired vs. empty-data is a UX gap" -> source: handoff (backlog candidate)
- (vs-3.2-bugfix-auth a1b2) "auth tests must cover expired-token cases" -> source: handoff (mcrule candidate)

Total: 8 candidates (5 from reports, 3 from handoffs).

## Step 2 — Categorize by target memory-bank file

Skill body proposes targets based on item content + memory-bank file conventions:

| Item | Proposed target | Source tag |
|---|---|---|
| `Depends(verify_bearer_token)` API pattern | `09-known-issues.md` (stack/convention note) | [report] |
| mypy not configured | `09-known-issues.md` (tooling caveat) OR backlog | [report] |
| Frontend card `empty_state` prop | `09-known-issues.md` (stack convention note) | [report] |
| Dashboard CSS grid layout | `09-known-issues.md` (stack convention note) | [report] |
| Chatbot intent auto-load | `09-known-issues.md` (stack convention note) | [report] |
| auth raises, never returns None | `09-known-issues.md` (API auth caveat) | [handoff] |
| auth-expired UX gap | BACKLOG (not memory bank) | [handoff] |
| auth-test expired-token mcrule | `03-code-patterns.md` rules zone — via `authoring-machine-checkable-rules`, NOT a raw harvest append | [handoff] |

## Step 3 — Surface to user

Skill body presents each item with proposed target + source tag + editable text. Example surfacing for item 1:

```
Item 1 of 8 [report] — work-3.2.01 report §8

Text:
  "API routes that wrap a query function use `Depends(verify_bearer_token)` pattern;
   query function takes user_id (extracted from token) as first arg."

Proposed target: `.claude/memory-bank/09-known-issues.md` (stack/convention note)

Action: accept / edit / reject / defer / change-target?
```

User responds: accept.

## Step 4 — User decisions across all 8

Continuing through items:

| Item | User decision | Final target |
|---|---|---|
| `Depends(verify_bearer_token)` API pattern | accept | `09-known-issues.md` |
| mypy not configured | change-target -> BACKLOG (not memory bank) | (backlog item) |
| Frontend `empty_state` prop | defer (still divergent across VS-3.2 and VS-3.3 implementations; harmonize later) | (re-surface at sprint-3 carry-forward) |
| Dashboard CSS grid layout | reject (too implementation-detail; not a re-use pattern) | (none) |
| Chatbot intent auto-load | accept, edit (clarify wording) | `09-known-issues.md` |
| auth raises, never returns None | defer (one instance; need 3rd before promoting) | (re-surface at sprint-3 carry-forward) |
| auth-expired UX gap | accept as backlog | (backlog item) |
| auth-test expired-token mcrule | defer (low frequency) | (none yet) |

3 accepted + 1 backlog (memory bank); 1 backlog UX; 1 mcrule deferred; 1 rejected; 2 deferred to carry-forward.

## Step 5 — Apply with provenance

For accepted items, skill body appends to the target file with provenance trailer:

Example append to `.claude/memory-bank/09-known-issues.md`:

```markdown
### API auth via bearer-token dependency

API routes that wrap a query function use the `Depends(verify_bearer_token)` pattern.
The query function takes `user_id` (extracted from the validated token) as its first
positional argument. See `api/routes/insights.py` for the canonical example.

<!-- Added from VS-3.2 retrospective, 2026-05-26; source: report -->

### Chatbot intent registration

Chatbot intents are declared as modules under `chatbot/intents/<name>.py`. The
package's `__init__.py` auto-registers any module whose name doesn't start with `_`.
To add a new intent: drop a file with a top-level `handle(message)` function; no
manual wiring needed.

<!-- Added from VS-3.2 retrospective, 2026-05-26; source: report -->
```

Skill body writes the file, commits separately (per `git_policy`).

## Step 6 — Record outcomes in retrospective

The slice retrospective doc records all 8 decisions:

```markdown
## 4. Memory bank harvest

8 candidate items surfaced (5 from reports, 3 from handoffs):

| Item | Source | Decision | Target |
|---|---|---|---|
| API auth `Depends(verify_bearer_token)` | report | accepted | 09-known-issues.md |
| mypy not configured | report | backlog | (backlog item BL-127) |
| Frontend `empty_state` prop | report | deferred | sprint-3 carry-forward |
| Dashboard CSS grid layout | report | rejected | n/a |
| Chatbot intent auto-load | report | accepted (edited) | 09-known-issues.md |
| auth raises, never returns None | handoff | deferred | sprint-3 carry-forward |
| auth-expired UX gap | handoff | backlog | (backlog item BL-128) |
| auth-test expired-token mcrule | handoff | deferred | n/a (low freq) |
```

The retrospective is the authoritative log of harvest decisions. The carry-forward handoff (sprint-3 -> 4) picks up the 2 deferred items.

## Why source-tagging matters

The `[report]` vs. `[handoff]` tag in step 3 helps the user distinguish:
- **Report-origin items** were written by the implementer-agent subagent in section 8 of report.md. They reflect implementation-level pattern observations.
- **Handoff-origin items** were written by the orchestrator (or by a fork session) in section 4 of a handoff.md. They reflect orchestrator-level decisions, negative-space, or cross-cutting observations.

Distinguishing helps the user calibrate trust: a report-origin item is grounded in the just-written code; a handoff-origin item is grounded in conversational context that may or may not have made it to code.

## Cleanup after harvest

Per SPEC §14.4 ordering: harvest -> remove worktrees + delete branches. The harvest does NOT itself remove handoffs (handoffs survive until sprint-close cleanup per SPEC §6b.6). The deferred handoff items will be visible again to sprint-close cleanup; the user can re-surface them when authoring the carry-forward.
