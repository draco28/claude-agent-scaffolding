---
description: Run all tests for the current slice; capture results to state.last_test_result; mark slice complete if exit 0, otherwise stay in verify phase. Run repeatedly while iterating on fixes.
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

sf_slice_phase_verify
exit $?
'
```

After running, the bash output tells you whether the slice is now `complete` (all tests passed) or stuck at `verify` (some failing).

- **If complete**: briefly congratulate, mention the slice id, and suggest the next move — usually `/slice-new <next-name>` for the next slice, or `/changelog` to record what was just shipped, or `/adr-new` if a non-obvious decision was made along the way.
- **If failing**: read the captured failing-test output (last 10 lines printed by the bash). Identify which AC the failures map to. Suggest a focused fix; don't try to address everything at once. After the fix, re-run `/slice-verify`.

If tests are passing but specific ACs in the spec file are still unchecked (`- [ ]`), the user may want to manually update the checklist in the spec file to reflect reality, since v1 doesn't auto-map test outcomes to AC ids.
