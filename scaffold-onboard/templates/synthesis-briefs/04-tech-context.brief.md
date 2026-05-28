---
doc: 04-tech-context
routes_to: memory_bank
wave: 4
required_sections:
  - "Languages"
  - "Data stores"
  - "External APIs / third-party services"
  - "Local dev tooling"
  - "CI/CD"
  - "Hosting target"
  - "Backend specifics"
  - "Frontend specifics"
  - "Library specifics"
  - "See also"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This file is the branch-loaded tech-stack document. It is loaded when a conversation
touches tech choices, tooling, or deployment. Keep entries factual and spec-grounded —
no aspirational stack additions.

Languages: list the programming languages from `phase_5.2.1`. Include version
constraints if the spec records them (e.g., "Python 3.12+", "TypeScript 5.x").

Data stores: list all data stores from `phase_5.2.2`. For each store name the engine
(e.g., PostgreSQL 16, Redis 7, SQLite 3) and its primary role in the system.

External APIs / third-party services: list third-party APIs and services from
`phase_5.2.3`. For each entry name the service, its role, and any rate-limit or cost
constraint visible in the spec (Phase 2 budget context).

Local dev tooling: list local development tools from `phase_8.1.1` (e.g., Docker
Compose, Makefile targets, local seed scripts). Include version pins if recorded.

CI/CD: synthesize two sub-fields from Phase 8:
  - Platform: from `phase_8.2.1` — the CI/CD platform (GitHub Actions, GitLab CI, etc.)
  - Environments: from `phase_8.2.2` — the promotion pipeline (dev → staging → prod
    or equivalent). Name each environment and its promotion trigger.

Hosting target: state the deployment target from `phase_8.3.1`. Be specific: name
the cloud provider, container runtime, serverless platform, or on-prem environment.
Include region requirements if captured in Phase 4 (compliance).

Backend specifics (backend branch only): if the project has a backend, synthesize:
  - ORM / query / SQL: from `phase_7.2.1`
  - API style: from `phase_7.2.2`
  Omit this section entirely for projects with no backend.

Frontend specifics (frontend branch only): if the project has a frontend, synthesize:
  - State management: from `phase_7.3.1`
  Omit this section entirely for projects with no frontend.

Library specifics (library branch only): if the project is a library or SDK,
synthesize:
  - Public API + versioning: from `phase_7.4.1`
  Omit this section entirely for projects that are not a library/SDK.

**Conditional sections note:** emit only the branch-specific sections that apply to
this project. If a branch section is omitted, do not leave a blank heading — remove
the heading entirely from the output.

See also: emit the canonical cross-reference links exactly as they appear in the
template (MASTER-SPEC §Phase 5 and §Phase 8).
