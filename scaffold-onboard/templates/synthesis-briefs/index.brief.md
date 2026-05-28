---
doc: index
routes_to: memory_bank
wave: 4
required_sections:
  - "Memory Bank Index"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This file is the always-preloaded Tier 0 memory-bank index. Its sole job is to give
an LLM a quick map of all memory-bank files and their load tiers.

Memory Bank Index: emit the canonical index table VERBATIM from the template,
preserving all file names, purpose descriptions, and load-tier labels exactly as
specified. Do NOT reorder rows, alter descriptions, or add project-specific files
to the table.

The only project-specific element to synthesize is the derivation timestamp in the
`**Last derived from MASTER-SPEC.md @ {{ts}}**` line — replace `{{ts}}` with the
current ISO-8601 timestamp at synthesis time.

All other content — the table header, all eight data rows, the WORKFLOW.md row, and
the `index.md` row — must be copied verbatim from the template. Do NOT improvise
descriptions or change load-tier labels.

Do NOT add any content outside the heading and table (no intro paragraph, no footer,
no project-specific notes). This file must remain purely navigational.
