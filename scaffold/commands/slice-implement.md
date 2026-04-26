---
description: Enter the implement phase. Gate-checks prior phase ∈ {scaffold, implement, verify}, then flips state. The agent (or user, in z2-build) adds logic until tests start passing.
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

sf_slice_phase_implement
exit $?
'
```

If the bash exits successfully, the slice is now in the implement phase. The work here is **filling in the logic** the scaffold left as TODOs.

Composition with ai-mentor depends on the user's mode:
- **z2-build (learning)**: user types the implementation; you give progressive L1→L4 hints. Don't write code unless the user signals an override.
- **z2-decide (daily/work)**: decisions should already be locked from earlier phases. If new architecture questions arise, surface them; if user runs `/locked`, proceed to write code.
- **z1 / ambient**: write the implementation directly.

Iterate test-first: pick one AC, make its tests pass, move to the next. Run the test command frequently. When all (or enough) ACs pass, advise `/slice-verify` for the formal gate.
