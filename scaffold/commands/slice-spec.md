---
description: Re-enter the spec phase for the current slice. Re-parses acceptance criteria from the spec file into state. Use to refresh AC tracking after editing the spec by hand.
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

sf_slice_phase_spec
RC=$?
if [[ $RC -eq 0 ]]; then
  ID="$(sf_current_slice)"
  COUNT="$(sf_read_state | jq -r ".slices[\"$ID\"].acceptance_criteria | length")"
  echo "Refreshed ACs from spec file: ${COUNT} criteria"
fi
exit $RC
'
```

After running, if the AC list changed (new entries added since the last refresh), briefly summarize what's new. If ACs are still placeholder ("TODO"), open the spec file with Read and walk the user through capturing concrete, measurable criteria. Once ACs are good, advise `/slice-contract`.
