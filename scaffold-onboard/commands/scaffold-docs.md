---
description: Derive governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001) from MASTER-SPEC.md. --full adds 9 more; --regenerate overwrites existing.
argument-hint: "[--full] [--regenerate]"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set -u
source "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/parser.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/docs.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "scaffold-onboard: not inside a git repo."
  exit 1
fi
cd "$REPO_ROOT"

if ! sf_spec_validate ./MASTER-SPEC.md; then
  exit 1
fi

FLAGS=()
[[ "$1" == "--full" || "$2" == "--full" ]] && FLAGS+=("--full")
[[ "$1" == "--regenerate" || "$2" == "--regenerate" ]] && FLAGS+=("--regenerate")

echo "scaffold-docs: deriving governance docs (flags: ${FLAGS[*]:-default})..."
sf_docs_derive "${FLAGS[@]}"

echo ""
echo "scaffold-docs: done."
echo ""
ls -1 docs/ docs/adr/ 2>/dev/null | head -30
' -- "${1:-}" "${2:-}"
```

After running, summarize: how many docs were written, how many preserved, whether LLM-gated docs were generated or skipped.
