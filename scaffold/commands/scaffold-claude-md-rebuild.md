---
description: Regenerate <repo>/CLAUDE.md from the personal-defaults + project-layer sources. Warns if manual edits are detected since last generation.
argument-hint: "[--force]"
allowed-tools: Bash(bash:*)
---

Concatenate the two source layers into `<repo>/CLAUDE.md`. Detects manual edits to the working-tree CLAUDE.md (via footer-timestamp vs mtime comparison) and warns before overwriting. Pass `--force` to regenerate anyway.

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/claude-md.sh"

ARG="${ARGUMENTS:-}"
[[ -z "$ARG" ]] && ARG="$1"
FORCE=0
[[ "$ARG" == "--force" ]] && FORCE=1

cd "$(sf_repo_root)" || exit 1

# Manual-edit check
if sf_claude_md_manually_edited; then
  if [[ "$FORCE" != "1" ]]; then
    echo "⚠ <repo>/CLAUDE.md appears to have been edited manually since last generation."
    echo "  Footer timestamp: $(sf_claude_md_footer_timestamp)"
    echo "  File mtime: $(stat -c %y "$(sf_claude_md_path)" 2>/dev/null || stat -f %Sm "$(sf_claude_md_path)" 2>/dev/null)"
    echo ""
    echo "Regenerating will overwrite your manual edits."
    echo ""
    echo "Options:"
    echo "  1. Save your edits into the project source layer first:"
    echo "       /scaffold-claude-md-edit project"
    echo "       (then copy the relevant lines from CLAUDE.md into the project layer)"
    echo "  2. Run /scaffold-claude-md-rebuild --force to overwrite anyway"
    exit 1
  else
    cp "$(sf_claude_md_path)" "$(sf_claude_md_path).bak"
    echo "Backed up manual CLAUDE.md → $(sf_claude_md_path).bak"
  fi
fi

OUT="$(sf_generate_claude_md)"; rc=$?
if [[ $rc -eq 0 && -n "$OUT" ]]; then
  echo "Regenerated: $OUT"
  echo "  Personal layer: $(sf_personal_defaults_path)"
  echo "  Project layer:  $(sf_project_layer_path)"
else
  echo "Regeneration failed (claude_md_managed may be false; check /scaffold-status)"
  exit 1
fi
' "$ARGUMENTS"
```

After running, briefly mention which layers contributed and how many lines the generated file has. If a `.bak` was created, remind the user to manually merge any wanted lines into the source layers (`/scaffold-claude-md-edit project`).
