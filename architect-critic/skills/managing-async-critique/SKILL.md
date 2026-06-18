---
name: managing-async-critique
description: Manage background (async) close-depth critique jobs — status, result, cancel, and resume. Triggers on "critique jobs", "resume critique", "resume the async audit", "cancel critique audit", "check critique job", "/critique-jobs". Resume consolidates the finished Codex result with the persisted host self-audit and runs one unified rebuttal; a concluded run resumes inspect-only.
---

# managing-async-critique

You have been invoked to manage **background close-depth critique jobs** created by `/critique --close --async` (#39). Those runs dispatch Codex as an external adversary in the background and record themselves in `state.json` under `external_runs[]`. This skill exposes four verbs: **status**, **result**, **cancel**, **resume**.

Parse the verb (+ optional `<run-id>`) from `$ARCHITECT_CRITIC_ARGS` (the `/critique-jobs` wrapper exports it; env-var bridge per [[feedback_slash_command_dollar_n_bug]]). If no `<run-id>` is given, default to the most recent applicable run (see each verb). All state/spine calls go through the `arc` dispatcher.

List runs for context with:
```bash
arc state_external_run_list            # all
arc state_external_run_list --status running
```
Each record carries: `run_id, host_agent, adversary, artifact_path, depth, status, started_at, completed_at, result_path, codex_session_id, resolved_run_request_id`. The `target_root` for spine calls is `arc codex_target_root "<artifact_path>"`.

---

## Verb: status [run-id]

Default `run-id`: the most recent `running` run (else the most recent overall).

1. Read the record: `arc state_external_run_get "<run-id>"` (rc1 → tell the user no such run; list runs).
2. If `status == running`, check once for a fresh disposition (non-blocking and non-mutating — do **not** use the bounded wait loop):
   ```bash
   term="$(arc codex_status "$(arc codex_target_root "<artifact_path>")" "<run-id>")"
   ```
   Update the stored status only if it changed to a terminal token: `arc state_external_run_set_status "<run-id>" "$term"` for `completed|failed|cancelled|stalled|capped`. Never persist `running` or `error`.
3. Report: run id, artifact, depth, status, started/completed timestamps, and — if `resolved_run_request_id` is set — that the run has already been resumed/concluded.

## Verb: result [run-id]

Default `run-id`: the most recent `completed` run.

1. Read the record; require `status == completed` (else report the current status and stop).
2. Fetch the raw Codex challenges (no rebuttal): `arc codex_result "$(arc codex_target_root "<artifact_path>")" "<run-id>"` → a `{challenges,gaps}` object.
3. Present the challenges read-only. Remind the user that **`resume`** is what folds them into a rebuttal; `result` is inspect-only.

## Verb: cancel [run-id]

Default `run-id`: the most recent `running` run.

1. Read the record; if already terminal, say so and stop.
2. Cancel via the spine and record the returned disposition:
   ```bash
   term="$(arc codex_cancel "$(arc codex_target_root "<artifact_path>")" "<run-id>")"
   ```
   If `term == cancelled`, persist `arc state_external_run_set_status "<run-id>" cancelled`. If `term == completed`, persist completed and tell the user the job completed before cancellation, so `resume` is still available. For `failed|stalled|capped`, persist that terminal token; for `error`, report the error without overwriting state.
3. Confirm the final disposition to the user.

## Verb: resume [run-id]  — the defer-to-resume unified rebuttal (#39)

Default `run-id`: the most recent `completed` (else `running`) run for the current artifact.

1. **Read the record.** `arc state_external_run_get "<run-id>"`.
2. **Idempotency guard.** If `resolved_run_request_id` is already set, this run was concluded — **resume inspect-only**: print the prior conclusion (the `recent_runs` entry whose `request_id` matches) and STOP. Append nothing. (Mechanically: a later `arc state_external_run_finalize_resume` would also return rc1, so never re-append.)
3. **Require terminal `completed`.** If the job is still `running`, report status (poll once as in `status`) and stop — do not partially consolidate. If `failed/cancelled/stalled/capped`, report that terminal status and the still-available host self-audit preview, and stop (nothing to consolidate).
4. **Load both adversaries.**
   - `claude_audit` = the persisted turn-1 host self-audit at `${CLAUDE_PLUGIN_DATA}/async/<run-id>/claude-audit.json`.
   - `codex_audit` = `arc codex_result "$(arc codex_target_root "<artifact_path>")" "<run-id>"`.
5. **Enter the shared procedure.** Run the **"Consolidate + Rebuttal + Append"** procedure defined in `critiquing-spec` Steps 7–9 with `{claude_audit, codex_audit, artifact: <artifact_path>, depth: close}`: consolidate (cross-confirmation surfaces first) and run the one unified sequential rebuttal cycle with T=4 concession scoring. When Step 9 would append the run, use the atomic async finalizer below instead of direct `arc state_append_run`.
6. **Append + mark resolved atomically.** After the rebuttal concludes, mint the run's `request_id` and finalize with one locked state transaction:
   ```bash
   arc state_external_run_finalize_resume \
     --run-id "<run-id>" \
     --request-id "<request_id-from-step-5>" \
     --depth close \
     --adversaries claude,codex \
     --challenge-count "<challenge_count>" \
     --concessions "<concessions>" \
     --skill-invoked critiquing-spec \
     --elapsed-ms "<elapsed_ms>"
   ```
   This appends `recent_runs[]` and sets `resolved_run_request_id` once under the same lock. If it returns rc1, the run was already resolved — do not append a duplicate; switch to inspect-only output.

This skill never dispatches new audits (that is `/critique --async`) and never auto-installs anything.
