---
doc: MODEL_CARD
routes_to: product_adrs
wave: 4
required_sections:
  - "Model"
  - "Intended use"
  - "Out-of-scope use"
  - "Limitations"
  - "Data inputs"
  - "Eval reference"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes a model card from MASTER-SPEC Phase 1 (users, use case),
Phase 4 (security, sensitive data), Phase 5 (tech stack, stores, latency budgets), and
Phase 9.3 (eval plan). It applies when the project uses an LLM or ML model.

Model: state the specific model family, vendor, and version visible in Phase 5
(`phase_5.2.1`) and any AI/ML tooling noted in Phase 9.3. If the spec names a specific
model ID (e.g., `claude-3-5-sonnet-20241022`, `gpt-4o`), use it verbatim. State the
access pattern (API / hosted / self-hosted on which infra from `phase_8.3.1`).

Intended use: derive from `phase_1.2.2` (primary use case) and `phase_1.2.1` (user
personas). Write 2–3 sentences describing the specific task the model performs, the
users it serves, and the context in which outputs are consumed. Cite FR IDs from the
ledger that encode the model's functional responsibilities.

Out-of-scope use: enumerate 2–4 concrete exclusions grounded in the project's domain
and constraints (Phase 3, Phase 4). Examples: content types not represented in the
golden eval set, regulatory domains where the project is explicitly out of scope
(`phase_4.1.2`), use cases that require human-in-the-loop not present in the system.
Do NOT list generic AI limitations — these must be project-specific.

Limitations: address three dimensions with project-specific data:
  - Hallucination risk: describe what types of factual errors are most likely given
    the domain (Phase 3) and the mitigation in place (e.g., RAG grounding, citation
    requirements visible in FR IDs).
  - Latency: state the measured or budgeted P50/P95/P99 from `phase_5.3.2` and any
    NFR IDs in the ledger that encode latency acceptance bars.
  - Cost per call: state the budget from `phase_2.2.1` and how it translates to a
    per-call cost ceiling. Reference the cost-tracking mechanism if visible in Phase 8.

Data inputs: state the specific data stores from `phase_5.2.2` that feed model inputs
and the sensitive data handling rules from `phase_4.1.1`. If the project RAG-indexes
user data, name the data class and any access-control constraint from `phase_4.2.2`.

Eval reference: link to EVALS_PLAN.md for the golden set and acceptance thresholds.
State the top-level acceptance bar (the primary NFR ID that governs model quality) so
this card is self-contained enough to share with external stakeholders.
