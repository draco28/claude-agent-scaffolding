---
description: Derive .claude/memory-bank/ (11 files) and CLAUDE.md from MASTER-SPEC.md. Deterministic and idempotent. Use --force to overwrite live files.
argument-hint: "[--force]"
allowed-tools: Bash(bash:*)
---

Validate MASTER-SPEC.md, then run the deterministic derivation pipeline.

```bash
bash -c '
set -u
source "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/parser.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/memory-bank.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "scaffold-onboard: not inside a git repo."
  exit 1
fi
cd "$REPO_ROOT"

FORCE=""
if [[ "${1:-}" == "--force" ]]; then
  FORCE="--force"
  echo "scaffold-project: --force passed; live files WILL be overwritten."
  echo "Continue? Type yes to proceed: "
  read -r REPLY
  [[ "$REPLY" == "yes" ]] || { echo "Cancelled."; exit 0; }
fi

if ! sf_spec_validate ./MASTER-SPEC.md; then
  exit 1
fi

echo "scaffold-project: deriving memory-bank..."
sf_memory_bank_derive $FORCE
echo "scaffold-project: generating CLAUDE.md..."
sf_claude_md_generate
echo "scaffold-project: writing .claude/settings.json..."
sf_claude_settings_generate

echo ""
echo "scaffold-project: done."
echo "  memory-bank: .claude/memory-bank/ (11 files)"
echo "  router:      CLAUDE.md"
echo "  settings:    .claude/settings.json"
echo ""
echo "Next: /scaffold-docs (governance docs) or /slice-new (start first slice via the scaffold plugin)."
' -- "$1"
```

After running, summarize in 1-2 sentences: which files were created vs preserved. If `--force` was passed, note that live files were reset. Otherwise mention that `05-active-context.md` and `06-progress.md` were preserved across the run.
