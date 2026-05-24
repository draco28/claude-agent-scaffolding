# `auto:` grammar — deep dive with worked examples

Reference for the `authoring-vertical-slice-demo` skill (scaffold-onboard SPEC §9.1, scaffold-dev SPEC §14.1). This doc covers the `auto:` form only — the machine-checkable demo-criterion line that scaffold-dev's `closing-vertical-slice` skill runs at slice-close time. See `user-grammar.md` for the `user:` form.

---

## 1. Grammar

```
- [ ] auto: <bash command> → expected: <exit code 0 | pattern in output>
```

Components, in order:

1. **Checkbox prefix** — the literal string `- [ ] ` (dash, space, open-bracket, space, close-bracket, space). Present in markdown mode; stripped in state mode (the `demo_criteria[]` array stores only the bullet body).
2. **Form prefix** — the literal token `auto:` followed by a single space.
3. **Bash command** — a single shell command (or pipeline) that can run non-interactively. Backtick-quoted command text is conventional but not required.
4. **Arrow delimiter** — the literal **U+2192 arrow character** (`→`), surrounded by single spaces. NOT the ASCII `->` digraph. See §5 for why.
5. **Expected clause** — the literal token `expected:` followed by a single space, then either an exit-code form or a pattern form (§2).

`sf_demo_parse_line` validates all five components in one pass. A mismatch on any component is rejected at the authoring boundary — downstream consumers never see a half-valid line.

---

## 2. Two expected-clause modes

The `expected:` tail has exactly two well-formed shapes. Pick one per line; never combine both.

### 2.1 Exit-code mode (default success criterion)

```
expected: exit 0
expected: exit <N>     (non-zero permitted for negative-test slices, e.g., expected: exit 1)
```

scaffold-dev's execution runs the command via `bash -c` (subshell) and asserts `$? == <N>`. Stdout/stderr are captured for the slice-close log but NOT pattern-checked. Use exit-code mode when the command's own assertions (pytest, go test, jest, `set -e` scripts) carry the verification weight — the binary pass/fail is the answer.

### 2.2 Pattern mode (output matching)

```
expected: output contains "<substring>"
expected: output matches /<regex>/
expected: count > 0                        (informal predicate, judge-verified)
expected: stdout contains "<substring>"    (synonym for "output contains")
```

scaffold-dev's execution runs the command and grep-checks captured stdout against the pattern. The pattern body is preserved byte-for-byte from authoring to execution — quoted substrings, regex anchors, and informal predicates (`count > 0`, `> 5 rows`) all pass through unchanged. The slice-close skill is responsible for matching the predicate shape; this skill only validates that the `expected:` tail is non-empty and follows the arrow.

**Pick one, not both.** A line like `expected: exit 0 AND output contains "ok"` validates as a single string (the parser doesn't reject it) but obscures the success criterion. Split into two `auto:` lines if both gates matter.

---

## 3. Worked examples across project classes

Each example is a complete, copy-paste-ready bullet line. All use the literal `→` arrow.

### 3.1 Python CLI / integration test (exit-code mode)

```
- [ ] auto: `pytest tests/integration/test_insight_pipeline.py` → expected: exit 0
```

Most common shape across Python-heavy projects. The command is fully self-contained — `pytest`'s own assertions decide pass/fail; the slice-close runner just reads the exit code.

### 3.2 Web API endpoint (pattern mode, JSON output)

```
- [ ] auto: `curl -s localhost:8000/api/insights | jq '.[]'` → expected: output contains "action_needed"
```

The pipeline curls a local dev server, extracts JSON array entries via `jq`, and the slice-close runner grep-checks stdout for the substring `action_needed`. Assumes the dev server is up at slice-close time — see §4 on setup commands.

### 3.3 Database query (pattern mode, informal predicate)

```
- [ ] auto: `psql -d insights -c "SELECT count(*) FROM action_needed"` → expected: count > 0
```

The expected tail is an informal predicate (`count > 0`) that the slice-close runner interprets contextually — it reads the `count` column from the psql output and verifies the inequality. Use this shape when the binary "did the command run" answer is less interesting than "did it return non-empty data".

### 3.4 Go test suite (exit-code mode, package globbing)

```
- [ ] auto: `go test ./pkg/parser/...` → expected: exit 0
```

`./pkg/parser/...` recursively tests the parser package and its subpackages. Exit 0 means all tests in the recursive scope passed. Idiomatic for Go projects where one VS may touch multiple subpackages.

### 3.5 Frontend build + artifact check (chained command, exit-code mode)

```
- [ ] auto: `npm run build && ls dist/main.js` → expected: exit 0
```

Two sub-commands chained with `&&` — the build runs, and if it succeeds, `ls` checks that the expected artifact exists. Both must succeed for `exit 0`. Use chaining when a single criterion needs to verify "build + smoke-check" as one gate. See §4 anti-pattern on multi-line commands.

### 3.6 Schema migration (exit-code mode, scoped CLI)

```
- [ ] auto: `alembic upgrade head` → expected: exit 0
```

Runs migrations to head. Exit 0 means all pending migrations applied. The slice-close runner does NOT roll back after success — migrations are forward-only in the slice-close context. (If your slice tests a rollback path, that's a separate `auto:` line.)

### 3.7 ML pipeline checkpoint (pattern mode, file-output check)

```
- [ ] auto: `python train.py --epochs 1 --dry-run && ls models/checkpoint.pt` → expected: output contains "checkpoint.pt"
```

Runs one training epoch in dry-run mode and verifies the checkpoint file landed. The `output contains` pattern matches `ls`'s stdout (the filename) rather than the exit code, because the upstream `train.py` may print warnings that confuse exit-code-only interpretation.

### 3.8 Container build + smoke test (exit-code mode, multi-stage)

```
- [ ] auto: `docker build -t insights:demo . && docker run --rm insights:demo --version` → expected: exit 0
```

Builds the image and runs the container with a non-zero-trivial entrypoint (`--version`). Exit 0 means both stages succeeded. Slice-close runner inherits the surrounding shell's docker context.

### 3.9 Data-pipeline output validation (pattern mode, regex)

```
- [ ] auto: `python pipelines/etl.py --date 2026-01-01 | wc -l` → expected: output matches /^[0-9]+$/
```

The pipeline emits one record per line; `wc -l` counts them. The regex anchors stdout to a non-negative integer. Useful when "did the ETL produce SOME output" is the success criterion.

---

## 4. Edge cases

### 4.1 Commands needing setup (DB seeded, env var set, server running)

The grammar does NOT carry environment setup. If your `auto:` line is `curl -s localhost:8000/api/X → expected: output contains "Y"`, the slice-close runner assumes the dev server is already up. Environment provisioning belongs to:

- **Test fixtures** — pytest/jest fixtures that boot a server, seed a DB, set env vars, then run the assertion. The `auto:` line invokes the fixture-wrapped test.
- **Slice-close orchestrator preamble** — scaffold-dev's `closing-vertical-slice` skill may have its own preamble for "boot dev stack before running auto: lines". That's scaffold-dev's lane, not this grammar's.
- **A separate prep step in the same `auto:` line via `&&`** — e.g., `make seed-db && pytest tests/integration → expected: exit 0`. Acceptable when prep is fast and idempotent.

If you find yourself writing prose like "first run `docker compose up`, then `auto: curl ... → expected: ...`", the prose is a smell. Either fold the setup into the command (`docker compose up -d && curl ...`) or rely on a test fixture.

### 4.2 Long-running commands

scaffold-dev's `closing-vertical-slice` imposes a **default timeout** on each `auto:` line (see scaffold-dev SPEC §14.1 for the current default). A `cargo build --release` that legitimately takes 5 minutes on a clean cache should NOT be a demo criterion — surface it via a prebuilt artifact check instead (`ls target/release/insights → expected: exit 0`).

If a long-running command is unavoidable (e.g., a full E2E suite that genuinely takes 90 seconds), author it as-is and let the slice-close runner's timeout policy decide. Do not encode a custom timeout in the grammar — there's no `timeout:` clause. Timeout is the runner's concern, not the criterion's.

### 4.3 Backtick-quoted command text + nested quotes

When the bash command contains its own quoted substrings (e.g., a SQL query inside `psql -c`), backtick the whole command and escape carefully:

```
- [ ] auto: `psql -d insights -c "SELECT count(*) FROM action_needed WHERE due_date < NOW()"` → expected: count > 0
```

Inside the backticks, double-quotes around the SQL are preserved byte-for-byte; the parser doesn't strip backticks at write time. The `expected:` tail comes after the closing backtick + arrow.

### 4.4 Commands with shell special characters (`|`, `&`, `>`, `<`)

Pipes (`|`) are fine — they're part of the bash command. Background operators (`&`) are NOT fine — `pytest tests/ &` returns 0 immediately and tells you nothing. Redirections (`>`, `<`) are fine when the redirection target is deterministic; avoid `> /tmp/$$` style ad-hoc PIDs.

### 4.5 Multi-command chains: when to split vs combine

**Combine with `&&`** when the chain represents one logical gate (build + artifact check, migrate + assert schema). **Split into multiple `auto:` lines** when each command tests an independent property and you want per-command pass/fail granularity at slice-close. Rule of thumb: if the failure of step N would still leave step N+1 informative, split.

---

## 5. Anti-patterns

### 5.1 ASCII `->` instead of `→`

```
WRONG: - [ ] auto: pytest tests/ -> expected: exit 0
RIGHT: - [ ] auto: pytest tests/ → expected: exit 0
```

The grammar delimiter is U+2192 (`→`), not the ASCII digraph `->`. `sf_demo_parse_line` rejects `->` with a specific error class. The skill body MUST NOT silently rewrite `->` into `→` — surface the rejection and let the user re-supply (skill body §11). The eval judge verifies the U+2192 codepoint explicitly.

### 5.2 Multi-line command text

```
WRONG:
- [ ] auto: pytest tests/integration \
            --verbose \
            --maxfail=1 → expected: exit 0
```

The grammar is single-line. Fold flags onto one line; if the command is genuinely too long to read, factor it into a script (`scripts/run-integration.sh`) and reference the script:

```
RIGHT: - [ ] auto: `scripts/run-integration.sh` → expected: exit 0
```

### 5.3 Expected clause with both exit-code AND pattern

```
WRONG: - [ ] auto: pytest tests/ → expected: exit 0 AND output contains "PASSED"
```

Pick one. If both gates matter, split into two `auto:` lines:

```
- [ ] auto: `pytest tests/` → expected: exit 0
- [ ] auto: `pytest tests/ -v | grep PASSED` → expected: output contains "PASSED"
```

### 5.4 Pseudo-commands and placeholders

```
WRONG: - [ ] auto: <run the tests> → expected: <they pass>
WRONG: - [ ] auto: TODO: figure out the right command → expected: exit 0
```

The bash command body must be a real, runnable command at the time slice-close executes. Skeleton authoring during R1.C is permitted (the command may reference test files that don't yet exist), but the SHAPE must be executable. Placeholder angle-brackets or TODO markers fail validation downstream even when `sf_demo_parse_line` accepts them syntactically.

### 5.5 Interactive commands

```
WRONG: - [ ] auto: `vim tests/integration.py && pytest tests/` → expected: exit 0
WRONG: - [ ] auto: `read -p "continue?" yn && deploy.sh` → expected: exit 0
```

Slice-close runs non-interactively. Commands that prompt for input (vim, `read`, `gh auth login`, `npm init`) will hang or fail unpredictably. If the slice's verification truly requires interaction, it's a `user:` line, not an `auto:` line.

### 5.6 Cross-slice contamination

```
WRONG (for VS-1.2.1): - [ ] auto: `pytest tests/` → expected: exit 0
```

`pytest tests/` runs every test in the project, including tests landed by future slices. A passing run here may mask a failure introduced by the current slice's code. Scope to the slice's own tests:

```
RIGHT: - [ ] auto: `pytest tests/integration/test_insight_pipeline.py` → expected: exit 0
```

The slice-close runner has no way to know which subset of tests "belongs" to the slice — that judgment lives with the author.

---

## 6. Cross-references

- **scaffold-onboard SPEC §9.1** — grammar definition (verbatim source).
- **scaffold-dev SPEC §14.1** — runtime semantics (how the slice-close skill executes each line).
- **scaffold-onboard SPEC §9.3** — `sf_demo_parse_line` API contract.
- **SKILL.md §3, §7, §11, §15** — form discrimination, validation flow, U+2192 rationale, anti-patterns at the skill-body layer.
- **`user-grammar.md`** — companion reference for the `user:` form.
