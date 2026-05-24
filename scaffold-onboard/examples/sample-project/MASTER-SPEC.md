# todo-cli — Master Specification (illustrative sample)

> **NOTE:** This is an illustrative sample for `scaffold-onboard/examples/sample-project/`. It is **NOT** validatable by `sf_spec_validate` — it omits the `<!-- master-spec:phase id=N -->` HTML markers required by `lib/parser.sh` and several enum-driven fields. To see a real, validatable MASTER-SPEC, run `/onboard` against a real project.

**Spec version:** 1.0
**Project class:** CLI tool
**Status:** Illustrative sample only

---

## Executive Summary

`todo-cli` is a single-user terminal todo manager with SQLite local storage, tag-based filtering, recurring tasks, and weekly digest output. The motivating problem is that existing TUI/CLI todo tools either store data in opaque cloud silos or use plain-text formats that don't scale past ~200 active items. `todo-cli` keeps storage local (SQLite), supports rich queries (tag filters, date ranges, recurring tasks), and emits a Monday-morning markdown digest of upcoming/overdue items.

The 6-month MVP horizon is *"replace my current Notion-based personal todo list."* The 18-month value horizon adds shared-list sync (via a local-first sync protocol), an `ask` interactive query mode, and pluggable notifier backends (terminal banner + system notification).

---

## Phase 1: Foundation

### 1.1 Vision & Problem

**Pitch:** A terminal todo tool that keeps everything local, scales to thousands of items, and surfaces the right next action without requiring me to remember filters.

**Problem:** Cloud-based todo tools lock data behind vendor APIs and feel sluggish on a slow connection. Plain-text systems (TODO.md, taskwarrior data files) don't index well and break down past a few hundred items.

**6-month success:** `todo-cli` is my primary daily-driver for personal task management; I've stopped opening Notion for todo capture.

### 1.2 Users & Use cases

**Primary user:** me (single-user, single-machine — multi-device sync is Phase 5+ scope).

**Core use cases:**
- Quick capture (`todo add "buy groceries" --tags errand`)
- Daily review (`todo list --due today`)
- Weekly digest (`todo digest --week current`)
- Recurring tasks (`todo add "pay rent" --recur monthly:1`)

### 1.3 Project class & MVP

**Project class:** CLI tool

**MVP cut:** capture (add/edit/delete), list with filters, tag indexing, recurring tasks, Monday digest. Sync, ask-mode, and notifier are post-MVP.

---

## Phase 2: Strategy

### 2.1 Timeline & Resources

**Target weeks to MVP:** 12

**Team size:** 1 (solo, evenings + weekends).

### 2.2 Constraints

**Monthly budget cap:** $0 (no SaaS / API costs).

**Top risks:** scope-creep into multi-device sync; SQLite schema rework if I miss a core query pattern; recurring-task edge cases (DST, month-boundary).

### 2.3 Success criteria

I use `todo-cli` daily for 4 consecutive weeks and stop reaching for Notion.

---

## Phase 3: Architecture

### 3.1 Stack

Rust binary, SQLite via `rusqlite`, `clap` for CLI parsing, `serde` for serialisation. No network code in MVP. Distribution via `cargo install` and a one-line Homebrew formula.

### 3.2 Data shape

Single SQLite file at `~/.todo-cli/todos.db`. Three tables: `todos`, `tags`, `todo_tags` (join). Recurring tasks stored as a `recur_rule` column on `todos` parsed at runtime — not denormalised into individual instances.

### 3.3 Storage location

`~/.todo-cli/` — single directory holding SQLite DB + logs. Backup is "tar up the directory".

---

## Phase 4: Quality

### 4.1 Testing

`cargo test` for unit + integration. End-to-end via a `tests/cli/` directory that spawns the compiled binary against a temp `TODO_CLI_HOME`. Coverage floor of 70% on `src/storage/` (the SQLite layer is where bugs hide).

### 4.2 Observability

Structured logs to `~/.todo-cli/logs/todo.jsonl` on every mutating command. `todo log tail` reads the log. No telemetry to remote.

---

## Phase 5: Delivery

### 5.1 Channels

`cargo install todo-cli` for the Rust ecosystem; a Homebrew tap for macOS users; statically-linked binary uploaded to GitHub Releases for direct download.

### 5.2 Versioning

SemVer; pre-1.0 (`0.x.y`) until I've daily-driven for 4+ weeks. Then 1.0.

---

## Phase 6: Lifecycle

### 6.1 Maintenance cadence

Weekly: triage issues, merge ready PRs. Monthly: cut a release if there are merged changes.

### 6.2 Deprecation policy

Schema migrations forward-only with automatic backup on first run after upgrade.

---

## Phase 7: Decision Record

### 7.1 Open decisions

- D1: Should the digest be markdown-only or also offer HTML?
- D2: How aggressive should the recurring-task "auto-skip past instances" logic be?

### 7.2 Closed decisions

- C1: SQLite over plain-text JSON for storage (closed; SQLite wins on query performance past ~500 items).
- C2: Rust over Go (closed; preferred ergonomics + `clap` derive macros).

---

## Phase 8: People & Comms

Solo project; no comms beyond GitHub issues + a personal CHANGELOG. No Slack, no Discord.

---

## Phase 9: Compliance

No PII collected beyond what the user voluntarily types into todos. Storage is local-only. No GDPR / SOC2 surface area in MVP.

---

## Phase 10: Behavioral Discipline (opt-in)

Karpathy behavioral discipline section included per Phase 10.4. Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT).

---

*End of illustrative MASTER-SPEC. See `ROADMAP.md` for the R1 hierarchy derived from this spec, and `.claude/memory-bank/03-code-patterns.md` for R2 machine-checkable rules.*
