# Resume handling

How `/onboard --resume` and the implicit-resume default work, plus edge cases that aren't obvious from SKILL.md §4 alone.

This doc supplements SKILL.md §4 (State management) + §9 (Slash-command flags). Read those first; this file zooms in on the resume protocol's failure modes and reconciliation flows.

---

## 1. Mode resolution

On every `/onboard` invocation the skill calls `sf state_mode` (the `sf` dispatcher on `$PATH`; resolves to `sf_state_mode` in `lib/state.sh`). It returns one of:

| Mode value         | Meaning                                                                   | Skill behavior                                                                                                              |
|--------------------|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `new`              | No state file present                                                     | `sf state_init` → Phase 1                                                                                                    |
| `resume`           | State file present, `status=in_progress`, `project_root` matches cwd      | Re-enter at first unanswered question                                                                                        |
| `reonboard`        | State file present, `status=complete`, `project_root` matches cwd         | Confirm prompt → `--regenerate` path                                                                                         |
| `project_mismatch` | State file present, `project_root` ≠ cwd (or stored `project_root` empty) | Prompt: *"State from `<stored>` found. Resume that, or start fresh here?"* — user picks → resume-with-cd OR fresh-init       |

`project_mismatch` (v0.2.1+) prevents the v0.x.1 Issue #4 bug where a stale state file from a different project triggered a false-resume at session start. Stored `project_root` is captured by `sf state_init` from `pwd` (or from `$SF_PROJECT_ROOT` if pre-exported by a manifest-aware caller). Legacy state files (pre-v0.2.1) lacking `project_root` surface as `project_mismatch` with `stored="unknown"`, forcing the user to confirm.

To surface the prompt, fetch the stored path with `sf state_stored_project_root` (returns `unknown` for legacy state). Render:

> State from `<stored>` found (initialized `<created_at>`). Resume that, or start fresh here?
> &nbsp;&nbsp;1. Resume the existing state (cd to the stored project root and re-invoke /onboard)
> &nbsp;&nbsp;2. Start fresh here (overwrites the existing state file with a new init from `<pwd>`)

The mode is computed once at skill entry. Explicit flags override:

- `--resume` forces `resume`; errors if no state file OR if `project_mismatch` fires (user must reconcile first).
- `--regenerate` forces the reonboard confirm-and-reset flow regardless of `status` or `project_root`.

---

## 2. Lock acquisition (refusal-on-already-held)

Every entry into the skill body acquires the advisory lock via `sf_state_lock_acquire`. The lock file lives next to `onboarding-state.json` at `${CLAUDE_PLUGIN_DATA}/onboarding-state.lock`. It records:

```
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

- Phase 10 close, after `sf_state_write_atomic status complete`.
- Any clean exit (user cancels at a confirm prompt; lock released before the skill returns).

Crash-released locks are detected on next entry by stat'ing the recorded `pid`. If it's no longer alive (e.g., the Claude Code process was killed mid-Phase-4), `sf_state_mode` treats the lock as stale and offers `--force-unlock` in the warning text.

---

## 3. The checkpoint: `current_phase` + first-unanswered-question

There's no separate `checkpoint` field in the state schema. Resume position is derived from two reads:

1. `sf_state_read_field current_phase` → integer 1..10.
2. For each question id in that phase (via `sf_phases_questions_for <yaml> <current_phase>`), call `sf_state_read_answer <qid>` and find the **first** that returns `null` *and* is either required or has not been explicitly marked `skip`.

This is the resume point. If every question in `current_phase` is already answered, the resume point is the *first* question of `current_phase + 1` (the user crashed between question-answer-write and `sf_state_advance_phase`).

### Worked example — mid-Phase-4 interrupt

State file:

```json
{
  "schema_version": "1.0",
  "status": "in_progress",
  "current_phase": 4,
  "started_at": "2026-05-24T13:40:00Z",
  "answers": {
    "1.1.1": "...", "1.1.2": "...", ..., "3.3.1": "...",
    "4.1.1": "none", "4.1.2": "none"
  }
}
```

User runs `/onboard --resume`. Skill:

1. Acquires lock.
2. Reads `current_phase=4`.
3. Iterates `sf_phases_questions_for phases.yaml 4` → `[4.1.1, 4.1.2, 4.2.1, 4.2.2, 4.3.1]`.
4. Finds first unanswered → `4.2.1` ("Auth model: none / API keys / OAuth / SSO / custom?").
5. Announces:
   > Resuming at Phase 4 (Security & Compliance), question 3 of 5. *3 of 5 questions remaining.* Last answered: 4.1.2 (regulated domain → none).
6. Asks `4.2.1`.

Phases 1-3 + the first 2 questions of Phase 4 are **never re-asked**. Existing answers are read-only during resume.

---

## 4. Flag matrix: --resume vs --regenerate vs no-flag default

| Invocation              | State file: absent       | State file: `in_progress`   | State file: `complete`       |
|-------------------------|--------------------------|------------------------------|------------------------------|
| `/onboard` (no flag)    | Fresh: Phase 1           | Implicit resume               | Confirm → reonboard          |
| `/onboard --resume`     | Error: "no state file"   | Explicit resume               | Error: "use --regenerate"    |
| `/onboard --regenerate` | (treated as fresh)       | Confirm → backup + reset      | Confirm → backup + reset     |
| `/onboard --force-unlock` | Error: "no lock to release" | Confirm → release lock; user re-runs with intended flag | Same as in_progress |

The no-flag default is *forgiving*: it does the most likely-intended thing based on state. The explicit flags are *strict*: they refuse to do anything other than what the flag names. This makes `/onboard --resume` safe to wire into hooks or scripts without worrying about it accidentally starting a fresh onboarding when state is missing.

---

## 5. Edge case: MASTER-SPEC hand-edited externally

State file is `in_progress` at Phase 7, but the user has manually edited `MASTER-SPEC.md` in their editor between sessions — added a new line under Phase 3, rephrased a Phase 1 bullet. On `/onboard --resume`, the skill detects drift:

1. After lock acquisition, skill reads the on-disk MASTER-SPEC.md mtime + a content hash (lib/render.sh helper `sf_render_master_spec_hash`).
2. Compares against the hash recorded at the last `sf_master_spec_update_phase` call (stored in `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` under `answers["__internal.master_spec_hash"]` or a sibling field — implementation detail of T2.3 render helpers).
3. If the hash differs, skill emits:

   > MASTER-SPEC.md has been edited outside the onboarding flow since the last persisted phase recap. Your manual edits may conflict with the auto-rendered sections.
   >
   > Choose one:
   >   `revalidate` — re-render MASTER-SPEC from state.answers (your manual edits are backed up to `MASTER-SPEC.md.handedit-<ISO8601>` and replaced).
   >   `merge`      — keep your manual edits; resume from Phase 7 question N. Future `sf_master_spec_update_phase` calls will only touch the Phase 7+ sections; earlier phases are left as-edited.
   >   `cancel`     — stop. Inspect the file and re-run when ready.

This is a **warn-and-offer** flow, not a hard error. The user is authoritative; we never silently overwrite a hand-edit.

The `merge` path requires the skill to skip `sf_master_spec_update_phase` for phases earlier than `current_phase`. Phase 1-6 sections become user-owned; Phase 7+ remain skill-owned. This is honestly best-effort — if the user hand-edits the Phase 5 section *and* the Phase 5 critic later wants to revise it, the user has to redo the merge by hand. We document the limitation rather than pretend to solve it.

The `revalidate` path is the clean restart: full re-render from `state.answers`, hand-edits archived in the `.handedit-<ISO8601>` backup. Equivalent to "trust the state file, distrust the file on disk."

---

## 6. Resume across `${CLAUDE_PLUGIN_DATA}` migration

The state file lives at `${CLAUDE_PLUGIN_DATA}/onboarding-state.json`. If the user changes `CLAUDE_PLUGIN_DATA` between sessions (or moves the plugin install), `/onboard --resume` will say *"no state file"* and refuse. This is intentional — the skill never scans the filesystem for orphaned state files. If the user knows they moved their plugin data dir, they can copy the state file manually; the schema is stable across v0.1.0 → v0.2.

---

## 7. Concurrency model summary

- One state file, one lock, one in-flight onboarding per `${CLAUDE_PLUGIN_DATA}` namespace.
- Two sessions trying to onboard the same project at the same time: second one gets refused at lock acquisition.
- Two sessions onboarding *different* projects with different `CLAUDE_PLUGIN_DATA` values: independent, no contention.
- Crash mid-write: atomic-mv via `sf_state_write_atomic` means the state file is never half-written. Worst case: the last unflushed answer is lost; resume picks up at that question.

This is deliberately conservative. We don't try to merge concurrent onboarding sessions; that way lies madness. Lock-then-refuse is the contract.
