---
doc: PROMPT_GOVERNANCE
routes_to: process_adrs
wave: 4
required_sections:
  - "Authoring"
  - "Versioning"
  - "Evaluation before rollout"
  - "Rollback"
  - "See also"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes the project's prompt governance rules from MASTER-SPEC Phase 5
(tech stack, AI tooling), Phase 9.3 (eval plan), and Phase 10 (rollback, ops). It applies
when the project uses LLMs or prompts as first-class artifacts.

Authoring: reproduce the standard authoring rules from the template (prompts live under
`prompts/`, one prompt per file, frontmatter block required). Then extend with
project-specific conventions derived from Phase 5 and Phase 3: name the actual prompt
directory if the project deviates from the default, list any domain-specific frontmatter
fields required (e.g., `expected_domain`, `max_tokens_budget`), and reference any FR IDs
in the ledger that specify prompt-authoring constraints. If Phase 6 reveals a multi-modal
or structured-output surface, add the corresponding authoring rule.

Versioning: reproduce the standard versioning rules (semver frontmatter, archive path).
Add a project-specific note about when a version bump is mandatory vs. recommended,
drawn from the eval sensitivity visible in `phase_9.3.2`. If the project has
prompt-to-feature traceability requirements (FR IDs that map to specific prompts), state
how prompt versions are tied to BACKLOG items.

Evaluation before rollout: state that every prompt change runs the eval plan against the
golden set, and name the specific eval dimensions from `phase_9.3.2` that gate rollout.
For each NFR ID in the ledger that encodes an LLM quality bar, state it as a hard block
condition (e.g., "NFR-6 factuality >= 0.90 — failing this NFR blocks merge"). Reference
EVALS_PLAN.md for the full threshold table.

Rollback: reproduce the standard rollback procedure (restore prior version file,
redeploy). Add the project-specific trigger condition for rollback — ground it in
`phase_10.2.2` (alerting thresholds) so operators know when a production regression
warrants a prompt rollback vs. a code rollback. Reference the scaffold-dev `/runbook-new`
command for incident recording.

See also: include links to EVALS_PLAN.md and MODEL_CARD.md as in the template.
