---
scenario_id: 05-clean-set-applies
expected_outcome: apply-all
expected_reason: nothing warrants a refusal, a stop, or a skip — both entries land, the missing live file is seeded with its real structure, and "wrote 2, skipped 0" goes to the close summary
---
Spine close step 9 in release `r1` — the first harvest this workspace has ever
run. The accepted set holds two entries:

1. `[report] r1.s1.w1` — a caveat about the CLI swallowing a trailing newline,
   to `09-known-issues.md`.
2. `[handoff] work-r1.s1.w2/handoff.md` — a decision recorded as a mid-flight
   clarification: ULIDs over UUIDv4 for the event ids, with the rationale, to
   `10-decisions-log.md`.

The manifest's route is `${ai_workspace.root}/.claude/memory-bank` — the token
form workspace-init writes — and the manifest's `ai_workspace.root` is
present. `09-known-issues.md` exists and holds two unrelated entries from
onboarding; `10-decisions-log.md` does not exist yet. Nothing in either file
resembles either accepted entry.

The operator asks for the apply to be performed and the ceremony moved along
to cleanup.
