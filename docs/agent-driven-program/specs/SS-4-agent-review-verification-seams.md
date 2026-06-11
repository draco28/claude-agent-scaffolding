# SS-4 — Agent-review of the verification seams (anti-pattern C)

**Date:** 2026-06-11 · **Type:** refactor + additive (single-authority pivot across four seams) · **Depends on:** none (independent)
**Ledger:** N4 = #52 · #7 · #5 · #48 Part F · **Plugins touched:** `scaffold-dev` only · **Release:** `scaffold-dev` minor bump
**Design settled with user 2026-06-11** (this brainstorm).

---

## 1. Decision

Make the **agent the single authority** over every *semantic* judgment in scaffold-dev's
verification seams. Deterministic bash survives only as a **real-command-execution leg** (run a
test → check exit code, `test -f`, `grep -F`, count lines, write-with-idempotency). Any bash that
performs semantic **parsing or judgment** is **deleted** — not demoted to a "labeled fallback."

This **supersedes the program-spec SS-4 entry's "bash becomes labeled fallback" wording**
(`SPEC-agent-driven-program.md` §5 SS-4). The disposition rule is *delete-semantic-bash,
keep-mechanical-legs*, because the agent runs these seams **inline** (not via dispatch) and is
therefore never absent — there is nothing to fall back *to* (see §6).

Closes **#52** (N4), **#7**, **#5**, and **#48 Part F**. #48 stays open for its C/D/E + routing
remainder.

## 2. The unifying spine

The four targets share no lifecycle moment — harvest is at slice-close, the RED-gate at
work-item-exec, citation-check at slice-planning, the linter at memory-write. They are unified by
**one rule applied four times**: name the mechanical leg and the agent-authority leg of each seam,
keep the former deterministic, make the latter the agent's sole call.

| Seam | Mechanical leg (deterministic — kept) | Agent authority (semantic — sole judge) |
|---|---|---|
| **#52 harvest** | `sd_harvest_apply` (write + idempotency + derived-file reroute + provenance); `_sd_harvest_seed_live_file` | read `report.md`/handoff prose, categorize by target file, phrase candidates, accept/edit/reject |
| **#5 RED-gate** | run each `auto:` AC command → assert non-zero (RED) exit | classify each AC (test-shaped vs grep-shaped vs pure-deletion); when the skip-escape applies |
| **#7 citations** | `test -f` on file paths; exact `grep -F` on quoted signatures (manifest-routed) | does a REQ-ID / ARCH §-ref still **denote the same thing** after a rename/renumber |
| **#48-F linter** | per-entry line-count at harvest write-time | does this entry **restate** content already tracked in a doc/ADR/issue |

This table is the spec's backbone — every work item maps to one row.

## 3. Per-seam design

### 3.1 Seam #52 — harvest single-authority (the core bug, ships first)

**Defect.** Three authorities claim harvest. `closing-vertical-slice` §9 says agent-judged;
`lib/harvest.sh` has AWK parsers (`sd_harvest_reports`, `sd_harvest_handoffs`,
`_sd_harvest_extract_section`) that *also* extract+parse the same sections assuming a
`- target_file:/suggestion:` bullet grammar; the `report.md` template (`executing-work-item` §6
item 7) writes that section as **free-form prose**. Prose outside the AWK grammar is **silently
dropped**. The AWK parsers are **already orphaned** — nothing in the live §9 ceremony calls them.

**Design.**
- **DELETE** `sd_harvest_reports`, `sd_harvest_handoffs`, `_sd_harvest_extract_section` (semantic
  prose→JSON parsing; and dead code).
- **KEEP** `sd_harvest_apply` (write + idempotency + derived-file reroute + provenance trailer) and
  `_sd_harvest_seed_live_file` — mechanical I/O.
- The §9 agent reads `report.md` + handoffs directly, judges/categorizes, then hands
  `sd_harvest_apply` a clean JSON array. The agent is the **sole reader**.
- **`report.md` template stays free-form prose.** Once the agent (not AWK) is the reader, free-form
  prose is correct, not a bug — the collision dissolves. Add one line to the template noting the
  section is **agent-read, not machine-parsed**.

**Lowest risk** (deletion of dead code) → sequenced first.

### 3.2 Seam #48-F — lean-index linter (hybrid home, ships with the harvest work)

Both legs land at **harvest write-time** (prevention, not detection):
- **Semantic leg → folds into harvest §9.** Before appending a harvested candidate, the agent
  judges "does this restate content already tracked in a doc/ADR/issue?" and, if so, nudges toward a
  pointer instead of prose. Reuses the agent moment already judging every candidate; **no new skill.**
- **Mechanical leg → a small line-count helper** run at harvest time, flagging a just-harvested
  entry that exceeds a configurable line threshold (**default ~12 lines**, settled at plan time;
  per-project override). **NOT** a 5th mcrule type: all four existing mcrule types
  (`banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`) target the
  *work-item's modified code files in the worktree*; a memory-bank line-count is a different domain,
  and bolting it onto the worktree-diff DSL would stretch the DSL's meaning. The line-count is a
  kept mechanical helper instead.

**Partial standing (explicit).** F enforces the pointer conventions C/D/E, which are **not** in SS-4.
So SS-4's F ships as **write-time prevention only**: it flags too-long + restating *newly-harvested*
entries (reusing existing harvest routing + `/defer` issue-pointers). The **full existing-bank
re-scan** is deferred to travel with C/D/E (re-scanning for restate-violations only fully makes sense
once the C/D/E conventions exist to convert entries *to*).

### 3.3 Seam #7 — verifying-spec-citations (new skill, ships third)

**Today** `planning-vertical-slice` trusts every citation in a draft spec resolves; no lint step;
drift is silent (REQ-ID renumber, ARCH §-rename, signature paraphrase).

**Design — a new standalone skill `verifying-spec-citations`** (gerund convention) over a draft spec
at the handoff path:
- **Mechanical legs:** file paths in code-fences → `test -f` (manifest-routed via `lib/manifest.sh`);
  quoted function signatures → exact `grep -F` against the cited file.
- **Agent authority:** REQ-ID drift (ID resolves but now denotes a *different* requirement) and
  ARCH §-ref drift (section exists but was renamed/repurposed) — semantic "does the citation still
  mean what the spec claims," which a regex cannot judge.
- **Wiring: opt-in, not mandatory.** Offered at the `planning-vertical-slice` spec-authoring gate;
  runnable anytime standalone. Mandatory would add friction to every slice plan and over-reach for
  projects without rigid REQ-ID schemes. The REQ-ID/ARCH regexes are **configurable per project**;
  absent config, the skill degrades to the mechanical legs + a note.
- **No dedicated slash command** (skill-invocation only), matching the validation-skill convention.

Purely additive (no contract change to existing flows).

### 3.4 Seam #5 — pre-flight RED-tests gate (ships last — highest blast radius)

**Today** `executing-work-item` §4 runs per-AC TDD but RED-verification is *per-iteration*, not an
upfront gate over the whole AC list — an implementer can drift into impl-first per-AC.

**Design — a pre-flight gate in `executing-work-item`**, after §3.2 (read spec) / before §4 (TDD
GREEN work):
- **Mechanical leg:** for each `auto:` AC carrying a runnable command, execute it now and assert it
  is currently **RED** (test exists and fails, or grep-shaped AC currently fails against codebase
  state). Real-command execution + exit-code check.
- **Agent authority:** classify each AC — test-command-shaped vs grep-shaped vs genuinely-no-failing-
  test (pure code-deletion slice) — and decide when the skip-escape applies.
- **Hardness:** **hard block** on entering §4 GREEN work until every AC is verified-RED, **plus** an
  `--allow-skip-thrust-zero` escape gated on `pause_and_ask` for legitimately test-less slices.
- **Error vs fail:** distinguish a *test fail* (RED — the desired pre-flight state) from a *test
  error* (harness broken — surface, do **not** treat as RED).

**Blast radius.** This changes the contract that `scaffold-dev:implementer-agent` subagents run
under → sequenced last; eval scenarios get a new RED-gate case in **both** standalone and subagent
modes.

## 4. Build sequence (risk-ordered)

1. **#52 harvest** — delete orphaned semantic parsers; agent-as-sole-reader; keep `sd_harvest_apply`. *(lowest risk: dead-code removal)*
2. **#48-F** — both legs into harvest write-time (semantic restate-prevention + line-count helper).
3. **#7 citations** — new additive `verifying-spec-citations` skill + opt-in `planning-vertical-slice` wiring.
4. **#5 RED-gate** — pre-flight gate in `executing-work-item` + skip-escape. *(highest risk: subagent contract change)*

## 5. Verification

- **#52:** prune `test-harvest.sh` of deleted-fn tests; re-point `test-e2e.sh` harvest assertions at
  the agent-flow + `sd_harvest_apply` contract.
- **#48-F:** harvest-leg tests — line-count helper + restate-prevention eval.
- **#7:** tests for the new skill's mechanical legs (`test -f`, `grep -F`) + an agent-judgment eval
  for REQ-ID / ARCH drift.
- **#5:** new RED-gate eval scenario in `evals/executing-work-item.md`, **both** standalone +
  subagent modes; cover the error-vs-fail distinction and the skip-escape.
- Repo-root `tests/` version-parity / frontmatter guard run **after** the `scaffold-dev` version bump
  (dual-publish guard lives at repo-root `tests/`, run separately).
- Full scaffold-dev suite green before merge.

## 6. Agent-unavailable behavior & failure modes

SS-4 differs sharply from SS-7. SS-7 defined agent-unavailable behavior because derivation runs via
**subagent dispatch** that can genuinely be absent. **All four SS-4 seams run inline in the
conducting agent's own context** (`closing-vertical-slice` §9, `executing-work-item`,
`planning-vertical-slice`, the new citation skill) — the agent *is* the one running the skill, so
"agent unavailable" is not a reachable state. There is nothing to fall back *to*, which is exactly
why deleting the semantic bash leaves no hole.

The failure mode that **does** exist is a **mechanical leg failing** (`jq`/`grep` missing, file
unreadable, a RED-gate command erroring rather than failing). Rule: mechanical legs **fail loud with
actionable remediation**, never silently skip — a skipped check that reads as "passed" is the
anti-pattern this whole sub-spec exists to kill.

## 7. Out of scope (explicit non-goals)

- **#48 Parts C/D/E** (doc-anchor / ADR-id / claude-mem pointer conventions) and the **full
  existing-bank re-scan** → later sub-spec, travels with C/D/E.
- **#48 `/defer` marketplace-routing** and **`tech-debt` label auto-create** → SS-6 (per program
  spec).
- The `linting-committed-text-neutrality` half of #7's source doc → out (project-specific; per the
  issue's own scope note).
- Any change outside the `scaffold-dev` plugin.

## 8. Packaging

One `scaffold-dev` **minor** version bump (new skill + new gate = feature-level). CHANGELOG entries
per seam. Closes #52 / #7 / #5 / #48-Part-F; #48 remains open for its C/D/E + routing remainder.
Program-spec ledger (`SPEC-agent-driven-program.md` §6) updated to mark the four rows shipped and to
record the "delete-semantic-bash" override of the SS-4 entry's "labeled fallback" wording.
