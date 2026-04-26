---
description: Show the current scaffold state — current slice, phase, stack, LLM flag, branch, last audit.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Pretty-print the state file for the current repo + branch.

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"

if ! sf_is_managed; then
  echo "scaffold: this repo + branch is not yet initialized."
  echo "  repo:   $(sf_repo_root)"
  echo "  branch: $(sf_branch)"
  echo ""
  echo "Run /scaffold-init to bootstrap, or /scaffold-audit to gap-check without initializing."
  exit 0
fi

STATE="$(sf_read_state)"
echo "scaffold status"
echo "  project:       $(basename "$(sf_repo_root)")"
echo "  hash:          $(sf_repo_hash)"
echo "  branch:        $(sf_branch)"
echo "  state file:    $(sf_state_path)"
echo ""
echo "  schema:        $(echo "$STATE" | jq -r .schema_version)"
echo "  stack:         $(echo "$STATE" | jq -r ".stack | join(\", \")")"
echo "  llm project:   $(echo "$STATE" | jq -r .llm_project)"
echo "  current slice: $(echo "$STATE" | jq -r ".current_slice // \"(none)\"")"

CURRENT="$(echo "$STATE" | jq -r ".current_slice // empty")"
if [[ -n "$CURRENT" ]]; then
  PHASE="$(echo "$STATE" | jq -r ".slices[\"$CURRENT\"].phase // \"?\"")"
  echo "  slice phase:   $PHASE"
fi

SLICE_COUNT="$(echo "$STATE" | jq -r ".slices | length")"
echo "  slices total:  $SLICE_COUNT"
echo "  adr counter:   $(echo "$STATE" | jq -r .adr_counter)"
echo "  claude_md:     $(echo "$STATE" | jq -r .claude_md_managed)"
LAST_AUDIT="$(echo "$STATE" | jq -r ".last_audit_at // \"never\"")"
echo "  last audit:    $LAST_AUDIT"
echo "  updated:       $(echo "$STATE" | jq -r .updated_at)"
'
```

After running, if a slice is active, mention the next likely action (e.g., "current phase is contract — next: `/slice-scaffold` once tests are failing"). If no slice is active, suggest `/slice-new <name>`.
