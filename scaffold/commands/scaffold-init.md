---
description: Bootstrap or onboard the current repo with sensible defaults (LICENSE, .gitignore, README, CLAUDE.md, docs structure). Idempotent.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Initialize scaffold state for the current repo and add any missing baseline files. Conservative: never overwrites existing files, only adds what's missing.

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/claude-md.sh"

REPO_ROOT="$(sf_repo_root)"
cd "$REPO_ROOT" || exit 1

# Ensure a git repo exists. /scaffold-init refuses outside git.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "scaffold: not inside a git repo. Run \`git init\` first."
  exit 1
fi

# Already managed → no-op + status
if sf_is_managed; then
  echo "scaffold: already initialized for this branch"
  echo "  hash:   $(sf_repo_hash)"
  echo "  branch: $(sf_branch)"
  echo "  state:  $(sf_state_path)"
  exit 0
fi

# Initialize state (detects stack and LLM signals on first call)
sf_init_state

ADDED=()

# LICENSE — default MIT
if [[ ! -e LICENSE && ! -e LICENSE.md && ! -e COPYING ]]; then
  YEAR="$(date +%Y)"
  HOLDER="$(git config user.name 2>/dev/null)"
  [[ -z "$HOLDER" ]] && HOLDER="the author"
  TMPL="${CLAUDE_PLUGIN_ROOT}/templates/LICENSE.MIT.tmpl"
  if [[ -r "$TMPL" ]]; then
    sed -e "s|{{year}}|${YEAR}|g" -e "s|{{holder}}|${HOLDER}|g" "$TMPL" > LICENSE
    ADDED+=("LICENSE (MIT — change if you prefer a different license)")
  fi
fi

# .gitignore — language-aware
if [[ ! -e .gitignore ]]; then
  STACK="$(sf_stack_detect | head -1)"
  GI_TMPL="${CLAUDE_PLUGIN_ROOT}/templates/gitignore/${STACK}.gitignore"
  if [[ -n "$STACK" && -r "$GI_TMPL" ]]; then
    cp "$GI_TMPL" .gitignore
    ADDED+=(".gitignore (${STACK})")
  else
    printf "%s\n" ".DS_Store" "Thumbs.db" ".vscode/" ".idea/" "*.swp" > .gitignore
    ADDED+=(".gitignore (minimal)")
  fi
fi

# README
if [[ ! -e README.md ]]; then
  PROJECT_NAME="$(basename "$REPO_ROOT")"
  STACK_DESC="$(sf_stack_detect | tr "\n" " " | sed "s/ \$//")"
  [[ -z "$STACK_DESC" ]] && STACK_DESC="(stack TBD)"
  TMPL="${CLAUDE_PLUGIN_ROOT}/templates/readme.md.tmpl"
  if [[ -r "$TMPL" ]]; then
    sed -e "s|{{project_name}}|${PROJECT_NAME}|g" \
        -e "s|{{one_line_description}}|TODO: one-line description|g" \
        -e "s|{{install_command}}|TODO|g" \
        -e "s|{{run_command}}|TODO|g" \
        -e "s|{{status_summary}}|Bootstrapped via scaffold; ${STACK_DESC}|g" \
        -e "s|{{license}}|MIT — see LICENSE|g" \
        "$TMPL" > README.md
    ADDED+=("README.md (skeleton)")
  fi
fi

# docs/ structure
for d in docs/adr docs/runbooks docs/slices; do
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d" && touch "$d/.gitkeep"
    ADDED+=("$d/")
  fi
done

# CLAUDE.md — generate if missing; on existing, leave alone with a note
if [[ -e CLAUDE.md ]]; then
  EXISTING_CLAUDE_MD="yes"
else
  EXISTING_CLAUDE_MD="no"
  if sf_generate_claude_md >/dev/null 2>&1; then
    ADDED+=("CLAUDE.md (generated from personal+project layers; gitignored on your setup)")
  fi
fi

# Marker (informational; plugin-data presence is the canonical signal)
mkdir -p .claude/scaffold && touch .claude/scaffold/.gitkeep

# Report
echo "scaffold-init complete"
echo "  project: $(basename "$REPO_ROOT")"
echo "  hash:    $(sf_repo_hash)"
echo "  branch:  $(sf_branch)"
echo "  stack:   $(sf_stack_detect | tr "\n" " " | sed "s/ \$//")"
echo "  llm:     $(sf_llm_detect)"
echo ""
if [[ ${#ADDED[@]} -gt 0 ]]; then
  echo "Added:"
  for f in "${ADDED[@]}"; do echo "  + $f"; done
else
  echo "(no files added — everything was already in place)"
fi
echo ""
if [[ "$EXISTING_CLAUDE_MD" == "yes" ]]; then
  echo "Note: CLAUDE.md already exists; not regenerated."
  echo "  Options:"
  echo "    - keep as-is (no action)"
  echo "    - import existing into project layer + regenerate (manual: copy contents into \$(sf_project_layer_path), then /scaffold-claude-md-rebuild)"
  echo "    - replace (back up CLAUDE.md.bak; run /scaffold-claude-md-rebuild after)"
fi
'
```

After running, summarize what changed in 1–2 sentences. If `LICENSE` was created with MIT and the user prefers a different license, offer to swap it. If `CLAUDE.md` already existed, walk the user through the import / keep / replace options interactively. Otherwise, suggest `/slice-new` to start the first slice or `/scaffold-audit` to gap-check the repo.
