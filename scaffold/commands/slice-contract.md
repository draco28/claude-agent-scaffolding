---
description: Enter the contract phase. Gate-checks that the spec has at least one acceptance criterion, then flips state to phase=contract. The agent then scaffolds failing tests for each AC.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/slice.sh"

if ! sf_is_managed; then
  echo "scaffold: this branch is not initialized. Run /scaffold-init first."
  exit 1
fi

sf_slice_phase_contract
exit $?
'
```

If the bash exits successfully, the slice is now in the contract phase. Now: scaffold failing tests for each acceptance criterion, using the test framework printed in the bash output (e.g., pytest/vitest/jest/cargo test/go test).

Conventions to follow:
- Each test should reference its AC id in the test name or a docstring (e.g., `def test_ac1_login_with_google():` or `// AC-2: session persists 24h`).
- Tests should be **failing** at this point — they describe behavior that doesn't exist yet.
- Don't over-test: one test per AC is the floor; add more only when an AC has multiple cases.
- After writing the tests, run the test command once to confirm they fail. The `/slice-scaffold` step expects this.

If the gate failed (no ACs in spec, or wrong prior phase), fix what the error message asked for and re-run `/slice-contract`. Test scaffolding is Curve-1 work — mechanical, template-driven — so this is fine to run in `/z1` even if you're normally in spotter mode.
