# Example ROADMAP.md — Fully-Worked Hierarchy

> Companion reference for `planning-project-roadmap` §4 + §11. A fictional **4-phase, 12-sprint, ~30-slice** roadmap demonstrating the data shape from SPEC §7.1, the 3-timelines framing applied end-to-end, and the demo-criteria `auto:` / `user:` grammar with the literal Unicode arrow (→).
>
> **Fictional project:** *PipelinePulse* — an internal sales-pipeline analytics CLI that pulls from Salesforce, normalises into PulseDB, and surfaces weekly deal-health digests for an account-executive team. Used as a worked example only; not a real product.

---

# ROADMAP — PipelinePulse

> Derived from MASTER-SPEC.md by `/plan-roadmap` on 2026-06-15.
> Co-edited by user + scaffold-dev orchestrator over time.

## Roadmap overview

PipelinePulse exists because the AE team currently runs deal-health reviews by hand: someone exports Salesforce CSVs every Monday morning, pastes them into a spreadsheet, eyeballs which deals slipped a stage, and emails a digest. That ritual takes ~3 hours a week, gets skipped during quota crunch, and the digest itself has no historical trend — only a snapshot.

The 5-year shape is an internal CLI (`pulsepipe`) that owns the full pipeline: pulls Salesforce data into a local PulseDB store, runs deal-health heuristics historically, and emits weekly digests automatically with trend deltas (*"3 deals slipped this week vs. 1 last week"*). The visionary horizon is *every AE gets a Monday-morning digest with no manual export* and *managers can ask the CLI ad-hoc questions about pipeline shape*.

The 12-18 month value horizon is owned ingestion + a digest that's good enough to replace the spreadsheet ritual, followed by a query layer that answers the most common manager questions without writing SQL. The 90-day visibility horizon decomposes each of those into demoable cycles — first ingestion of a single Salesforce object, then a digest scaffold, then trend deltas, then ad-hoc queries, then richer history.

---

## Phase 1: Foundation — Q3 2026

The Foundation phase ships the bottom of the stack: a reproducible local datastore plus a Salesforce-ingestion pipeline that the rest of PipelinePulse builds on. At 5-year shape, "Foundation" is the layer that exists *before anyone runs a useful command* — once it's done, every downstream phase reuses it without re-thinking storage or ingestion.

By Phase 1 close the AE team has nothing user-facing yet, but the engineering team can replay any week of Salesforce history locally, write one-off SQL against PulseDB, and ingest fresh data on demand. The Foundation is the substrate, not the product.

### Sprint 1.1: PulseDB Bootstrap

Stand up a local PulseDB instance with the deal/opportunity/account schema, migrations, and a healthcheck command. The sprint goal is *"PulseDB exists locally, schema matches Salesforce shape, can survive a wipe-and-restore."* Closes when an engineer can `pulsepipe db init && pulsepipe db migrate && pulsepipe db status` cleanly.

#### VS-1.1.1: Database bootstrap + healthcheck

Initial PulseDB schema lands with deal/opportunity/account/contact tables and migration runner. Demoed by initialising a fresh DB and showing the schema introspection output.

##### Demo criteria

- [ ] auto: `pulsepipe db init && pulsepipe db status` → expected: exit code 0, prints `schema: 4 tables`
- [ ] user: open a fresh shell and run `pulsepipe db init` against an empty PULSE_HOME → expected: directory created, no errors

#### VS-1.1.2: Migration roll-forward + wipe-restore

Migration scripts numbered + idempotent; full DB wipe-and-restore from migrations works end-to-end. Demoed by dropping the DB, re-running migrations, confirming row counts match a seeded fixture.

##### Demo criteria

- [ ] auto: `pulsepipe db wipe --yes && pulsepipe db migrate && pulsepipe db seed --fixture demo` → expected: exit code 0, prints `seeded 50 deals`
- [ ] auto: `pulsepipe db diff --against schema-baseline.sql` → expected: pattern `no schema drift`

### Sprint 1.2: Salesforce Ingestion (Read-Only)

Build the SF ingestion path: API auth, a fetch loop for a single object (deals), incremental delta sync, and write into PulseDB. Sprint goal: *"Engineer can pull last 30 days of deals from sandbox into PulseDB and re-pull idempotently."* Closes when re-running ingestion produces zero duplicates and re-syncs only changed rows.

#### VS-1.2.1: Salesforce auth + single-object pull

OAuth flow against SF sandbox, fetch all deals modified in last 30 days, persist into PulseDB. Demoed by running the ingestion once and showing row counts.

##### Demo criteria

- [ ] auto: `pulsepipe ingest deals --since 30d --sandbox` → expected: exit code 0, prints `ingested N deals` where N>0
- [ ] user: confirm SF sandbox credentials work via the OAuth device flow → expected: token cached at `~/.pulsepipe/sf-token.json`

#### VS-1.2.2: Incremental delta sync (no duplicates)

Re-run ingestion is idempotent; only changed rows update; `last_synced_at` tracked per object. Demoed by running ingestion twice and asserting unchanged rows aren't re-written.

##### Demo criteria

- [ ] auto: `pulsepipe ingest deals --since 30d && pulsepipe ingest deals --since 30d` → expected: exit code 0, second run prints `0 new, 0 updated`
- [ ] auto: `pulsepipe db inspect deals --where 'updated_at > ?' --param "$(date -v-1H +%s)"` → expected: pattern `0 rows`

### Sprint 1.3: Multi-Object Ingestion + Operational Hardening

Extend ingestion to opportunities + accounts + contacts; add retry/backoff on SF rate limits; add `pulsepipe ingest --all`. Sprint goal: *"All four objects ingest reliably, including 429 rate-limit handling."*

#### VS-1.3.1: Opportunity + account + contact ingestion

Each new object follows the same pattern as deals: auth-aware fetch, incremental delta, idempotent re-run. Demoed by `pulsepipe ingest --all` populating all four tables.

##### Demo criteria

- [ ] auto: `pulsepipe ingest --all --since 30d` → expected: exit code 0, prints `ingested deals, opportunities, accounts, contacts`
- [ ] user: inspect PulseDB after ingest → expected: all four tables have non-zero rows for the last 30 days

#### VS-1.3.2: Rate-limit retry + observability

Hit SF rate limit deliberately (or via mock), confirm exponential backoff kicks in; structured logs to `~/.pulsepipe/logs/ingest.jsonl`. Demoed by replaying a 429 fixture and showing the retry log entries.

##### Demo criteria

- [ ] auto: `PULSEPIPE_SF_MOCK=rate_limit pulsepipe ingest deals --since 1d` → expected: exit code 0, log contains pattern `retry attempt 1`
- [ ] auto: `jq '.event' ~/.pulsepipe/logs/ingest.jsonl | tail -5` → expected: pattern `ingest_complete`

---

## Phase 2: Digest Replacement — Q4 2026

Phase 2 ships the first user-facing value: a weekly digest that replaces the manual spreadsheet ritual. The 5-year shape of this phase is *"AEs and managers wake up Monday to a useful digest without anyone running an export."* At phase close, the team has stopped doing the Monday-morning spreadsheet — that's the visionary milestone.

The digest is plain markdown (or email-rendered) and covers four deal-health signals: stage stalls, slipped close dates, large-deal anomalies, and quota-pace warnings. The signals are the *minimum viable replacement* for what the spreadsheet currently surfaces.

### Sprint 2.1: Digest Scaffold

Stand up `pulsepipe digest --week current` as a command that reads PulseDB and emits a markdown digest skeleton (no real signals yet — placeholder sections). Sprint goal: *"The shape of the digest exists; we can iterate on signal quality without re-writing the rendering layer."*

#### VS-2.1.1: Digest renderer + section skeleton

Markdown renderer with four placeholder sections (stage stalls, slipped close dates, large-deal anomalies, quota-pace). Demoed by running `pulsepipe digest` and showing the four sections with mock data.

##### Demo criteria

- [ ] auto: `pulsepipe digest --week 2026-W40 --mock` → expected: exit code 0, output contains pattern `## Stage stalls`
- [ ] user: render the digest to email-safe HTML via `pulsepipe digest --format html` → expected: opens cleanly in mail client

#### VS-2.1.2: Digest delivery (file + stdout + clipboard)

Three output paths: write to `~/Documents/pulsepipe/digest-YYYY-WW.md`, print to stdout, copy to clipboard. Demoed by running with each flag combination.

##### Demo criteria

- [ ] auto: `pulsepipe digest --week current --output file` → expected: exit code 0, creates file matching `~/Documents/pulsepipe/digest-*.md`
- [ ] user: run `pulsepipe digest --output clipboard` and paste into a notes app → expected: full digest text appears

### Sprint 2.2: Stage-Stall + Slipped-Close Signals

Implement the first two real signals: deals stalled in same stage >14 days, and deals where close_date moved backward in the last week. Sprint goal: *"Two of four signals produce real outputs that match what the spreadsheet would have flagged."*

#### VS-2.2.1: Stage-stall signal

Heuristic: any deal in same stage for >14 days, weighted by amount. Outputs top 10 in the digest's stage-stall section. Demoed against a fixture with known stalled deals.

##### Demo criteria

- [ ] auto: `pulsepipe digest --week 2026-W40 --fixture stalls-fixture.json` → expected: exit code 0, output contains pattern `stalled \d+ days`
- [ ] auto: `pulsepipe signal stage-stall --threshold 14 --json | jq 'length'` → expected: pattern `^[1-9]`

#### VS-2.2.2: Slipped-close-date signal

Detect deals where close_date moved backward >=7 days in the last week. Compare to historical close_date snapshots in PulseDB. Demoed by injecting a synthetic slip into the fixture.

##### Demo criteria

- [ ] auto: `pulsepipe signal slipped-close --window 7d --json` → expected: exit code 0, pattern `"days_slipped":`
- [ ] user: review the digest's "slipped close dates" section against last week's spreadsheet → expected: same deals flagged

### Sprint 2.3: Large-Deal-Anomaly + Quota-Pace Signals

Implement remaining two signals plus a digest acceptance test. Sprint goal: *"All four signals in the digest, AE team agrees this replaces the spreadsheet, ritual is officially retired."*

#### VS-2.3.1: Large-deal-anomaly signal

Heuristic: deals >2x the AE's median deal size that changed stage in the last week. Surfaces unusual movement on big deals. Demoed against fixture.

##### Demo criteria

- [ ] auto: `pulsepipe signal large-deal-anomaly --multiplier 2 --json | jq 'length'` → expected: pattern `^[0-9]`
- [ ] user: confirm digest highlights the same large-deal movement that an AE would have flagged manually → expected: overlap >=80%

#### VS-2.3.2: Quota-pace signal + AE sign-off

Quota-pace heuristic (closed-won YTD vs. linear quota pace) + a 1-week trial with the AE team where they receive both spreadsheet and `pulsepipe` digest. Demoed by AE team sign-off ("we don't need the spreadsheet anymore").

##### Demo criteria

- [ ] auto: `pulsepipe signal quota-pace --ae alice@example.com --json` → expected: exit code 0, pattern `"pace_ratio":`
- [ ] user: AE lead signs off via written confirmation that PipelinePulse digest replaces the spreadsheet ritual → expected: sign-off recorded in `docs/decisions/`

#### VS-2.3.3: Weekly cron + digest archive

Cron entry runs ingestion + digest every Monday 6am local; archived digests land in `~/Documents/pulsepipe/digest-history/`. Demoed by inspecting the archive after a simulated week-roll.

##### Demo criteria

- [ ] auto: `pulsepipe schedule install --weekly && crontab -l | grep pulsepipe` → expected: pattern `0 6 * * 1`
- [ ] user: wait one Monday morning and check digest arrives in archive folder → expected: file `digest-2026-WNN.md` exists

---

## Phase 3: Query Layer — Q2 2027

Phase 3 ships the second visionary milestone: managers can ask the CLI ad-hoc questions ("which deals over $50k stalled in the last 30 days?") without writing SQL. At the 5-year horizon, this is when PipelinePulse stops being "the digest tool" and becomes "the pipeline brain" — anything a manager would ask gets a one-line CLI answer.

The query layer is a constrained DSL over PulseDB, not full SQL. The constraint is deliberate: managers shouldn't have to learn joins, but should get rich answers for the 20 most-asked questions. Phase 3 ships the DSL + the first 20 query templates.

### Sprint 3.1: Query DSL Foundation

Design + ship the constrained query DSL: noun-verb-filter shape (e.g., `deals stalled >14d amount >50k`). Sprint goal: *"DSL parses, plans, and executes 5 representative queries end-to-end."*

#### VS-3.1.1: DSL parser + query planner

Tokenise + parse the DSL into an AST; plan into PulseDB SQL behind the scenes. Demoed by `pulsepipe query "deals stalled >14d"` returning rows.

##### Demo criteria

- [ ] auto: `pulsepipe query "deals stalled >14d" --format json | jq 'length'` → expected: pattern `^[0-9]`
- [ ] auto: `pulsepipe query --explain "deals stalled >14d amount >50k"` → expected: output contains pattern `JOIN deals`

#### VS-3.1.2: Query result rendering (table + json + markdown)

Three output renderers for query results. Demoed by piping into each format.

##### Demo criteria

- [ ] auto: `pulsepipe query "deals stage='proposal'" --format table` → expected: exit code 0, output contains pattern `\| deal_id`
- [ ] user: copy a markdown-rendered result into Slack → expected: renders as a markdown table

### Sprint 3.2: Query Template Library (20 templates)

Pre-baked templates for the 20 most-asked manager questions. Sprint goal: *"Manager runs `pulsepipe ask` (interactive) or `pulsepipe query --template stalls-over-50k` and gets the right answer."*

#### VS-3.2.1: Template library + browser command

Ship 20 query templates with metadata (description, parameters). `pulsepipe templates list` shows all available. Demoed by listing + running 3 templates.

##### Demo criteria

- [ ] auto: `pulsepipe templates list | wc -l` → expected: pattern `^2[0-9]`
- [ ] auto: `pulsepipe query --template stalls-over-50k --param threshold=14` → expected: exit code 0, output contains pattern `deal_id`

#### VS-3.2.2: Interactive `ask` mode

Conversational interactive mode: `pulsepipe ask` prompts user for the question, suggests matching templates, runs the best fit. Demoed by typing a natural-language question and getting a result.

##### Demo criteria

- [ ] user: run `pulsepipe ask` and type *"which big deals stalled?"* → expected: suggests `stalls-over-50k` template, runs it
- [ ] auto: `echo "show me slipped deals" | pulsepipe ask --no-tty` → expected: exit code 0, output contains pattern `slipped`

### Sprint 3.3: Query Performance + History

Index hot query paths in PulseDB; ship a query-history log; warn on slow queries. Sprint goal: *"Queries return in <200ms median, manager sees their query history, slow queries warn at runtime."*

#### VS-3.3.1: PulseDB indexes + query benchmark

Add indexes on `deals(stage, updated_at)`, `deals(amount)`, `deals(close_date)`. Run a benchmark suite of the 20 templates and assert p50 <200ms. Demoed by benchmark output.

##### Demo criteria

- [ ] auto: `pulsepipe bench --templates all --json | jq '.p50_ms'` → expected: pattern `^[0-1][0-9]{0,2}$`
- [ ] auto: `pulsepipe db inspect --indexes deals | wc -l` → expected: pattern `^[3-9]`

#### VS-3.3.2: Query history + slow-query warnings

Every `query` / `ask` run is logged to `~/.pulsepipe/history.jsonl`. Queries >500ms emit a warning. Demoed by running history command + replaying a known slow query.

##### Demo criteria

- [ ] auto: `pulsepipe query "deals stage='proposal'" && pulsepipe history --last 1 --json | jq '.duration_ms'` → expected: pattern `^[0-9]+$`
- [ ] user: deliberately run a slow query and observe the warning → expected: stderr contains pattern `slow query`

---

## Phase 4: Trend Intelligence — H2 2027

Phase 4 is the "intelligence" phase — at 5-year shape, PipelinePulse stops being reactive (digest, query) and becomes proactive (alerts, trend deltas, forecasts). Managers stop asking the CLI questions because the CLI is already telling them the answers.

The visionary milestone is *"managers spend more time acting on PipelinePulse output than generating it."* Practically, that means trend alerts that surface BEFORE the Monday digest, simple pipeline forecasts, and a per-AE coaching summary.

### Sprint 4.1: Trend Alerts (Push, Not Pull)

Cron-driven trend alerts that fire when PulseDB metrics cross thresholds (e.g., "stage-stall count up 2x week-over-week"). Sprint goal: *"Manager receives <=3 alerts/week that they act on."*

#### VS-4.1.1: Alert engine + threshold config

Alert config in `~/.pulsepipe/alerts.yml`; daily cron evaluates thresholds, emits to a notifier (email/slack stub). Demoed by triggering a synthetic alert.

##### Demo criteria

- [ ] auto: `pulsepipe alerts run --once --mock-threshold-cross` → expected: exit code 0, output contains pattern `alert fired`
- [ ] user: edit `alerts.yml` and add a custom threshold → expected: `pulsepipe alerts validate` exits 0

#### VS-4.1.2: Alert notifier (email + Slack webhook)

Pluggable notifier backends; ship email (SMTP) + Slack webhook. Demoed by firing a test alert to each.

##### Demo criteria

- [ ] auto: `PULSEPIPE_NOTIFIER=stdout pulsepipe alerts test` → expected: exit code 0, stdout pattern `[ALERT]`
- [ ] user: configure a real Slack webhook and run `pulsepipe alerts test --notifier slack` → expected: message arrives in Slack

### Sprint 4.2: Pipeline Forecast

Simple linear forecast: project current pipeline forward based on historical stage-conversion rates. Sprint goal: *"Manager gets a 'projected closed-won by EOQ' number with confidence interval."*

#### VS-4.2.1: Stage-conversion-rate model

Compute historical stage-to-stage conversion rates per AE (last 90 days). Demoed by inspecting the model output for a known AE.

##### Demo criteria

- [ ] auto: `pulsepipe forecast model --ae alice@example.com --json | jq '.conversions | length'` → expected: pattern `^[1-9]`
- [ ] auto: `pulsepipe forecast model --backtest --window 30d` → expected: exit code 0, output pattern `mae:`

#### VS-4.2.2: EOQ forecast with confidence interval

Project pipeline forward to end-of-quarter using the conversion model + a bootstrap CI. Demoed by running `pulsepipe forecast eoq`.

##### Demo criteria

- [ ] auto: `pulsepipe forecast eoq --json | jq '.projected_closed_won'` → expected: pattern `^[0-9]+$`
- [ ] user: compare EOQ projection against manager's intuition for the team → expected: within ~15%

### Sprint 4.3: Per-AE Coaching Summary

A per-AE weekly summary surfacing pipeline composition, stage progression rate, and a coaching prompt. Sprint goal: *"Each AE gets a personal weekly read; manager uses it as 1:1 input."*

#### VS-4.3.1: Per-AE pipeline composition card

Markdown card per AE: deal count by stage, total ACV, week-over-week movement. Demoed by rendering one AE's card.

##### Demo criteria

- [ ] auto: `pulsepipe coach card --ae alice@example.com` → expected: exit code 0, output contains pattern `## Pipeline composition`
- [ ] user: AE reviews their own card → expected: confirms numbers match SF dashboard

#### VS-4.3.2: Coaching prompt heuristic

Per-AE heuristic surfaces one concrete coaching prompt ("focus on stage X this week"). Demoed by inspecting the prompt for a fixture AE.

##### Demo criteria

- [ ] auto: `pulsepipe coach prompt --ae alice@example.com --json | jq '.prompt'` → expected: pattern `".+"`
- [ ] user: manager uses the prompt as a 1:1 talking point → expected: prompt is concrete enough to anchor a conversation

#### VS-4.3.3: Coaching-card scheduled delivery

Cron-driven weekly delivery of coaching cards to each AE's preferred channel. Demoed by running the scheduled job once and verifying delivery.

##### Demo criteria

- [ ] auto: `pulsepipe coach deliver --week current --mock-notifier` → expected: exit code 0, output pattern `delivered \d+ cards`
- [ ] user: AEs report receiving their card on Monday morning → expected: 100% delivery rate over a 4-week trial

---

## Hierarchy summary

- **4 phases**: Foundation, Digest Replacement, Query Layer, Trend Intelligence
- **12 sprints**: 3 per phase
- **30 vertical slices**: 2-3 per sprint, each with 2 demo criteria mixing `auto:` and `user:` forms
- **Total node count**: 4 + 12 + 30 = 46 — within the ≤50-node default size class (no 3-path size-class prompt fires at R1.A close)

The shape generalises: a 4-phase product roadmap, three sprints per phase, slices that each correspond to a 90-day demoable cycle. Demo criteria use the literal Unicode arrow (→), NOT the ASCII `->`. Slice IDs follow `VS-<phase>.<sprint>.<slice>` and chain into scaffold-dev's `docs/specs/sprint-N/VS-N.M-<kebab>/` schema cleanly.
