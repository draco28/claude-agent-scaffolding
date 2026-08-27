---
name: sync
description: Force a full reconcile of this project's ossify state onto its Huly board, or bind a repo to a Huly project the first time. Use when the user says sync the board, push to huly, bind this repo to huly, /board:sync, or after ossify state changed in a harness without hooks (Codex). Not diagnostics (/board:doctor).
---

# sync

You force the mirror. The Stop hook does this automatically after any session that changed
`.ossify/project-state.json`; this skill exists for the first binding, for harnesses without
hooks, and for "I want to see it happen now".

Every command below invokes `board` bare, from `PATH` — the harness puts each installed
plugin's `bin/` there. Never spell the path with `${CLAUDE_PLUGIN_ROOT}`: that variable is
not exported into Bash-tool subprocesses and expands empty. If `command -v board` finds
nothing, say the board plugin is not installed and stop.

## 1. Preconditions — say what is missing, then stop

Run `board env-check`. If any line says `MISSING`, tell the user which variable and where it
belongs (the harness's shell wrapper — never `~/.claude/settings.json`) and stop.
`HULY_EMAIL` is optional — its line says `not set` rather than `MISSING` and never blocks;
when set, sync self-ensures the harness account is a member of the project's space before
mirroring (Huly gates read visibility by space membership).

## 2. First run in a repo: the binding

If the user already gave an identifier (`--bind IDENT` arrived via the command), run
`board sync "$PWD" --bind IDENT` directly and skip the proposal below — never substitute
your own identifier for one the user chose. Otherwise run `board sync "$PWD"`.

- rc 4 means no binding. Propose an identifier: 2–5 upper-case characters derived from the
  project name in `.ossify/project-state.json` (`pulse-trader` → `PTRD`). Huly caps
  identifiers at 5 characters (`^[A-Z][A-Z0-9_]{0,4}$`) — never propose a longer one.
  **Ask the user to confirm or replace it** — the identifier is permanent on Huly. Then run
  `board sync "$PWD" --bind <IDENT>`.
- rc 3 with no state file is the bare-binding case (a repo not on ossify): `--bind` still
  works and mirrors nothing; say so. Derive the proposed identifier from the directory
  name here, under the same 5-character cap.
- rc 5: print the tool's message verbatim — it contains the one-time UI step for the
  `Ossify project` space type, including seeding its first task type `Spine` (the CLI can
  only copy an existing task type onto a new one, never create the first one). Stop.
- rc 6: the CLI cannot create a typed project — that is UI-only. Print the message verbatim;
  the user creates the project in Tracker by hand (name, identifier, project type
  `Ossify project`) and reruns with `--bind`.
- rc 7: the repo is already bound to a different identifier. Print the message verbatim —
  rebinding is deliberate (edit `.board/config.json`), never something you do unasked.
- rc 9: the identifier names an existing project of the wrong type (not `Ossify project`).
  Print the message verbatim; no project-scoped Huly data was mutated (the local `.board/`
  directory may already exist).

## 3. The reconcile — one pass, not two

The §2 run already reconciles when it runs at all: a JSON line with `skipped: null` **is
the result** — report it as one sentence (created, updated, unchanged, relations added) and
stop; do not run a second, forced pass on top (each pass is one CLI process per entity, so
a doubled pass doubles runtime and API load for nothing). Run `board sync "$PWD" --force`
only when §2 skipped as `"unchanged"` — the user invoked the command to see it happen now —
and report that JSON line the same way. `skipped: "bare-binding"` is the successful no-op
for a repo with no ossify state — say the binding is recorded and nothing was mirrored,
and stop (no forced pass). `skipped: "locked"` means another sync of this
workspace is running right now (usually the Stop hook) — wait for it and rerun. A non-zero
rc prints the failing step on stderr and appends to `.board/sync.log`; show both and do not
retry blindly — `AUTHENTICATION_FAILED` means the token, `NOT_FOUND` on the project means
the binding names a project that no longer exists.

## 4. What you never do

Edit anything under `.ossify/`; delete anything on Huly; "fix" the board by hand — the file
is the truth and the next sync overwrites hand edits.
