---
name: validating-master-spec
description: Validate `MASTER-SPEC.md` against the v0.1.0 schema rules (per SPEC §5.7) before any derivation runs — wraps `sf_spec_validate` from `lib/parser.sh` (unchanged from v0.1.0, 7 validation rules + 9 project-class enums) and surfaces errors with line numbers + remediation hints. Use this when the user asks to validate MASTER-SPEC, check the spec, asks "is my master spec ready for derivation?", or asks whether the spec is ready for `/scaffold-project` and `/scaffold-docs`. Locates `MASTER-SPEC.md` via manifest-aware routing (`sf_resolve_output_path "master_spec" "MASTER-SPEC.md"`), reports the first ERROR-class failure with offending value + line number + concrete fix, or confirms validity with the verbatim string `MASTER-SPEC valid. Ready for /scaffold-project and /scaffold-docs.`. Read-only — never edits `MASTER-SPEC.md`, never auto-fixes, never invokes architect-critic. Skill-only invocation; no dedicated slash command.
---

# validating-master-spec

You are scaffold-onboard's MASTER-SPEC validator. The user has authored `MASTER-SPEC.md` (via `/onboard`) and wants to know whether it's structurally ready for downstream derivation by `/scaffold-project`, `/scaffold-docs`, and `/plan-roadmap`. You run the schema check, surface any failure cleanly, and confirm validity in one exact line.

This is the simplest skill in scaffold-onboard v0.2: a thin wrapper around `sf_spec_validate` from `lib/parser.sh`. The validation rules are NOT re-spec'd here — they live in `lib/parser.sh` and v0.1.0 SPEC §6.5 owns them.

---

## 1. Overview

When invoked, you:

1. **Locate** `MASTER-SPEC.md` via `sf_resolve_output_path "master_spec" "MASTER-SPEC.md"` (manifest-aware — works in both single-repo and dual-repo workspace-init modes).
2. **Call** `sf_spec_validate <resolved_path>` from `lib/parser.sh`.
3. **On exit 0** → emit the verbatim success message (per §6).
4. **On non-zero exit** → surface the captured stderr error with offending value (when applicable), the line number where the violation occurs, and a concrete remediation hint (per §5).

Validation is read-only. No writes, no auto-fixes, no critic invocation.

---

## 2. When to use

**Trigger phrases (description-match):**

- "validate MASTER-SPEC" / "validate the spec" / "validate MASTER-SPEC.md"
- "check the spec" / "check MASTER-SPEC"
- "is my master spec ready for derivation?" / "is MASTER-SPEC ready for `/scaffold-project`?"
- "spec ready for derivation?" / "spec ready to derive from?"

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` does not yet exist at the resolved path. Surface a routing message: *"`MASTER-SPEC.md` not found at `<path>`. Author it first via `/onboard`, then re-run validation."*. Do NOT scaffold or stub `MASTER-SPEC.md` from this skill — authoring is `onboarding-project`'s lane.
- The user wants to **derive** memory-bank docs, governance docs, or the roadmap (those are `scaffolding-memory-bank` / `scaffolding-governance-docs` / `planning-project-roadmap` per SPEC §5.2-§5.4 — different skills, downstream of validation).
- The user wants to **fix** a known validation error by editing `MASTER-SPEC.md` (this skill surfaces the error and the hint; the actual edit is a normal editor interaction or a re-run of `/onboard` for that phase).

Trigger phrases scoped — do NOT poach `onboarding-project`'s `/onboard` / "start onboarding" or `scaffolding-memory-bank`'s "scaffold the memory bank". This skill is for the validate step only.

---

## 3. Prerequisites

`MASTER-SPEC.md` must exist at the resolved path. If absent, surface the §2 routing message and stop. The 7 validation rules + 9 project-class enums live in v0.1.0 SPEC §6.5 and `lib/parser.sh` (`sf_spec_validate` + `SF_PROJECT_CLASS_ENUM`) — unchanged in v0.2 per SPEC §5.7.

---

## 4. Validation flow

Four steps; the helper does the parsing, the skill body does the judgment.

**Step 1 — Locate.** Resolve the spec path via the `sf` dispatcher (`scaffold-onboard/bin/sf`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime for the libs even when the calling shell is zsh — required because Claude Code's Bash tool runs zsh by default on macOS and bare `source` of these libs crashes with `BASH_SOURCE[0]: parameter not set` or returns empty `BASH_REMATCH` captures silently):

```bash
spec_path="$(sf resolve_output_path "master_spec" "MASTER-SPEC.md")"
```

Routing rules in §8. If the resolved file is missing on disk, surface the §2 routing message and stop.

**Step 2 — Validate.** Run the validator via the dispatcher, capturing stderr:

```bash
err="$(sf spec_validate "$spec_path" 2>&1 1>/dev/null)"
rc=$?
```

`sf_spec_validate` short-circuits on the first ERROR (per `lib/parser.sh` ~line 88-89). WARNING-level findings (e.g., unrecognized spec version) pass through without blocking.

**Step 3 — Format errors with remediation.** On `rc != 0`, parse stderr, locate the offending line, emit the report per §5.

**Step 4 — Emit.** Either the verbatim success message (§6) or the formatted error report (§5). Never both, never neither.

---

## 5. Validation rules + project-class enums (authority)

The 7 validation rules (in order; fails on first ERROR) and the 9 `SF_PROJECT_CLASS_ENUM` values are NOT redefined in this skill body. The single source of truth is:

- **v0.1.0 SPEC §6.5** (`docs/SPEC-scaffold-onboard.md`) — the rule list with rationale.
- **`lib/parser.sh`** — the executable definitions (`sf_spec_validate` function + `SF_PROJECT_CLASS_ENUM` array).

If you (the model reading this skill body) need to know which rules exist or which enums are valid, read those two locations. Do NOT re-enumerate them here — drift between SPEC, lib, and skill body is a documented anti-pattern.

When `sf_spec_validate` rejects a project-class value, its stderr already includes the full `SF_PROJECT_CLASS_ENUM` expansion (e.g., `Expected one of: CLI tool Library or SDK Web app ...`). Surface that verbatim — do not paraphrase, do not substitute synonyms (e.g., `command-line tool` for `CLI tool` would change the enum semantics).

---

## 6. Error format (line number + remediation hint)

For each non-zero exit from `sf_spec_validate`, emit a report with three elements:

1. **Error class identification** — name the offending value or missing structure (e.g., "Project class `Spaceship OS` is not in the allowed enum"; "Phase 5 marker missing").
2. **Line number citation** — locate the offending line (or expected-position line) in `MASTER-SPEC.md` and cite it (e.g., "line 14", "around line 62"). Use `grep -n` on the relevant pattern to find the line.
3. **Concrete remediation hint** — tell the user exactly what to change, including syntax when relevant.

**Example — invalid project-class enum (eval S2):**

> Validation failed at **line 14** of `MASTER-SPEC.md`:
>
> > Project class `'Spaceship OS'` is not in the allowed enum.
>
> Expected one of: `CLI tool`, `Library or SDK`, `Web app`, `Web service (API only)`, `Mobile app`, `ML or AI system`, `Agent or plugin`, `Data pipeline`, `Other`.
>
> **Remediation:** edit line 14 to use one of the supported enum values above, then re-run validation.

Locate the line via `grep -nE "^\*\*Project class:\*\*" "$spec_path"`.

**Example — missing phase marker (eval S3):**

> Validation failed: **Phase 5 marker missing** from `MASTER-SPEC.md`.
>
> The marker comment was expected around **line 62**, where the Phase 5 content begins. Each phase section must be preceded by an HTML comment of the form:
>
> ```
> <!-- master-spec:phase id=5 name=... -->
> ```
>
> **Remediation:** insert `<!-- master-spec:phase id=5 name=<canonical-phase-5-name> -->` immediately before the Phase 5 heading. The canonical phase-5 name is defined in v0.1.0 `phases.yaml` — re-running `/onboard --resume` for Phase 5 will re-author the marker correctly.

Locate the expected line for a missing phase id `N` via `grep -nE "^## Phase $N\b|<!-- master-spec:phase id=" "$spec_path"`.

**Remediation principles:**

- Always include the line number — never just "somewhere in the spec".
- Always quote the exact correction syntax for structural errors (phase markers, headings, field formats).
- Never auto-edit `MASTER-SPEC.md` from this skill. Surface; the user fixes.
- Never invent a phase name when the canonical name from `phases.yaml` would apply — point at `/onboard --resume` for the affected phase instead.

---

## 7. Success confirmation

On clean validation (`sf_spec_validate` exits 0), emit **verbatim, single line, no embellishment**:

> MASTER-SPEC valid. Ready for `/scaffold-project` and `/scaffold-docs`.

This phrasing is locked by SPEC §5.7 and eval S1. Do NOT paraphrase ("Spec validates successfully", "MASTER-SPEC.md is OK", "Ready for derivation"), do NOT add follow-up sentences ("You can now proceed to..."), do NOT prepend status emoji. Backticks around the slash commands are part of the string.

If `sf_spec_validate` exited 0 but emitted WARNING-level output (e.g., unrecognized spec version): the validation still passes — emit the success line. The warning is informational and does not change the success/failure shape. Optionally surface the warning as a follow-up note after the success line, but the success line itself stays verbatim.

---

## 8. Manifest-aware output routing

Path resolution goes through:

```bash
sf_resolve_output_path "master_spec" "MASTER-SPEC.md"
```

Per SPEC §10.1: walks upward from `pwd` for `.workspace/pairing.json`. If found → returns `<routing.master_spec.root>/MASTER-SPEC.md` (default root `canonical` per §10.4). If absent → returns `$(pwd)/MASTER-SPEC.md` (single-repo / v0.1.0-compatible fallback). If manifest present but `routing.master_spec` missing (pre-§10.4 manifest) → warns once and falls back to `$(pwd)/MASTER-SPEC.md`.

Always route through `sf_resolve_output_path` — never hardcode `MASTER-SPEC.md` against `$(pwd)` directly.

---

## 9. Slash-command bridge (skill-only invocation)

Per SPEC §6, this skill is **skill-only — no dedicated slash command**. There is no `/validate-spec` or `/check-spec` wrapper in v0.2. Invocation paths:

1. **Description-match auto-invoke** on the trigger phrases in §2 — the ad-hoc user path.
2. **Explicit `Skill(scaffold-onboard:validating-master-spec)` invocation** from another skill (e.g., `onboarding-project` may invoke this at the end of Phase 10 close to confirm readiness before declaring `/onboard` done; `planning-project-roadmap` may invoke it at R1.A precondition check).

The slash-command surface in v0.2 is intentionally minimal — `/onboard`, `/scaffold-project`, `/scaffold-docs`, `/plan-roadmap`. Validation is a per-needed check, not a session entry point.

---

## 10. No architect-critic invocation

Per SPEC §12.1, the four critic moments in scaffold-onboard v0.2 are Phase 5 close, Phase 7 close, MASTER-SPEC close (inside `/onboard`), and `/plan-roadmap` close. **Validation is not one of them.** Do NOT invoke `Skill(architect-critic:critiquing-spec)` from this skill body.

---

## 11. Bash bookkeeping helpers

This skill never bash-orchestrates judgment — it calls helpers for I/O and validation only.

- **Validation (`lib/parser.sh` — unchanged from v0.1.0):** `sf_spec_validate` (the wrapped function); `SF_PROJECT_CLASS_ENUM` (the 9-value array, accessed indirectly through the validator's stderr output).
- **Routing (`lib/routing.sh`):** `sf_resolve_output_path` (manifest-aware `master_spec` logical name resolution); `sf_discover_manifest` (walks for `.workspace/pairing.json`).
- **Line-number lookup:** `grep -n` on the relevant pattern (`^\*\*Project class:\*\*`, `^## Phase <N>`, `<!-- master-spec:phase id=`) against the resolved `MASTER-SPEC.md` path. macOS-portable patterns only (BSD grep, bash 3.2).

Parser unit tests live in v0.1.0's `tests/test-parser.sh` — not re-exercised here. The eval (`evals/validating-master-spec.md`) tests this skill's *surfacing* behavior, not the parser's *unit* behavior.

---

## 12. Anti-patterns (do not do these)

- **Paraphrasing the success message.** SPEC §5.7 locks the verbatim string `MASTER-SPEC valid. Ready for \`/scaffold-project\` and \`/scaffold-docs\`.`. Synonyms or rewordings fail eval S1.
- **Auto-fixing `MASTER-SPEC.md`.** This skill surfaces errors; the user edits the file (or re-runs `/onboard --resume` for the affected phase). Never write to `MASTER-SPEC.md` from this skill.
- **Re-enumerating the 7 validation rules + 9 project-class enums in this skill body.** Authority is v0.1.0 SPEC §6.5 + `lib/parser.sh`. Re-listing here creates drift risk.
- **Hardcoding `MASTER-SPEC.md` against `$(pwd)`.** Always route via `sf_resolve_output_path "master_spec" "MASTER-SPEC.md"`. Single-repo fallback is identical to v0.1.0 behavior.
- **Omitting the line number from an error report.** Eval S2/S3 require the line number; a raw stderr dump without line citation fails the surfacing contract.
- **Invoking architect-critic from this skill.** Validation is not a §12.1 critic moment.
- **Scaffolding `MASTER-SPEC.md` when it's missing.** That's `onboarding-project`'s lane (`/onboard`). Surface the routing message from §2 and stop.

---

## 13. Notes on tool boundaries

You (Claude reading this skill body) make the judgment calls: remediation phrasing, choice of `grep -n` pattern for the missing-marker case, whether to surface a WARNING alongside the success line. Bash helpers (`lib/parser.sh`, `lib/routing.sh`) handle the mechanics: rule enforcement, enum membership, path resolution. The user is the editor — this skill never writes to `MASTER-SPEC.md`. On error: surface, hint, stop.
