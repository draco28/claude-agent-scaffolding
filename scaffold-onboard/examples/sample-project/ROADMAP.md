# ROADMAP — todo-cli

> Derived from MASTER-SPEC.md by `/plan-roadmap` (illustrative sample).
> Demonstrates the R1 hierarchy (Phase → Sprint → Vertical Slice) and R3 demo-criteria grammar (`auto:` / `user:` with literal U+2192 → arrow).

## Roadmap overview

`todo-cli` ships in 4 phases over 12 weeks. The Foundation phase lays down the SQLite schema and capture commands. Capture-and-Query closes the daily-review loop. Recurring-and-Digest replaces the part of my Notion workflow that I rely on weekly. Polish-and-Release gates the 1.0 daily-driver milestone.

Hierarchy size: 4 phases + 8 sprints + 19 slices = **31 nodes** (under the 50-node default size class — no size-class prompt fires).

---

## Phase 1: Foundation — Weeks 1-3

The Foundation phase ships nothing user-facing yet: a SQLite-backed datastore, a `todo` binary skeleton, and the schema for todos + tags. By phase close I can `cargo run -- add "test" && cargo run -- list` and see one row.

### Sprint 1.1: Storage Bootstrap

Sprint goal: *"SQLite schema exists, migrates cleanly, survives wipe-restore."*

#### VS-1.1.1: Database init + schema migrations

Initial schema (todos, tags, todo_tags) lands with a forward-only migration runner. Demoed by initialising a fresh `~/.todo-cli/` and inspecting the schema.

##### Demo criteria

- [ ] auto: `cargo run -- db init && sqlite3 ~/.todo-cli/todos.db ".tables"` → expected: output contains pattern `todos`
- [ ] user: delete `~/.todo-cli/`, run `cargo run -- db init` → expected: directory recreated, schema fresh

#### VS-1.1.2: Backup-on-upgrade + migration safety

When a migration runs, a timestamped backup of the prior `todos.db` lands in `~/.todo-cli/backups/`. Demoed by simulating a schema bump.

##### Demo criteria

- [ ] auto: `cargo run -- db migrate --simulate-version-bump && ls ~/.todo-cli/backups/ | wc -l` → expected: pattern `^[1-9]`
- [ ] user: bump the schema version manually, run migrate → expected: backup file exists with today's date

### Sprint 1.2: CLI Skeleton + Capture

Sprint goal: *"`todo add` and `todo delete` work end-to-end against the live SQLite DB."*

#### VS-1.2.1: `todo add` with title + optional tags

Capture command parses `--tags` and writes one todo + N tag rows in a single transaction. Demoed by adding a tagged todo and inspecting the rows.

##### Demo criteria

- [ ] auto: `cargo run -- add "buy groceries" --tags errand,home && sqlite3 ~/.todo-cli/todos.db "SELECT COUNT(*) FROM todos"` → expected: pattern `^1$`
- [ ] auto: `sqlite3 ~/.todo-cli/todos.db "SELECT COUNT(*) FROM todo_tags"` → expected: pattern `^2$`

#### VS-1.2.2: `todo delete` + `todo edit`

Delete-by-id and edit-title-by-id commands. Demoed by adding, editing, deleting one todo and confirming the final state.

##### Demo criteria

- [ ] auto: `cargo run -- add "test" && cargo run -- edit 1 --title "renamed" && cargo run -- list --json | jq '.[0].title'` → expected: pattern `renamed`
- [ ] user: run `todo delete 1 --confirm`, observe interactive y/N prompt → expected: prompt shows, deletes on `y`

---

## Phase 2: Capture-and-Query — Weeks 4-6

Phase 2 closes the daily-review loop: rich `list` filtering, tag-based queries, and date-range filtering. By phase close I can run `todo list --due today --tag work` and get a useful answer.

### Sprint 2.1: List + Filter Engine

Sprint goal: *"`todo list` supports tag, status, and date-range filters with stable JSON + table output."*

#### VS-2.1.1: `todo list` with tag + status filters

`todo list --tag <name>`, `todo list --status open|done`. Demoed against a fixture of 5 todos.

##### Demo criteria

- [ ] auto: `cargo run -- list --tag errand --json | jq 'length'` → expected: pattern `^[0-9]+$`
- [ ] auto: `cargo run -- list --status open --json | jq '.[] | .status' | sort -u` → expected: pattern `"open"`

#### VS-2.1.2: Date-range filters (`--due`, `--created-since`)

Filter by due-date relative tokens (`today`, `tomorrow`, `this-week`, `overdue`) and absolute ISO dates. Demoed with a fixture spanning the week.

##### Demo criteria

- [ ] auto: `cargo run -- list --due today --json | jq 'all(.[]; .due_date == "'$(date +%Y-%m-%d)'")'` → expected: pattern `true`
- [ ] user: run `todo list --due overdue` against a fixture with one past-due item → expected: output lists exactly that item

### Sprint 2.2: Output Renderers

Sprint goal: *"List output renders cleanly to terminal table + JSON + plain markdown."*

#### VS-2.2.1: Table renderer with column auto-width

Terminal table output respects `$COLUMNS`, truncates long titles with ellipsis. Demoed by piping to `head` and inspecting alignment.

##### Demo criteria

- [ ] auto: `cargo run -- list --format table | head -3 | tail -1 | awk '{print NF}'` → expected: pattern `^[3-9]$`
- [ ] user: resize terminal to 60 columns, re-run `todo list` → expected: long titles ellipsised

#### VS-2.2.2: Markdown renderer for digests + sharing

`--format md` emits checkbox-list markdown. Demoed by piping into a `.md` file and rendering in a viewer.

##### Demo criteria

- [ ] auto: `cargo run -- list --format md | head -1` → expected: pattern `^- \[`
- [ ] user: paste markdown output into a notes app → expected: renders as a checkbox list

---

## Phase 3: Recurring-and-Digest — Weeks 7-9

Phase 3 ships the two features that replace my Notion weekly review: recurring tasks and a Monday digest. By phase close `todo-cli` is feature-complete for daily-driver use.

### Sprint 3.1: Recurring-Task Engine

Sprint goal: *"`--recur` rules generate the right next-instance dates across DST and month-boundary edges."*

#### VS-3.1.1: `--recur` rule parser + next-instance calculator

Parse rules of form `daily`, `weekly:mon`, `monthly:1`, `monthly:last`. Compute next-instance date. Demoed with a property test.

##### Demo criteria

- [ ] auto: `cargo test --test recurring -- --nocapture` → expected: exit code 0, pattern `all 12 recurring tests passed`
- [ ] auto: `cargo run -- add "rent" --recur monthly:1 && cargo run -- show 1 --json | jq '.next_instance'` → expected: pattern `^"\d{4}-\d{2}-01"$`

#### VS-3.1.2: Auto-instance materialisation on `list`

When `todo list` runs, due recurring instances materialise into concrete todos so they appear in filtered output. Demoed by listing one day after a `daily` rule.

##### Demo criteria

- [ ] auto: `cargo run -- add "standup" --recur daily && cargo run -- _internal advance-clock 1d && cargo run -- list --due today --json | jq 'length'` → expected: pattern `^[1-9]`
- [ ] user: leave a `daily` recurring todo overnight → expected: next morning's `todo list` shows it without manual action

### Sprint 3.2: Weekly Digest

Sprint goal: *"Monday `todo digest --week current` emits a markdown digest with overdue + upcoming + completed sections."*

#### VS-3.2.1: Digest renderer with three sections

Markdown digest: `## Overdue`, `## Due this week`, `## Completed last week`. Demoed against a fixture.

##### Demo criteria

- [ ] auto: `cargo run -- digest --week current --fixture week-of-2026-05-25 | grep -c '^## '` → expected: pattern `^3$`
- [ ] auto: `cargo run -- digest --week current --json | jq 'keys | length'` → expected: pattern `^3$`

#### VS-3.2.2: Digest delivery (stdout + file + clipboard)

Three delivery channels: stdout (default), `--output file` writes to `~/Documents/todo-digest-YYYY-WW.md`, `--output clipboard` copies (macOS `pbcopy` / Linux `xclip`).

##### Demo criteria

- [ ] auto: `cargo run -- digest --week current --output file && ls ~/Documents/todo-digest-*.md | wc -l` → expected: pattern `^[1-9]`
- [ ] user: run `todo digest --output clipboard`, paste into an editor → expected: full digest text appears

#### VS-3.2.3: Monday cron install

`todo schedule install --weekly` writes a cron entry (or LaunchAgent on macOS) firing the digest at Monday 8am. Demoed by inspecting `crontab -l`.

##### Demo criteria

- [ ] auto: `cargo run -- schedule install --weekly --dry-run` → expected: exit code 0, output contains pattern `0 8 * * 1`
- [ ] user: wait until next Monday morning → expected: digest file appears in `~/Documents/`

---

## Phase 4: Polish-and-Release — Weeks 10-12

Phase 4 gates the 1.0 daily-driver milestone: distribution channels, observability, and a 4-week real-use trial.

### Sprint 4.1: Distribution + Logging

Sprint goal: *"`cargo install todo-cli` works end-to-end; structured logs land in `~/.todo-cli/logs/`."*

#### VS-4.1.1: `cargo install` packaging + Homebrew formula

`Cargo.toml` metadata complete; static binary builds for macOS + Linux; Homebrew tap formula published. Demoed by installing from a clean machine.

##### Demo criteria

- [ ] auto: `cargo install --path . && which todo-cli` → expected: pattern `/.cargo/bin/todo-cli`
- [ ] user: `brew install draco28/todo-cli/todo-cli` on a fresh macOS box → expected: `todo-cli --version` prints version

#### VS-4.1.2: Structured logging + `todo log tail`

Every mutating command appends a JSONL line to `~/.todo-cli/logs/todo.jsonl`. `todo log tail -n N` reads the tail.

##### Demo criteria

- [ ] auto: `cargo run -- add "x" && cargo run -- log tail -n 1 --json | jq '.event'` → expected: pattern `"todo_added"`
- [ ] auto: `jq -e . ~/.todo-cli/logs/todo.jsonl | wc -l` → expected: pattern `^[1-9]`

### Sprint 4.2: Daily-Driver Trial + 1.0

Sprint goal: *"4 consecutive weeks of daily-driver use without falling back to Notion. Cut 1.0."*

#### VS-4.2.1: 4-week real-use trial

Self-trial: I use `todo-cli` exclusively for 4 weeks, log friction in `docs/trial-notes.md`. Demoed by trial-notes commit history.

##### Demo criteria

- [ ] user: after week 4, count Notion-todo accesses in browser history → expected: zero
- [ ] user: write trial-summary in `docs/trial-notes.md` → expected: 4 weekly entries, no "had to fall back to Notion" notes

#### VS-4.2.2: 1.0 release cut

Bump version to 1.0.0; tag; cut Homebrew + cargo + GitHub Release. Update CHANGELOG.

##### Demo criteria

- [ ] auto: `git tag --list | grep '^v1.0.0$'` → expected: pattern `v1.0.0`
- [ ] user: install `todo-cli@1.0.0` from a fresh box → expected: `todo-cli --version` prints `1.0.0`

---

## Hierarchy summary

- **4 phases:** Foundation, Capture-and-Query, Recurring-and-Digest, Polish-and-Release
- **8 sprints:** 2 per phase
- **19 vertical slices:** 2-3 per sprint, each with 2 demo criteria
- **Total node count:** 4 + 8 + 19 = **31** (under the ≤50-node default; no size-class prompt fires)

Demo criteria use the literal Unicode arrow (→), NEVER the ASCII `->`. Slice IDs follow `VS-<phase>.<sprint>.<slice>` (the canonical 3-part identifier; cross-plugin consumer-contract alignment tracked in #28).
