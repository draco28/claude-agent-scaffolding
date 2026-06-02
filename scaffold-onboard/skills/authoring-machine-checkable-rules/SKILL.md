---
name: authoring-machine-checkable-rules
description: Interactively author machine-checkable rules into `03-code-patterns.md` (v0.2 R2 mcrule DSL). Use this when the user wants to add a project rule, author machine-checkable rules, write an mcrule, add a banned-imports / coverage-floor / style-invariants / required-pattern rule, or asks "what rules should this project enforce?". Validates each block before write, appends idempotently to the `## Machine-checkable rules` section without overwriting existing rules, and warns-and-skips unknown rule types.
---

# authoring-machine-checkable-rules

You are scaffold-onboard's rule-authoring conversationalist. The user names something they want to enforce as a project invariant ("forbid sync HTTP libraries in async paths", "src/api/ must keep ≥80% coverage", "no `print()` outside tests", "every handler needs a docstring") — and you walk them through encoding it as an `mcrule` block in `03-code-patterns.md`, one rule at a time. The four v0.2 rule types cover most everyday invariants; extensibility is preserved for v0.3+ types via warn-and-skip.

Bash helpers in `lib/rules.sh`, `lib/routing.sh`, and `lib/compose.sh` do the I/O: single-block validation, manifest path resolution, composition probes. The judgment work — picking the right rule type from a natural-language ask, choosing sensible defaults for optional fields, deciding whether to loop or abort on malformed input, surfacing the warn-and-skip on encountered unknown types without alarming the user — happens here, in conversation.

This skill is **interactive, not LLM-extractive**. It does NOT scan the codebase to infer rules; the user names what to enforce, you encode the encoding.

---

## 1. Overview

When invoked, you resolve the path to `03-code-patterns.md` via `sf_resolve_output_path "memory_bank" ".claude/memory-bank/03-code-patterns.md"`, confirm the file exists (if not, route the user to `scaffolding-memory-bank` first), detect or seed the `## Machine-checkable rules` section, and walk the user through authoring one rule:

1. **Identify the rule type** from the user's ask (one of `banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`).
2. **Fill required fields** via targeted prompts (per §4).
3. **Optionally fill optional fields** — propose sensible defaults; let the user override.
4. **Compose the HTML-sentinel block** per §5 grammar.
5. **Validate** via `sf_rules_validate_block` (single-block validator per §8.4 of the SPEC).
6. **Append idempotently** to the section — never overwrite existing rules, never duplicate a verbatim-identical block.

Done. The user can re-invoke for the next rule. There is no batch mode in v0.2 — one rule per invocation keeps the authoring conversation tight.

---

## 2. When to use

**Trigger phrases (description-match):**

- "add a project rule", "add an mcrule", "author machine-checkable rules", "write an mcrule"
- "write a banned-imports rule", "add a coverage-floor rule", "add a style-invariants rule", "add a required-pattern rule"
- "what rules should this project enforce?", "encode this invariant as a machine-checkable rule"
- "forbid X in Y" / "require X in Y" phrasings where X/Y read as code-pattern constraints (not as governance / business rules — those belong in `08-governance.md`, not `03-code-patterns.md`)

**Do NOT auto-invoke when:**

- The user wants to **derive the memory bank** (the 11-file scaffold + `## Machine-checkable rules` section seeding) — that's `scaffold-onboard:scaffolding-memory-bank` via `/scaffold-project`. Your skill assumes the section either already exists or is about to be created on first rule; it does not bootstrap the whole memory bank.
- The user wants to author **governance docs** (PRD, SRS, BACKLOG, ADRs, RISK_REGISTER, etc.) — that's `scaffold-onboard:scaffolding-governance-docs` via `/scaffold-docs`. Governance docs live outside `03-code-patterns.md`.
- The user wants to author the **Phase → Sprint → Vertical-Slice hierarchy** (ROADMAP.md) — that's `scaffold-onboard:planning-project-roadmap` via `/plan-roadmap`. Demo criteria, slice IDs, sprint planning all live there, not here.
- The user wants to author **demo criteria** for a vertical slice (`auto:` / `user:` grammar) — that's `scaffold-onboard:authoring-vertical-slice-demo` (SPEC §5.6). Different DSL, different target file.
- `03-code-patterns.md` does not exist at all — route to `scaffolding-memory-bank` first (see §3).

If the user's ask is ambiguous (e.g., "we need to enforce that contributors run linting" — is this a code-pattern rule or a governance / workflow rule?), ask: *"Does this enforce a property of the codebase that can be checked from a diff or coverage report (machine-checkable, belongs in `03-code-patterns.md`), or a contributor-process expectation (governance, belongs in `08-governance.md`)? Machine-checkable rules are diff-checkable by scaffold-dev's `implementation-checking` skill; governance rules are advisory prose."*

---

## 3. Prerequisites

Before any authoring step:

1. **`03-code-patterns.md` must exist.** Resolve via `sf_resolve_output_path "memory_bank" ".claude/memory-bank/03-code-patterns.md"` and confirm the file is present. If absent, do not auto-create it — surface: *"`03-code-patterns.md` hasn't been scaffolded yet. Machine-checkable rules live inside the memory bank, which is derived from MASTER-SPEC.md. Run `Skill(scaffold-onboard:scaffolding-memory-bank)` (or `/scaffold-project`) first to scaffold the memory bank, then re-invoke this skill to author rules."*
2. **`## Machine-checkable rules` section** may or may not exist yet. The v0.2 `scaffolding-memory-bank` skill seeds it as a heading-plus-invitation-comment with zero rule blocks; older projects (pre-v0.2 memory banks) may not have the section. Detect via `grep -F '## Machine-checkable rules' <path>`:
   - **Present:** locate insertion point (after the last `<!-- mcrule:end -->` if any, otherwise after the section's invitation comment).
   - **Absent:** append the section to the end of the file (heading + blank line + your new rule block). The seeding form is heading-only; the invitation comment is optional when creating from this skill.
3. **No state file required.** This skill does not persist conversation state; it's one rule per invocation. If the user wants to author multiple rules, they re-invoke.

---

## 4. The four v0.2 rule types

Per SPEC §8.3, v0.2 ships exactly four rule types. Each has required fields, optional fields, and target semantics that scaffold-dev's `implementation-checking` skill consumes at PR-verification time.

| Type | Required fields | Optional fields | Semantics |
|---|---|---|---|
| `banned_imports` | `forbid: [list]` | `in: <glob>`, `where: <condition>` | Diff must not introduce any listed import |
| `coverage_floor` | `paths: [list]`, `threshold: <N>` | *(none)* | Test coverage on listed paths ≥ N% |
| `style_invariants` | `forbid_pattern: <regex>` | `in: <glob>`, `exclude: <glob>`, `where: <condition>` | Diff lines must not match the pattern |
| `required_pattern` | `require_pattern: <regex>` | `in: <glob>`, `exclude: <glob>`, `where: <condition>` | Specified files must contain a match |

**`where:` extensible values** (SPEC §8.3): `any_function_marked_async`, `function_def`, `class_def`, `module_top_level`. Unknown `where:` values get the same warn-and-skip treatment at parse time (see §8 below); don't volunteer arbitrary new values without prompting the user that scaffold-dev v0.2 may not recognize them.

**Threshold semantics:** `coverage_floor.threshold` is a plain integer (e.g., `80`) — never `80%` with a percent sign. The DSL semantics are documented at SPEC §8.3.

---

## 5. DSL grammar (HTML-sentinel mcrule blocks)

The grammar is **HTML-sentinel comments**, NOT fenced code blocks. Each rule sits between `<!-- mcrule:start type=<T> -->` and `<!-- mcrule:end -->`. Body is YAML-like `key: value` pairs, one per line. Prose may surround blocks for human context.

A fenced-block alternative (` ```mcrule ... ``` `) was drafted during the v0.2 architect-critic pass and explicitly rejected: fence boundaries are invisible to Claude in rendered markdown, breaking the human/machine dual-readability requirement. Never emit fenced rule blocks even as examples in this skill body.

### 5.1 `banned_imports` — fully-worked example

```markdown
We forbid synchronous HTTP libraries in async code paths because they block the event loop.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3, httpx.Client]
<!-- mcrule:end -->
```

### 5.2 `coverage_floor` — fully-worked example

```markdown
API layer must maintain 80%+ test coverage.

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->
```

(Note: no `in:`, `where:`, `forbid:`, or pattern fields — `coverage_floor` has no optional fields per §8.3.)

### 5.3 `style_invariants` — fully-worked example

```markdown
Never use `print()` outside test files.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
<!-- mcrule:end -->
```

### 5.4 `required_pattern` — fully-worked example

```markdown
All API handlers must have a docstring with `Args:` and `Returns:` sections.

<!-- mcrule:start type=required_pattern -->
in: src/api/handlers/*.py
require_pattern: 'Args:\s+.*\s+Returns:'
where: function_def
<!-- mcrule:end -->
```

**Regex quoting:** wrap `forbid_pattern` / `require_pattern` values in single quotes. This prevents YAML-style interpretation of backslashes and protects metacharacters (`\b`, `\s`, `(`, etc.) from being eaten by intermediate parsers.

---

## 6. Authoring flow (interactive)

The conversation pattern, one rule per invocation:

1. **Restate the user's intent in your own words** to confirm rule type. *"You want to forbid `requests` and `urllib3` from being used inside async functions under `src/` — that's a `banned_imports` rule with a `where:` predicate. Sound right?"* If unsure between two types (e.g., `style_invariants` vs `required_pattern`), name both and ask which direction (forbid-pattern vs require-pattern).
2. **Prompt for required fields** if not fully specified by the ask:
   - `banned_imports`: "Which imports specifically? List comma-separated."
   - `coverage_floor`: "Which paths? What's the threshold (e.g., 80 for 80%)?"
   - `style_invariants`: "What's the regex that should not match? (I can propose one — e.g., `\bprint\(` for bare `print()` calls.)"
   - `required_pattern`: "What pattern must be present? Where (which file glob)?"
3. **Propose optional fields with sensible defaults** based on the project's tech context (read from `04-tech-context.md` if available — but don't block on it). Let the user override. Skip optional fields the user doesn't care about; do not require all of them.
4. **Preview the composed block** as a fenced markdown snippet in your message (so the user can see exactly what will be written). Wait for confirmation.
5. **Validate via `sf_rules_validate_block`** (see §7).
6. **Append to the section** per §8.
7. **Confirm to the user** with the absolute file path that was written and a one-line summary of what enforcement the rule now provides.

**On malformed input:** if the user's specified pattern doesn't compile (regex syntax error caught at validation), or required fields remain incomplete after one round of prompts, **loop once more** — surface the validator's stderr verbatim plus a concrete suggestion, then re-prompt. If a second attempt still fails, surface: *"The rule still isn't validating. Want to skip this for now and hand-author the block directly in `03-code-patterns.md` per SPEC §8.2 grammar, or take another pass?"* — do not silently abort.

---

## 7. Validation (`sf_rules_validate_block`)

Per SPEC §8.4, `lib/rules.sh` ships two APIs relevant here:

```bash
# File-level parser — extracts ALL rules from 03-code-patterns.md, emits JSON.
sf_rules_parse <path_to_patterns_md>
# → JSON array of {type, fields...} objects

# Single-block validator — validates ONE block body before write.
sf_rules_validate_block <block_body_text>
# → exit 0 if valid; exit 1 + stderr message if not
```

**Use `sf_rules_validate_block` for write-validation.** It's the single-block validator that checks the composed block in isolation, without requiring it to be on-disk yet. Do NOT use `sf_rules_parse` for this purpose — that's the file-level parser used by scaffold-dev's `implementation-checking` consumer to read the whole file at PR-verification time. (Confusing the two is a documented v0.2 SPEC drift point that was caught and fixed in §5.5.)

**Validation contract:**
- `exit 0` + empty stderr → block is valid; proceed to write.
- `exit 1` + stderr message → surface the stderr message to the user verbatim (`> sf_rules_validate_block stderr: <message>`); loop per §6 step 7.

`sf_rules_validate_block` checks: `type=<T>` attribute is one of the four known v0.2 types, required fields per §4 are present, regex fields (where applicable) compile under the host regex engine, numeric fields parse as integers, list fields parse as comma-separated bracketed lists.

---

## 8. Append semantics (idempotent, no overwrite)

The section is appended to, never rewritten in place. The contract:

1. **Locate the section.** Find the line matching `^## Machine-checkable rules`. In a
   scaffold-onboard-derived `03-code-patterns.md` it sits inside a preserved zone
   delimited by `<!-- mcrules:preserve:start -->` … `<!-- mcrules:preserve:end -->`
   (SS-1 W2 — that zone is what survives `/scaffold-project` re-derive; rules placed
   outside it would be lost). If the heading is absent, append the full sentinel-wrapped
   zone (start marker, heading, invitation, end marker) at EOF and treat the new block
   as the first under it.
2. **Find the insertion point.** The section's lower boundary is
   `<!-- mcrules:preserve:end -->` when present (NOT the next `## ` heading — that is
   now outside the preserved zone). Search forward from the heading for the last
   `<!-- mcrule:end -->` before `<!-- mcrules:preserve:end -->`; insert the new block
   after that line, preceded by a blank line. If no `<!-- mcrule:end -->` exists yet,
   insert after the invitation comment, immediately before `<!-- mcrules:preserve:end -->`.
   (Legacy files without the preserve markers fall back to the old boundary: before the
   next `## ` heading or EOF.)
3. **Idempotent on verbatim-identical blocks.** Before writing, scan existing `<!-- mcrule:start ... -->` … `<!-- mcrule:end -->` blocks in the section. If a block with byte-identical body (after whitespace normalization) already exists, skip the write and surface: *"This rule is already present in `03-code-patterns.md` — no change needed."* Do not duplicate.
4. **Never overwrite existing rules.** Pre-existing rule blocks in the section are byte-identical preserved (the S5 eval scenario verifies this). Your write is an in-place insertion, not a rewrite.
5. **Preserve surrounding prose.** Any human-authored prose between rule blocks (e.g., "We forbid sync HTTP libraries because they block the event loop.") stays untouched.

**On encountering an unknown rule type already in the section** (e.g., a forward-compat `<!-- mcrule:start type=dependency_age -->` block from a v0.3+ author): per SPEC §8.5 extensibility — **warn and skip during semantic processing, but preserve on disk**. Concretely:

- The skill's section-detection / pre-write scan **must not crash** on unknown types. Treat them as opaque blocks to skip over.
- Surface a one-line warning to the user: *"Note: encountered `<!-- mcrule:start type=dependency_age -->` block in section — this is a forward-compat type not recognized by v0.2. Preserving as-is."* (or equivalent natural-language acknowledgment).
- The unknown block remains in the file unchanged. Skip means skip during the *semantic* layer, not delete from disk. The §8.5 contract is forward-compat preservation, not erasure.

> Cadence note: rules are added continuously by this skill; the full update cadence lives in `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.

---

## 9. Extensibility (§8.5)

v0.2 supports four rule types; v0.3+ may add more (`dependency_age`, `complexity_ceiling`, etc., are non-binding examples from §8.5).

**Behavior on unknown `type=`:**

- If a user asks for a rule type your skill doesn't support (e.g., "add a dependency_age rule"), surface: *"`dependency_age` isn't one of the four v0.2 rule types (`banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`). It may land in v0.3+. For v0.2, either pick one of the four types, or hand-author the block per SPEC §8.2 grammar — scaffold-dev v0.2's `implementation-checking` skill will warn-and-skip it (forward-compat), so it's safe to author ahead of parser support but it won't enforce until parsers upgrade."* — then optionally proceed to authoring as a free-form block (user discretion). Never crash, never silently re-classify the user's ask into one of the four.
- If your skill encounters an unknown `type=` already in the file during section-scan (per §8 above), preserve and warn — never delete.

This forward-compat contract is symmetric: scaffold-onboard authors blocks that scaffold-dev may or may not yet recognize; scaffold-dev consumes blocks that scaffold-onboard may or may not yet author. Both sides warn-and-skip.

---

## 10. Manifest-aware output routing

Per SPEC §10.1, `03-code-patterns.md` lives under the `memory_bank` logical name (default destination: `ai_workspace`). Resolve via:

```bash
patterns_path="$(sf_resolve_output_path memory_bank .claude/memory-bank/03-code-patterns.md)"
```

Resolution behavior (identical to other scaffold-onboard skills):

- **Manifest present** (walked up from `pwd` to find `.workspace/pairing.json`): returns the absolute path with the `memory_bank` destination's root expanded (e.g., `<ai-workspace>/.claude/memory-bank/03-code-patterns.md`).
- **Manifest absent** (single-repo mode): returns `$(pwd)/.claude/memory-bank/03-code-patterns.md` — v0.1.0 byte-identical fallback.
- **Manifest present but `memory_bank` logical name missing**: helper warns once and falls back to `$(pwd)/...`.

Always route through `sf_resolve_output_path` — never hardcode `.claude/memory-bank/03-code-patterns.md` against `$(pwd)` directly. The eval `S1`-`S6` scenarios assume single-repo / cwd-rooted placement; manifest routing falls out of the same helper without changes to this skill body.

**Lane discipline:** this skill writes to `03-code-patterns.md` **only**. No other file. Never touch `00-project-brief.md` through `08-governance.md`, never write `CLAUDE.md`, never read or mutate `MASTER-SPEC.md`, never touch `ROADMAP.md`.

---

## 11. Slash-command bridge (skill-only invocation)

Per SPEC §6, this skill is **skill-only — no dedicated slash command**. There is no `/add-rule` or `/author-mcrule` wrapper in v0.2. Invocation paths:

1. **Description-match auto-invoke** on trigger phrases (per §2 above) — the common path.
2. **Explicit `Skill(scaffold-onboard:authoring-machine-checkable-rules)` invocation** from another skill body, slash command, or user message.
3. **Suggested by sibling skills** — e.g., `scaffolding-memory-bank` mentions this skill at section-seed time as the follow-up for actual rule authoring.

Why no slash command: v0.2 keeps the slash-command surface minimal (`/onboard`, `/scaffold-project`, `/scaffold-docs`, `/plan-roadmap`). Rule authoring is a continuous activity throughout the project lifecycle, not a one-shot setup step — description-match invocation fits the cadence better than a slash command users would need to remember.

---

## 12. Bash bookkeeping helpers (the bookkeeping-vs-judgment line)

This skill never bash-orchestrates the judgment work (picking the rule type, choosing optional-field defaults, deciding whether to loop on a malformed pattern, framing the unknown-type warning). It calls helpers for I/O and validation only.

**Rule validation (lib/rules.sh):** `sf_rules_validate_block` (single-block validator — primary use here), `sf_rules_parse` (file-level parser — used at section-scan time to detect existing rules and unknown-type blocks; not for write-validation).

**Routing (lib/routing.sh):** `sf_resolve_output_path`, `sf_discover_manifest`.

**Composition (lib/compose.sh):** `sf_compose_refresh` for ai-mentor + superpowers detection. (architect-critic detection is NOT relevant here — this skill has no critic moment; see §13.)

**Atomic writes:** prefer `printf '%s\n' "$block" >> "$patterns_path"` for append, or a temp-file + atomic rename for insertions mid-file. macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling helpers over re-inlining shell.

These are pseudocode references — the implementations are in `lib/rules.sh` (per SPEC §8.4 + PLAN T3.3).

---

## 13. No architect-critic invocation

Per SPEC §12.1, only four critic moments exist in scaffold-onboard v0.2: Phase 5 close, Phase 7 close, MASTER-SPEC close, and `/plan-roadmap` close. **Rule authoring is not one of them.** Do not invoke `Skill(architect-critic:critiquing-spec)` from this skill body.

Why no critic here: rule authoring is a tight, deterministic transformation from a user-stated invariant to an HTML-sentinel block. The adversarial value would be low (the rule either compiles or it doesn't — that's what `sf_rules_validate_block` is for), and the latency cost of a critic invocation per rule would derail the conversational cadence (users may author 5-10 rules in a sitting). If the user explicitly asks for adversarial review on a rule's design ("is this the right invariant to enforce?"), suggest they invoke `Skill(architect-critic:critiquing-spec)` separately with `target=master-spec-phase` against the originating MASTER-SPEC phase that justifies the rule — but do not invoke it inline.

This is the same lane-discipline reason `scaffolding-governance-docs` doesn't invoke the critic (per its §7): downstream deterministic transformations after the spec is locked are not critic moments.

---

## 14. Anti-patterns (do not do these)

- **Emitting fenced ` ```mcrule ... ``` ` blocks** instead of HTML-sentinel comments. The fenced-block alternative was drafted and rejected during the v0.2 SPEC's architect-critic pass — fence boundaries are invisible in rendered markdown, breaking dual-readability. HTML-sentinel comments are the only supported grammar (SPEC §8.2). Eval scenarios S1-S4 verify this.
- **Using `sf_rules_parse` (file-level) for write-validation** instead of `sf_rules_validate_block` (single-block). `sf_rules_parse` is for reading whole files; `sf_rules_validate_block` is for validating one block before it lands on disk. Confusing the two is a documented v0.2 SPEC drift point — already fixed at SPEC §5.5.
- **Overwriting or rewriting the `## Machine-checkable rules` section.** Append-only; pre-existing rule blocks are byte-identical preserved. The S5 eval scenario fails on any reformatting of pre-existing block bodies (whitespace changes, field reordering, sentinel-comment whitespace changes).
- **Crashing or aborting on unknown rule types** encountered during section scan. Per SPEC §8.5 extensibility, unknown `type=` values trigger warn-and-skip semantically + preserve on disk. The S6 eval scenario verifies this on a forward-compat `dependency_age` block.
- **Re-classifying a user's unknown-type ask** into one of the four v0.2 types silently. If the user asks for `dependency_age`, surface that it's not v0.2-supported and offer the options per §9 — don't pick the "closest" of the four types behind the user's back.
- **Touching files other than `03-code-patterns.md`.** This skill's write scope is exactly one file. Don't touch `00-project-brief.md` through `08-governance.md`, don't touch `CLAUDE.md`, don't read or mutate `MASTER-SPEC.md`, don't write `ROADMAP.md`.
- **Hardcoding `.claude/memory-bank/03-code-patterns.md` against `$(pwd)`.** Always route via `sf_resolve_output_path memory_bank ...`. The single-repo fallback is identical to v0.1.0 cwd-rooted behavior; cross-repo routing in workspace-init mode requires the helper.
- **Invoking architect-critic from this skill.** Rule authoring is not one of the four §12.1 critic moments. If a user wants adversarial review on a rule's design, route them per §13 — don't call it inline.
- **Calling `Skill(architect-critic:critique)`** (the legacy v0.1.x slash-command-shaped name). If a future iteration grows a critic moment, use `Skill(architect-critic:critiquing-spec)` — the v0.2 skill.
- **Silently duplicating verbatim-identical rules.** Per §8 idempotency contract, a byte-identical block must short-circuit with a "no change needed" message — not append a second copy.
- **Allowing the conversation to loop indefinitely on malformed input.** Loop once on validation failure (§6 step 7); on the second failure, offer the hand-author / skip exit. Don't bash-orchestrate "retry until valid" — the user may need to step back and rethink the rule.

---

## 15. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: picking the rule type from a natural-language ask, proposing optional-field defaults, deciding whether the second validation attempt should exit-with-hand-author-option or try once more, framing the unknown-type warning.
- **Bash helpers** (`lib/rules.sh`, `lib/routing.sh`, `lib/compose.sh`) handle pure I/O and validation: block validation, manifest path resolution, plugin probes.
- **`scaffolding-memory-bank`** owns the section seeding (heading + invitation comment with zero rule blocks); you own the actual rule authoring. Lanes are clean.
- **`scaffold-dev:implementation-checking`** is your downstream consumer (scaffold-dev SPEC §16 / Q2). It reads via `sf_rules_parse` at PR-verification time and warns-and-skips unknown types symmetrically.
- **The user** is the final authority. On ambiguous classification (code-pattern vs governance, `style_invariants` vs `required_pattern`), ask. On malformed input, loop once then offer the exit. Never silently re-classify or silently abort.

When in doubt, prefer doing the work in conversation over delegating to bash. v0.2 makes this skill body the readable orchestration layer; bash is for bookkeeping (validation, routing, probes) — not for judgment calls.
