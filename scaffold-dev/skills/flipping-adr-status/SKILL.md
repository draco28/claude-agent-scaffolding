---
name: flipping-adr-status
description: Flip an ADR's Status from Proposed to Accepted post-merge and append an Empirical validation section (operator-reported signal + date). Use this when the user says "flip ADR status", "mark ADR accepted", "accept ADR <n>", "empirical validation for ADR", or invokes `/flip-adr <adr-number-or-path>`. Resolves the ADR via the manifest-routed product/process dirs, verifies it is currently in the Proposed status, and refuses if it is already Accepted or not found. Targeted edit only — never re-authors the ADR body.
---

# flipping-adr-status

You are the second half of scaffold-dev's `proposed-then-flip` ADR lifecycle (see `recording-architecture-decision` §9.1). An ADR authored with `status_protocol: proposed-then-flip` ships as `Status: Proposed` alongside the slice that builds the architecture. After the build merges and the operator observes an empirical signal that the decision actually holds, this skill flips the Status to `Accepted` and records the validating signal — creating a durable trail of *when and how* each architectural decision was confirmed.

This skill makes a **targeted edit** to an existing ADR: it flips one metadata line and appends one section. It does NOT re-author the ADR body, renumber the series, supersede/deprecate other ADRs, or author new ADRs (that's `recording-architecture-decision`). The flip is gated on the ADR currently being `Status: Proposed` — an already-`Accepted` ADR is refused (this lifecycle is one-way: Proposed → Accepted).

---

## 1. Overview

When invoked, you:

1. **Discover the workspace-init pairing manifest** via the `sd` dispatcher. Refuse fail-fast if absent (mirrors `recording-architecture-decision` §3.1).
2. **Resolve the target ADR** from the argument — an absolute path, or an ADR number (e.g. `0003` / `3`) scanned across BOTH the product and process ADR dirs. Disambiguate or fail clearly when the number matches in both series or in neither.
3. **Read the ADR** and verify it is currently `Status: Proposed`. Refuse (no edit) if it is `Accepted`, `Superseded`, `Deprecated`, or has no recognizable Status line.
4. **Prompt for the empirical signal** — a one-or-two-sentence description of what validated the decision. Wait for it.
5. **Apply the flip** — Edit `- Status: Proposed` → `- Status: Accepted`, and append an `## Empirical validation` section carrying the operator's signal + today's date.
6. **Emit the final message** naming the ADR's absolute path, the new Status, and the recorded signal.

---

## 2. When to use

**Trigger phrases (description-match):**

- `flip ADR status` / `flip adr <n>`
- `mark ADR <n> accepted` / `accept ADR <n>`
- `empirical validation for ADR <n>`
- `/flip-adr <adr-number-or-path>` (argument bridge per `feedback_slash_command_dollar_n_bug`)

**Do NOT auto-invoke when:**

- The user wants to *author* a new ADR (that's `recording-architecture-decision`).
- The user wants to *supersede* / *deprecate* an ADR (a different lifecycle, deferred — this skill only does Proposed → Accepted).
- No workspace-init pairing manifest exists (refuse per §3).

---

## 3. Pre-flight + manifest discovery (refuses fail-fast)

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`). Refuse if no manifest:

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

The literal `/init-workspace` and `/pair-workspace` tokens are load-bearing (mirrors `recording-architecture-decision` §3.1). Never read manifest fields via raw inline `jq` — route through `sd manifest_get` / `sd manifest_resolve`.

---

## 4. Resolve the target ADR

The argument arrives via `$SCAFFOLD_DEV_ARGS` (from the `/flip-adr` command bridge) or the trigger-phrase text.

### 4.1 Argument is an absolute path

If the argument resolves to an existing `*.md` file, use it directly. Confirm it lives under one of the manifest-routed ADR dirs (product or process) before editing — refuse a path outside both.

### 4.2 Argument is an ADR number

Resolve both ADR dirs and scan each for `adr-<NNNN>-*.md`:

```bash
prod_dir="$(sd manifest_resolve "$(sd manifest_get '.routing.product_adrs')")"
proc_dir="$(sd manifest_resolve "$(sd manifest_get '.routing.process_adrs')")"
num="$(printf '%04d' "$((10#${arg_num}))")"
matches=$(ls "$prod_dir"/adr-"$num"-*.md "$proc_dir"/adr-"$num"-*.md 2>/dev/null)
```

- **Exactly one match** → that's the target.
- **A match in BOTH series** (product `0003` and process `0003` both exist) → surface both absolute paths and ask which one. Never guess.
- **No match** → fail with a message naming both scanned dirs and the number. Do not create anything.

---

## 5. Verify Status: Proposed (gate)

Read the resolved ADR. Its Status line — the metadata form authored by `recording-architecture-decision` — is:

```
- Status: Proposed
```

- If `Status: Proposed` → proceed.
- If `Status: Accepted` → refuse: *"ADR `<path>` is already Accepted; the Proposed → Accepted flip is one-way — nothing to do."* No edit.
- If `Status: Superseded` / `Deprecated` / anything else → refuse: *"ADR `<path>` has Status `<value>`, not `Proposed`; this skill only flips Proposed → Accepted."* No edit.
- If no recognizable Status line → refuse and name the file so the user can inspect it.

**Format contract.** `recording-architecture-decision`'s `templates/adr.md.tmpl` always emits the status as the `- Status: <value>` **metadata line** (`- Status: {{status}}`) — that is the only form this skill matches and flips. If an ADR carries its status some other way (e.g. a `## Status` heading in a hand-authored or non-template ADR), this skill does NOT guess or rewrite it: it refuses per the "no recognizable Status line" bullet above and asks the user to normalize the ADR first. Refusing-not-guessing keeps a wrong match from corrupting the decision record.

The gate is binding: never flip an ADR that is not currently Proposed, and never edit on refusal.

---

## 6. Prompt for the empirical signal

Surface:

> What empirical signal validated this decision? One or two sentences — e.g. *"Path A smoke test passed against a prod-equivalent stack on 2026-06-15"* or *"30 days in production with no retry-storm regressions."*

Wait for the user's response. This is the validation record — do NOT fabricate it or proceed without it. If the user has no signal yet, say so and stop (the ADR stays Proposed).

---

## 7. Apply the flip (targeted edit)

Two targeted edits to the resolved ADR — nothing else changes:

1. **Flip the Status line** (Edit tool, exact one-line replace):

   `- Status: Proposed` → `- Status: Accepted`

2. **Append the Empirical validation section** at end of file:

```markdown

## Empirical validation

- Validated: <YYYY-MM-DD>
- Signal: <operator's one-or-two-sentence description, verbatim>
```

Use the Edit tool for both. Do NOT re-render the ADR from the template, renumber it, reorder sections, or touch Context / Decision / Consequences / References. The decision record is preserved; you only flip the status and add the validation trail.

---

## 8. Final assistant message

After the edits, emit a one-paragraph confirmation naming:

1. **The ADR's absolute path** (code-formatted).
2. **The new Status** (`Accepted`) and the previous (`Proposed`).
3. **The recorded signal + date.**

E.g.: *"Flipped `<abs-path>` Proposed → Accepted; recorded empirical validation (`<signal>`, `<date>`)."* The ADR in canonical typically gets committed alongside the validating change; the skill does NOT auto-commit.

---

## 9. Anti-patterns (do not do these)

- **Flipping an ADR that is not `Status: Proposed`.** §5 is binding — already-Accepted is one-way-done; Superseded/Deprecated are a different lifecycle. Refuse, no edit.
- **Fabricating or skipping the empirical signal.** The signal IS the value of this skill — the durable record of *why* the decision was accepted. No signal → no flip.
- **Re-authoring the ADR body or renumbering.** This is a two-edit change (Status flip + appended section). Re-rendering from the template would clobber the user-authored body.
- **Guessing between product and process when a number matches both series.** Surface both paths and ask.
- **Reading manifest fields via raw `jq`.** Route through `sd manifest_get` / `sd manifest_resolve`.
- **`mkdir`-ing or creating a missing ADR.** If the resolved number/path doesn't exist, fail with the scanned dirs named — never author.

---

## 10. Notes on tool boundaries

- **You** make the judgment calls: which series an ambiguous number belongs to (ask, don't guess), how to format the operator's signal into the validation section.
- **Bash helpers** (`lib/manifest.sh`) handle manifest reads + path resolution; the Edit tool does the surgical status flip + section append.
- **`recording-architecture-decision`** is the upstream author: it writes the `Status: Proposed` ADRs this skill flips (via `status_protocol: proposed-then-flip`). The handoff is one-way (author Proposed → flip to Accepted).
- **No worktree, no commit.** The flip edits a tracked file in place; the operator commits it alongside the validating change.
