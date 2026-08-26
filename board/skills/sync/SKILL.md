---
name: sync
description: Force a full reconcile of this project's ossify state onto its Huly board, or bind a repo to a Huly project the first time. Use when the user says sync the board, push to huly, bind this repo to huly, /board:sync, or after ossify state changed in a harness without hooks (Codex). Not diagnostics (/board:doctor).
---

# sync

You force the mirror. The Stop hook does this automatically after any session that changed
`.ossify/project-state.json`; this skill exists for the first binding, for harnesses without
hooks, and for "I want to see it happen now".

## 1. Preconditions — say what is missing, then stop

Run `bash ${CLAUDE_PLUGIN_ROOT}/bin/board env-check`. If any line says `MISSING`, tell the
user which variable and where it belongs (the harness's shell wrapper — never
`~/.claude/settings.json`) and stop.

## 2. First run in a repo: the binding

Run `bash ${CLAUDE_PLUGIN_ROOT}/bin/board sync "$PWD"`.

- rc 4 means no binding. Propose an identifier: 2–6 upper-case letters derived from the
  project name in `.ossify/project-state.json` (`pulse-trader` → `PTRD`; no state file →
  from the directory name). **Ask the user to confirm or replace it** — the identifier is
  permanent on Huly. Then run `bash ${CLAUDE_PLUGIN_ROOT}/bin/board sync "$PWD" --bind <IDENT>`.
- rc 3 with no state file is the bare-binding case (a repo not on ossify): `--bind` still
  works and mirrors nothing; say so.
- rc 5: print the tool's message verbatim — it contains the one-time UI step for the
  `Ossify project` space type. Stop.
- rc 6: the typed create did not yield a Tracker project. Print the message verbatim; the
  user creates the project in Tracker with the `Ossify project` type and reruns with `--bind`.

## 3. Force the reconcile

Run `bash ${CLAUDE_PLUGIN_ROOT}/bin/board sync "$PWD" --force` and report the JSON line it
prints as one sentence: created, updated, unchanged, relations added. A non-zero rc prints
the failing step on stderr and appends to `.board/sync.log`; show both and do not retry
blindly — `AUTHENTICATION_FAILED` means the token, `NOT_FOUND` on the project means the
binding names a project that no longer exists.

## 4. What you never do

Edit anything under `.ossify/`; delete anything on Huly; "fix" the board by hand — the file
is the truth and the next sync overwrites hand edits.
