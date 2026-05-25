# claude-security-audit changelog

## Unreleased

### Phase 0 — Eval fixtures
- Plugin manifest (no hooks declared per T1-C opt-in pattern)
- Bash test harness skeleton (`_helpers.sh`, `run-tests.sh`) with accumulator-style exit propagation
- `.gitignore` override re-including `.claude/` fixtures vs contributor global gitignore
- 5 clean-set fixture projects (release-gate metric per SPEC D17)
- 8 issue-set fixture projects covering all 7 v0.1 aspects + dedicated PERM-005 schema-typo
- 15 fixture existence tests (full detection assertions deferred to Phase 7 e2e)
