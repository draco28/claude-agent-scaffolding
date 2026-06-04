# Edge cases: scaffolding-memory-bank

Non-happy-path scenarios for `/scaffold-project`. Each entry names the trigger, the helper behavior, and what this skill body should surface in conversation. The happy path lives in `example-walkthrough.md`.

---

## 1. Re-derive on an existing repo (live-seed preservation)

**Trigger:** user runs `/scaffold-project` a second time after weeks of work. `.claude/memory-bank/05-active-context.md` and `.claude/memory-bank/06-progress.md` now hold real working notes; the user does NOT want to lose them.

**Helper behavior:** `sf_memory_bank_derive` (no `--force`) re-renders the 8 derived files (overwriting them — idempotent for unchanged spec), preserves `05-active-context.md` and `06-progress.md` byte-for-byte, and skips `WORKFLOW.md` (already present; copy-once).

**Skill body surfacing:** announce the split — "8 derived files re-rendered. 2 live-seed files preserved (`05-active-context.md`, `06-progress.md`). `WORKFLOW.md` untouched (static)." No confirmation prompt needed — the safe path is automatic.

**The opt-in clobber path:** `/scaffold-project --regenerate` passes `--force` to `sf_memory_bank_derive`. Before clobbering live-seed files, ALWAYS list the absolute paths that will be overwritten and require an explicit `yes`:

> `--regenerate` will overwrite these files:
> - `/Users/<you>/work/todo-cli/.claude/memory-bank/05-active-context.md`
> - `/Users/<you>/work/todo-cli/.claude/memory-bank/06-progress.md`
>
> Both hold in-flight work that won't be reconstructable from MASTER-SPEC. Type `yes` to proceed, anything else to cancel.

If the user types anything other than `yes`, drop back to the no-flag path (re-render derived files, preserve live-seed). `--force` does NOT touch `WORKFLOW.md` even with `yes` — it's static and project-agnostic (§11 anti-patterns).

---

## 2. Manifest schema missing a logical name

**Trigger:** A user updated their workspace-init manifest from an older schema that pre-dates the `routing.memory_bank` key. cwd is inside the pair; `.workspace/pairing.json` is present but `routing.memory_bank`, `routing.claude_md`, or `routing.scaffold_project_outputs` is not declared.

**Helper behavior:** `sf_resolve_output_path` walks up, finds the manifest, parses `routing.<missing_name>`, and discovers the key absent. Per SPEC §10.3 + §11 anti-patterns, the helper emits a one-time warning to stderr and falls back to `$(pwd)/<relative_path>`. This is forward-compatible: manifests pre-dating a logical-name addition still work, they just lose the cross-repo routing for that one name.

**Skill body surfacing:** surface the warning verbatim to the user once, then proceed with the fallback path. Example:

> Manifest at `/Users/<you>/work/todo-cli-pair/.workspace/pairing.json` does not declare `routing.memory_bank`. Falling back to cwd routing for memory-bank outputs. Update the manifest to add `"memory_bank": "ai_workspace"` (or `"canonical"`) under `routing` to enable cross-repo routing for this logical name.

Do NOT block derivation. The fallback is the documented v0.1.0-equivalent path; derivation proceeds normally to cwd.

---

## 3. Stale `composition.json` on source-aware sessions

**Trigger:** the user installed ai-mentor v2.0 after the last `/onboard` run. `composition.json` at `${CLAUDE_PLUGIN_DATA}/composition.json` still has `has_ai_mentor=false` from the previous session.

**Helper behavior:** `sf_compose_refresh` re-detects plugins in the marketplace cache directories at derivation start (per §8 step 1). It rewrites `composition.json` atomically with the current detection result. On the next read of `_composition_args`, `has_ai_mentor=true` is folded into the CLAUDE.md template arg list and the `{{#if has_ai_mentor}}` block is emitted in CLAUDE.md.

**Skill body surfacing:** no announcement needed. The refresh is silent. If the user notices a new plugin-awareness block in CLAUDE.md they didn't expect, that's the correct behavior — composition.json refreshes at every derivation start so the rendered CLAUDE.md always reflects the current plugin set. If the user wants ai-mentor / superpowers awareness OMITTED despite their presence, that's not currently supported (per §11 the skill never hand-edits template arg booleans).

**Note on architect-critic:** the filesystem probe `sf_compose_detect_architect_critic` runs separately and never writes to `composition.json` (per ac v0.2 settlement #1). If ac was installed since last run, the probe will pick it up at this run.

---

## 4. Karpathy opt-out (`phase_10.4.include_karpathy != "yes"`)

**Trigger:** at the close of `/onboard`, the user typed `no` to the Karpathy opt-in. State has `phase_10.4.include_karpathy = "no"`.

**Helper behavior:** the skill reads the answer via `sf_state_read_answer phase_10.4.include_karpathy` → `"no"`. Per §6, any value other than the literal string `yes` (including `null`, `no`, or a missing state file per §3 fallback) is treated as opt-out. `include_karpathy=false` is folded into the template arg list. The CLAUDE.md template's `{{#if include_karpathy}}` block does not render.

**What this means for the emitted CLAUDE.md:** the file is written normally — Tier-0 router preamble, plugin-awareness blocks, project-specific guidance — but with NO `## Behavioral Discipline (Karpathy-inspired)` section. The attribution string `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)` is absent.

**Skill body surfacing:** no announcement needed. Karpathy opt-out is explicit; the user knows they answered `no`. If they later want the section, they can re-run `/onboard --resume` to flip the answer (or manually edit the state file), then re-run `/scaffold-project`.

**Critical:** never default-include Karpathy on a missing state file or on `null`. Silently pushing opinionated cognitive guidance into projects that opted out (or never opted in) is the failure mode §11 calls out explicitly. Treat ambiguity as opt-out.

---

## 5. User-edited `03-code-patterns.md` mcrule blocks preserved on re-derive

**Trigger:** after first `/scaffold-project`, the user invoked `Skill(scaffold-onboard:authoring-machine-checkable-rules)` and added 3 mcrule blocks inside the `## Machine-checkable rules` preserve zone, before `<!-- mcrules:preserve:end -->`. Their `03-code-patterns.md` now contains:

```markdown
<!-- mcrules:preserve:start -->
## Machine-checkable rules
<!-- TODO: add machine-checkable rules. ... -->

<!-- mcrule:start type=naming -->
<!-- mcrule:scope src/**/*.rs -->
<!-- mcrule:rule No public functions named `do_*`; prefer verb phrases. -->
<!-- mcrule:end -->

<!-- mcrule:start type=structure -->
<!-- mcrule:scope src/db/**/*.rs -->
<!-- mcrule:rule Repository methods MUST return `Result<T, DbError>`. -->
<!-- mcrule:end -->

<!-- mcrule:start type=test -->
<!-- mcrule:scope tests/**/*.rs -->
<!-- mcrule:rule Every public CLI command MUST have at least one integration test. -->
<!-- mcrule:end -->
<!-- mcrules:preserve:end -->
```

Now the user runs `/scaffold-project` again (no `--regenerate`) — maybe MASTER-SPEC was edited to clarify Phase 3 entities.

**What MUST happen:** the 8-derived bucket includes `03-code-patterns.md`, which means the file IS re-rendered from the template. **However, the template-rendered file ONLY seeds the `## Machine-checkable rules` heading + invitation comment** — it has zero rule blocks. If the helper naively overwrites the existing file, the user's 3 hand-authored mcrule blocks are LOST.

**Helper behavior (v0.2 contract):** `sf_memory_bank_derive` performs a **zone-preserving merge** for `03-code-patterns.md`: it captures the full `<!-- mcrules:preserve:start -->` ... `<!-- mcrules:preserve:end -->` zone before re-render, then re-injects it into the freshly rendered file. Legacy files that only have the `## Machine-checkable rules` heading are wrapped in the new sentinels on first upgrade so existing `<!-- mcrule:start ... --> ... <!-- mcrule:end -->` blocks survive.

**Skill body discipline:** this skill **seeds the SECTION** — it does not own the SECTION's content. mcrule blocks are owned by `authoring-machine-checkable-rules` (SPEC §5.5); the seeding skill must preserve them on re-derive. Document this clearly in any user-facing surfacing on re-derive:

> Re-derived `03-code-patterns.md`. 3 existing machine-checkable rules preserved in the `## Machine-checkable rules` section (your edits are intact).

If the user explicitly wants to discard hand-authored rules and re-seed the section as empty, that's `/scaffold-project --regenerate` (which clobbers the live-seed files AND re-seeds `## Machine-checkable rules` as heading-plus-invitation only). As with the live-seed case, ALWAYS list the absolute paths and rule block counts that will be lost, and require explicit `yes` confirmation.

---

## 6. MASTER-SPEC absent or invalid

**Trigger:** user runs `/scaffold-project` from a directory with no `MASTER-SPEC.md`, or with a `MASTER-SPEC.md` that fails `sf_spec_validate` (broken YAML frontmatter, missing phase marker, unknown `project_class` enum, etc.).

**Helper behavior:** `sf_resolve_output_path master_spec MASTER-SPEC.md` returns a path; the skill checks `[ -f "$path" ]`. If missing → surface routing message and stop (§3 step 1). If present, `sf_spec_validate "$path"` returns non-zero with stderr containing the validation error. Surface the stderr verbatim and stop (§3 step 2 + §11 anti-pattern).

**Skill body surfacing (missing):**

> `MASTER-SPEC.md` hasn't been authored yet. Do you want to start onboarding first (`/onboard`), or are you regenerating from an existing MASTER-SPEC at a non-default location?

**Skill body surfacing (invalid):** dump the validator's stderr verbatim, then stop. Do NOT attempt to derive from a broken spec — the templates will silently emit `{{placeholder}}` artifacts that look complete but aren't. Route the user to `validating-master-spec` (SPEC §5.7) if they want a richer error-with-remediation surfacing.

---

## What these edge cases protect

- **Live-seed preservation** prevents data loss from accidental re-runs. `05-active-context.md` is the daily working scratchpad; silently overwriting it is a project-killing bug.
- **Manifest fallback warnings** keep cross-repo routing forward-compatible without blocking single-repo or legacy-manifest users.
- **Composition refresh on every run** keeps CLAUDE.md plugin-awareness blocks in sync with the user's current plugin set without requiring re-onboarding.
- **Karpathy strict opt-in** prevents silent imposition of opinionated cognitive guidance on projects that didn't ask for it.
- **mcrule block preservation** keeps the lane boundary clean: this skill owns the SECTION (seeding); `authoring-machine-checkable-rules` owns the CONTENT (rule blocks). Re-derive must respect that split.
- **Refuse-on-invalid-spec** prevents the `{{placeholder}}` failure mode where derived files look complete but are silently broken.
