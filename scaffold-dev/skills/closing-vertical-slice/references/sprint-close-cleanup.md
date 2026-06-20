# Sprint-close cleanup (final slice of the sprint)

Referenced by `closing-vertical-slice` §11. Runs ONLY when the slice being closed is the final slice of its sprint. The detection helpers (`sd roadmap_next_slice` / `sd roadmap_next_sprint`) are the same shared lookup the §12 active-context reconcile uses — never grep ROADMAP headings or split on the wrong id field (the #28 bug).

## Detect final-slice condition

```bash
# Field-read the next slice in THIS sprint. Empty ⇒ this is the final slice.
# sd_roadmap_next_slice sorts same-sprint slices by the 3rd id index and returns
# the smallest one greater than this slice's.
next_vs_id="$(sd roadmap_next_slice "$vs_id")"
if [[ -z "$next_vs_id" ]]; then
  is_final_slice_of_sprint=1
  # Next sprint is an array-order lookup over sprints[] (dotted ids, no integer +1).
  next_sprint_id="$(sd roadmap_next_sprint "$sprint_id")"
else
  is_final_slice_of_sprint=0
  next_sprint_id=""
fi
```

## Sweep non-carry-forward handoffs (when `is_final_slice_of_sprint=1`)

- Read every handoff in `${handoffs_dir}/`.
- For each, check its frontmatter or section-1 metadata for a `carry_forward: true` marker (per §6b.5).
- Delete handoffs WITHOUT the marker. Carry-forward handoffs (e.g. `sprint-${sprint_id}-to-${next_sprint_id}-handoff-XXXX.md`, where `next_sprint_id` is field-read from the next `sprints[]` entry — no integer `+1` for a dotted id like `1.1`) survive into the next sprint. If `next_sprint_id` is empty (final roadmap sprint), preserve only explicitly marked carry-forward handoffs and say there is no next sprint in the published roadmap.
- Surface: *"Sprint ${sprint_id} closed. Swept N non-carry-forward handoffs; K carry-forward handoffs preserved for sprint ${next_sprint_id:-<none in roadmap>}."*

**Ownership lock for v0.1:** sprint-close cleanup lives in this skill, not a separate `closing-sprint` skill (per SPEC §6b.6 settlement during PLAN). A future v0.2 may split this out.

## Sprint retrospective (out of scope)

Sprint-level retrospective authoring (`sprint-${sprint_id}/sprint-retrospective.md`, 6 sections per §16b) is handled by `writing-sprint-retrospective` (separate skill, T1.7). This skill authors only the slice retrospective + the conditional handoff sweep above.
