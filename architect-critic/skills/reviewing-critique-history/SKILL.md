---
name: reviewing-critique-history
description: Show recent architect-critic runs as a table, plus any in-flight background (async) audits. Triggers on "show recent critiques", "critique history", "list pending audits", "recent audits", "audit log", "in-flight critiques", "background audits". Reads state.json schema v3 (recent_runs[] + external_runs[]). Default N=10 rows; --limit N overrides.
---

# reviewing-critique-history

You have been invoked because the user wants to see a history of recent architect-critic audit runs. Your job is to read `state.json` (schema v3), slice the most-recent N rows from `recent_runs[]`, render them as a clean markdown table, and — when present — list any **in-flight / recent background (async) audits** from `external_runs[]` (#39).

This skill is intentionally narrow: read, format, display. No judgment, no rebuttal, no state mutation.

---

## Step 1: Resolve the state.json path

The canonical location is `~/.claude/architect-critic/state.json`. Expand `~` to the actual home directory — the Bash tool does not always expand tilde in arguments.

```bash
STATE_FILE="${HOME}/.claude/architect-critic/state.json"
```

If the file does not exist at that path, stop here and output:

> No critique runs yet — state.json not found.

Do not error. Do not try to create the file. Exit gracefully.

---

## Step 2: Parse `--limit N` from `$ARCHITECT_CRITIC_ARGS`

The slash-command wrapper (`commands/critique-list.md`) exports the raw argument string as `$ARCHITECT_CRITIC_ARGS`. Read that env var — do not reference bash positionals like `$1` or `$2`, which get silently corrupted by Claude Code's template substitution at render time.

Parse the limit with:

```bash
LIMIT="$(printf "%s" "${ARCHITECT_CRITIC_ARGS:-}" | sed -nE "s|.*--limit[= ]+([0-9]+).*|\1|p" | head -1)"
[[ -z "$LIMIT" ]] && LIMIT=10
```

Valid range: 1–100. If the user passes `--limit 0` or a negative value, treat as default (10). If they pass `--limit 200`, cap at 100 and note it.

---

## Step 3: Read `recent_runs[]` and `external_runs[]`

Read the file and extract both arrays. The schema v3 shape has **no `in_flight` field** — do not look for it, do not render it, do not mention its absence. Background audits are represented by durable `external_runs[]` records instead.

```bash
TOTAL="$(jq '.recent_runs | length' "$STATE_FILE" 2>/dev/null || echo 0)"
RUNS_JSON="$(jq -c ".recent_runs | sort_by(.completed_at) | reverse | .[:${LIMIT}] | .[]" "$STATE_FILE" 2>/dev/null)"
EXTERNAL_TOTAL="$(jq '(.external_runs // []) | length' "$STATE_FILE" 2>/dev/null || echo 0)"
```

If `recent_runs` is an empty array (`TOTAL == 0`) and `external_runs[]` is also empty (`EXTERNAL_TOTAL == 0`), output:

> No critique runs yet.

Do not render an empty table. An empty table with headers but no rows is harder to read than a one-line message.

If `recent_runs` is empty but `external_runs[]` has entries, output the empty completed-run message briefly and continue to Step 4b so the background audit table is still visible.

---

## Step 4: Render the markdown table

Emit the table directly as markdown in your turn message. Do not use bash `printf` alignment tricks for the markdown output — render it as a fenced or pipe-delimited table that Claude Code's markdown renderer will format automatically.

### Column order (mandatory — do not reorder)

| Column | Field in `recent_runs[]` | Format notes |
|---|---|---|
| `completed_at` | `completed_at` | ISO8601 → human-readable (see below) |
| `depth` | `depth` | `shallow` or `close` |
| `adversaries_used` | `adversaries_used` | array → `claude` or `claude+codex` |
| `challenge_count` | `challenge_count` | integer |
| `concessions` | `concessions` | integer |
| `skill_invoked` | `skill_invoked` | string, e.g. `critiquing-spec` |
| `timeout?` | `codex_timeout` | `*` if `true`, blank otherwise |

**`completed_at` formatting.** Convert ISO8601 to a human-friendly relative string using the same logic the slash-command wrapper uses:

- < 60 s ago → `just now`
- < 1 h ago → `Xm ago`
- < 24 h ago → `Xh ago`
- < 7 d ago → `Xd ago`
- older → bare date `YYYY-MM-DD`

Use Bash for the relative-time conversion if you need it, but keep the computation in a helper snippet rather than a long script block.

**`adversaries_used` formatting.** The field is a JSON array. Join with `+`:

- `["claude"]` → `claude`
- `["claude","codex"]` → `claude+codex`

**`timeout?` column.** Only render this column if at least one row in the result set has `codex_timeout: true`. If no row has it, omit the column entirely to keep the table clean.

### Limit and total annotation

If `TOTAL > LIMIT`, prepend a one-line note before the table:

> Showing 10 of 23 total runs. Use `--limit N` to see more.

If `TOTAL <= LIMIT`, no annotation needed.

---

## Step 4b: List background (async) audits from `external_runs[]` (#39)

After the `recent_runs` table, or immediately after the empty completed-run message when there are no completed runs, surface any background close-depth audits. These are dispatched by `/critique --close --async` and tracked in `external_runs[]`.

```bash
arc state_external_run_list                 # all background runs
arc state_external_run_list --status running   # just the in-flight ones
```

If the array is empty, render nothing for this section (no header). Otherwise, emit a short second table — **running jobs first** — with columns: `run_id`, `status`, `artifact_path` (basename), `started_at` (relative), and a `resumed?` mark (`*` when `resolved_run_request_id` is non-null). End with a one-line pointer: *"Manage background audits with `/critique-jobs status|result|cancel|resume`."* This section is read-only — it never polls, cancels, or resumes (that is `managing-async-critique`).

---

## Step 5: Worked example

Suppose state.json contains this schema v3 state (3 completed runs and one background run):

```json
{
  "schema_version": 3,
  "recent_runs": [
    {
      "request_id": "crit-20260520T140000Z-shallow-a1b2",
      "completed_at": "2026-05-20T14:00:00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 5,
      "concessions": 2,
      "skill_invoked": "critiquing-spec",
      "elapsed_ms": 42000
    },
    {
      "request_id": "crit-20260522T091500Z-close-c3d4",
      "completed_at": "2026-05-22T09:15:00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 9,
      "concessions": 4,
      "skill_invoked": "critiquing-spec",
      "elapsed_ms": 118000,
      "codex_timeout": false
    },
    {
      "request_id": "crit-20260524T073000Z-close-e5f6",
      "completed_at": "2026-05-24T07:30:00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 7,
      "concessions": 1,
      "skill_invoked": "critiquing-spec",
      "elapsed_ms": 95000,
      "codex_timeout": true
    }
  ],
  "external_runs": [
    {
      "run_id": "task-async-001",
      "host_agent": "claude",
      "adversary": "codex",
      "artifact_path": "/repo/docs/spec.md",
      "depth": "close",
      "status": "running",
      "started_at": "2026-05-24T09:00:00Z",
      "completed_at": null,
      "result_path": "/tmp/async/task-async-001/result.json",
      "codex_session_id": null,
      "resolved_run_request_id": null
    }
  ]
}
```

With `--limit 10` (default) and today being `2026-05-24`, the rendered output is:

---

| completed_at | depth | adversaries_used | challenge_count | concessions | skill_invoked | timeout? |
|---|---|---|---|---|---|---|
| 7h ago | close | claude+codex | 7 | 1 | critiquing-spec | * |
| 2d ago | close | claude+codex | 9 | 4 | critiquing-spec | |
| 4d ago | shallow | claude | 5 | 2 | critiquing-spec | |

---

The `timeout?` column appears because at least one row has `codex_timeout: true`. The `*` marks the affected row. The rows are sorted most-recent first. Because `external_runs[]` is non-empty, also render the background-audits table after the completed-runs table.

---

## Schema fields this skill depends on

Coupled to these `recent_runs[]` and `external_runs[]` fields in schema v3. If `lib/state.sh:ac_state_append_run`, `ac_state_external_run_add`, or `ac_state_external_run_finalize_resume` renames any field, this skill breaks silently (jq returns `null`).

| Field | Type | Notes |
|---|---|---|
| `completed_at` | ISO8601 UTC string | Sort key + relative-time display |
| `depth` | `shallow` \| `close` | Verbatim |
| `adversaries_used` | string array | Joined with `+` |
| `challenge_count` | integer | Bare count |
| `concessions` | integer | v2 addition |
| `skill_invoked` | string | v2 addition |
| `codex_timeout` | boolean (optional) | Present only when codex timed out |

**Removed in v2 — do not reference:** `in_flight` (top-level, async dropped), `cost_usd` (per-run, dropped).

If `schema_version == 1`, emit: "Warning: state.json is schema v1. Run `/critique` once to migrate." Then render with missing v2 fields blank.

---

## Empty-state and error handling summary

| Condition | Output |
|---|---|
| `state.json` not found | "No critique runs yet — state.json not found." |
| `recent_runs` empty array | "No critique runs yet." |
| `recent_runs` has entries, all within limit | Table with no annotation |
| `recent_runs` has entries, total exceeds limit | "Showing N of M total runs." + table |
| `schema_version == 1` | One-line warning + table (graceful degradation) |
| `--limit` out of range | Cap at 100 or reset to 10; note adjustment inline |

---

## Tool boundary

All I/O (reading state.json, computing the relative timestamp) runs in Bash. The table rendering happens in your turn message as plain markdown — not inside a bash `printf` block, not as a tool-call trace. The user reads your turn, not bash stdout.

Do not mutate state.json. This skill is read-only.
