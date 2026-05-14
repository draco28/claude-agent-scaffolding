---
description: Render the merged principles set from user-global, project context, patterns, and governance sources
allowed-tools: Bash, Read
---

# /principles-list

Render the merged principles set from all four sources (user-global, project context, patterns, governance).

```bash
bash -c '
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"

source "${PLUGIN_ROOT}/lib/_helpers.sh"
source "${PLUGIN_ROOT}/lib/principles.sh"
source "${PLUGIN_ROOT}/lib/state.sh"

# ── Bootstrap ──────────────────────────────────────────────────────────────
ac_state_init
ac_principles_seed

# ── Locate spec file ──────────────────────────────────────────────────────────
SPEC_PATH=""
if [[ -f "./MASTER-SPEC.md" ]]; then
  SPEC_PATH="./MASTER-SPEC.md"
fi

# Infer phase_ids from project (if onboarded, use 1..10; else empty)
PHASE_IDS="1,2,3,4,5,6,7,8,9,10"

# ── Compose principles ───────────────────────────────────────────────────────
echo "=== Merged principles set ==="
echo ""

COMPOSED="$(ac_principles_compose "$SPEC_PATH" "$PHASE_IDS")"

if [[ -z "$COMPOSED" ]]; then
  echo "(empty)"
else
  printf "%s\n" "$COMPOSED"
fi
'
```
