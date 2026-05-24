# Rule types reference — v0.2 R2 mcrule DSL

> Companion reference to `SKILL.md` for the `authoring-machine-checkable-rules` skill. Per SPEC §8.3, v0.2 ships exactly four rule types. This doc walks each type end-to-end: when to reach for it, what fields it takes, fully-worked HTML-sentinel examples covering simple-through-narrowed forms, and the edge cases / gotchas the skill body should surface in conversation when relevant.

All examples use the **HTML-sentinel grammar** (`<!-- mcrule:start type=<T> -->` … `<!-- mcrule:end -->`) per SPEC §8.2. Fenced ` ```mcrule ` blocks are not a supported alternative — they were drafted and rejected during the v0.2 architect-critic pass because fence boundaries are invisible to Claude in rendered markdown. Examples below are shown as plain markdown so the sentinels render visibly here; in `03-code-patterns.md` they sit inline with surrounding prose exactly as shown.

---

## `banned_imports`

### Use case

Use `banned_imports` when you want to forbid one or more import names from being introduced anywhere (or under a glob, optionally inside a `where:`-scoped function context). The canonical motivating example is forbidding synchronous HTTP libraries inside async code paths: `requests`, `urllib3`, and `httpx.Client` block the event loop when awaited, so the rule catches them at diff time before they reach review.

Other common framings: forbidding a deprecated library across the codebase (`from old_legacy import *`), banning a heavyweight dependency from a tight inner module, or enforcing that test-only fixtures don't leak into production paths. Reach for `banned_imports` when the invariant is "this name must not appear as an import in this scope" — if you're matching arbitrary code text rather than imports, `style_invariants` is the right tool.

### Fields

| Field | Required? | Form | Notes |
|---|---|---|---|
| `forbid` | required | `[name1, name2, ...]` bracketed list | Comma-separated; import names as they appear in source (e.g., `requests`, not `python-requests`). Submodule paths like `httpx.Client` are supported. |
| `in` | optional | glob pattern | Scopes the check to matching files (e.g., `src/**/*.py`). Default is "all files in the diff". |
| `where` | optional | semantic predicate | One of `any_function_marked_async`, `function_def`, `class_def`, `module_top_level` per §8.3. Unknown values warn-and-skip at parse time. |

### Examples

**Simple — forbid one library project-wide:**

```markdown
We have standardized on httpx for HTTP calls; requests is forbidden everywhere.

<!-- mcrule:start type=banned_imports -->
forbid: [requests]
<!-- mcrule:end -->
```

**With `in:` glob narrowing — only inside the API package:**

```markdown
The API package must not pull in the legacy auth shim — it routes through the new identity service instead.

<!-- mcrule:start type=banned_imports -->
in: src/api/**/*.py
forbid: [legacy_auth, legacy_auth.session]
<!-- mcrule:end -->
```

**With `where:` predicate — async paths only:**

```markdown
Synchronous HTTP libraries block the event loop when called from an async function. Forbid them in async code paths.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3, httpx.Client]
<!-- mcrule:end -->
```

(Note: `httpx.Client` is the synchronous client. `httpx.AsyncClient` is fine inside async — the rule lists the synchronous symbol specifically.)

**Multi-library, no scoping — broad deprecation sweep:**

```markdown
The deprecated `legacy_serializer` module is forbidden across the codebase; use `domain.serialization` instead.

<!-- mcrule:start type=banned_imports -->
forbid: [legacy_serializer, legacy_serializer.v1, legacy_serializer.compat]
<!-- mcrule:end -->
```

**With `in:` + `where:` — module-top-level only:**

```markdown
Heavy ML libraries cause cold-start latency when imported at module load — they should be lazy-imported inside the function that uses them, not at the top of the module.

<!-- mcrule:start type=banned_imports -->
in: src/handlers/**/*.py
where: module_top_level
forbid: [torch, tensorflow, transformers]
<!-- mcrule:end -->
```

### Edge cases & gotchas

- **Vendored copies are not blocked.** `banned_imports` matches import statements by name — a vendored copy under `src/_vendor/requests/` will be imported as `_vendor.requests` and won't trip a rule listing `requests`. If you have a vendoring policy, write a complementary `style_invariants` rule on the vendored path or layer in a `required_pattern` check on the wrapper module.
- **Aliased imports.** `import requests as r` still tripwires on `requests` — the matcher reads the source name before `as`, not the local alias. `from requests import get` likewise trips on `requests`.
- **Submodule paths are exact.** `forbid: [httpx.Client]` does NOT block `from httpx import Client` if the diff text reads `import httpx` and uses `httpx.Client(...)` inline — only the top-level `import httpx` line matches the rule against `httpx`. To block the synchronous client specifically, list `httpx.Client` AND consider whether `from httpx import Client` (which would also need to be banned) is plausible in your codebase. When in doubt, list both.
- **`where:` predicates apply to the import site's enclosing context, not the import target.** `where: any_function_marked_async` means "this import statement appears inside an `async def`" — which is unusual (most imports are top-of-module). If you want to catch *calls* to `requests.get` from inside an async function, that's a `style_invariants` rule on `\brequests\.\w+\(`, not `banned_imports`.
- **List form is required for `forbid`.** A bare scalar (`forbid: requests`) is a validation error — wrap single-item bans in brackets: `forbid: [requests]`.

---

## `coverage_floor`

### Use case

Use `coverage_floor` when you want to assert that named paths maintain at least a numeric test-coverage threshold. The canonical motivating example is API surface area: handlers, routers, middleware — the cross-cutting paths whose coverage failures cascade into many downstream defects. Setting `threshold: 80` on `src/api/` means scaffold-dev's `implementation-checking` skill flags any PR whose coverage report drops these paths below the floor.

This is the only one of the four v0.2 types that consults a non-diff artifact (the coverage report) rather than matching diff content directly. It's also the simplest — no globs, no predicates, no regex. Two required fields and you're done.

### Fields

| Field | Required? | Form | Notes |
|---|---|---|---|
| `paths` | required | `[path1, path2, ...]` bracketed list | Directory paths (or specific files) the threshold applies to. |
| `threshold` | required | integer (no `%` suffix) | Percentage as plain integer: `80`, not `80%`. Per §8.3 semantics. |

`coverage_floor` has **no optional fields** — no `in:`, no `where:`, no `exclude:`. The `paths` field IS the scoping mechanism.

### Examples

**Simple — single path, common threshold:**

```markdown
API layer must maintain 80%+ test coverage.

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->
```

**Multiple paths under one threshold:**

```markdown
Core domain logic and the public API surface both require high coverage — they're the load-bearing parts of the codebase.

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/, src/domain/, src/services/]
threshold: 85
<!-- mcrule:end -->
```

**Stricter threshold on a critical subpath:**

```markdown
Authentication paths require very high coverage — auth bugs are security bugs.

<!-- mcrule:start type=coverage_floor -->
paths: [src/auth/]
threshold: 95
<!-- mcrule:end -->
```

**Mixed file + directory paths:**

```markdown
The settings loader is a small file with outsized blast radius. Hold it to a high floor independently of the surrounding directory.

<!-- mcrule:start type=coverage_floor -->
paths: [src/config/settings.py, src/config/loaders/]
threshold: 90
<!-- mcrule:end -->
```

### Edge cases & gotchas

- **Threshold is a plain integer, not a percentage string.** `threshold: 80` is correct; `threshold: 80%` is a validation error per §8.3 ("never `80%` with a percent sign"). Decimals are not supported — round to the nearest integer.
- **Line vs branch coverage is determined downstream, not in the rule.** The v0.2 mcrule DSL only specifies the threshold; the coverage report's metric (line coverage from `coverage.py`, branch coverage from `coverage.py --branch`, statement coverage from another tool) is determined by the project's coverage tooling — scaffold-dev's `implementation-checking` consumer reads whatever metric the report provides for the listed paths. If your project measures branch coverage, the threshold is interpreted as a branch-coverage floor; if line coverage, line-coverage floor. Be explicit about which metric the project uses in surrounding prose so the human reader has context.
- **Per-file thresholds.** `paths: [foo.py]` enforces the threshold against the single file — if `foo.py` has 100 lines and 75 covered, that's 75% and fails an `80` threshold. The check is per-path, not pooled across the list.
- **Empty paths means no enforcement.** `paths: []` validates as a list-of-strings but is operationally a no-op — every listed path passes vacuously. The skill should ask "which paths?" rather than write an empty list.
- **Coverage that doesn't exist yet.** If the project has no coverage tooling configured at all, scaffold-dev's consumer cannot evaluate `coverage_floor` rules — it surfaces "no coverage data available for paths [src/api/]" and the rule degrades to warn-and-skip (per scaffold-dev's verification semantics). The rule still lives in `03-code-patterns.md` as a forward-looking commitment; it just doesn't enforce until coverage tooling is in place.
- **Paths are relative to the repo root, not to the memory bank.** `paths: [src/api/]` always means `<repo-root>/src/api/`, regardless of where `03-code-patterns.md` lives (canonical repo in single-repo mode, AI workspace in dual-repo mode). The path convention is workspace-agnostic.

---

## `style_invariants`

### Use case

Use `style_invariants` when you want to forbid a regex pattern from matching introduced diff lines under an optional file glob. The canonical motivating example is the "no `print()` calls outside tests" rule — bare prints leak into production paths during debugging and never get cleaned up. The pattern is forbid-shaped (must-not-match), distinguishing it from `required_pattern` (must-match).

Reach for `style_invariants` when the invariant is "no diff line in scope should match this regex": forbidden TODO markers, forbidden trailing whitespace patterns, forbidden inline dynamic-code-execution calls, forbidden hardcoded secrets matching a shape. If your invariant is "every file/function must contain this pattern," that's `required_pattern` instead.

### Fields

| Field | Required? | Form | Notes |
|---|---|---|---|
| `forbid_pattern` | required | regex (single-quoted) | Pattern that must not match. Single-quote the value to protect backslashes and metacharacters from YAML interpretation. |
| `in` | optional | glob pattern | Scope to matching files. |
| `exclude` | optional | glob pattern | Exclude matching files from the scope (e.g., tests). |
| `where` | optional | semantic predicate | Per §8.3 — scopes to function/class/module-top-level/async-marked contexts. |

### Examples

**Simple — forbid bare `print()` calls project-wide:**

```markdown
Use the project logger; bare prints are forbidden.

<!-- mcrule:start type=style_invariants -->
forbid_pattern: '\bprint\('
<!-- mcrule:end -->
```

**With `in:` + `exclude:` — production code only, not tests:**

```markdown
Never use `print()` outside test files.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
<!-- mcrule:end -->
```

**Hardcoded-secret shape catcher:**

```markdown
Forbid hardcoded AWS-style access keys appearing as string literals.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
forbid_pattern: 'AKIA[0-9A-Z]{16}'
<!-- mcrule:end -->
```

**Forbid TODO markers in production paths:**

```markdown
TODO and FIXME markers in production code go stale — track them in the issue tracker instead.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '#\s*(TODO|FIXME)\b'
<!-- mcrule:end -->
```

**With `where:` predicate — async-context-specific anti-pattern:**

```markdown
`time.sleep()` inside an async function blocks the event loop. Use `asyncio.sleep` instead.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
where: any_function_marked_async
forbid_pattern: '\btime\.sleep\('
<!-- mcrule:end -->
```

### Edge cases & gotchas

- **Regex anchoring matters.** `forbid_pattern: 'print\('` (without `\b`) will match `imprint(` and `sprint(` as false positives. Use `\b` word-boundary anchors when forbidding short common identifiers: `\bprint\(` matches `print(` but not `imprint(`. For multi-character keywords the false-positive risk is lower but `\b` is still good hygiene.
- **Single-quote your regex values.** Per SKILL.md §5: wrap `forbid_pattern` in single quotes to prevent YAML-style backslash interpretation. `forbid_pattern: '\bprint\('` is correct; `forbid_pattern: \bprint\(` (unquoted) may have `\b` interpreted as a YAML escape and silently break the pattern.
- **Anchors and multiline matching.** `^` and `$` anchor to line boundaries (single-line mode is the default). To match start-of-file, you'd need a different rule type — `style_invariants` is line-oriented because it consumes diff content line by line.
- **Greedy quantifiers can over-match.** A pattern like `'foo\(.*\)'` greedily consumes through closing parens on the same line — if the line is `foo(x) + bar(y)`, the `.*` swallows both. Use `[^)]*` for tighter scoping when intent is "single call only."
- **`exclude:` is path-glob, not pattern-exclude.** `exclude: tests/**/*.py` excludes files matching that glob from the rule's scope. There's no "exclude these lines from the pattern" mechanism — if you need conditional skipping inside a file, structure the regex itself (e.g., negative lookbehind) or use a `where:` predicate to scope by code structure.
- **Diff lines vs file content.** The rule checks introduced diff lines, not whole-file content. Pre-existing forbidden patterns in untouched code are not flagged — only newly-added or modified lines that match. This is by design (rules should catch new violations without blocking unrelated PRs on legacy lint debt), but it means rolling out a new `style_invariants` rule doesn't retroactively clean up the codebase.
- **Regex dialect.** The pattern compiles under the host regex engine (Python `re` for the v0.2 parser implementation). PCRE-specific features like atomic groups or possessive quantifiers may not be portable. Stick to POSIX-extended + common backreference / `\b` / `\d` / `\s` shorthand.

---

## `required_pattern`

### Use case

Use `required_pattern` when you want to assert that specified files (under a glob, optionally inside a `where:`-scoped context) **must contain** at least one match for a regex. The canonical motivating example is docstring-style requirements: every handler function in `src/api/handlers/` must contain `Args:` followed by `Returns:` in its docstring.

This is the inverse of `style_invariants`. Reach for it when the invariant is "every file/function in scope must have this pattern present": required docstring shapes, required `__all__` declarations at module top level, required license headers, required type-annotation presence (matched as `def \w+\(.*\) ->`).

### Fields

| Field | Required? | Form | Notes |
|---|---|---|---|
| `require_pattern` | required | regex (single-quoted) | Pattern that must be present at least once per matched scope. |
| `in` | optional | glob pattern | Scope to matching files (typically tighter than `style_invariants` because you're requiring presence). |
| `exclude` | optional | glob pattern | Exclude matching files. |
| `where` | optional | semantic predicate | Per §8.3 — scopes "at least once" to each function/class/module-top-level. |

### Examples

**With `in:` + `where:` — required docstring shape per handler function:**

```markdown
All API handlers must have a docstring with `Args:` and `Returns:` sections.

<!-- mcrule:start type=required_pattern -->
in: src/api/handlers/*.py
require_pattern: 'Args:\s+.*\s+Returns:'
where: function_def
<!-- mcrule:end -->
```

**With `where: module_top_level` — required license header:**

```markdown
Every source file must carry the project license header at the top of the file.

<!-- mcrule:start type=required_pattern -->
in: src/**/*.py
where: module_top_level
require_pattern: 'SPDX-License-Identifier:\s*Apache-2\.0'
<!-- mcrule:end -->
```

**With `where: class_def` — required Base inheritance:**

```markdown
Domain models must inherit from `DomainEntity` for serialization to work.

<!-- mcrule:start type=required_pattern -->
in: src/domain/models/*.py
where: class_def
require_pattern: 'class\s+\w+\(.*DomainEntity.*\)'
<!-- mcrule:end -->
```

**With `in:` + `exclude:` — required `__all__` in public packages:**

```markdown
Public package modules must declare `__all__` to make the public API explicit. Internal modules under `_internal/` are exempt.

<!-- mcrule:start type=required_pattern -->
in: src/**/__init__.py
exclude: src/**/_internal/**/__init__.py
require_pattern: '__all__\s*='
<!-- mcrule:end -->
```

**Required type-annotation presence on function definitions:**

```markdown
Every public function in the service layer must have a return-type annotation.

<!-- mcrule:start type=required_pattern -->
in: src/services/**/*.py
where: function_def
require_pattern: 'def\s+\w+\([^)]*\)\s*->\s*\S+'
<!-- mcrule:end -->
```

### Edge cases & gotchas

- **False-positive risk is high.** `require_pattern: 'Args:\s+.*\s+Returns:'` matches any text in the file containing `Args:` ... `Returns:` — including a comment block, a string literal, a copy-pasted example. Tighten the pattern by anchoring to docstring delimiters (`"""[\s\S]*?Args:[\s\S]*?Returns:[\s\S]*?"""`) when you need stricter semantics. The trade-off: tighter patterns are harder to read and harder to maintain.
- **`where:` scoping is what makes `required_pattern` tractable.** Without `where: function_def`, the rule requires the pattern to appear *once anywhere in the file* — not once per function. For docstring-shape requirements that need per-function enforcement, `where: function_def` is essentially mandatory.
- **Multiline patterns.** `\s+.*\s+` may not span newlines depending on the regex dialect's default `.` semantics. For multiline-spanning requirements, use `[\s\S]*?` (matches any character including newlines, non-greedy) instead of `.*`.
- **Newly-added files vs existing files.** Like `style_invariants`, `required_pattern` operates on the diff at PR-verification time — but the semantics differ: a `required_pattern` rule checks that *files touched by the diff* (or matched by `in:` and newly created) contain the pattern. Existing files with the pattern missing aren't retroactively flagged unless they're modified. Roll-out strategy: introduce the rule, then sweep existing files in a separate cleanup PR.
- **Negative requirements don't belong here.** "Must NOT contain X" is `style_invariants` with `forbid_pattern`, not `required_pattern` with a negative-lookahead `require_pattern`. The grammar is clearer when each type matches its semantic intent — don't smuggle forbid-shape patterns into required-pattern fields.
- **`exclude:` combined with `where:`.** When both are present, `exclude:` filters files first (path-level), then `where:` filters contexts within remaining files (structure-level). Order matters in your mental model: a file excluded by `exclude:` is never reached by the `where:` scoping.
- **Single-quote your regex.** Same rule as `style_invariants`: wrap `require_pattern` values in single quotes to protect backslashes and metacharacters from YAML-style interpretation.

---

## Cross-type guidance

- **Choosing between `style_invariants` and `required_pattern`:** the question is forbid vs require. "No bare print calls" → `style_invariants`. "Every handler needs a docstring" → `required_pattern`. If you find yourself reaching for a negative-lookahead in `require_pattern`, you probably want `style_invariants` instead.
- **Choosing between `banned_imports` and `style_invariants`:** if the thing-to-forbid is an import statement (matched by name), use `banned_imports` — it understands import structure and handles aliases. If it's a call site or arbitrary code text, use `style_invariants` with a regex. They compose: a `banned_imports` rule plus a `style_invariants` rule on the call pattern catches both the import and the inline use.
- **`coverage_floor` is its own world** — it consumes a coverage report, not diff content. It cannot be substituted by any pattern-based rule. If your project lacks coverage tooling, the rule degrades to warn-and-skip rather than gating PRs.
- **Layering multiple rules of the same type.** You can have several `banned_imports` blocks targeting different scopes (e.g., one for module-top-level heavy ML, one for async paths sync-HTTP). The parser treats them independently — the diff must satisfy all of them. Don't try to cram unrelated bans into a single block.
