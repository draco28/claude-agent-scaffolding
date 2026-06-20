# Per-work-item dispatch — Claude subagent + Codex backend (§8.3)

Referenced by `planning-vertical-slice` §8.3. The body resolves the backend (`sd backend_resolve`, precedence: per-invocation `--backend` override > manifest `.implementer_backend` > default `claude_subagent`) and keeps the manual fresh-session handoff as a first-class path for either backend. This file holds the two dispatch templates.

## 8.3a — `claude_subagent` (default)

Dispatch each work item in the round with:

```text
Task(
  subagent_type="scaffold-dev:implementer-agent",
  description="Execute work item ${work_id}",
  prompt="""
    Read handoff at <abs path to work-${work_id}-${kebab}/handoff.md>
    and execute the work item per its instructions.

    Your worktree: <abs path to ${worktrees_dir}/sprint-${sprint_id}/work-${work_id}-${kebab}>
    Use this path for all git operations and file edits in canonical.

    First turn: PRE-FLIGHT CHECK (per SPEC §6.2).
    Return structured response (gaps-surfaced | complete) per the multi-call protocol.
  """
)
```

The `scaffold-dev:` prefix on `subagent_type` is **load-bearing** — that's the registered custom subagent type per SPEC §6.1. Do NOT use the bare `implementer-agent` or any other prefix.

## 8.3b — `codex` (optional backend, SS-5)

The Codex backend dispatches the **same** work item to the externally-installed `codex-plugin-cc` companion through `lib/codex.sh`, under the **same** `{mode,…}` contract, gaps-mode escalation, and no-commit boundary as the Claude path. The only new surface is async liveness — Codex is an external process, so the orchestrator polls for the surface. **Dispatch Codex work items sequentially within a round** (the companion's `--resume-last` resolves the latest session thread; concurrent same-session tasks race).

Per work item (let `WT` = the absolute worktree path):

1. **Pre-flight — hard gate, no silent fallback.**
   ```bash
   sd codex_preflight "$WT"
   ```
   rc≠0 → **STOP** and surface the remediation (§12.2). Do NOT fall back to Claude — the user explicitly chose Codex; quietly running Claude would violate intent.

2. **Assemble the prompt-file.** Codex does not auto-load the skill, so the contract is prompt-carried. Write a temp prompt file outside the worktree (e.g. under `${TMPDIR:-/tmp}`), not `$WT/.codex-prompt.md`, containing, in order: the full `executing-work-item` contract (read it from the installed scaffold-dev skill as the single source of truth, else treat the handoff's embedded constraints as binding); `Read the handoff at <abs handoff.md> and execute the work item per its instructions.`; `Your worktree: $WT — use it for all git operations and file edits.`; the no-commit prohibition `NEVER run git commit / push / pull / fetch; never launch nested subagents.`; and the return-contract instruction: *end your turn with a single fenced ```json block holding `{mode, report_path, summary, stage_status, gaps}` exactly as the Claude implementer returns; if pre-flight surfaces blocking gaps, emit `{"mode":"gaps-surfaced","gaps":[…]}` and stop.* Remove the temp prompt file after `sd codex_dispatch` returns a job id.

3. **Record baseline + dispatch + watch:**
   ```bash
   baseline="$(git -C "$WT" rev-parse HEAD)"
   prompt_file="$(mktemp "${TMPDIR:-/tmp}/sd-codex-prompt.XXXXXX.md")"
   trap 'rm -f "$prompt_file"' EXIT INT TERM
   # write the Codex prompt contract to "$prompt_file"
   job="$(sd codex_dispatch "$WT" "$prompt_file" [--model M] [--effort E])"
   rm -f "$prompt_file"
   trap - EXIT INT TERM
   term="$(sd codex_wait "$WT" "$job")"   # background+poll+stall+cap; one of: completed|failed|cancelled|stalled|capped|error
   ```

4. **No-commit verify immediately after wait** — before any failure/malformed exit path:
   ```bash
   if ! verdict="$(sd codex_verify_nocommit "$WT" "$baseline")"; then
     # commit-violation or helper usage failure: surface loudly before any retry/menu
   fi
   ```
   rc≠0 / `commit-violation` → surface loudly; the orchestrator decides remediation. This runs even when `term` is `failed`/`cancelled`/`stalled`/`capped`/`error`, because an aborted or malformed Codex run may still have moved `HEAD`. Any `term` other than `completed` → surface the failure-response menu (§12.2 "Subagent crash/timeout" row) only after the no-commit verdict is clean; `sd codex_wait` already cancelled a stalled/capped job (recoverable — re-dispatch via `--resume-last` or fall back to a manual session).

5. **Read the return** (only on `completed`):
   ```bash
   if ! out="$(sd codex_result "$WT" "$job")"; then
     # no-commit already verified above; route to §8.4 malformed-return menu
   fi
   ```

6. **Judge dirtiness before trusting a complete result.** A `complete` return with `ok-clean` (no staged/working-tree changes) is suspect → treat as a malformed/empty return; a `gaps-surfaced` return with `ok-clean` is expected.

7. **Join the Claude downstream unchanged.** The `{mode,…}` object feeds §8.4 exactly as a Claude subagent return would: `gaps-surfaced` → clarify + re-dispatch (Codex via `--resume-last`); `complete` → read `report.md`, proceed to §8.5 verification. Everything from here is backend-agnostic.
