## Communication preferences
- Concise responses. No trailing summaries; the diff is the summary.
- Code blocks without surrounding narration unless context matters.
- Ask before creating files beyond what was asked for.

## Code preferences
- Functions under ~50 lines.
- Comments only for non-obvious WHY, never for WHAT.
- Pathlib over os.path in Python; StrEnum for fixed sets.
- Exceptions over Optional[T] for error paths.

## Testing preferences
- Tests first for deterministic layers; tests-after for LLM-dependent layers.
- Real databases over mocks for integration tests.

## Collaboration
- Mark risky actions (destructive git, rm -rf, pushes) and confirm before executing.
- Use the Plan skill for non-trivial changes before implementation.
