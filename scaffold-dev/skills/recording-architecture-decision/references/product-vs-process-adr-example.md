# Product ADR vs. process ADR — routing worked example

The `recording-architecture-decision` skill is manifest-routed (SPEC §7.1): product ADRs go to canonical; process ADRs stay in the AI workspace. This walks through the distinction and the routing logic.

## The two categories

- **Product ADR** — a decision about the product itself: API design, data model, technology stack, deployment topology, security posture. Future product developers (and other AI sessions reading canonical) need this context. Belongs in canonical's `docs/adr/`.

- **Process ADR** — a decision about how the project is BUILT: orchestrator-vs-subagent boundary, slice decomposition policy, retrospective cadence, AI-workspace tooling choices. Future AI sessions onboarding to the workspace need this; product developers don't. Belongs in AI workspace's `docs/adr/`.

The distinction is who needs the artifact, NOT topic-area.

## Examples

### Clear product ADR

> "We chose PostgreSQL over MongoDB for the insights store because we need JSON columns AND relational joins; PostgreSQL JSONB is the best fit for both."

Audience: future devs maintaining the DB layer. Lives forever in the codebase's history. **Canonical.**

### Clear process ADR

> "We use the strict-layer DAG for round identification within a slice (not loose-layer or topological-only) because strict-layer enforces minimum coupling between rounds and surfaces parallelism opportunities deterministically."

Audience: future AI sessions running scaffold-dev workflows. Not visible to product code. **AI workspace.**

### Ambiguous — example 1

> "We invoke architect-critic in-conversation rather than via inbox/outbox file IPC."

This is a SCAFFOLD-DEV decision. Most product devs will never know architect-critic exists. **Process. AI workspace.**

### Ambiguous — example 2

> "Auth dependencies must raise HTTPException, never return None on credential failure."

This is a PRODUCT decision: it's about how `api/auth.py` (canonical code) behaves. Even though it was surfaced via the AI-workflow handoff process, the decision is about the product's auth contract. **Product. Canonical.**

The shortcut: if the decision RECORDS a constraint that the running system enforces, it's product. If it records a constraint on how the team (or the AI agent fleet) operates, it's process.

## Skill flow

User invokes:

```
"Record an ADR for the auth-raises-never-returns-None decision"
```

Skill body:

1. **Read manifest** via `mi_manifest_resolve`. Manifest has `canonical.adr_dir` (e.g., `docs/adr/`) and `ai_workspace.adr_dir` (e.g., `docs/adr/`).

2. **Surface a category prompt to user:**
   ```
   Is this a product ADR (lives in canonical; future devs need it) or a process ADR
   (lives in AI workspace; future AI sessions need it)?
   
   Hint: this decision constrains api/auth.py behavior, which suggests PRODUCT. But
   you make the call. Reply 'product' or 'process'.
   ```

3. **User chooses.** Suppose user says "product."

4. **Number ADR.** Skill body scans the target dir for the next free `NNNN-` prefix:
   ```bash
   ls <canonical>/docs/adr/NNNN-*.md | tail -1
   # -> 0007-postgres-insights-store.md
   # next: 0008
   ```

5. **Prompt for slug and title.** Default slug derived from the decision summary:
   ```
   Proposed: 0008-auth-dependencies-must-raise.md
   Accept / edit?
   ```

6. **Author file using MADR-lite template** (see `templates/adr.md.tmpl`). Skill body fills in:
   - Status: Accepted (or Proposed; user chooses)
   - Date: today
   - Context: from user description
   - Decision: the decision statement
   - Consequences: positive + negative + neutral

7. **Write to target dir.** For product -> `<canonical>/docs/adr/0008-auth-dependencies-must-raise.md`. For process -> `<ai-workspace>/docs/adr/0008-strict-layer-dag-rationale.md`.

8. **Commit per git_policy.** Skill body does the git ops. For product ADRs: commits in canonical (per `git_policy.canonical_commit_template`). For process ADRs: commits in AI workspace (per `git_policy.ai_workspace_commit_template`).

9. **Update index if present.** Some projects maintain `docs/adr/README.md` as a TOC. If present, skill body appends:
   ```markdown
   - [0008 — Auth dependencies must raise](./0008-auth-dependencies-must-raise.md) — Accepted, 2026-05-26
   ```

## Worked output — product ADR file

```markdown
# 0008 — Auth dependencies must raise, never return None

- Status: Accepted
- Date: 2026-05-26
- Deciders: project lead, AI orchestrator pair

## Context

During VS-3.2 (action-needed insights), an integration bug was discovered: `verify_bearer_token`
in `api/auth.py` returned `None` for expired tokens instead of raising. Downstream code paths
treated the `None` as "no user" and returned empty data — silent auth failure indistinguishable
from a genuine empty result. The bug masked AC-3 verification on work-3.2.01 (the test was passing
only because the test token was fresh).

The root cause is a contract inconsistency: some auth dependencies in the codebase raise on
failure (modern pattern), others return None (legacy pattern). Mixing both creates the silent-
failure mode.

## Decision

All auth dependencies (anything used as a FastAPI `Depends()` and named `verify_*` or
`require_*`) MUST raise `HTTPException(status_code=401, detail=...)` on credential failure.
Returning `None`, `False`, or any falsy value is FORBIDDEN.

This applies to:
- `api/auth.py:verify_bearer_token` (already updated as part of VS-3.2 bug-fix detour)
- All future auth dependencies

## Consequences

Positive:
- Silent auth failures become impossible. Any downstream code receives a 401 response, not
  empty data.
- The mental model is uniform: dependency present and validated -> user object; absent or
  invalid -> 401 raised, request never reaches the route function.

Negative:
- Existing code that catches `verify_bearer_token == None` and degrades gracefully (e.g.,
  the public-feed routes) had to be reworked to use a different mechanism (optional auth
  via `try/except HTTPException` in a wrapper).

Neutral:
- A new mcrule in `memory-bank/03-code-patterns.md` `style_invariants` could enforce this
  (regex search for `return None` inside `verify_*` functions). Captured as a follow-up.

## References

- `vs-3.2-bugfix-auth-a1b2.md` (the handoff that triggered the decision)
- `api/auth.py` (current implementation)
- VS-3.2 retrospective §3 (architect-critic findings)
```

## Worked output — process ADR file (alternative path)

If the user had answered "process":

Filename: `<ai-workspace>/docs/adr/0008-architect-critic-invocation-mechanism.md` (or similar slug).

Content shape is identical (MADR-lite template), but the audience and language differ — process ADRs explain how the AI workflow operates, not how the product behaves.

## Anti-patterns

- **Skipping the prompt.** Skill body must NOT auto-route based on heuristics. The user explicitly chooses product vs. process; the skill body provides a hint but never overrides.
- **Writing to both dirs.** An ADR has exactly one home. Cross-references from one to the other (e.g., a process ADR mentioning a product ADR) are written via inline links, not by duplicating the file.
- **Skipping the index update.** If the index file exists, NOT updating it leaves the TOC stale. If the index doesn't exist, skill body does NOT create one (out of scope).
- **Committing both ADR and code changes in the same commit.** Per `git_policy`: ADRs commit separately. Code changes implementing the decision commit elsewhere. Keeps the ADR commit as a clean reference point.
