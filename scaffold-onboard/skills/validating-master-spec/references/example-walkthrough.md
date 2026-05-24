# Example walkthrough: validating MASTER-SPEC.md

Two concrete traces of the validating-master-spec skill: one valid spec (happy path, verbatim success line), one invalid spec (missing Phase 5 marker — error with line number + remediation hint). The 7 validation rules + 9 enum values are delegated to v0.1.0 SPEC §6.5 + `lib/parser.sh` — see §5 of the skill body. This walkthrough demonstrates the *surfacing* behavior on top of `sf_spec_validate`.

---

## Example 1 — Valid spec (success path)

**Setup:**

```
$ cd ~/work/todo-cli
$ ls
MASTER-SPEC.md  EXECUTIVE-SUMMARY.md  CLAUDE.md  .claude/
```

`MASTER-SPEC.md` is the closed spec from the `/onboard` walkthrough — passed the close-depth architect-critic, all 10 phase markers present, `**Project class:** CLI tool` (a valid enum), `**Spec version:** 1.0`.

**Trigger:** user types `validate MASTER-SPEC`.

Description-match resolves to `scaffold-onboard:validating-master-spec` (per §2 triggers list).

**Step 1 — Locate.** Skill calls:

```bash
spec_path="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
# → /Users/<you>/work/todo-cli/MASTER-SPEC.md
[ -f "$spec_path" ] && echo "present"
# → present
```

Single-repo fallback (no `.workspace/pairing.json` up the tree); resolved path is `$(pwd)/MASTER-SPEC.md`. File exists.

**Step 2 — Validate.** Skill sources the helper and runs:

```bash
source "$PLUGIN_DIR/lib/parser.sh"
err="$(sf_spec_validate "$spec_path" 2>&1 1>/dev/null)"
rc=$?
# rc=0; err=""
```

All 7 validation rules pass:

1. Top-level heading `# todo-cli — Master Specification` present.
2. `## Executive Summary` section present.
3. All 10 phase markers `<!-- master-spec:phase id=1 name=Foundation -->` through `id=10 name=Operations` present.
4. `**Project class:** CLI tool` matches `SF_PROJECT_CLASS_ENUM[0]`.
5. `**Spec version:** 1.0` matches the recognized version.
6. Required per-phase fields populated per `phases.yaml`.
7. No malformed YAML / broken markdown structures.

**Step 4 — Emit success.** Skill emits the verbatim line (per §7 of the skill body — SPEC §5.7 + eval S1 lock this string):

> MASTER-SPEC valid. Ready for `/scaffold-project` and `/scaffold-docs`.

**Verbatim discipline:** the backticks around `/scaffold-project` and `/scaffold-docs` are part of the string. Do NOT paraphrase ("Spec validates successfully", "MASTER-SPEC.md is OK", "Ready for derivation"), do NOT add follow-up sentences ("You can now proceed to..."), do NOT prepend status emoji. Eval S1 fails any synonym or rewording.

**No filesystem mutations.** Validation is read-only — no Write / Edit tool calls, no shell redirects into the repo. The transcript shows only Bash reads (`sf_resolve_output_path`, `sf_spec_validate`, optional `grep -n` if a follow-up error path were triggered).

---

## Example 2 — Invalid spec (missing Phase 5 marker)

**Setup:**

```
$ cd ~/work/halftime-onboard
$ ls
MASTER-SPEC.md  ...
```

`MASTER-SPEC.md` is a partially-authored spec — the user ran `/onboard` but interrupted before Phase 5 closed cleanly. The Phase 5 heading section starts around line 62, but the marker comment `<!-- master-spec:phase id=5 name=Architecture -->` is absent — only the prose body of Phase 5 is on disk.

**Trigger:** user types `is my master spec ready for derivation?`.

Description-match resolves to `scaffold-onboard:validating-master-spec` (per §2 triggers list).

**Step 1 — Locate.**

```bash
spec_path="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
# → /Users/<you>/work/halftime-onboard/MASTER-SPEC.md
```

File exists.

**Step 2 — Validate.**

```bash
source "$PLUGIN_DIR/lib/parser.sh"
err="$(sf_spec_validate "$spec_path" 2>&1 1>/dev/null)"
rc=$?
# rc=1
# err="Missing phase markers: id=5. Phases must be authored via /onboard."
```

`sf_spec_validate` short-circuits on the first ERROR (per `lib/parser.sh` line 88-89 comment). The validator detected that no `<!-- master-spec:phase id=5 ... -->` comment exists in the file, even though the body content for Phase 5 is present.

**Step 3 — Format error with remediation.** Skill locates the expected line via `grep -n`:

```bash
grep -nE "^## Phase 5\b|<!-- master-spec:phase id=" "$spec_path"
# → 14:<!-- master-spec:phase id=1 name=Foundation -->
# → 24:<!-- master-spec:phase id=2 name=Strategy -->
# → 34:<!-- master-spec:phase id=3 name=Domain & Data Model -->
# → 44:<!-- master-spec:phase id=4 name=Security & Compliance -->
# → 62:## Phase 5 — Architecture
# → 72:<!-- master-spec:phase id=6 name=UX / Surfaces -->
# ...
```

The Phase 5 prose heading is at line 62; the missing marker should precede it. Skill cites line 62.

**Step 4 — Emit error.** Skill emits the three-element report (per §5 + §6 of the skill body):

> Validation failed: **Phase 5 marker missing** from `MASTER-SPEC.md`.
>
> The marker comment was expected around **line 62**, where the Phase 5 content begins. Each phase section must be preceded by an HTML comment of the form:
>
> ```
> <!-- master-spec:phase id=5 name=Architecture -->
> ```
>
> **Remediation:** insert `<!-- master-spec:phase id=5 name=Architecture -->` immediately before the Phase 5 heading at line 62. The canonical phase-5 name (`Architecture`) is defined in v0.1.0 `phases.yaml` — re-running `/onboard --resume` for Phase 5 will re-author the marker correctly, or you can hand-insert and re-run validation.

**Three required elements verified:**

1. **Error class identification** — "Phase 5 marker missing" names the offending structure (not "a phase is missing" generically; not "Phase 1" or some other id).
2. **Line number citation** — "around line 62" cites the expected-position line; the judge confirms this matches the fixture's Phase 5 content start within ±2 lines.
3. **Concrete remediation hint** — the exact comment syntax `<!-- master-spec:phase id=5 name=Architecture -->` is quoted; the user can copy-paste it. Pointing at `/onboard --resume` is the alternative remediation for users who'd rather re-author the phase interactively.

**Discipline:**

- The skill does NOT auto-fix `MASTER-SPEC.md`. No Write or Edit tool calls. Surface; the user fixes.
- The skill does NOT emit the SPEC §5.7 success string. A false-positive success on a broken spec would be a stealth bug (downstream `/scaffold-project` would silently emit `{{placeholder}}` artifacts).
- The skill does NOT invent a phase name when the canonical `phases.yaml` name applies — `Architecture` is the canonical Phase 5 name; the skill quotes it directly rather than using a placeholder like `<name>`.

---

## What these two examples demonstrate

- **Happy path is a one-line verbatim success message.** No embellishment, no follow-up sentence, no status emoji. The string is locked by SPEC §5.7 + eval S1.
- **Error path is a three-element report:** error class identification + line number citation + concrete remediation hint. Raw stderr dumps without line citation fail eval S3's surfacing contract.
- **`grep -n` is the line-number lookup tool.** For project-class errors: `grep -nE "^\*\*Project class:\*\*"`. For missing-phase-marker errors: `grep -nE "^## Phase $N\b|<!-- master-spec:phase id="`. macOS-portable patterns only (BSD grep, bash 3.2).
- **Validation is read-only.** No Write / Edit / mv. No shell redirects into the repo. The skill surfaces; the user (or `/onboard --resume`) fixes.
- **Other error cases** (invalid project_class enum, duplicate phase marker, file absent, file empty) follow the same three-element report shape — see `references/edge-cases.md`.
