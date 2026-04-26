---
description: Print the path to the personal or project CLAUDE.md source layer (seeds it from template if missing). Edit the file directly, then run /scaffold-claude-md-rebuild.
argument-hint: "personal|project"
allowed-tools: Bash(bash:*)
---

Print the path to the chosen source layer and seed it from template if it doesn't exist yet. The user edits the file (via Claude Code's Edit tool, an external editor, or any way they prefer), then runs `/scaffold-claude-md-rebuild` to regenerate the working-tree CLAUDE.md.

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/claude-md.sh"

LAYER="${ARGUMENTS:-}"
[[ -z "$LAYER" ]] && LAYER="$1"
LAYER="$(echo "$LAYER" | tr -d "[:space:]" | tr "[:upper:]" "[:lower:]")"

case "$LAYER" in
  personal)
    if sf_seed_personal_defaults; then
      echo "Seeded from template:"
    else
      echo "Already exists:"
    fi
    PATH_VAR="$(sf_personal_defaults_path)"
    SCOPE="user-global (applies to all your projects)"
    ;;
  project)
    if sf_seed_project_layer; then
      echo "Seeded from template:"
    else
      echo "Already exists:"
    fi
    PATH_VAR="$(sf_project_layer_path)"
    SCOPE="per-repo (just this project)"
    ;;
  *)
    echo "Usage: /scaffold-claude-md-edit personal|project"
    echo ""
    echo "  personal — your defaults across all projects"
    echo "  project  — additions specific to the current repo"
    exit 1
    ;;
esac

echo "  $PATH_VAR"
echo ""
echo "Scope: $SCOPE"
echo ""
echo "Edit this file, then run /scaffold-claude-md-rebuild to regenerate <repo>/CLAUDE.md."
' "$ARGUMENTS"
```

After running, offer to read the file back and walk the user through edits using the Edit tool. When edits are done, remind them to run `/scaffold-claude-md-rebuild` to materialize the changes into the working-tree CLAUDE.md.
