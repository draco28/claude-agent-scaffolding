# Memory-bank harvest — mechanics

Referenced by `closing-vertical-slice` §9. The SKILL.md body holds the operative 8-step order + the load-bearing tokens; this file holds the categorization routing detail, the lean-index check mechanics, a worked surface example, and the `sd harvest_apply` payload schema + provenance-trailer format.

## Categorization routing (§9.4)

For each candidate, decide which **dev-authored** memory-bank file it belongs in, per the cadence policy (`memory-bank/WORKFLOW.md` → **Memory-bank update cadence**, harvest routing):

- caveats / gotchas / stack notes → `09-known-issues.md`
- decisions / advisory patterns → `10-decisions-log.md`
- an **enforceable** pattern → NOT a raw harvest append — route the user to `Skill(scaffold-onboard:authoring-machine-checkable-rules)` so it lands in `03`'s preserved rules zone.

Spec-derived files (`00,01,02,04,07,08,index`) and `03`'s derived prose are **never** harvest targets; `sd harvest_apply` rejects the complete payload before writing when any item names one. (There is no `06-product-context.md` file — `06` is `06-progress`; `01` is product-context.) Surface the proposed target alongside the candidate at step 5.

## Lean-index check (#48-F, write-time prevention) (§9.4)

Before proposing a target, judge whether the candidate **restates content already tracked** in a doc/ADR/issue (a `DOC §anchor` like `MASTER-SPEC.md §5.2`, an existing ADR id like `ADR-0007`, an open issue `#N`). If it does, do NOT harvest the prose — surface a **pointer** instead, per the forms in `memory-bank/WORKFLOW.md` → **Lean-index pointer conventions** (#33/#48 C/D/E) — and route the deferral via `Skill(scaffold-dev:deferring-work-item)` if it is genuinely new debt.

**When you surface (or harvest an entry carrying) a pointer, confirm it resolves** so the bank never stores a dangling reference:
- `sd citations_check_anchor "<doc-file>" "<anchor>"` for a `DOC §anchor`
- `sd citations_check_adr "ADR-NNNN" "<product-adr-dir>" "<process-adr-dir>"` for an ADR id

Each returns 0 = resolves, non-zero = flag it to the user; you still judge whether the cited target still *denotes* what the entry claims — the mechanical leg only confirms the heading/ADR exists. If the **claude-mem** plugin is present, a history/recall candidate may instead become a claude-mem topic pointer (e.g. `claude-mem: "data-pipeline decisions" corpus <name>`) rather than harvested prose; if claude-mem is absent, skip this — do not author a dead pointer. Also run the **mechanical length leg**: `sd harvest_lint_length "<candidate text>"` — non-zero (exceeds ~12 lines) means the entry is too long for a lean index; ask the user to tighten it to a pointer + one-line gist before accepting. These checks are advisory nudges surfaced at step 5, not hard blocks.

## Worked surface example (§9.5)

Each candidate's first line MUST start with the literal source-tag token in square brackets — either `[report]` or `[handoff]` (load-bearing per eval S1 + S4; `(report)`, `<handoff>`, `*report*`, `[Report]` all fail).

```
Harvest candidates for VS-1.1.1 (4 items):

1. [report] from work-1.01/report.md → target: 09-known-issues.md
   "subagent must use absolute paths when reading worktree files (relative paths break under Task dispatch)"

2. [report] from work-1.03/report.md → target: 09-known-issues.md
   "merge conflict surface on shared schema.json when two parallel work items both touch it"

3. [handoff] from vs-1.1.1-bugfix-auth-a1b2.md section 4 → target: 10-decisions-log.md
   "auth retry pattern: exponential backoff with 3 attempts, jitter 100-500ms"

4. [handoff] from vs-1.1.1-techdebt-logging-e5f6.md section 4 → target: 09-known-issues.md
   "log-rotation cron caveat — rotation fires at 03:00 UTC and races with the scheduled backup"

Per item: accept (apply as-is) / edit (give me the revised text) / reject (drop).

> Targets are dev-authored files only (`09`/`10`). A strictly **enforceable** rule (not
> advisory prose) is NOT harvested into `03` as raw text — route it to
> `Skill(scaffold-onboard:authoring-machine-checkable-rules)`. `sd harvest_apply`
> rejects any spec-derived target before writing.
```

## Apply payload + provenance trailer (§9.7)

Build a JSON array of all accepted / edited candidates — one object per item:

- Report-origin item: `{"source": "report", "target_file": "09-known-issues.md", "text": "<text>"}`
- Handoff-origin item: `{"source": "handoff", "target_file": "10-decisions-log.md", "handoff_file": "<vs-N.M.K-*.md basename>", "text": "<text>"}`

`text` is the canonical content field for both origins. The helper accepts legacy
`suggestion` and `item` fields only when `text` is absent, so older callers remain
compatible while new payloads have one contract.

Then apply in one call: `sd harvest_apply "$accepted_json" "VS-N.M.K"`.

`sd harvest_apply` is the **single mechanical write authority**: it validates the full array before filesystem mutation, accepts only the dev-authored `09-known-issues.md` / `10-decisions-log.md` targets, writes each item with the exact provenance trailer, and enforces idempotency (skips text already present). Do **not** hand-author the trailer or append directly. The trailer it produces (documented for eval reference):

```
<!-- Added from VS-N.M.K retrospective, YYYY-MM-DD; source: report -->
```
or
```
<!-- Added from VS-N.M.K retrospective, YYYY-MM-DD; source: handoff -->
```

Every accepted item MUST include `target_file`. The `source:` field MUST be set by the agent to exactly match the candidate's origin (`report` for report-sourced, `handoff` for handoff-sourced); `sd harvest_apply` writes the provided source verbatim. Eval S4 rejects: missing trailer, missing `source:` field, mis-labeled source. Eval S1 accepts minor date-format variation but rejects a missing `VS-N.M.K` reference. For `reject` decisions: omit those items from `$accepted_json` — the candidate is dropped; eval S4 confirms via filesystem diff that only accepted items appear as memory-bank modifications.
