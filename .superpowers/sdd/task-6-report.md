# Task 6 Report

## Status

Implemented Architect Critic's one-time OpenCode session lifecycle adapter and
the package-owned OpenCode host policy overlay from base `d8ecd09`.

## RED

Command:

```bash
node --test --test-name-pattern "Task 6" tests/test-opencode-runtime-adapter.mjs
```

Result: 8 tests, 1 passed, 7 failed. The lifecycle tests failed because
`experimental.chat.messages.transform` did not exist, and the host-policy test
failed because no OpenCode overlay was present. The already-satisfied negative
overlay restriction test passed.

## GREEN

Focused command:

```bash
node --test --test-name-pattern "Task 6" tests/test-opencode-runtime-adapter.mjs
```

Result: 8 tests, 8 passed, 0 failed, 0 skipped.

Full adapter command:

```bash
node --test tests/test-opencode-runtime-adapter.mjs
```

Result: 62 tests, 62 passed, 0 failed, 0 skipped.

Canonical Architect Critic command:

```bash
bash architect-critic/run-tests.sh
```

Result: 15 test files run, 0 failed. The suite reported its two expected
not-yet-built consumer integration skips; all executed canonical tests passed.

Relevant parity commands:

```bash
bash tests/test-codex-dual-publish.sh
bash tests/test-recommendation-policy-parity.sh
```

Results: 155 passed and 0 failed; 7 passed and 0 failed, respectively.

## Behavior

- Uses the tested OpenCode `{ info, parts }` message shape and `info.sessionID`.
- Executes only `architect-critic/hooks-handlers/session-start.sh`, directly via
  `execFile` with an argument array, the caller environment/HOME, and canonical
  `PLUGIN_ROOT`/`CLAUDE_PLUGIN_ROOT` context.
- Marks each valid session attempted before execution, preventing repeated or
  concurrent reruns. Failed attempts remain attempted.
- Prepends nonblank stdout to the first text part of the first user message
  without changing message or part schemas. All malformed, missing, empty, and
  execution-error cases fail open.
- Keeps independent session IDs independent and does nothing when Architect
  Critic is not selected.
- Appends a concise binding OpenCode policy only to ownership-verified
  `critiquing-spec` skill output. Canonical handler and skill files are
  unchanged.
- Does not discover lifecycle files; Workspace Init's generated `commit-msg`
  hook remains outside adapter execution.

## Files

- `.opencode/lib/runtime.js`: one-time fail-open session-start transform.
- `.opencode/lib/translate.js`: package-owned Architect Critic OpenCode overlay.
- `tests/test-opencode-runtime-adapter.mjs`: lifecycle, failure, isolation,
  ownership, host-policy, and Workspace Init exclusion coverage.
- `.superpowers/sdd/task-6-report.md`: TDD and verification evidence.

`marketplace.js` required no dedicated change because its existing runtime hook
spread composes the new transform without an override.

## Commit And Concerns

Commit message: `feat(opencode): adapt architect critic lifecycle`.

No implementation concerns. A live OpenCode async compatibility smoke test is
still intentionally required before reusing the Claude-host Codex async spine;
the binding overlay requires explicit async requests to fail clearly rather
than silently falling back to foreground.
