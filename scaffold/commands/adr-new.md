---
description: Create a new Architecture Decision Record. Auto-numbers (4-digit zero-padded), slugs the title, writes docs/adr/NNNN-<slug>.md from the Nygard template. The agent then walks the user through filling Context / Decision / Consequences.
argument-hint: "<title>"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"

TITLE="${ARGUMENTS:-}"
[[ -z "$TITLE" ]] && TITLE="$*"

if [[ -z "$TITLE" ]]; then
  echo "Usage: /adr-new <title>"
  echo "Example: /adr-new \"choose Postgres over MySQL\""
  exit 1
fi

if ! sf_is_managed; then
  echo "scaffold: this branch is not initialized. Run /scaffold-init first."
  exit 1
fi

# Increment counter, fetch new number
sf_state_apply ".adr_counter += 1"
N="$(sf_state_get adr_counter)"
NN="$(printf "%04d" "$N")"
SLUG="$(sf_slug "$TITLE")"

REPO_ROOT="$(sf_repo_root)"
ADR_DIR="${REPO_ROOT}/docs/adr"
mkdir -p "$ADR_DIR"

OUT_PATH="${ADR_DIR}/${NN}-${SLUG}.md"
TMPL="${CLAUDE_PLUGIN_ROOT}/templates/adr.md.tmpl"
DATE="$(date -u +%Y-%m-%d)"

if [[ -r "$TMPL" ]]; then
  sed -e "s|{{number}}|${N}|g" \
      -e "s|{{title}}|${TITLE}|g" \
      -e "s|{{date}}|${DATE}|g" \
      "$TMPL" > "$OUT_PATH"
else
  {
    echo "# ${N}. ${TITLE}"
    echo ""
    echo "**Date:** ${DATE}"
    echo "**Status:** Proposed"
    echo ""
    echo "## Context"
    echo "TODO"
    echo ""
    echo "## Decision"
    echo "TODO"
    echo ""
    echo "## Consequences"
    echo "TODO"
  } > "$OUT_PATH"
fi

REL_PATH="${OUT_PATH#${REPO_ROOT}/}"
echo "Created ADR: ${REL_PATH}"
echo "  number: ${N} (zero-padded: ${NN})"
echo "  title:  ${TITLE}"
echo "  status: Proposed (update once accepted)"
echo ""
echo "Next: open the file and fill in Context / Decision / Consequences."
' "$ARGUMENTS"
```

After running, open the new ADR file with the Read tool and walk the user through filling sections:

- **Context**: what forces are at play (technical, business, team)? What's the situation that requires a decision?
- **Decision**: what was chosen, in active voice ("we will use Postgres" not "Postgres should be used")
- **Consequences**: positive, negative, neutral. Be specific — "we lose easy local-MySQL setup" beats "trade-offs exist."
- **Alternatives considered**: list 2–3 with the reason each was rejected. Future readers learn most from the rejected paths.

Once the file is complete, suggest changing `Status: Proposed` to `Status: Accepted` and committing it. ADR numbering is per-repo (driven by `state.adr_counter`), so each `/adr-new` produces a stable next number even across worktrees of the same repo.
