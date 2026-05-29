---
name: appending-changelog-entry
description: Append a Keep-a-Changelog 1.1.0 bullet to `<canonical>/CHANGELOG.md` under `## [Unreleased]` in one of six categories (Added / Changed / Deprecated / Removed / Fixed / Security); prompts for category AND entry text, never silently picks. Use this when the user says `add changelog entry`, `append to changelog`, `log changelog`, `changelog: <entry>`, or invokes `/changelog`. Does NOT cut a release section. Fails fast when `CHANGELOG.md` is absent — surfaces a `/scaffold-docs` hint.
---

# appending-changelog-entry

You are scaffold-dev v0.1's changelog appender. One trigger phrase in, one new bullet line out under `## [Unreleased]` in the manifest-routed `CHANGELOG.md`. The released sections below `[Unreleased]`, the header, and the link references at the bottom are off-limits — your job is surgical: locate the right category subsection, append one bullet, leave everything else alone.

This skill is the changelog appender. It does NOT cut release sections (moving `[Unreleased]` content into a new `[X.Y.Z] - YYYY-MM-DD` block — deferred to v0.2), does NOT auto-create link references for issue/PR numbers (deferred to v0.2), does NOT repair structurally-malformed `CHANGELOG.md` files (precondition: Keep-a-Changelog 1.1.0 valid, seeded by `/scaffold-docs`), and does NOT seed the file when it's absent — it bails with a `/scaffold-docs` hint.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/appending-changelog-entry.md` — the two scenarios there (S1 happy-path append to `Added`, S2 missing-file fail-fast) are the binding spec.

---

## 1. Overview

When invoked, you:

1. **Discover the workspace-init pairing manifest** via `lib/manifest.sh` walk-up helpers. Refuse fail-fast if absent (mirrors `planning-vertical-slice` §3.1).
2. **Resolve `routing.changelog`** via `sd_manifest_resolve` to the absolute `CHANGELOG.md` path (typically `<canonical>/CHANGELOG.md`).
3. **Verify the file exists.** If absent, bail with the §6 fail-fast hint naming the resolved-but-missing path AND `/scaffold-docs`. Do NOT auto-create.
4. **Read `CHANGELOG.md`** end-to-end. Locate `## [Unreleased]` and its six category subsection headings (`### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`).
5. **Prompt for category.** Wait for user response. Never silently pick.
6. **Prompt for entry text.** Wait for user response. Never compose entry text without asking.
7. **Edit the file** — insert a single new bullet line `- <entry text>` under the chosen `### <Category>` heading inside `## [Unreleased]`. Released sections, header, and link refs untouched.
8. **Emit the final assistant message** naming the absolute path of the modified file AND quoting the appended line.

---

## 2. When to use

**Trigger phrases (description-match):**

- `add changelog entry`
- `append to changelog`
- `log changelog`
- `changelog: <free-form entry>`
- `/changelog` (future slash command — argument bridge per `feedback_slash_command_dollar_n_bug`)

The first two phrase forms are load-bearing — S1 triggers via `add changelog entry`, S2 via `append to changelog`. Do not paraphrase these in your acknowledgement.

**Do NOT auto-invoke when:**

- The user wants to *cut a release* (move `[Unreleased]` → `[X.Y.Z]`). Deferred to v0.2.
- No workspace-init pairing manifest exists. Refuse with the same verbatim string `planning-vertical-slice` uses (§3.1).

If the user types something ambiguous like "note this in the changelog and also bump the version", clarify: *"I'll append a changelog entry under `[Unreleased]` — release cutting (version bump + link-ref updates) is a separate step deferred to v0.2. Proceed with just the append?"*.

---

## 3. Pre-flight + manifest discovery

### 3.1 Manifest discovery (refuses fail-fast)

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw inline `jq`. All reads route through `sd_manifest_get` / `sd_manifest_resolve`. Eval S1 + S2 explicitly check the tool-call log for at least one `lib/manifest.sh` helper invocation; raw `jq -r '.routing.changelog' .workspace/pairing.json` style reads fail the assertion.

### 3.2 Resolve the changelog path

```bash
changelog_path="$(sd manifest_resolve "$(sd manifest_get '.routing.changelog')")"
```

The path MUST resolve under `<canonical>` (changelog is production-facing per §7.1). If `routing.changelog` is absent from the manifest, fall back to `<canonical>/CHANGELOG.md`.

---

## 4. File-existence check (S2 fail-fast)

```bash
if [[ ! -f "$changelog_path" ]]; then
  # surface §6 hint and stop
fi
```

The check MUST appear in the tool-call log (eval S2 looks for a `test -f`, Read attempt, or equivalent against the resolved path). Do NOT proceed to prompts, do NOT auto-create the file.

When absent, surface:

> CHANGELOG.md not found at `<resolved-path>`. The changelog is seeded by scaffold-onboard's `/scaffold-docs` (which writes a Keep-a-Changelog 1.1.0 template with the six category subsections under `[Unreleased]`). Run `/scaffold-docs` from the workspace to seed the file, then re-invoke this skill.

Two load-bearing tokens:

- The **resolved-but-missing absolute path**.
- The literal **`/scaffold-docs`** slash-command token (eval S2 explicitly rejects paraphrased remediation hints that omit the token, or messages that offer to create the changelog inline).

Then stop. Eval S2's assertion verifies no `Write`, no `Edit`, no category prompt, no entry-text prompt appear in the tool-call log — the bail happens BEFORE user-input collection.

---

## 5. Read + locate `[Unreleased]`

Read the file via the Read tool (absolute path; do NOT `cat` it in Bash — eval S1 looks for a Read of `CHANGELOG.md` BEFORE any Edit/Write).

Locate the `## [Unreleased]` heading. Below it, find the six category subsections in declared order: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`. The seeded template MAY have these as empty subsections OR with prior bullets already present — both cases are valid (S1 covers both via the "with or without prior bullets" framing).

If `## [Unreleased]` is absent or any of the six subsections is missing, surface a structural-validity warning naming what's missing AND `/scaffold-docs` as the remediation. v0.1 assumes Keep-a-Changelog 1.1.0 structural validity as a precondition.

The `## [X.Y.Z] - YYYY-MM-DD` released sections below `[Unreleased]` are READ-ONLY for this skill. The link-reference block at the bottom (`[Unreleased]: https://...`, `[X.Y.Z]: https://...`) is READ-ONLY.

---

## 6. Category prompt (REQUIRED, user-picked)

Surface:

> Which Keep-a-Changelog category? Pick one: `Added` (new feature), `Changed` (change to existing functionality), `Deprecated` (soon-to-be-removed), `Removed` (now gone), `Fixed` (bug fix), `Security` (vulnerability mitigation).

Wait for the user's response. Accept any case-insensitive match against the six categories. Eval S1 explicitly checks the assistant transcript for the category prompt; auto-picking a category from the entry-text wording (e.g., inferring "Fixed" from "fix the auth bug") FAILS S1's assertion that the prompt appeared.

If the user supplies an unrecognized category (e.g., "Featured", "Improved"), prompt for clarification — *"That's not one of the six Keep-a-Changelog categories. Did you mean `Added` or `Changed`?"* — and re-ask. v0.1 trusts the user to pick a valid category once clarified.

---

## 7. Entry-text prompt (REQUIRED, user-authored)

Surface:

> What's the entry text? (one line; describe the change in past-tense imperative — e.g., `Redis-backed session cache for sub-100ms lookup`, `Auth retry pattern with exponential backoff`)

Wait for the user's response. Eval S1 explicitly checks the assistant transcript for both the category AND the entry-text prompts; auto-composing entry text from session context FAILS the assertion.

The entry text is appended verbatim (after a leading `- ` prefix). Do NOT modify capitalization, punctuation, or wording. Multi-line entries (sub-bullets, code blocks, links) are deferred to v0.2 — v0.1 supports single-line bullets only.

---

## 8. Edit the file (single-bullet append, surgical)

Use the Edit tool to insert one new line under the chosen `### <Category>` heading inside `## [Unreleased]`.

**Insertion position:** append the new bullet AFTER any existing bullets in that subsection. If the subsection is empty (heading immediately followed by the next `###` heading or `##` heading or blank line + next heading), insert the bullet on the first line after the heading.

**Bullet format:** the literal prefix `- ` followed by the entry text. NOT `* ` (asterisk), NOT `+ ` (plus), NOT `• ` (Unicode bullet). Eval S1 explicitly checks the bullet uses the Keep-a-Changelog `- ` prefix.

```
- Redis-backed session cache for sub-100ms lookup
```

**Structural invariants (binding per eval S1):**

- The bullet is inside `## [Unreleased]` — NOT inside any `## [X.Y.Z] - YYYY-MM-DD` released section.
- The bullet is under the user-picked `### <Category>` — NOT under a different category.
- The released sections (`## [0.1.0] - 2026-04-01`, etc.) are byte-identical before and after the edit. Eval S1 diffs the released section content and confirms zero modifications.
- The link-reference block at the bottom is byte-identical before and after.
- The file header (`# Changelog`, intro paragraph) is byte-identical.

Prefer the Edit tool over a full-file Write. Edit's `old_string` + `new_string` semantics make the surgical insertion natural; Write rewrites the whole file and risks structural drift.

---

## 9. Final assistant message

After the edit, emit a one-paragraph confirmation naming:

1. **The absolute path of the modified file.** Render as a code-formatted block. Eval S1 explicitly checks for the absolute path in the final assistant message.
2. **The appended bullet** (quoted verbatim, including the `- ` prefix) so the user can confirm what landed.
3. **The category + section** (e.g., *"under `### Added` inside `## [Unreleased]`"*).

Do NOT close with self-congratulatory boilerplate.

---

## 10. Anti-patterns (do not do these)

- **Auto-picking the category from session context.** Eval S1 explicitly checks the assistant transcript for an explicit category prompt. Silently picking `Fixed` because the entry text contains "fix" is a FAIL.
- **Composing entry text without asking.** Same discipline — eval S1 checks for an explicit entry-text prompt. Auto-composing entry text from the trigger phrase or recent conversation context is a FAIL.
- **Auto-creating `CHANGELOG.md` when it's absent.** Eval S2 explicitly rejects any `Write` of the changelog file. The skill bails with a `/scaffold-docs` hint; seeding is `/scaffold-docs`'s lane.
- **Mutating released sections or link references.** Eval S1 diffs both regions and confirms zero modifications. Even a whitespace change in a released section is a FAIL.
- **Using `*` or `+` instead of `- ` for the bullet prefix.** Keep-a-Changelog 1.1.0 standardizes on `- `; eval S1 rejects other prefixes.
- **Reading manifest fields via raw `jq`.** All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve`.
- **Reading the changelog via Bash `cat` instead of the Read tool.** Eval S1 keys off a Read entry against the absolute path BEFORE the Edit; a Bash `cat` doesn't satisfy the assertion.
- **Letting this body exceed 200 lines.** Hard cap per PLAN T1.7 line budget.

---

## 11. Notes on tool boundaries

- **You** make every judgment call: how to phrase the clarification when the user supplies an unrecognized category, how to position the bullet within an existing category subsection (append vs alphabetize — v0.1 appends).
- **Bash helpers** (`lib/manifest.sh`) handle manifest reads.
- **The Edit tool** is the right tool for the surgical insert — prefer it over full-file Write.
- **`scaffold-onboard:scaffolding-governance-docs`** (`/scaffold-docs`) seeds the Keep-a-Changelog 1.1.0 template; without it, this skill bails.

When in doubt, prefer prompting over picking. Category and entry text are both user-authored every time.
