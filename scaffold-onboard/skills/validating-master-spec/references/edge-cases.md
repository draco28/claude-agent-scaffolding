# Edge cases: validating-master-spec

Non-happy-path scenarios for the validation surface. Each entry names the trigger, the helper behavior (`sf_spec_validate` from `lib/parser.sh` — unchanged from v0.1.0), and the three-element error report the skill body should emit. The 7 validation rules + 9 `SF_PROJECT_CLASS_ENUM` values are NOT re-enumerated here — authority is v0.1.0 SPEC §6.5 + `lib/parser.sh` (per §5 of the skill body).

---

## 1. Invalid `Project class` enum (out of `SF_PROJECT_CLASS_ENUM`)

**Trigger:** user runs `validate MASTER-SPEC` against a spec containing `**Project class:** Spaceship OS` on line 14. `Spaceship OS` is not a member of the v0.1.0 enum (the 9 values live in `SF_PROJECT_CLASS_ENUM` in `lib/parser.sh`).

**Helper behavior:** `sf_spec_validate` exits non-zero with stderr containing the parser's full enum expansion:

```
Project class 'Spaceship OS' not in enum. Expected one of: CLI tool Library or SDK Web app Web service (API only) Mobile app ML or AI system Agent or plugin Data pipeline Other
```

**Line lookup:** skill locates the offending line via:

```bash
grep -nE "^\*\*Project class:\*\*" "$spec_path"
# → 14:**Project class:** Spaceship OS
```

**Skill body surfacing (three-element report):**

> Validation failed at **line 14** of `MASTER-SPEC.md`:
>
> > Project class `'Spaceship OS'` is not in the allowed enum.
>
> Expected one of: `CLI tool`, `Library or SDK`, `Web app`, `Web service (API only)`, `Mobile app`, `ML or AI system`, `Agent or plugin`, `Data pipeline`, `Other`.
>
> **Remediation:** edit line 14 to use one of the supported enum values above, then re-run validation. If your project class genuinely doesn't fit any of the 9 enums, use `Other` and document the actual class in the Executive Summary.

**Discipline:**

- Name the offending value (`Spaceship OS`) explicitly. Eval S2 requires this.
- Surface the full 9-value enum verbatim — do NOT paraphrase. Substituting `command-line tool` for `CLI tool` would change the enum semantics and fail downstream template substitution.
- Cite the line number — never just "somewhere in the spec".
- Suggest `Other` as the safety-net enum for projects that don't fit.

---

## 2. Duplicate phase marker

**Trigger:** user's `MASTER-SPEC.md` has TWO `<!-- master-spec:phase id=5 name=Architecture -->` comments — one at line 62 (correct position) and a stray duplicate at line 145 (from a copy-paste or interrupted re-author).

**Helper behavior:** `sf_spec_validate` rejects with stderr like:

```
Duplicate phase marker: id=5 appears at line 62 and line 145.
```

(Or whatever the parser's exact stderr is — `lib/parser.sh` owns the format. The skill body's job is to relay it with the surfacing contract.)

**Skill body surfacing:**

> Validation failed: **Phase 5 marker duplicated** in `MASTER-SPEC.md`.
>
> The `<!-- master-spec:phase id=5 ... -->` marker appears at:
>   - **line 62** (first occurrence — likely correct position)
>   - **line 145** (second occurrence — likely the stray duplicate)
>
> Each phase id must appear exactly once.
>
> **Remediation:** delete the duplicate at line 145 (or whichever occurrence is in the wrong section), then re-run validation. If line 145 marks the start of legitimate Phase 5 *continuation* content, remove the marker from there and keep the prose — markers head sections, they do not punctuate them.

**Discipline:**

- Name both line numbers. The user needs to know which one to delete.
- Suggest which one is likely the stray (based on context — usually the second occurrence in a copy-paste scenario, but the user is the authority).
- Don't auto-delete. The skill surfaces; the user fixes.

---

## 3. File missing (`MASTER-SPEC.md` not at resolved path)

**Trigger:** user runs `validate MASTER-SPEC` from a directory with no `MASTER-SPEC.md` at the path `sf_resolve_output_path master_spec MASTER-SPEC.md` returns.

**Helper behavior:** none — `sf_spec_validate` is never called. The skill body checks `[ -f "$spec_path" ]` before invoking the validator (per §3 + §4 step 1 of the skill body).

**Skill body surfacing:**

> `MASTER-SPEC.md` not found at `/Users/<you>/work/halftime-onboard/MASTER-SPEC.md`.
>
> Validation is read-only — it can't bring a spec into being. Author one first:
>
>   /onboard
>
> Or, if your `MASTER-SPEC.md` lives at a non-default location, ensure `.workspace/pairing.json` declares the correct `routing.master_spec` destination and re-run from a directory inside that workspace pair.

**Discipline:**

- Do NOT scaffold a stub `MASTER-SPEC.md`. Authoring is `onboarding-project`'s lane (SPEC §5.1) — this skill is validate-only.
- Do NOT emit the SPEC §5.7 success line (no spec was validated).
- Surface the absolute path the skill was looking at — the user needs to know whether the resolution worked correctly.

---

## 4. File present but empty (distinct error from "invalid")

**Trigger:** `MASTER-SPEC.md` exists at the resolved path but is zero bytes (e.g., `touch MASTER-SPEC.md`).

**Helper behavior:** `sf_spec_validate` exits non-zero. Stderr is parser-specific — likely:

```
MASTER-SPEC.md is empty (0 bytes). No content to validate.
```

(Or the parser may report a "Missing top-level heading" error if it treats empty as missing-heading; either way, the surfacing is the same shape.)

**Skill body surfacing:**

> Validation failed: **`MASTER-SPEC.md` is empty.**
>
> The file exists at `/Users/<you>/work/halftime-onboard/MASTER-SPEC.md` but contains no content (0 bytes).
>
> Empty is distinct from missing — an empty spec is a half-state, usually the result of an interrupted `/onboard` or a `touch` command. To recover:
>
>   /onboard            # author from scratch
>   /onboard --resume   # resume if state file is present
>
> After authoring, re-run validation.

**Discipline:**

- Distinguish empty from missing in the surfacing. Both are not-validatable, but they imply different user actions (resume vs. start fresh; or "did I run `touch` by accident?").
- Do NOT treat empty as "invalid" with a malformed-content error. The user error class is different (likely interrupted onboarding vs. wrong content), so the remediation path is different.

---

## 5. WARNING-level findings (non-blocking, e.g., unrecognized spec version)

**Trigger:** spec has `**Spec version:** 1.2` instead of `1.0`. The parser recognizes only `1.0` as the v0.1.0 schema version; `1.2` is a forward-version not yet supported.

**Helper behavior:** `sf_spec_validate` emits a WARNING-level finding via `sf_log_warn` but does NOT exit non-zero. The validator's stderr contains the WARNING; the exit code is 0 because no ERROR-class rule fired. Per §4 of the skill body, WARNING-level findings pass through without blocking.

**Skill body surfacing:** emit the SPEC §5.7 success line first (verbatim, locked), THEN optionally surface the WARNING as a follow-up note:

> MASTER-SPEC valid. Ready for `/scaffold-project` and `/scaffold-docs`.
>
> Note: the validator emitted a WARNING — `Unrecognized spec version: 1.2`. The current parser is built against `1.0` and may not handle forward-version semantics; consider downgrading the `**Spec version:**` field to `1.0` if you didn't intentionally bump it.

**Discipline:**

- The success line stays verbatim. Eval S1 fails any synonym; the WARNING follow-up does NOT replace or alter the success line.
- WARNINGs are informational, not blockers. Do NOT refuse to validate, do NOT emit an error-shaped report. The user's spec is structurally valid even with the WARNING.

---

## 6. Other validation rules (delegated to v0.1.0 SPEC §6.5 + `lib/parser.sh`)

The 7 validation rules + 9 enum values are NOT re-enumerated in this skill body or this reference doc. Single source of truth:

- **v0.1.0 SPEC §6.5** (`docs/SPEC-scaffold-onboard.md`) — the rule list with rationale.
- **`lib/parser.sh`** — the executable definitions (`sf_spec_validate` + `SF_PROJECT_CLASS_ENUM`).

Cases 1–5 above cover the most common surfacing patterns. Other rule failures (missing top-level heading, missing `## Executive Summary`, missing `**Project class:**` field entirely, broken YAML frontmatter, etc.) all flow through the same three-element report shape — name the offending structure, cite the line number (via `grep -n` on a relevant pattern), include a concrete remediation hint quoting exact syntax. The wrapper's surfacing logic doesn't branch per-rule; only the line-lookup pattern changes.

If you (Claude reading this doc) need to know which rules exist or which enums are valid, read v0.1.0 SPEC §6.5 + `lib/parser.sh` directly. Re-enumerating them here would create drift risk (per §11 anti-patterns).

---

## What these edge cases protect

- **Enum violation reports** surface the bad input, the full valid set, the line number, and a safety-net suggestion (`Other`). Eval S2 contracts this surfacing shape.
- **Duplicate marker reports** cite both line numbers. The user needs to know which one to delete.
- **Missing vs. empty distinction** routes the user to the right remediation (`/onboard` vs. `/onboard --resume` vs. "did I `touch` by accident").
- **WARNING-passthrough** keeps the success line verbatim while surfacing informational findings as follow-up.
- **Delegation to v0.1.0 SPEC §6.5 + `lib/parser.sh`** keeps the skill body and reference docs from drifting against the parser. The wrapper's job is *surfacing*, not rule enforcement.
