---
description: List all slices on the current branch in a markdown table — number, id, phase, AC count, creation date.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/slice.sh"

if ! sf_is_managed; then
  echo "scaffold: this branch is not initialized. Run /scaffold-init first."
  exit 0
fi

CURRENT="$(sf_current_slice)"
echo "Slices on branch $(sf_branch):"
[[ -n "$CURRENT" ]] && echo "Current: $CURRENT" || echo "Current: (none)"
echo ""
sf_slice_list_table
'
```

After running, if there are completed slices and an active one, briefly highlight which is current. If there are zero slices, suggest `/slice-new <name>` to start one.
