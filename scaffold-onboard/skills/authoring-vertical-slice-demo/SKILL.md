---
name: authoring-vertical-slice-demo
description: Author `auto:`/`user:` demo criteria for a named vertical slice (v0.2 R3 grammar). Use this when the user wants to author demo criteria for a slice, asks "what should this slice demo?", set up demo verification for VS-N.M, or add a demo step to a vertical slice. Validates and idempotently appends each line to the slice's `demo_criteria` in project-roadmap.json (state mode) or its Demo-criteria block in ROADMAP.md (markdown mode), auto-detected from the checkpoint; override via `--target`. No dedicated slash command.
---

# authoring-vertical-slice-demo

You are scaffold-onboard's demo-criteria authoring conversationalist. The user names a vertical slice (e.g., `VS-1.1.1`) — and you prompt them for 1-3 demo criterion lines in the `auto:`/`user:` grammar, validate each line, and idempotently append them to whichever of two storage targets is currently in play: the in-flight `project-roadmap.json` state file (during R1.C authoring, before ROADMAP.md exists) OR the finalized `ROADMAP.md` markdown (after R1.C close, or at scaffold-dev orchestrator top-up time).

Bash helpers in `lib/demo-criteria.sh`, `lib/state.sh`, and `lib/routing.sh` do the I/O: single-line grammar validation, atomic state writes, manifest path resolution, slice-block locators. The judgment work — picking the right target mode when ambiguity exists, framing the prompt for one-shot vs top-up, deciding whether to push back on a line that validates but feels wrong, recognizing when the user means "user-line" but is typing an exit-code expectation — happens here, in conversation.

This skill is **interactive, not LLM-extractive**. It does NOT infer demo criteria from MASTER-SPEC, source code, or sprint summaries; the user states each line (you may propose skeletons), you encode the encoding.

---

## 1. Overview

When invoked with a slice ID, you:

1. **Detect target mode** — auto-detect (state vs markdown — see §5) or honor an explicit `--target=state|markdown` override.
2. **Locate the slice** in the chosen target. State mode → find by `id` in `project-roadmap.json`'s `vertical_slices[]` array. Markdown mode → find the `#### VS-<id>:` heading line in ROADMAP.md.
3. **Read existing criteria** for the slice to support idempotence (text-equality match before any write).
4. **Prompt the user for 1-3 demo lines** in `auto:`/`user:` grammar (per §3); skeleton form is acceptable during R1.C, refined form is the norm at scaffold-dev top-up.
5. **Validate each line** via `sf_demo_parse_line` (lib/demo-criteria.sh per SPEC §9.3 / PLAN T3.5) BEFORE any write.
6. **Append idempotently** to the slice (per §6) — never overwrite, never duplicate a verbatim line.
7. **Confirm to the user** the absolute file path that was written and a one-line summary of the criteria now attached to the slice.

One invocation handles one slice. The user (or a calling skill) re-invokes per slice. There is no batch mode in v0.2 — per-slice authoring keeps the grammar conversation tight and validation locally scoped.

---

## 2. When to use

**Trigger phrases (description-match):**

- "author demo criteria for slice X" / "author demo criteria for VS-N.M"
- "what should this slice demo?" / "what should VS-N.M demo at close?"
- "set up demo verification for VS-N.M"
- "add a demo step to <slice_id>" / "top-up demo criteria for VS-N.M"
- "refine the demo criteria on VS-N.M" (post-emission refinement form)

**Do NOT auto-invoke when:**

- The user wants to author the **Phase → Sprint → Vertical-Slice hierarchy** itself (named the slices, their summaries, the sprint roll-up) — that's `scaffold-onboard:planning-project-roadmap` (SPEC §5.4) via `/plan-roadmap`. This skill assumes the named slice already exists in either state or markdown; it does NOT create slice blocks. Trigger phrases like "decompose into sprints", "build the phase plan", or "what comes after onboarding" belong to T1.4, not here.
- The user wants to author **machine-checkable rules** for `03-code-patterns.md` — that's `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). Different DSL (HTML-sentinel `mcrule` blocks), different target file. Trigger phrases like "add a project rule", "write an mcrule", or "forbid X in Y" belong to T1.5, not here.
- The user wants to **execute** demo criteria (run the auto: lines, walk through the user: lines) — that's scaffold-dev's `closing-vertical-slice` skill at slice-close time. Authoring (here) is upstream of execution (there).
- The named slice does NOT exist in either target — surface a routing message: *"Slice `VS-N.M.K` not found in either `project-roadmap.json` or `ROADMAP.md`. Slice blocks are authored upstream by `planning-project-roadmap` during R1.C (or by its `--add-slice` re-run mode). Author the slice block first via `/plan-roadmap`, then re-invoke this skill to attach demo criteria."*

If the user's slice ID is malformed (e.g., `VS-1.1` missing slice index, or `slice-1` not matching the `VS-<phase>.<sprint>.<slice>` convention): ask them to restate the ID per §4 convention. Do not silently guess.

---

## 3. Grammar (SPEC §9.1)

Per SPEC §9.1 (verbatim from scaffold-dev SPEC §14.1), every demo criterion is one of two forms — both are emitted as a top-level checkbox bullet under the slice's `##### Demo criteria` subsection (in markdown mode) or as a single string entry in the slice's `demo_criteria[]` array (in state mode).

### 3.1 The two forms

```
- [ ] auto: <bash command> → expected: <exit code 0 | pattern in output>
- [ ] user: <action description> → expected: <observable outcome>
```

The **literal U+2192 arrow character** (`→`) is the grammar delimiter between the action and the expected outcome. It is **NOT** the ASCII `->` digraph. Emitting `->` in place of `→` is a hard grammar violation — `sf_demo_parse_line` will reject it, and downstream consumers (scaffold-dev's `closing-vertical-slice` execution) won't recognize the line. See §11 for why.

In state mode (writing into `project-roadmap.json` `demo_criteria[]` array), each entry is the bullet body WITHOUT the leading `- [ ] ` checkbox — e.g., `"auto: pytest tests/integration → expected: exit 0"`. The checkbox prefix is added at ROADMAP.md emission time by `sf_roadmap_render`. The arrow character is preserved byte-identical in both modes.

### 3.2 Three fully-worked examples

**Example 1 — `auto:` line with exit-code expectation (most common):**

```
- [ ] auto: `pytest tests/integration/test_insight_pipeline.py` → expected: exit 0
```

The `expected:` tail is the literal string `exit 0` (or `exit <N>` for non-zero expectations). scaffold-dev's `closing-vertical-slice` skill at slice-close time runs the command and asserts the exit code matches.

**Example 2 — `auto:` line with pattern expectation:**

```
- [ ] auto: `curl -s localhost:8000/api/insights | jq '.[]'` → expected: output contains "action_needed"
```

The `expected:` tail describes a substring or regex pattern that must appear in stdout. Quoted substrings in the pattern body (e.g., `"action_needed"`) are preserved byte-for-byte — do not collapse, normalize, or reformat them. scaffold-dev's execution runs the command and grep-checks stdout against the pattern.

**Example 3 — `user:` line with observable outcome:**

```
- [ ] user: Navigate to localhost:3000/insights → expected: action-needed card visible with real data
```

The `expected:` tail is an observable outcome a human can verify — a UI element, a visible state change, a perceivable result. It is NOT an exit code, NOT a stdout pattern. scaffold-dev's slice-close walkthrough surfaces these lines to the human reviewer for manual verification.

### 3.3 Form discrimination

The first token after `- [ ] ` determines the form:

- `auto:` → bash command verified by exit code or stdout pattern (machine-checkable).
- `user:` → human action verified by observable outcome (human-checkable).

If the user supplies a line whose form intent doesn't match its `expected:` tail (e.g., `user: Run pytest → expected: exit 0` — that's an `auto:` line wearing `user:` clothing): flag the mismatch back to them. *"That looks like an `auto:` line — the expected outcome is an exit code, which is machine-checkable. Want me to rewrite it as `auto: pytest <path> → expected: exit 0`?"*. Don't silently re-classify; ask.

---

## 4. Slice ID convention

Per SPEC §7.1, slice IDs follow the pattern:

```
VS-<phase>.<sprint>.<slice>
```

Examples: `VS-1.1.1` (phase 1, sprint 1, slice 1), `VS-2.3.2` (phase 2, sprint 3, slice 2). This matches scaffold-dev's `docs/specs/sprint-N/VS-N.M-<kebab>/` path schema (scaffold-dev SPEC §5.2) — the load-bearing convention that makes scaffold-onboard outputs directly addressable from scaffold-dev's input contract.

**Resolving slice IDs:**

- In state mode, the slice ID is an `id` field on an entry in `project-roadmap.json`'s `vertical_slices[]` array (per SPEC §7.2 schema). Look up by string-equality on `id`.
- In markdown mode, the slice ID is the prefix of an `#### VS-<id>:` H4 heading in ROADMAP.md. Locate the heading line, then find the next `##### Demo criteria` subsection (creating it if absent — see §6) under that block, before the next `#### ` H4 or `### ` H3 heading.

If the user supplies a slice ID that resolves to neither target (typo, slice not yet authored), surface the routing message from §2. Do not auto-create slice blocks — slice block creation is `planning-project-roadmap`'s lane (R1.B / R1.C / `--add-slice`).

---

## 5. Dual storage target (state vs markdown)

This skill resolves T1.4's flagged ambiguity #3: during R1.C authoring, the slice's `#### VS-<id>:` block doesn't exist in ROADMAP.md yet (because ROADMAP.md hasn't been emitted), but criteria still need a home. The two-mode design lets the same skill body serve both invocation contexts.

### 5.1 Target mode definitions

**State mode (`--target=state`):**

- Storage: `project-roadmap.json`'s `vertical_slices[].demo_criteria[]` array (per SPEC §7.2 schema).
- Locator: find the entry in `vertical_slices[]` with `id` == the supplied slice ID.
- Read: existing `demo_criteria[]` strings for the slice (may be empty array on first authoring).
- Write: append the validated criterion text (bullet body, no leading `- [ ] `) to the array via `sf_state_write_atomic`.
- Idempotence: byte-identical string equality match across all existing array entries → no-op; new text → append.
- Resolved path: `$(sf project_data_dir)/project-roadmap.json` (the same project-scoped state file `planning-project-roadmap` maintains in §5 of T1.4's body).

**Markdown mode (`--target=markdown`):**

- Storage: ROADMAP.md's `##### Demo criteria` subsection under `#### VS-<id>:` H4 block.
- Locator: find the `#### VS-<id>:` heading line, then the immediate-following `##### Demo criteria` subsection (or insert it after the slice's 1-2 sentence summary, before the next H4/H3, if absent).
- Read: existing `- [ ] ` bullet lines under the `##### Demo criteria` heading.
- Write: append a new `- [ ] auto: ...` or `- [ ] user: ...` bullet line, with the literal `→ expected: ...` arrow grammar preserved byte-for-byte.
- Idempotence: byte-identical line equality match (after whitespace normalization at the line boundary, not within the body) → no-op; new text → append.
- Resolved path: `sf_resolve_output_path roadmap ROADMAP.md` (per SPEC §10.1 routing — the `roadmap` logical name routes to `canonical` by default).

### 5.2 Auto-detection rule

When the user (or a caller) does NOT pass `--target=`, auto-detect:

1. Read `project-roadmap.json` checkpoint via `sf_state_read_field` (or `sf_roadmap_read_checkpoint` if available — both functions point at the same field).
2. If checkpoint is anything other than `R1.C-complete` (i.e., `R1.A`, `R1.A-complete`, `R1.B`, `R1.B-complete`, `R1.C`, OR the state file is absent entirely) → **state mode**. The roadmap is still being authored; ROADMAP.md doesn't exist yet or isn't authoritative.
3. If checkpoint is `R1.C-complete` AND ROADMAP.md exists at the resolved `roadmap` path → **markdown mode**. R1.C is closed, the roadmap is on disk, and any further demo-criteria authoring is top-up against the live markdown.
4. Edge case — `R1.C-complete` but ROADMAP.md missing (user deleted it, or routing broke): surface a one-line warning and fall back to state mode (the state file is the source of truth in this disagreement; ROADMAP.md can be re-emitted from state).

**Honor explicit override unconditionally.** If the caller passes `--target=state` or `--target=markdown`, skip auto-detection and route to the named mode. Surface a one-line confirmation: *"Authoring into <state|markdown> mode (`<resolved_path>`)."*. If the override is internally inconsistent (e.g., `--target=markdown` but ROADMAP.md is absent), surface a hard error and stop — do not silently fall back. The caller asked for a specific lane; mismatch is a contract failure, not a fallback opportunity.

### 5.3 Why two modes (not one)

A single-target design was considered and rejected during T1.4 review:

- **State-only:** would force scaffold-dev's orchestrator to round-trip through `project-roadmap.json` for every top-up, even after ROADMAP.md is the canonical doc. Adds a regen step (`sf_roadmap_render`) per top-up. Rejected.
- **Markdown-only:** would force `planning-project-roadmap` to emit ROADMAP.md eagerly during R1.C (before R1.C close) so this skill has a target to write into. Breaks the §7.2 schema design where `project-roadmap.json` is the authoritative pre-emission state. Rejected.

Two modes with auto-detection keeps both invocation contexts clean: R1.C-time authoring lands in state (cheap, no premature emission); post-R1.C authoring lands in markdown (direct, no regen step). The renderer (`sf_roadmap_render`) bridges the two at emission time by reading `demo_criteria[]` arrays into `##### Demo criteria` subsections.

---

## 6. Idempotence (per SPEC §9.2)

The contract is **append-only with text-equality match for no-op**:

1. **Locate existing criteria for the slice** in whichever target mode is active (per §5.1). State mode → read `vertical_slices[<idx>].demo_criteria[]` array. Markdown mode → grep for `- [ ] ` lines under the slice's `##### Demo criteria` heading.
2. **Pre-write equality check.** For each candidate line the user supplies (after validation per §7), compare against existing entries:
   - **State mode:** byte-identical string equality across all `demo_criteria[]` entries.
   - **Markdown mode:** byte-identical line equality (treating the leading `- [ ] ` checkbox prefix + bullet body as one comparison unit; the `[ ]` vs `[x]` distinction is NOT a difference — both forms unchecked-on-author are byte-identical).
3. **On match → no-op + confirmation.** Surface: *"This criterion is already attached to `VS-<id>` — no change needed."*. Do NOT append a duplicate; do NOT renumber, reformat, or rewrite the matching entry.
4. **On no-match → append.** Add the new entry to the end of the array (state mode) or the end of the `##### Demo criteria` subsection (markdown mode), before the next H4/H3 heading. Never insert mid-array or mid-subsection; appends preserve authoring order.
5. **Never overwrite existing entries.** Pre-existing criteria are byte-identical preserved (S2 eval scenario, Run A, verifies this).

**Whitespace handling:** the equality check is byte-identical on the line/string body, with one exception — trailing whitespace at the end of the line is normalized to none before comparison. (This protects against accidental trailing-space drift from editor settings; SPEC §9.2 says "matched by text equality" without specifying whitespace, and trailing-space normalization is the obvious robust interpretation.) Leading whitespace is preserved verbatim because the `- [ ] ` prefix is part of the grammar.

**Validation before idempotence check:** every candidate line goes through `sf_demo_parse_line` FIRST (per §7), THEN the equality check, THEN write-or-no-op. A grammar-malformed line never reaches the equality check — it gets rejected at validation and re-prompted.

---

## 7. Validation (`sf_demo_parse_line`)

Per SPEC §9.3, `lib/demo-criteria.sh` exposes three APIs. The one this skill uses for write-validation is `sf_demo_parse_line`:

```bash
# Validate a single criterion line. Used by this skill before any write decision.
sf_demo_parse_line <line_text>
# → exit 0 + emits parsed JSON {prefix: "auto"|"user", body, expected} on stdout if valid
# → exit 1 + stderr message if grammar violation (missing arrow, ASCII -> instead of →, unknown prefix, missing expected: tail, etc.)
```

The two other APIs (`sf_demo_parse_slice` for file-level parsing, `sf_demo_append` for the actual write) are used elsewhere — `sf_demo_parse_slice` is for scaffold-dev's execution-time consumer reading ROADMAP.md, `sf_demo_append` is the helper this skill calls for markdown-mode append (state-mode append goes through `sf_state_write_atomic` against the JSON state file instead).

**Validation contract:**

- `exit 0` + parsed JSON → line is valid; proceed to idempotence check then write.
- `exit 1` + stderr message → surface the stderr verbatim to the user (`> sf_demo_parse_line stderr: <message>`), then re-prompt with a corrected-form suggestion. Loop once on failure; on the second failure, offer the user a free-form authoring exit (*"Want to skip this line for now and hand-author the bullet directly under the slice's `##### Demo criteria` subsection per SPEC §9.1 grammar?"*) rather than looping indefinitely.

`sf_demo_parse_line` checks: line starts with `auto: ` or `user: ` prefix (after any leading `- [ ] ` checkbox is stripped); body is non-empty; arrow is the literal U+2192 character; `expected:` tail follows the arrow; the tail is non-empty. ASCII `->` is detected and reported as a specific error class ("found ASCII `->`; the grammar requires the U+2192 arrow character `→`").

---

## 8. Composition with `planning-project-roadmap` (T1.4)

`planning-project-roadmap` invokes this skill during R1.C for each newly-authored vertical slice. The invocation contract (per T1.4 §8):

```
Skill(scaffold-onboard:authoring-vertical-slice-demo)
  with: slice_id=<VS-N.M.K>, --target=state
```

Behavior:

- **Target mode:** T1.4 sets `--target=state` explicitly because at R1.C-time `project-roadmap.json` is the authoritative store and ROADMAP.md doesn't exist on disk yet. This skill honors the override without auto-detection.
- **Authoring tightness:** during R1.C, the goal is 1-3 skeleton criteria per slice (per SPEC §9.2 hybrid authoring) — enough to scaffold the demo intent, not enough to require full implementation context. Lean toward "at least one criterion per slice" over "zero"; eval S1 checks this.
- **State write:** appends to `vertical_slices[<idx>].demo_criteria[]` via `sf_state_write_atomic`. No `sf_demo_append` call (that's markdown-mode). T1.4 does NOT re-render ROADMAP.md between per-slice invocations — emission happens once at §11 of T1.4, after R1.C close.
- **Idempotent within R1.C:** if T1.4 is `--refine-slice`d and this skill is re-invoked on the same slice, existing `demo_criteria[]` entries are preserved (per §6); only new lines append.

The split is clean: T1.4 owns the slice block + summary + sprint roll-up; this skill owns the demo-criteria array contents.

---

## 9. Composition with scaffold-dev

scaffold-dev's orchestrator-implementer cycle (scaffold-dev SPEC §16.2) invokes this skill at slice planning time — when the orchestrator opens a sprint and walks each slice to fill in implementation context. The invocation contract:

```
Skill(scaffold-onboard:authoring-vertical-slice-demo)
  with: slice_id=<VS-N.M.K>, --target=markdown
```

Behavior:

- **Target mode:** scaffold-dev sets `--target=markdown` explicitly because at slice-planning time ROADMAP.md has been emitted (R1.C is closed) and is the live document scaffold-dev reads / writes. This skill honors the override.
- **Authoring intent:** top-up. The slice may already have 1-3 skeleton criteria from R1.C; scaffold-dev's orchestrator refines or adds based on the now-available implementation context (which test files exist, which endpoints land in this slice, which UI surfaces are demoable). The criteria count grows from "skeleton" to "implementable", but the grammar stays the same.
- **Markdown write:** appends to the slice's `##### Demo criteria` subsection via `sf_demo_append`. The helper handles slice-block location + idempotent line equality + atomic write.
- **Idempotent across runs:** S2 eval scenario verifies this. Run A (same-text re-supply) is a no-op; Run B (new text) appends without reordering pre-existing lines.

The split is clean: scaffold-dev owns sprint planning + slice implementation; this skill owns the demo-criteria grammar layer (so scaffold-dev doesn't reinvent the `→ expected:` parser or duplicate idempotence logic).

---

## 10. Manifest-aware output routing

State mode writes go to `$(sf project_data_dir)/project-roadmap.json` — that's scaffold-onboard's project-scoped plugin data directory, **not** subject to manifest routing. State files live with the plugin data, not in the user's canonical or ai_workspace repos.

Markdown mode writes go through manifest routing, identical to T1.4's emission path:

```bash
roadmap_path="$(sf_resolve_output_path roadmap ROADMAP.md)"
```

Resolution behavior (per SPEC §10.1):

- **Manifest present** (walked up from `pwd` to find `.workspace/pairing.json`): returns absolute path with `routing.roadmap`'s destination root expanded (default `canonical.root` per §10.4) — e.g., `<canonical-repo>/ROADMAP.md`.
- **Manifest absent** (single-repo mode): returns `$(pwd)/ROADMAP.md` — v0.1.0-style fallback. The roadmap doc lives at project root in single-repo mode, identical to T1.4's emission.
- **Manifest present but `routing.roadmap` missing** (older workspace-init manifest pre-dating SPEC §10.4): helper warns once and falls back to `$(pwd)/ROADMAP.md`. workspace-init v0.1.1 (point release) added the key with default `"canonical"`.

Always route through `sf_resolve_output_path` for markdown-mode writes — never hardcode `ROADMAP.md` against `$(pwd)` directly. The single-repo fallback is byte-identical to v0.1.0 cwd-rooted behavior; cross-repo routing in workspace-init mode falls out of the same helper without changes to this skill body.

**Lane discipline:** this skill writes to ONE of two targets per invocation — `project-roadmap.json` (state mode) OR `ROADMAP.md` (markdown mode). Never both. Never any other file. Never touch `PROJECT_PLAN.md`, `MASTER-SPEC.md`, `CLAUDE.md`, `03-code-patterns.md`, `00-project-brief.md` through `08-governance.md`, or any sprint/scaffold-dev artifact.

---

## 11. Why U+2192 arrow (not ASCII `->`)

The grammar delimiter is the literal U+2192 arrow character (`→`), NOT the ASCII `->` digraph. This is a deliberate v0.2 design choice with three reinforcing reasons:

1. **Visual disambiguation.** `→` reads unambiguously as a delimiter in rendered markdown. `->` collides with arrow operators in many programming languages (Rust, Haskell, Python type hints), arrow function syntax (JavaScript), and shell redirection adjacent contexts — leading to grep / parser false matches when scanning ROADMAP.md from related tooling.
2. **Forced-correctness contract.** `sf_demo_parse_line` rejects ASCII `->` with a specific error class. The user can't accidentally author a half-valid line that downstream consumers (scaffold-dev's execution) silently mis-parse — they get a hard validation failure at authoring time with a remediation hint.
3. **Cross-plugin grammar lock.** scaffold-dev SPEC §14.1 specifies U+2192 verbatim; v0.2 of scaffold-onboard adopts the same delimiter byte-for-byte. The two plugins share the grammar at the byte level so `sf_demo_parse_line` (here) and scaffold-dev's execution-time parser are interchangeable.

**Practical concern — input methods:** the user can type `→` via OS-level character picker, IME shortcut, or copy-paste from this skill's examples. If they type `->` by reflex, `sf_demo_parse_line` catches it and surfaces a fix-up suggestion. **Do NOT** silently rewrite `->` into `→` on the user's behalf at write time — that hides the grammar contract from them. Surface the rejection, suggest the corrected line, let them re-supply.

**Anti-pattern reminder:** `->` ASCII as the delimiter is wrong; do not emit it in examples in this skill body, do not accept it from the user, do not normalize it silently. The arrow character is canonical.

---

## 12. Slash-command bridge (skill-only invocation)

Per SPEC §6, this skill is **skill-only — no dedicated slash command**. There is no `/add-demo` or `/author-demo-criteria` wrapper in v0.2. Invocation paths:

1. **Description-match auto-invoke** on trigger phrases (per §2 above) — the path for ad-hoc user-initiated authoring.
2. **Explicit `Skill(scaffold-onboard:authoring-vertical-slice-demo)` invocation** from another skill body — T1.4's `planning-project-roadmap` during R1.C (per §8), scaffold-dev's orchestrator at slice planning (per §9).
3. **No `/plan-roadmap`-style slash bridge.** The user does not say `/author-demo` — they say either "author demo criteria for VS-N.M" (description-match) or they invoke this skill via the parent skill's flow.

Why no slash command: v0.2 keeps the slash-command surface minimal — `/onboard`, `/scaffold-project`, `/scaffold-docs`, `/plan-roadmap`. Demo-criteria authoring is a per-slice fine-grained activity throughout the project lifecycle (R1.C + every scaffold-dev slice planning), not a session-level entry point. Description-match invocation fits the cadence better than a slash command users would need to remember per-slice.

---

## 13. Bash bookkeeping helpers

This skill never bash-orchestrates the judgment work (picking the right target mode when ambiguity exists, framing the prompt for skeleton vs implementable, deciding whether to push back on a line that validates but feels wrong, recognizing user-line / auto-line form-intent mismatches). It calls helpers for I/O and validation only.

**Demo-criteria validation + write (lib/demo-criteria.sh — T3.5):** `sf_demo_parse_line` (single-line write-validator — primary use here), `sf_demo_append` (markdown-mode append; handles slice-block location + idempotent line equality + atomic write), `sf_demo_parse_slice` (file-level read used by scaffold-dev's execution-time consumer — not invoked from this skill).

**State (lib/state.sh — re-used):** `sf_state_write_atomic` (state-mode append into `vertical_slices[<idx>].demo_criteria[]`), `sf_state_read_field` (reading the `checkpoint` field for auto-detection per §5.2).

**Routing (lib/routing.sh):** `sf_resolve_output_path` (markdown-mode `roadmap` logical name resolution), `sf_discover_manifest` (walking up for `.workspace/pairing.json`).

**Roadmap (lib/roadmap.sh — re-used):** `sf_roadmap_read_checkpoint` (alias for the §5.2 auto-detection field read), `sf_roadmap_render` (NOT invoked from this skill — rendering is T1.4's lane at R1.C close).

**Atomic writes:** state-mode writes go through `sf_state_write_atomic` (temp-file + atomic mv, per existing state.sh discipline). Markdown-mode writes go through `sf_demo_append` (which uses the same temp-file + atomic mv pattern under the hood). macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling helpers over re-inlining shell.

These are pseudocode references — the implementations live in `lib/demo-criteria.sh` (per SPEC §9.3 + PLAN T3.5). The skill body never inlines awk/sed pipelines for grammar parsing; that's the helper's lane.

---

## 14. No architect-critic invocation

Per SPEC §12.1, only four critic moments exist in scaffold-onboard v0.2: Phase 5 close, Phase 7 close, MASTER-SPEC close, and `/plan-roadmap` close. **Demo-criteria authoring is not one of them.** Do not invoke `Skill(architect-critic:critiquing-spec)` from this skill body.

Why no critic here: demo-criteria authoring is a tight, deterministic transformation from a user-stated demo intent to a grammar-conformant bullet line. The adversarial value would be low (the line either validates via `sf_demo_parse_line` or it doesn't — that's the verification mechanism), and the latency cost of a critic invocation per criterion would derail the per-slice cadence (T1.4's R1.C walks 5-25 slices per session; even a 30-second critic per slice would dominate the wall-clock).

If the user explicitly asks for adversarial review on a slice's demo design ("are these the right things to demo for VS-N.M?"), suggest they invoke `Skill(architect-critic:critiquing-spec)` separately with `target=roadmap` against the surrounding sprint context — but do not invoke it inline. The roadmap-close critic moment (T1.4 §10) covers slice-level adversarial review at sprint-end aggregation; per-slice inline criticism is intentionally out of scope.

This is the same lane-discipline reason `scaffolding-governance-docs` (per its §7) and `authoring-machine-checkable-rules` (per its §13) don't invoke the critic: downstream deterministic transformations after the spec is locked are not critic moments.

---

## 15. Anti-patterns (do not do these)

- **Using ASCII `->` instead of the U+2192 arrow character (`→`)** as the grammar delimiter. `sf_demo_parse_line` rejects `->`; the cross-plugin grammar with scaffold-dev locks on U+2192 byte-for-byte (per §11). Do NOT silently normalize `->` to `→` on the user's behalf — surface the rejection and let them re-supply.
- **Writing to `PROJECT_PLAN.md` as a demo-criteria target.** `PROJECT_PLAN.md` is `/scaffold-docs`'s v0.1.0 Phase-2-Strategy-derived timeline doc, **unchanged from v0.1.0** and unrelated to the R1 hierarchy / demo criteria. Demo criteria land in `project-roadmap.json` (state mode) OR `ROADMAP.md` (markdown mode) — never `PROJECT_PLAN.md`. The filename collision was specifically avoided by SPEC §13.5's rename.
- **Auto-creating slice blocks when the named slice doesn't exist.** Slice block creation is `planning-project-roadmap`'s lane (R1.B / R1.C / `--add-slice`). If the slice ID resolves to neither target, route the user upstream per §2 — do NOT create a `#### VS-<id>:` heading from this skill.
- **Silently re-classifying form intent.** If a user supplies `user: Run pytest → expected: exit 0`, the line validates against `user:` grammar but the `expected:` tail is an exit code (an `auto:` shape). Surface the mismatch and offer a rewrite suggestion (per §3.3); do NOT silently convert `user:` to `auto:` behind the user's back.
- **Inlining `auto:`/`user:` grammar from another skill's body** (especially `planning-project-roadmap`). T1.4 explicitly defers to this skill at SPEC §5.4 / its §8; the grammar lives here. If you find yourself authoring grammar prompts in T1.4, you've crossed lanes.
- **Touching files other than the active target.** State mode writes ONLY `project-roadmap.json`; markdown mode writes ONLY ROADMAP.md. Never both in one invocation; never `MASTER-SPEC.md`, `CLAUDE.md`, `PROJECT_PLAN.md`, `03-code-patterns.md`, governance docs, or sprint artifacts.
- **Hardcoding `ROADMAP.md` against `$(pwd)`.** Always route via `sf_resolve_output_path roadmap ROADMAP.md` for markdown mode. The single-repo fallback is identical to v0.1.0 behavior; cross-repo routing requires the helper.
- **Skipping the idempotence check.** Every candidate line, after grammar validation, must compare against existing entries for the slice before the append decision. A byte-identical match is a no-op + confirmation message; a no-match is the append. Never skip the check — duplicate lines under a slice are a hard FAIL on S2 eval scenario.
- **Auto-detecting target mode when an explicit `--target=` override is supplied.** The override is unconditional — if it conflicts with on-disk state (e.g., `--target=markdown` but ROADMAP.md absent), surface a hard error and stop. Do NOT fall back silently.
- **Invoking architect-critic from this skill.** Demo-criteria authoring is not one of the four §12.1 critic moments. If a user wants adversarial review on demo design, route per §14 — don't call it inline.
- **Calling `Skill(architect-critic:critique)`** (the legacy v0.1.x slash-command-shaped name). If a future iteration grows a critic moment, the v0.2 skill is `Skill(architect-critic:critiquing-spec)`.
- **Letting this body exceed 500 lines.** Hard cap per Pass D skill-first guidance. Target ~300-400.

---

## 16. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: picking the right target mode when auto-detection is ambiguous, framing the per-slice prompt for skeleton (R1.C) vs implementable (scaffold-dev top-up), deciding whether to push back on a line that validates but feels semantically wrong, recognizing user-line / auto-line form-intent mismatches, deciding when to offer the hand-author exit after two validation failures.
- **Bash helpers** (`lib/demo-criteria.sh`, `lib/state.sh`, `lib/routing.sh`) handle pure I/O and grammar parsing: single-line validation, atomic state writes, manifest path resolution, slice-block location, idempotent line append.
- **`planning-project-roadmap` (T1.4)** is your upstream caller during R1.C — invokes this skill per slice with `--target=state`, seeds 1-3 skeleton criteria.
- **scaffold-dev's orchestrator** is your other upstream caller at slice planning — invokes this skill per slice with `--target=markdown`, tops up with implementable criteria.
- **scaffold-dev's `closing-vertical-slice`** is your downstream consumer at slice-close time — reads via `sf_demo_parse_slice`, executes the `auto:` lines, surfaces the `user:` lines for human walkthrough. Not invoked from this skill.
- **The user** is the final authority on the demo intent. On form-intent mismatch, ask. On validation failure, loop once then offer the hand-author exit. Never silently re-classify, never silently abort, never bypass the grammar contract.

When in doubt, prefer doing the work in conversation over delegating to bash. v0.2 makes this skill body the readable orchestration layer; bash is for bookkeeping (validation, state writes, path resolution, idempotent append) — not for judgment calls.
