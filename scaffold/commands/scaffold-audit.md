---
description: Run a gap analysis on the current repo (README, license, gitignore, ADRs, runbooks, slices, test framework, LLM artifacts). Outputs a markdown table.
argument-hint: "[--save]"
allowed-tools: Bash(bash:*)
---

Audit the current repo against scaffold's checklist. Without args, prints a table to terminal. With `--save`, also writes `docs/AUDIT.md`.

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/audit.sh"

REPO_ROOT="$(sf_repo_root)"
cd "$REPO_ROOT" || exit 1

SAVE=0
if [[ "${ARGUMENTS:-}" == "--save" ]] || [[ "$1" == "--save" ]]; then
  SAVE=1
fi

# Run audit and capture rows once; tee to renderer + summary
ROWS="$(sf_audit_run)"
echo "$ROWS" | sf_audit_render_md
echo "$ROWS" | sf_audit_summary
EXIT_CODE=$?

# Update state.last_audit_at if managed
if sf_is_managed; then
  sf_state_apply ".last_audit_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
fi

# --save flag → write docs/AUDIT.md
if [[ "$SAVE" == "1" ]]; then
  mkdir -p docs
  {
    echo "$ROWS" | sf_audit_render_md
    echo ""
    echo "$ROWS" | sf_audit_summary
  } > docs/AUDIT.md
  echo ""
  echo "(saved to docs/AUDIT.md)"
  if sf_is_managed; then
    sf_state_apply ".audit_results_path = \"docs/AUDIT.md\""
  fi
fi

exit $EXIT_CODE
' "$ARGUMENTS"
```

After running, briefly note the most actionable warning or fail (the one with the highest leverage to fix). If the repo isn't scaffold-managed yet, suggest `/scaffold-init` to enable persistent audit-history tracking. If `--save` was used, mention the file path.
