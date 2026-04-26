---
description: Create a new runbook for a failure mode. Slugs the name, writes docs/runbooks/<slug>.md from the SRE-style template. The agent then walks the user through filling symptoms / diagnosis / remediation.
argument-hint: "<failure-mode-name>"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"

NAME="${ARGUMENTS:-}"
[[ -z "$NAME" ]] && NAME="$*"

if [[ -z "$NAME" ]]; then
  echo "Usage: /runbook-new <failure-mode-name>"
  echo "Example: /runbook-new \"high-latency-writes\""
  exit 1
fi

REPO_ROOT="$(sf_repo_root)"
RUN_DIR="${REPO_ROOT}/docs/runbooks"
mkdir -p "$RUN_DIR"

SLUG="$(sf_slug "$NAME")"
OUT_PATH="${RUN_DIR}/${SLUG}.md"

if [[ -e "$OUT_PATH" ]]; then
  echo "scaffold: runbook already exists at ${OUT_PATH#${REPO_ROOT}/}"
  echo "  edit the existing file directly, or pick a different name."
  exit 1
fi

TMPL="${CLAUDE_PLUGIN_ROOT}/templates/runbook.md.tmpl"
DATE="$(date -u +%Y-%m-%d)"

if [[ -r "$TMPL" ]]; then
  sed -e "s|{{failure_mode}}|${NAME}|g" \
      -e "s|{{date}}|${DATE}|g" \
      "$TMPL" > "$OUT_PATH"
else
  {
    echo "# Runbook: ${NAME}"
    echo ""
    echo "**Last reviewed:** ${DATE}"
    echo ""
    echo "## Symptoms"
    echo "TODO"
    echo ""
    echo "## Diagnosis"
    echo "TODO"
    echo ""
    echo "## Remediation"
    echo "TODO"
  } > "$OUT_PATH"
fi

REL_PATH="${OUT_PATH#${REPO_ROOT}/}"
echo "Created runbook: ${REL_PATH}"
echo "  failure mode: ${NAME}"
echo ""
echo "Next: fill in Symptoms, Dashboards, Diagnosis, Remediation."
' "$ARGUMENTS"
```

After running, open the runbook file with the Read tool and walk the user through:

- **Symptoms**: how does an on-call engineer recognize this failure? Specific signal: an alert name, a log pattern, a dashboard going red, user reports of a particular error.
- **Dashboards / signals**: links to the actual alerts, dashboards, log queries that fire for this failure.
- **Diagnosis**: step-by-step to confirm it's *this* failure (not something adjacent). Each step is a command or query the on-call runs.
- **Remediation**: the fix. Numbered steps. Include rollback if remediation might fail. Time-bound: "if not effective within X minutes, escalate to Y."

A runbook is best written *while you remember* an incident — `/runbook-new` is most valuable shortly after the next time this thing breaks. If you're writing it preemptively, leave realistic placeholders rather than perfect prose; the next incident will fill them in.
