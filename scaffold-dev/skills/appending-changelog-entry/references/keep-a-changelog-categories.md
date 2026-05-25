# Keep a Changelog 1.1.0 — categories reference

The `appending-changelog-entry` skill uses the [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) specification. This reference distills the spec for skill body authors and users.

## File location

Per project convention: `CHANGELOG.md` at canonical root. The skill body locates it via manifest (`canonical.changelog_path`); if absent in manifest, defaults to `<canonical>/CHANGELOG.md`.

## Versioning structure

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- entry 1
- entry 2

### Changed
- entry 1

## [1.2.0] - 2026-05-15

### Added
- entry 1

### Fixed
- entry 1

## [1.1.0] - 2026-04-30
...
```

## The six standard categories

In order of appearance under each version:

1. **Added** — new features.
2. **Changed** — changes in existing functionality.
3. **Deprecated** — soon-to-be removed features.
4. **Removed** — now-removed features.
5. **Fixed** — bug fixes.
6. **Security** — vulnerabilities addressed.

The skill body uses exactly these six headings. No custom categories (the Keep a Changelog 1.1 spec is strict about this; deviation breaks downstream tooling that assumes the standard set).

## Skill body flow

User invokes:

```
"log changelog: added action-needed card to dashboard"
```

Skill body:

1. **Identify category.** Often inferable from the user's wording:
   - "added X" -> Added
   - "fixed X bug" -> Fixed
   - "changed Y to Z" -> Changed
   - "deprecated A" -> Deprecated
   - "removed B" -> Removed
   - "security fix for C" -> Security

   If ambiguous, surface a prompt:
   ```
   Which category? (Added / Changed / Deprecated / Removed / Fixed / Security)
   ```

2. **Locate CHANGELOG.md** via manifest or default path.

3. **Find `## [Unreleased]` section.** If absent -> skill body creates it at top of file (with the six category headings as empty templates), then proceeds.

4. **Find the named category under `[Unreleased]`.** If absent -> skill body adds the `### <Category>` heading in the correct order (before the next category present, per the canonical order).

5. **Append entry.** As a bullet under the heading:
   ```markdown
   ### Added
   - Action-needed card on dashboard, sourced from action_needed table, with chatbot intent integration (VS-3.2).
   ```

   Entry style guidance:
   - One sentence per entry; past tense.
   - Mention the slice ID in parentheses for traceability (`(VS-3.2)`) when the entry is slice-scoped.
   - Mention an issue/PR number if the project uses one.

6. **Write file.** Commit per `git_policy`.

## Release flow (out of scope for v0.1)

When a release ships, the `[Unreleased]` section gets retitled to `[VERSION] - DATE`, and a new empty `[Unreleased]` section is created. v0.1's appending-changelog-entry skill does NOT handle releases — it only appends to `[Unreleased]`. Release authoring is a separate (potentially future) skill or a manual user step.

## Worked example — multi-entry slice close

At slice close, the user wants to log multiple entries from VS-3.2:

```
log changelog for VS-3.2:
- added: action-needed card on dashboard
- added: chatbot intent for "what's overdue"
- fixed: auth-token expiry now raises 401 (was silently returning None)
- changed: api/insights endpoint requires bearer token
```

Skill body processes each as a separate append. Final state of `## [Unreleased]`:

```markdown
## [Unreleased]

### Added
- Action-needed card on dashboard, sourced from action_needed table (VS-3.2).
- Chatbot intent for "what's overdue" reusing the action-needed query (VS-3.2).

### Changed
- `GET /api/insights/action-needed` requires bearer-token auth (VS-3.2).

### Fixed
- `verify_bearer_token` raises `HTTPException(401)` on expired tokens; previously returned `None` silently, masking auth failures as empty data (VS-3.2 bug-fix detour).
```

Heading order preserved per Keep a Changelog 1.1 (Added before Changed before Fixed).

## Category-disambiguation hints

- **Bug fix that adds behavior** — primarily Fixed, optionally cross-referenced under Added. v0.1 keeps it under Fixed only.
- **Refactor that changes API** — Changed.
- **Refactor with no API change** — usually no changelog entry (internal-only). Skill body should ask: "Is this user-visible? If not, no changelog needed."
- **New mcrule / new memory-bank pattern** — NOT a changelog entry. Process artifacts, not product changes.
- **New ADR** — NOT a changelog entry on its own. The PRODUCT decision the ADR records may warrant a changelog entry; the ADR doesn't.

## Anti-patterns

- **Adding entries to a versioned section.** `## [1.2.0]` is frozen; new entries go to `## [Unreleased]`.
- **Custom category headings.** No "### Internal", "### Performance", "### Docs" — Keep a Changelog 1.1 has six categories; respect the set or downstream tools (changelog parsers, GitHub Releases automation) break.
- **Forgetting the slice ID tag.** Without `(VS-N.M)`, traceability from changelog -> retrospective -> root commit gets weak.
- **Conflating "fixed" and "changed".** A fix restores intended behavior; a change alters intended behavior. The verb tense in the entry should match: "fixed" entries describe the bug that was removed; "changed" entries describe the new behavior.
