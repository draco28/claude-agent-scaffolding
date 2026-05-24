# Extensibility reference — forward-compat mcrule types (§8.5)

> Companion reference to `SKILL.md` for the `authoring-machine-checkable-rules` skill. This doc walks through SPEC §8.5 in depth: why the warn-and-skip contract exists, what it looks like in practice, what hypothetical v0.3+ rule types might do, what the experience is for a user with a v0.3 project running v0.2 tooling, and when a v0.2 user should reach for a new rule type vs use one of the four existing ones.

This is a **policy / behavior** reference. The four supported types and their fields are documented in `rule-types.md` — this doc is about what happens around the edges.

---

## Why forward-compat matters

The mcrule DSL is a shared contract between two plugins: `scaffold-onboard` authors rule blocks in `03-code-patterns.md`; `scaffold-dev`'s `implementation-checking` skill consumes them at PR-verification time. Both plugins version independently, can be installed independently, and may be at different release levels on a given user's machine.

The realistic asymmetries:

- **scaffold-onboard newer than scaffold-dev** — a user upgrades scaffold-onboard to v0.3 (which adds, say, `complexity_ceiling`), authors a `complexity_ceiling` rule, and then runs scaffold-dev v0.2 at PR-verification time. The older scaffold-dev parser doesn't recognize `complexity_ceiling`. Without forward-compat, it would crash on the unknown type — turning a successful authoring session into a broken verification pipeline.
- **scaffold-dev newer than scaffold-onboard** — a user has scaffold-dev v0.3 but is using scaffold-onboard v0.2 to author rules. The user can only author the four v0.2 types from the authoring skill, but a teammate might hand-author a `complexity_ceiling` block directly. scaffold-onboard v0.2's section-scan (during a subsequent rule-authoring invocation) must not crash on the unknown type the teammate added.
- **Older project, current tooling** — a user clones a project authored against scaffold-onboard v0.1.x (which used different sentinels or no rules at all) and starts a v0.2 authoring session. The grammar has been stable since v0.2 GA, but `03-code-patterns.md` may contain pre-v0.2 prose patterns. The skill must not crash because it found unexpected content in the section.

The unifying principle: **rule blocks the parser doesn't understand are not errors — they're signals from another version that this version doesn't yet (or no longer) speak.** The right response is warn-and-skip, not crash.

This is the same forward-compat philosophy that lets older browsers ignore unknown HTML attributes, older JSON parsers skip unknown object keys (with `additionalProperties: true`), and HTTP clients tolerate response headers they don't recognize. The contract is "preserve what you don't understand, act on what you do."

---

## Warn-and-skip behavior

The contract has two layers — the **parser layer** (in `lib/rules.sh`, consumed by both scaffold-onboard's authoring skill and scaffold-dev's `implementation-checking` skill) and the **skill layer** (the authoring conversation surface visible to the user).

### Parser layer (`sf_rules_parse` in `lib/rules.sh`)

When `sf_rules_parse` walks the `## Machine-checkable rules` section and encounters a `<!-- mcrule:start type=<T> -->` sentinel with a `<T>` that isn't one of the four v0.2 types:

1. The unknown block's body is **read but not interpreted** — fields are not validated against any schema (the parser doesn't know which schema to apply).
2. A warning is emitted to stderr in the form: `warning: unknown mcrule type '<T>' at <path>:<line>, skipping`.
3. The block is **omitted from the parser's JSON output** — downstream consumers see only blocks of recognized types.
4. The file on disk is **untouched** — parser is read-only.
5. Exit status remains `0` (success) — unknown types are not parse errors. A non-zero exit is reserved for malformed sentinels or non-parseable bodies of *recognized* types.

This means the parser's JSON output is the v0.2-recognized subset of what's on disk. A scaffold-dev consumer iterating over the JSON will only ever see types it has check logic for.

### Skill layer (the authoring conversation)

The skill's behavior on encountering an unknown type during its section-scan (per SKILL.md §8) layers a user-visible acknowledgment on top of the parser's stderr warning:

1. The skill surfaces a one-line note in conversation: *"Note: encountered `<!-- mcrule:start type=dependency_age -->` block in section — this is a forward-compat type not recognized by v0.2. Preserving as-is."* The framing is neutral, not alarming — the user shouldn't think their file is broken.
2. The skill **does not delete, modify, or reformat** the unknown block. The `## Machine-checkable rules` section on disk retains it byte-identical.
3. The skill **continues** with the authoring flow. The unknown block doesn't block authoring a new rule; the new rule appends after the existing content (including the unknown block) per §8 append semantics.
4. **Idempotency still holds** for the new block being authored — the skill scans for verbatim-identical recognized-type blocks, not against unknown-type blocks (which are opaque to it).

The user-visible artifact, end-to-end, looks like:

> "I see there's already a `dependency_age` block in the section — that's a forward-compat type not recognized by v0.2 tooling, so I'm preserving it as-is. Your new `style_invariants` rule will be appended after it. [proceeds with authoring conversation]"

Versus the no-forward-compat alternative (which v0.2 explicitly rejects):

> "Error: unknown rule type `dependency_age` in 03-code-patterns.md at line 47. Aborting."

The latter would break authoring sessions whenever a project's rule file pulls in any newer-than-v0.2 content — making the file format effectively non-portable across plugin versions. The forward-compat contract is what makes the DSL safe to evolve.

---

## Hypothetical v0.3+ rule types (illustrative, non-binding)

These are **examples of types that might land in a future version** — they are NOT spec'd in v0.2 and are listed here only to illustrate the shapes of invariants the four current types cannot capture. The actual v0.3+ design will be settled in that release's SPEC + brainstorm cycle; nothing here is a forward commitment.

### `dependency_age`

**Hypothetical intent:** "no dependency in `requirements.txt` / `package.json` may be older than N days since last upstream release." Catches stale pins that accumulate security vulnerabilities and ecosystem drift.

Hypothetical fields might include `manifest:` (which lockfile to read), `max_days:` (the staleness threshold), `exempt:` (a list of allowed-to-be-stale dependencies — e.g., pinned for compatibility reasons).

This is **not** expressible as a v0.2 rule type because none of the four read package manifests or consult a date-of-release lookup. `banned_imports` matches names but doesn't know about versions or dates; `coverage_floor` reads coverage reports; `style_invariants` / `required_pattern` operate on diff lines.

### `complexity_ceiling`

**Hypothetical intent:** "no function in scope may exceed cyclomatic complexity N." Catches functions that grow unwieldy and become bug magnets.

Hypothetical fields might include `max_complexity:` (the threshold), `in:` (file glob), `where: function_def` (per-function scoping, reusing the v0.2 `where:` vocabulary), and a metric selector (`metric: cyclomatic | cognitive`).

This is **not** expressible as a v0.2 rule type because cyclomatic complexity is computed from an AST, not regex-matchable from diff text. A `style_invariants` rule on `'^\s*(if|for|while)'` would only count keywords, not branch points — and it counts per-line, not per-function.

### `lock_file_drift`

**Hypothetical intent:** "the lock file (`poetry.lock`, `package-lock.json`) must be regenerated whenever the manifest (`pyproject.toml`, `package.json`) changes." Catches drift where someone edits the declared dependencies without re-resolving.

Hypothetical fields might include `manifest:` (the high-level file) and `lockfile:` (the resolved file). The check is "if `manifest` is in the diff, `lockfile` must also be in the diff."

This is **not** expressible as a v0.2 rule type because v0.2 rules check diff content within files, not cross-file diff-coverage relationships. A `required_pattern` rule on the lockfile wouldn't fire when the manifest changes alone — it only fires when the lockfile itself is touched.

### `secret_scan`

**Hypothetical intent:** "no diff line may match any pattern in a curated secret-shape list (AWS keys, GitHub tokens, JWT structures, private-key headers, etc.)." A first-class type for security scanning, sharing semantics with `style_invariants` but using a curated pattern library rather than a user-specified regex.

Hypothetical fields might include `library: built_in_v1` (which curated pattern set to use), `exclude:` (files exempt — e.g., `tests/fixtures/`), and maybe `severity: warn | block`.

You **can** approximate this in v0.2 with multiple `style_invariants` rules each pinning one secret shape (the `AKIA[0-9A-Z]{16}` example in `rule-types.md`'s `style_invariants` section), but you'd have to maintain the regex library yourself. A first-class type would bundle the library.

### Other plausible directions

- `dependency_pin` — "every dependency must have an exact version pin, not a range."
- `path_required` — "if a new module is added under `src/api/handlers/`, a corresponding test file must be added under `tests/api/handlers/`."
- `naming_convention` — "every file in `src/services/` must be named `*_service.py`."

These are all **outside the v0.2 scope** and listed only to show that the four types cover the most common invariants but leave room for an evolving DSL.

---

## What a v0.3 project on v0.2 tooling experiences

Concrete walkthrough. The user's project was authored against scaffold-onboard v0.3 (hypothetical) — their `03-code-patterns.md` contains a mix of v0.2 types and v0.3 types:

```markdown
## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
forbid: [requests]
<!-- mcrule:end -->

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->

<!-- mcrule:start type=dependency_age -->
manifest: pyproject.toml
max_days: 365
<!-- mcrule:end -->

<!-- mcrule:start type=complexity_ceiling -->
in: src/**/*.py
where: function_def
max_complexity: 10
<!-- mcrule:end -->
```

The user is running scaffold-dev v0.2 (older than scaffold-onboard v0.3). When `implementation-checking` runs at PR verification:

1. **`sf_rules_parse` is invoked on `03-code-patterns.md`.** Two of the four blocks are recognized (`banned_imports`, `coverage_floor`); the other two are not.
2. **Warnings on stderr:**
   ```
   warning: unknown mcrule type 'dependency_age' at .claude/memory-bank/03-code-patterns.md:11, skipping
   warning: unknown mcrule type 'complexity_ceiling' at .claude/memory-bank/03-code-patterns.md:16, skipping
   ```
3. **JSON output contains 2 rules, not 4** — only `banned_imports` and `coverage_floor` are visible to the consumer.
4. **scaffold-dev's `implementation-checking` runs the two recognized checks**, reports their pass/fail.
5. **The verification report flags the skipped types.** scaffold-dev's report surface includes a section: *"2 of 4 rules were skipped (unknown to v0.2 parser): `dependency_age`, `complexity_ceiling`. Verification is incomplete for these invariants — upgrade scaffold-dev to a version that supports them, or remove them from `03-code-patterns.md` if no longer desired."*
6. **The overall verification outcome is INCOMPLETE, not FAILED.** This is a deliberate v0.2 contract design: skipping due to forward-compat is not the same as a recognized rule failing. The PR isn't blocked by the skip alone, but the user has visibility that some invariants weren't checked.

The asymmetry matters. A recognized `banned_imports` rule that **fails** (the diff introduces `requests`) blocks the PR — that's a real violation. A `dependency_age` rule that **can't be evaluated** because the parser doesn't know its semantics doesn't block — the parser cannot confidently assert pass-or-fail on something it doesn't understand. Blocking on parser ignorance would be a false-positive failure mode worse than the silent-pass mode (which is bounded by the explicit "INCOMPLETE" surfacing).

The user's mental model: **scaffold-dev v0.2 + v0.3 rules = some invariants enforced, some deferred until tooling upgrade**. The file is portable forward; tooling catches up at its own pace.

---

## When the v0.2 user should author a new rule type vs use one of the four existing types

This is the question that comes up when a user asks "add a rule for X" and X doesn't cleanly map to `banned_imports` / `coverage_floor` / `style_invariants` / `required_pattern`.

### Use one of the four if you can express the invariant within their semantics

The four types are deliberately broad. Most invariants have a path through them:

- "No deprecated API surface" → `banned_imports` (if it's an import) or `style_invariants` (if it's a call pattern)
- "Specific subsystem must have high coverage" → `coverage_floor`
- "No bare `print()` calls" → `style_invariants`
- "Every handler needs a docstring" → `required_pattern`
- "No `eval`-style dynamic code execution" → `style_invariants` on the call pattern
- "Every module must declare `__all__`" → `required_pattern` with `where: module_top_level`
- "License header on every file" → `required_pattern` with `where: module_top_level`
- "No TODO comments in production code" → `style_invariants` with `exclude: tests/**/*.py`

If you can describe the invariant as a path-scoped forbid-pattern, require-pattern, banned-import, or coverage-threshold, **use the existing type**. Don't author a forward-compat block that the tooling won't enforce until v0.3+ if a v0.2 type would work — enforced today beats latent tomorrow.

### Reach for a forward-compat type when the invariant genuinely cannot be expressed

Some invariants don't fit:

- **Cross-file relationships** (lockfile must be regenerated when manifest changes) — none of the four v0.2 types span files.
- **AST-level metrics** (cyclomatic complexity, nesting depth) — regex can approximate but not measure.
- **Metadata-level checks** (dependency age, license type, package size) — v0.2 types read code, not package metadata.
- **Aggregate constraints** ("at least 80% of handlers must have rate limiting") — v0.2 types check per-match, not per-aggregate.

For these, the user has three options:

1. **Hand-author a forward-compat block** in the future-type form per §8.2 grammar. Document the intent in surrounding prose. The block will warn-and-skip in v0.2 tooling but will be honored once the tooling supports the type. The skill helps with this: it offers to free-form-author the block per §9 of `SKILL.md` when a user asks for an unknown type. The user accepts that enforcement is deferred.
2. **Approximate with an existing type and accept the approximation gap.** A `style_invariants` rule can catch some complexity signals (deeply nested code) by pattern-matching indentation; a `required_pattern` rule can catch some cross-file expectations (every handler file must reference the rate-limit decorator). The approximation won't be complete but may catch the most common violations.
3. **Defer the invariant entirely to v0.3+ planning.** If the approximation is too lossy and the latent forward-compat block adds clutter without enforcement value, the invariant lives in the project's `RISK_REGISTER.md` or governance prose until tooling catches up. Sometimes the right answer is "we want this but can't enforce it today."

The skill should not silently re-classify the user's ask into a poor-fit type. If the user asks for "dependency age" and the closest existing type would be a `banned_imports` of specific stale versions (an obviously poor fit), the skill should surface the mismatch and offer the three options — not write the misfit rule. See SKILL.md §9 for the conversational shape of this handoff.

---

## Summary

The forward-compat contract has three load-bearing properties:

1. **Unknown types don't crash** — parsers and skills both treat unknown `type=` values as opaque-but-preserve.
2. **Unknown types degrade gracefully** — verification becomes INCOMPLETE, not FAILED, when types can't be evaluated.
3. **Files are portable forward** — a v0.3-authored `03-code-patterns.md` is a valid v0.2 input (skipping the v0.3 blocks), and a v0.2-authored one is a trivially-valid v0.3 input (no skipping needed).

This is what makes the mcrule DSL safe to evolve. The four v0.2 types are a starting set, not a closed grammar. Future versions add types; older versions skip them; users get incremental value as their tooling catches up.

When in doubt, the skill prefers **using an existing type with an honest approximation** over authoring a forward-compat block whose enforcement is years away. Latency-of-enforcement is a real cost; deferred invariants tend to stay deferred. Encode what you can today; reach forward only when the four types genuinely don't fit.
