# ai-mentor tests

Hook regression suite for the plugin. 28 deterministic tests covering:

- **State helpers** (9 tests): missing/malformed state defaults, `am_set_zone`, `am_set_quiz`, `am_last_user_msg`, override-phrase detection.
- **PreToolUse hook** (11 tests): zone matrix (`ambient`/`1`/`2`), submode-specific block/allow, fail-open paths (malformed state, missing transcript), tool-name matcher scope.
- **SessionStart hook** (8 tests): source-aware behavior — reset on `startup`/`clear`, preserve on `resume`/`compact`, defensive default on missing source, non-empty `additionalContext` emission.

## Run

```bash
bash ai-mentor/tests/test-hooks.sh
```

Exit 0 on all-pass; non-zero with a list of failed assertions otherwise. The script isolates state in a tempfile under `/tmp/ai-mentor-tests-*`, never touches your real `${CLAUDE_PLUGIN_DATA}/state.json`, and cleans up via `trap` on exit.

## Dependencies

`bash`, `jq`. Same as the plugin itself.

## When to run

- Before committing any change to `lib/`, `hooks-handlers/`, or `commands/` (mode logic could regress).
- Before bumping the plugin version.
- After upgrading bash or jq versions on your machine.

## Future work

- A separate `evals/` directory for *model-behavior* tests (e.g., does the agent actually start at L1 hints, does `/eli10` actually simplify, etc.) — would require a Claude Code eval harness, not just bash.
