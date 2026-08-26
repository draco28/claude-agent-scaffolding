# board

Mirror an ossify project's lifecycle onto a self-hosted Huly board. `.ossify/project-state.json`
stays the source of truth; the board is regenerated from it and never read back.

## Install

    /plugin install board@claude-agent-scaffolding

## Environment (per harness, in your shell wrapper — never in settings.json)

    HULY_URL=http://100.94.13.43:8087  HULY_WORKSPACE=pulse-labs  HULY_TOKEN=<harness token>  HULY_CLI_TELEMETRY=0

## One-time workspace step

Create a space type named exactly `Ossify project` (Settings › Space types › +, category Tracker,
based on Classic project). The CLI cannot create space types; the sync fills in everything else.

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
