# Resume handling

How `/onboard --resume` and the implicit-resume default work, plus edge cases that aren't obvious from SKILL.md §4 alone.

This doc supplements SKILL.md §4 (State management) + §9 (Slash-command flags). Read those first; this file zooms in on the resume protocol's failure modes and reconciliation flows.

---

## 1. Mode resolution

On every `/onboard` invocation the skill calls `sf state_mode` (the `sf` dispatcher on `$PATH`; resolves to `sf_state_mode` in `lib/state.sh`). It returns one of:

| Mode value         | Meaning                                                                   | Skill behavior                                                                                                              |
|--------------------|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `new`              | No state file present                                                     | `sf state_init` → Phase 1                                                                                                    |
| `resume`           | Project-scoped state file present, `status=in_progress` **OR** `status=close_pending`, `project_root` matches current project identity | `in_progress`: re-enter at first unanswered question. `close_pending`: all phases answered, close not yet finished — announce and proceed directly to §7 (Karpathy opt-in) + §8 (MASTER-SPEC close ceremony). |
| `reonboard`        | Project-scoped state file present, `status=complete`, `project_root` matches current project identity    | Full re-walk re-synthesis: acquire lock → set `current_phase=1` + `status=in_progress` → announce → re-walk all 10 phases (existing answers as defaults) → close in first-author mode (backs up prior MASTER-SPEC.md). Use `--fresh` for a full wipe-and-restart (requires double confirmation). Partial-reconcile (choosing only some phases) was decided wontfix (#58). |
| `project_mismatch` | Project-scoped state file present, `project_root` ≠ current project identity (or stored `project_root` empty) | Prompt user to return to the original path / set `SF_PROJECT_ROOT`, or start fresh for the current project-scoped state.      |

`project_mismatch` (v0.2.1+) originally prevented stale singleton state from another project from being resumed. In v0.2.3+, state is already project-scoped under `sf project_data_dir`, so this mode is now a same-project safety net for moved workspaces, changed `SF_PROJECT_ROOT`, or malformed legacy state. Stored `project_root` is captured by `sf state_init` from `sf project_identity_root`.

To surface the prompt, fetch the stored path with `sf state_stored_project_root` (returns `unknown` for legacy state). Render:

> Project-scoped onboarding state says it belongs to `<stored>`, but this session resolves the project as `<current>`.
> &nbsp;&nbsp;1. Return to the original path or set `SF_PROJECT_ROOT=<stored>` and re-invoke /onboard.
> &nbsp;&nbsp;2. Start fresh for `<current>` (overwrites only this project-scoped state file).

The mode is computed once at skill entry. Explicit flags override:

- `--resume` forces `resume`; errors if no state file OR if `project_mismatch` fires (user must reconcile first).
- `--regenerate` forces the reonboard confirm-and-reset flow regardless of `status` or `project_root`.

---

## 2. Lock acquisition (refusal-on-already-held)

Every entry into the skill body acquires the advisory lock via `sf_state_lock_acquire`. The lock file lives next to the project-scoped `onboarding-state.json` as `onboarding.lock`. It records:

```json
{
  "pid":         <int>,
  "acquired_at": "<ISO8601>",
  "session_id":  "<claude session id, if available>"
}
```

If acquisition fails (lock present and the recorded process is not the current session), the skill emits:

> Onboarding already in progress in another session. Either close that session or re-run with `/onboard --force-unlock` after confirming no other session is active.

…and stops. The skill does **not** silently steal a lock. `--force-unlock` is the only escape, and it asks for explicit confirmation before releasing.

Release happens at:

- Phase 10 close, after `sf state_write_atomic status complete`.
- Any clean exit (user cancels at a confirm prompt; lock released before the skill returns).

Crash-released locks are detected on next entry by stat'ing the recorded `pid`. If it's no longer alive (e.g., the Claude Code process was killed mid-Phase-4), `sf_state_mode` treats the lock as stale and offers `--force-unlock` in the warning text.

---

## 3. The checkpoint: `current_phase` + first-unanswered-question

There's no separate `checkpoint` field in the state schema. Resume position is derived from two reads:

1. `sf state_read_field current_phase` → integer 1..10.
2. For each question id in that phase (via `sf phases_questions_for <yaml> <current_phase>`), call `sf state_read_answer <qid>` and find the **first** that returns `null` *and* is either required or has not been explicitly marked `skip`.

This is the resume point. If every question in `current_phase` is already answered, the resume point is the *first* question of `current_phase + 1` (the user crashed between question-answer-write and `sf_state_advance_phase`).

### Worked example — mid-Phase-4 interrupt

State file:

```json
{
  "schema_version": 2,
  "status": "in_progress",
  "current_phase": 4,
  "current_question": null,
  "project_class": "Web app",
  "project_root": "/Users/me/projects/myapp",
  "created_at": "2026-05-24T13:40:00Z",
  "updated_at": "2026-05-24T14:02:00Z",
  "answers": {
    "1.1.1": "...", "1.1.2": "...", "3.3.1": "...",
    "4.1.1": "none", "4.1.2": "none"
  },
  "phase_records": {
    "1": {
      "decisions": "Core product is a real-time analytics dashboard for SMB e-commerce.",
      "rationale": "User validated that Shopify-tier complexity is the right scope.",
      "alternatives_rejected": "Enterprise multi-tenant deferred to v2.",
      "constraints": "MVP in 8 weeks; two-person team.",
      "open_questions": "Pricing model TBD.",
      "authored_at": "2026-05-24T13:55:00Z"
    }
  }
}
```

User runs `/onboard --resume`. Skill:

1. Acquires lock.
2. Reads `current_phase=4`.
3. Repairs any phase **up to and including** `current_phase` whose `phase_records[N]` is missing but whose active required questions are all answered, by re-authoring the record in conversation. (Eligibility excludes required questions in gated-out subsections and never blocks on optional questions — see SKILL §4 for the exact rule.)
4. Iterates `sf phases_questions_for phases.yaml 4` → `[4.1.1, 4.1.2, 4.2.1, 4.2.2, 4.3.1]`.
5. Finds first unanswered → `4.2.1` ("Auth model: none / API keys / OAuth / SSO / custom?").
6. Announces:
   > Resuming at Phase 4 (Security & Compliance), question 3 of 5. *3 of 5 questions remaining.* Last answered: 4.1.2 (regulated domain → none).
7. Asks `4.2.1`.

Phases 1-3 + the first 2 questions of Phase 4 are **never re-asked**. Existing answers are read-only during resume.

---

## 4. Flag matrix: --resume vs --regenerate vs no-flag default

| Invocation              | State file: absent       | State file: `in_progress`      | State file: `close_pending`                     | State file: `complete`                          |
|-------------------------|--------------------------|--------------------------------|-------------------------------------------------|-------------------------------------------------|
| `/onboard` (no flag)    | Fresh: Phase 1           | Implicit resume                | Implicit resume → §8 close ceremony             | Full re-walk re-synthesis (all phases; prior spec backed up) |
| `/onboard --resume`     | Error: "no state file"   | Explicit resume                | Explicit resume → §8 close ceremony             | Error: "use --regenerate"                       |
| `/onboard --regenerate` | (treated as fresh)       | Full re-walk re-synthesis      | Full re-walk re-synthesis                       | Full re-walk re-synthesis: backup + re-walk all phases (existing answers as defaults) |
| `/onboard --fresh`      | (treated as fresh)       | Confirm → full wipe + Phase 1  | Confirm → full wipe + Phase 1                   | Double-confirm → full wipe + Phase 1            |
| `/onboard --force-unlock` | Error: "no lock to release" | Confirm → release lock; user re-runs with intended flag | Same as in_progress | Same as in_progress |

The no-flag default is *forgiving*: it does the most likely-intended thing based on state. The explicit flags are *strict*: they refuse to do anything other than what the flag names. This makes `/onboard --resume` safe to wire into hooks or scripts without worrying about it accidentally starting a fresh onboarding when state is missing.

---

## 5. Edge case: phase record missing (crash between answer-write and record-write)

State file is `in_progress` at Phase 7, but a prior session crashed after persisting the answers for Phase 3 without writing the Phase 3 record. On `/onboard --resume`, the skill detects the gap:

1. After lock acquisition, the skill iterates phases 1 through `current_phase` (inclusive — a crash after the current phase's last required answer was persisted but before its record was written leaves the record missing at `current_phase` itself, so the scan must cover it; on a `close_pending` resume it covers all 10 phases) calling `sf state_read_phase_record <phase_id>` on each.
2. Since MASTER-SPEC is synthesized at close from phase records + answers (not rendered per phase), a missing record for a fully-answered phase is a recoverable gap: the answers are intact, the reasoning was never captured.
3. If any phase records are missing for already-answered phases, skill emits:

   > Phase N answers are all present but the reasoning record is missing (the prior session likely crashed before authoring it). I'll re-author the Phase N record now from the existing answers.

   The skill re-authors the missing record in conversation (not by re-asking the user) and persists it via `sf state_write_phase_record <phase_id> <temp-file>`. This is a silent repair — the user is only notified, not re-prompted.

This is a **warn-and-repair** flow, not a hard error. The user's answers are authoritative and are never re-asked; only the reasoning record is reconstructed.

**Note:** MASTER-SPEC.md does not exist mid-onboarding (it is synthesized at close). If a user has manually created or edited a MASTER-SPEC.md in the project directory before close, that is an external artifact; the skill ignores it during the in-progress flow and overwrites it (with confirmation) at close.

---

## 6. Resume across `${CLAUDE_PLUGIN_DATA}` migration

The state file lives at `$(sf project_data_dir)/onboarding-state.json`, where `sf project_data_dir` is rooted under the install-level plugin data dir. If the user changes `CLAUDE_PLUGIN_DATA` between sessions (or moves the plugin install), `/onboard --resume` will say *"no state file"* and refuse. This is intentional — the skill never scans the filesystem for orphaned state files. If the user knows they moved their plugin data dir, they can copy the project subdirectory manually; the schema is stable across v0.1.0 → v0.2.

---

## 7. Concurrency model summary

- One state file and one lock per project identity under the install-level plugin data namespace.
- Two sessions trying to onboard the same project at the same time: second one gets refused at lock acquisition.
- Two sessions onboarding *different* projects with the same `CLAUDE_PLUGIN_DATA` value: independent, no contention.
- Crash mid-write: state helpers write to a temp file and only `mv` it over the state path after `jq` exits successfully, so the state file is never replaced with a partial/empty transform. Worst case: the last unflushed answer is lost; resume picks up at that question.

This is deliberately conservative. We don't try to merge concurrent onboarding sessions; that way lies madness. Lock-then-refuse is the contract.
