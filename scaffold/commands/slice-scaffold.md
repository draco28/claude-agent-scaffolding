---
description: Enter the scaffold phase. Gate-checks prior phase ∈ {contract, scaffold, implement}, then flips state. The agent writes Zone-1 boilerplate (skeletons, types, glue) — tests should still fail.
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

sf_slice_phase_scaffold
exit $?
'
```

If the bash exits successfully, the slice is now in the scaffold phase. Write the **structural Zone-1 boilerplate** that the implement phase will fill in:

- File structure and module organization
- Type definitions / interfaces / function signatures
- Glue code (router wiring, middleware registration, dependency injection setup)
- Imports and exports
- Constants and enum values
- Empty function bodies (`pass` / `return null` / `unimplemented!()` / `panic("todo")`)

The tests should **still be failing** after this phase — you've laid the structure, not the logic. Compose with `ai-mentor`: scaffold work is Curve 1; if you're in z2-build, override with "show me" or run `/z1` for this phase.

Once the skeleton is in place, advise `/slice-implement`. If you discover the spec/contract was wrong while scaffolding, run `/slice-spec` or `/slice-contract` to back up.
