# board

Mirror an ossify project's lifecycle onto a self-hosted Huly board. `.ossify/project-state.json`
stays the source of truth; the board is regenerated from it and never read back.

## Install

    /plugin install board@claude-agent-scaffolding

## Environment (per harness, in your shell wrapper — never in settings.json)

    HULY_URL=http://100.94.13.43:8087  HULY_WORKSPACE=pulse-labs  HULY_TOKEN=<harness token>  HULY_CLI_TELEMETRY=0

`HULY_EMAIL=<harness account email>` is optional: when set, sync self-ensures the harness
account is a member of the project's space before mirroring. Huly gates read visibility by
space membership — a non-member's writes persist but its own list reads come back empty, which
would otherwise create blind duplicates. Without it, the harness must already be a member (see
below).

## One-time workspace step

Create a space type named exactly `Ossify project` (Settings › Space types › +, category Tracker,
based on Classic project), then seed its first task type `Spine` (that type's Task types section
› +). The CLI cannot create space types or populate an empty one — `task-types create` only
copies an existing task type — so both are UI-only; the sync fills in everything else (the second
task type `Work item`, statuses, the `agent` role). Verify with:

    npx -y @firfi/huly-cli@0.48.2 task-types list --project-type "Ossify project" --json

(expect rc 0 with `Spine` in `.taskTypes[].name`).

## Commands

- `/board:sync [--bind IDENT]` — force a full reconcile; first run binds the repo to a Huly project.
- `/board:doctor` — env, reachability, binding, last sync, drift.

## Pilot

Planned bindings for the VS1 pilot, one Huly project per repo:

- pulse-trader → `PTRD`
- pulsebase → `PBASE`
- PulseHive → `PHIVE`
- PulseDB → `PDB`
- pulse-guard → `PGRD`

The exit criterion for VS1 is one week of normal work on pulse-trader with `/board:doctor`
reporting zero drift and no hand edits.

## Tests

    bash board/tests/run-all.sh
    BOARD_LIVE=1 bash board/tests/live/smoke.sh

The live smoke needs a project `SMK` created once, by hand, in Tracker with the `Ossify project`
type — typed project creation is UI-only, so the smoke can no longer create (or delete) it. Add
the harness account under Members in the create dialog (or set `HULY_EMAIL` so sync self-ensures
it).
