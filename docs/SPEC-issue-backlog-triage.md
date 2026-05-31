# SPEC — GitHub Issue Backlog Triage

**Date:** 2026-05-31
**Author:** Praveen (with Claude)
**Status:** For review
**Scope:** All 14 open issues in `draco28/claude-agent-scaffolding` as of 2026-05-31.

---

## 1. Purpose

We have 14 open issues — a mix of bugs and enhancements, several filed from live
dogfooding (PulseTrader, PulseHive), several synthesized from an external
"enhancement-opportunities" doc. This spec triages all 14: it decides what ships
**this cycle**, what is **deferred with a dated target**, and what is **gated behind a
demand signal** — with rationale grounded against the actual repo state, not the issue
text alone.

The deliverable of this cycle is a **pure bug-fix release**. Everything else is parked.

## 2. Decision lens (settled)

| Axis | Choice | Consequence |
|------|--------|-------------|
| Worth-it lens | **Fix-before-feature** | All bugs land first; enhancements rank strictly after, regardless of source. |
| Cycle appetite | **Bug-fix-only release** | No net-new skills this cycle. Every enhancement gets a dated defer bucket. |

### 2.1 Cross-cutting principle (emerged during triage)

> **Prefer agent / LLM-judge review over deterministic semantic-quality gates.**

Nearly every bug we filed is a *deterministic-gate failure*: #36 is a regex `auto:`
parser that cannot see a markdown table; #35 is YAML that a real parser rejects. Brittle
semantic linting keeps breaking in new ways.

The line to hold:

- **Deterministic *execution* of real commands stays.** Running an `auto:` acceptance
  command and checking its exit code is correct and non-brittle. Parsing a `SKILL.md`
  frontmatter block with a real YAML parser to assert it *parses* is a true/false
  mechanical fact. These are legitimate.
- **Deterministic *semantic judgment* is rejected.** Regex-scanning derived docs for
  "is this `/command` real?", "is the dev-loop present?", "does this citation still mean
  the same thing?" — that is judgment work, and it belongs to an **agent reviewer**, not
  a regex. This is why #30's enhancement-half is reframed (§5) and why the v0.2
  artifact-integrity items (#7, #5) must be (re)designed as agent-assisted reviews.

This principle is a candidate for promotion to the architect-critic principles set.

## 3. Triage summary

| # | Type | Title (short) | Disposition | Target |
|---|------|---------------|-------------|--------|
| **35** | bug | Invalid YAML frontmatter → Codex skips 4 skills | **DO NOW** | this cycle |
| **36** | bug | `implementation-checking` AC-format mismatch → false-green | **DO NOW** | this cycle |
| **30** | bug+enh | Derived `WORKFLOW.md`/`CLAUDE.md` drift + doc-quality gate | **Bug: RESOLVED** (close) · **Enh: reframed → agent review** | v0.2 |
| **40** | enh | PR-per-slice merge mode | DEFER | v0.2 (next priority) |
| **33** | enh | Lean-index memory bank + `/defer` + deep-reference channels | DEFER | v0.2 (next priority) |
| **7** | enh | `verifying-spec-citations` (→ agent-assisted) | DEFER | v0.2 (artifact-integrity) |
| **8** | enh | Ban `git stash` in spec/handoff templates | DEFER | v0.2 (artifact-integrity) |
| **5** | enh | Pre-flight RED-tests gate | DEFER | v0.2 (reconsider det. vs agent) |
| **9** | enh | `pairing-existing-dual` skill (Scenario C) | DEFER | v0.2 |
| **6** | enh | ADR Proposed→Accepted flip lifecycle | DEFER | v0.3 |
| **10** | enh | `coordinating-parallel-slices` skill | DEFER | v0.3 / demand-gated |
| **37** | enh | Grilling: domain-language capture + ADR thresholds | DEFER | demand-gated |
| **38** | enh | Handoff: suggested-skills + artifact-refs + redaction | DEFER | demand-gated |
| **39** | enh | architect-critic async external-adversary operability | DEFER | demand-gated |

**Nothing is hard "won't-do."** The demand-gated items are parked behind a concrete
need, not cancelled.

---

## 4. Tier 0 — This cycle (bug-fix release)

### #35 · Invalid YAML frontmatter → Codex skips 4 skills

**Status:** Verified live. Codex healthcheck confirmed all four files fail
`Psych::SyntaxError: mapping values are not allowed in this context`; the unquoted
`description:` values are still present in source.

**Root cause:** Four `SKILL.md` frontmatter `description:` values are unquoted scalars
containing YAML-significant `: ` (colon-space) sequences:

| File (`scaffold-dev/skills/.../SKILL.md`) | Offending `: ` token |
|---|---|
| `implementation-checking` | `Read-only: never commits…` |
| `appending-changelog-entry` | `changelog: <entry>` |
| `authoring-runbook` | `six sections: Overview…` |
| `executing-work-item` | `Dual-use: standalone skill…` |

**Fix:**
1. Quote each `description:` value so it parses as a single scalar. Single-quoted YAML is
   preferred — these descriptions embed double-quotes (e.g. `"is this work item done"`)
   but no apostrophes, so single-quote wrapping needs no escaping. **Preserve every
   trigger phrase byte-for-byte** (triggering accuracy depends on them).
2. Add a **frontmatter-parse regression check** to the dual-publish suite
   (`tests/test-codex-dual-publish.sh`, currently 119 assertions, no YAML-validity
   check). For every published `SKILL.md`, assert the frontmatter parses under a real
   YAML parser (`ruby -ryaml` matches Codex's reproducer and ships on macOS; stdlib, no
   new dependency). *This is a legitimate deterministic check per §2.1 — it asserts a
   mechanical parse fact, not semantic quality.*

**Acceptance criteria:**
- Codex loads all four skills; no skipped-skill warnings.
- Claude Code plugin loading remains compatible.
- All existing trigger phrases preserved verbatim.
- New regression check **fails** on any future unquoted-`: ` frontmatter and **passes**
  on the fixed tree.

**Touched:** the 4 `SKILL.md` files · `tests/test-codex-dual-publish.sh`.

---

### #36 · `implementation-checking` AC-format mismatch → silent false-green

**Status:** Verified live. `work-item-spec.md.tmpl` §6 renders ACs as `{{acs_table}}`
(*"markdown table: AC-N | description | verification"*) + §7 `{{verification_block}}`
(fenced bash) — **no `auto:` lines anywhere**. `implementation-checking` §4 parses
`auto:` lines per SPEC §14.1 grammar (line 162: *"AC parsing (per SPEC §14.1 grammar)"*;
line 166: *"For each AC line matching the `auto:` grammar"*). A normally-authored
work-item spec yields **zero** parsed ACs → the §6 verification loop runs nothing → the
gate falls through with no AC executed (false-green unless a human verifies out-of-band).

**Decision (settled):** **Option 1 + Option 3.**

- **Option 1 — align the template to the parser (the structural fix).** Add an
  `auto:`/`user:` AC block to `work-item-spec.md.tmpl`, and have
  `planning-vertical-slice` author executable `auto:` lines in the §14.1 grammar. The
  markdown table stays as human-readable prose. This **unifies the `auto:`/`user:`
  grammar across both the slice-demo level and the work-item AC level** as a single
  source of truth (the deliberate trade-off noted in #36; you confirmed you prefer the
  single-SoT outcome).
- **Option 3 — loud-degrade safety net.** If §4 finds zero machine-runnable `auto:`
  lines, `implementation-checking` emits an explicit advisory — *"no machine-runnable ACs
  found in spec — manual verification required"* — instead of passing silently. Cheap,
  and it permanently kills the silent-false-green failure mode even for hand-authored or
  malformed specs.

*Note on §2.1:* Option 1 is deterministic **execution** of real commands (run the AC,
check the result) — the legitimate kind. It is not semantic-quality linting.

**Acceptance criteria:**
- A spec rendered from `work-item-spec.md.tmpl` via `planning-vertical-slice` yields ≥1
  parsed `auto:` AC, and `implementation-checking` executes it (halt-on-first-fail).
- A spec with zero `auto:` lines triggers the loud-degrade advisory; the gate never
  reports green without either executing ≥1 AC or printing the advisory.
- A new eval scenario uses a **real template-rendered spec** (not a hand-written `auto:`
  fixture). The existing evals passed precisely because they hand-wrote `auto:` fixtures
  the real template never produces — that is why this bug escaped the suite.

**Touched:** `scaffold-dev/templates/work-item-spec.md.tmpl` ·
`scaffold-dev/skills/planning-vertical-slice/SKILL.md` ·
`scaffold-dev/skills/implementation-checking/SKILL.md` (§4/§6) · scaffold-dev evals.

---

## 5. #30 — Resolved + reframed (no Tier-0 build)

**Bug-half: ALREADY FIXED AND RELEASED.** Commit `cb9b835`
("v0.3.4 — … stale-command sweep (#26)") is an ancestor of `origin/main`; current
shipped scaffold-onboard is **0.3.6**. Verified against current source:

- `WORKFLOW.md` template carries the real scaffold-dev loop (`/orchestrate`,
  `/work-item`, `/impl-check`, `/handoff`) and real ai-mentor commands (`/council`,
  `/grill-me`, `/eli10`, `/fool`).
- `CLAUDE.md.tmpl` already surfaces the dev loop (lines 39–42 + `/plan-roadmap`),
  contradicting #30 Bug 2's "CLAUDE.md omits the development loop."
- No live dead-command emissions remain. The lone `/z1` in `CLAUDE.brief.md:47` is
  **negative-example guard text** ("earlier synthesis runs hallucinated … `/z1` … Never
  emit them"), not a live command.

#30 was filed `2026-05-30 13:20Z`; the sweep commit landed `~11:39Z` the same day — the
issue was filed reading a derived doc from an **older cached plugin**, before the fix was
installed locally.

**Action:** Close #30's bug concern as resolved-by-`cb9b835` (comment on the issue noting
the version that fixed it). **No Tier-0 code.**

**Enhancement-half: REFRAMED → agent-driven post-derivation doc review.** The original
issue proposed a *deterministic* post-derivation gate (regex dangling-command scan,
dev-loop-presence assertion, plugin-awareness consistency). Per §2.1, this is rejected as
brittle semantic-quality judgment. The redesigned capability is a **sub-agent that reads
the derived bundle** (`CLAUDE.md` / `WORKFLOW.md` / memory-bank) **against the installed
plugins' actual command surface** and surfaces advisory drift/gap findings — an LLM-judge
review, consistent with scaffold-onboard's existing LLM sub-agent synthesis and
architect-critic's LLM-judge evals. **Deferred to v0.2 (artifact-integrity).**

---

## 6. Tier 1 — Defer → v0.2 (dated)

**Recommended next priority — "Workflow-realism" (dogfooding-driven, highest real value):**

- **#40 · PR-per-slice merge mode.** Manifest `merge_mode ∈ {direct, pr_per_slice,
  pr_per_work_item}`; `pr_per_slice` opens a CI-gated PR at slice close so `default_branch`
  only advances through green. You hand-roll this today.
- **#33 · Lean-index memory bank + `/defer` + deep-reference channels.** Multi-part
  (A+B `/defer` + blocker-recall, C doc-anchors, D+E ADR/claude-mem pointers, F
  lean-index linter). Phase A+B first. *Note: parts C and F lean deterministic — design
  the validators as agent-assisted per §2.1.*

**Artifact-integrity (agent-review flavored):**

- **#30-enh · agent-driven post-derivation doc review** (see §5).
- **#7 · `verifying-spec-citations` → agent-assisted.** Original proposal is a
  deterministic lint (regex REQ-IDs, grep signatures). Redesign as agent-assisted
  citation review per §2.1; the cheap mechanical legs (file-path `test -f`) may stay
  deterministic.
- **#8 · ban `git stash` in templates.** Template-only literal-string ban — legitimately
  deterministic (a fixed banned-token list, not semantic judgment). Cheapest item; could
  be pulled forward if a future cycle wants a tiny win.

**Other v0.2:**

- **#5 · pre-flight RED-tests gate.** Reconsider deterministic-vs-agent framing;
  externally-synthesized and changes executor runtime behavior (higher risk).
- **#9 · `pairing-existing-dual` (Scenario C).** workspace-init skill for both-repos-
  already-populated pairing.

## 7. Tier 2 — Defer → v0.3 / demand-gated

- **#10 · `coordinating-parallel-slices`.** Self-tagged v0.3; gate on a real
  parallel-slice usage signal before building.
- **#6 · ADR Proposed→Accepted flip.** Niche; extends the acknowledged v0.1 ADR-status
  deferral.
- **#37 / #38 / #39 · external-benchmark-inspired trio** (grilling domain-language &
  ADR-thresholds · handoff suggested-skills & redaction · architect-critic async
  adversary). Speculative, sourced from reference plugins rather than felt friction.
  Park behind a concrete need. *Note: #38's redaction pass is the one leg with a clear
  standalone safety value — revisit independently if handoffs ever risk leaking secrets.*

---

## 8. Confirmations (resolved)

1. **#30 placement — CONFIRMED deferred.** The agent-driven doc review stays in v0.2;
   it will not be pulled into this bugs-only cycle. #30's bug-half is closed as
   already-shipped.
2. **Principle promotion — DONE.** §2.1 promoted to the architect-critic **user-global**
   principles set on 2026-05-31 (`principle_id: pp-e72993dfb626c518`,
   `~/.claude/architect-critic/principles.md`). The critic now applies it on every audit.

## 9. Next steps

1. User reviews this spec.
2. On approval → `writing-plans` for the Tier-0 release (#35 + #36), then implement.
3. Comment-and-close #30's bug-half referencing `cb9b835` / v0.3.4.
4. File/relabel the deferred items to their dated buckets (v0.2 / v0.3 / demand-gated).
