---
doc: 03-code-patterns
routes_to: memory_bank
wave: 4
required_sections:
  - "Module / package boundaries"
  - "Code style"
  - "Machine-checkable rules"
  - "User-global defaults (apply unless overridden above)"
  - "See also"
# Branch-gated sections — included ONLY when the project class activates the gate
# (see synthesis guidance). The validator does NOT hard-require these: omitting a
# gated section whose branch is false is correct, not a failure (#26 Slip 1).
gated_sections:
  - "Backend conventions"
  - "Frontend conventions"
  - "Library / SDK conventions"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This file is the branch-loaded implementation-context document. It is loaded when a
conversation touches code style, module structure, or naming conventions.

Module / package boundaries: synthesize the module/package layout from `phase_7.1.1`.
Name the top-level modules or packages, their responsibilities, and any boundary rules
(e.g., "no cross-import from `ui` → `core`"). Be concrete — use the project's actual
language and directory conventions.

Code style: synthesize the code style rules from `phase_7.1.2`. Cover language-level
conventions (naming, formatting, linting tool if specified) and any project-specific
rules that deviate from community defaults. Use a compact list.

Backend conventions (backend branch only): if the project has a backend, synthesize:
  - ORM / query builder / raw SQL: from `phase_7.2.1`
  - API style: from `phase_7.2.2` (REST, GraphQL, gRPC, etc.)
  Omit this section entirely for projects with no backend (`#if backend_branch` = false).

Frontend conventions (frontend branch only): if the project has a frontend, synthesize:
  - State management: from `phase_7.3.1`
  Omit this section entirely for projects with no frontend.

Library / SDK conventions (library branch only): if the project is a library or SDK,
synthesize:
  - Public API surface + versioning: from `phase_7.4.1`
  Omit this section entirely for projects that are not a library/SDK.

**IMPORTANT — Machine-checkable rules:** emit this section as an EMPTY seeded section.
Do NOT synthesize machine-checkable rules here. Output the section heading and the
HTML-comment invitation block EXACTLY as it appears in the template:

```
## Machine-checkable rules

<!--
  Project rules live below in the HTML-sentinel `mcrule` DSL (SPEC §8.2).
  Use `/add-project-rule` (skill: authoring-machine-checkable-rules) to add
  rules; this section is intentionally seeded empty for tools that parse it.
-->
```

Leave no additional content under this heading. Machine-checkable rules are authored
by the `authoring-machine-checkable-rules` skill and must NOT be pre-populated by
synthesis.

User-global defaults (apply unless overridden above): copy the canonical defaults
block VERBATIM from the template — do NOT modify the list items or add project-
specific overrides here (those belong in Code style). The defaults block is:
  - Functions ≤ 80 lines
  - No premature abstraction — 3 similar lines beat extraction-for-2
  - Functional by default; classes only when state must persist
  - Comments only for non-obvious *why*, never for *what*
  - Don't add error handling for impossible scenarios
  - No half-finished implementations or commented-out code blocks
  - Fix root causes, not symptoms

See also: emit the canonical cross-reference link exactly as it appears in the
template (MASTER-SPEC §Phase 7).
