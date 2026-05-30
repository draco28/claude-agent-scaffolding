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

Memory Bank Index: emit the canonical index table VERBATIM. The table below is
GROUND TRUTH — copy it exactly (you cannot see the deterministic template, so this
brief carries the authoritative table). Preserve all file names, purpose
descriptions, and load-tier labels exactly; do NOT reorder rows, alter descriptions,
add project-specific files, or improvise any cell. Output under the `# Memory Bank
Index` heading:

```markdown
# Memory Bank Index

**Last derived from MASTER-SPEC.md @ {{ts}}**

| File | Purpose | Load tier |
|---|---|---|
| `00-project-brief.md` | Vision · problem · users · MVP · project class | **Tier 0** (always preloaded) |
| `01-product-context.md` | Domain entities · user flows / DX · ubiquitous language | branch · product/UX |
| `02-system-patterns.md` | Architecture invariants · security posture · async rules | branch · architecture |
| `03-code-patterns.md` | Code style · function/class rules · banned patterns | branch · implementation |
| `04-tech-context.md` | Languages · frameworks · stores · hosting · tooling | branch · tech |
| `05-active-context.md` | What's happening *right now* — active sprint, slice, blockers | **Tier 0** · **LIVE** |
| `06-progress.md` | Append-only log: dated entries by sprint/slice/decision/gotcha | branch · history · **LIVE** |
| `07-constraints.md` | Hard constraints — budget · timeline · compliance · perf | branch · planning |
| `08-governance.md` | Pointers to governance docs · workflow rules | branch · planning |
| `WORKFLOW.md` | Per-sprint workflow — pointers to the slice loop | branch · workflow · **STATIC** |
| `index.md` | This file | **Tier 0** |
```

The ONLY project-specific element is the derivation timestamp: replace `{{ts}}`
in the `**Last derived from MASTER-SPEC.md @ {{ts}}**` line with the current
ISO-8601 timestamp at synthesis time. Every other cell is copied verbatim.

Do NOT add any content outside the heading and table (no intro paragraph, no footer,
no project-specific notes). This file must remain purely navigational.
