---
description: Run an architect-critic audit on a spec or plan with claude-self-audit + (optionally) codex fresh-frame review
allowed-tools: Bash, Read, Edit, SlashCommand
---

# /critique

Run the envelope synthesis + validation block, then proceed to the audit pipeline.

```bash
bash -c '
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"

source "${PLUGIN_ROOT}/lib/_helpers.sh"
source "${PLUGIN_ROOT}/lib/state.sh"
source "${PLUGIN_ROOT}/lib/principles.sh"
source "${PLUGIN_ROOT}/lib/inbox.sh"

# ── Argument parsing ────────────────────────────────────────────────────────
# Positional: $1 = request_id (optional, programmatic mode)
# Named: --phase N, --depth D, --spec PATH

REQUEST_ID=""
PHASE_ARG=""
DEPTH_ARG=""
SPEC_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)   PHASE_ARG="$2";  shift 2 ;;
    --depth)   DEPTH_ARG="$2";  shift 2 ;;
    --spec)    SPEC_ARG="$2";   shift 2 ;;
    --phase=*) PHASE_ARG="${1#--phase=}"; shift ;;
    --depth=*) DEPTH_ARG="${1#--depth=}"; shift ;;
    --spec=*)  SPEC_ARG="${1#--spec=}";   shift ;;
    crit-*)    REQUEST_ID="$1";  shift ;;
    *)         ac_log_warn "unknown arg: $1"; shift ;;
  esac
done

INBOX_DIR="$(ac_inbox_dir)"

# ── Mode detection ───────────────────────────────────────────────────────────
# Programmatic: request_id given AND inbox file exists
# Manual:       synthesize envelope from defaults

MODE="manual"
if [[ -n "$REQUEST_ID" && -f "${INBOX_DIR}/${REQUEST_ID}.json" ]]; then
  MODE="programmatic"
fi

ac_log_info "mode=${MODE}"

# ── Data dir bootstrap ───────────────────────────────────────────────────────
DATA_DIR="$(ac_data_dir)"
mkdir -p "${DATA_DIR}/inbox" "${DATA_DIR}/outbox"

ac_state_init

# ── Resolve envelope ─────────────────────────────────────────────────────────
if [[ "$MODE" == "programmatic" ]]; then
  ENVELOPE="$(ac_inbox_read "$REQUEST_ID")" || exit 1

else
  # Manual mode: synthesize envelope from defaults, apply arg overrides.

  # 1. Locate MASTER-SPEC.md
  if [[ -n "$SPEC_ARG" ]]; then
    SPEC_PATH="$SPEC_ARG"
  else
    SPEC_PATH="$(pwd)/MASTER-SPEC.md"
  fi

  if [[ ! -r "$SPEC_PATH" ]]; then
    echo "architect-critic: No MASTER-SPEC.md found at ${SPEC_PATH}." >&2
    echo "  Pass --spec PATH or run /onboard first." >&2
    exit 1
  fi

  # 2. Principles path
  PRINCIPLES_PATH="${DATA_DIR}/principles.md"

  # 3. Infer project_class from .onboarding-state.json (or "unknown")
  PROJECT_CLASS="unknown"
  STATE_LINK="$(pwd)/.claude/.onboarding-state.json"
  if [[ -r "$STATE_LINK" ]]; then
    PC="$(jq -r ".answers[\"1.3.1\"] // empty" "$STATE_LINK" 2>/dev/null || true)"
    [[ -n "$PC" ]] && PROJECT_CLASS="$PC"
  fi

  # 4. Defaults
  DEPTH="close"
  [[ -n "$DEPTH_ARG" ]] && DEPTH="$DEPTH_ARG"

  # Accumulated phases default: 1..10
  ACC_PHASES="[1,2,3,4,5,6,7,8,9,10]"

  # Target type + phase
  if [[ -n "$PHASE_ARG" ]]; then
    TARGET_TYPE="master-spec-phase"
    PHASE_NUM="$PHASE_ARG"
    # phase implies premise-audit depth unless overridden
    [[ -z "$DEPTH_ARG" ]] && DEPTH="premise-audit"
  else
    TARGET_TYPE="master-spec-full"
    PHASE_NUM="null"
  fi

  # 5. Generate request_id
  ENTROPY="$(LC_ALL=C tr -dc "a-z0-9" < /dev/urandom 2>/dev/null | head -c6 || echo "xxxxxx")"
  ISO_NOW="$(date -u +"%Y%m%dT%H%M%SZ")"
  if [[ -n "$PHASE_ARG" ]]; then
    REQUEST_ID="crit-${ISO_NOW}-phase${PHASE_NUM}-${ENTROPY}"
  else
    REQUEST_ID="crit-${ISO_NOW}-close-${ENTROPY}"
  fi

  # 6. Build envelope JSON
  INBOX_PATH="${INBOX_DIR}/${REQUEST_ID}.json"

  if [[ "$TARGET_TYPE" == "master-spec-phase" ]]; then
    TARGET_JSON="$(jq -n \
      --arg type "$TARGET_TYPE" \
      --arg path "$SPEC_PATH" \
      --argjson phase_id "$PHASE_NUM" \
      "{type: \$type, path: \$path, phase_id: \$phase_id}")"
  else
    TARGET_JSON="$(jq -n \
      --arg type "$TARGET_TYPE" \
      --arg path "$SPEC_PATH" \
      "{type: \$type, path: \$path}")"
  fi

  ENVELOPE="$(jq -n \
    --arg request_id "$REQUEST_ID" \
    --arg depth "$DEPTH" \
    --argjson adversaries "[\"claude\",\"codex\"]" \
    --argjson target "$TARGET_JSON" \
    --arg principles "$PRINCIPLES_PATH" \
    --argjson accumulated_phases "$ACC_PHASES" \
    --argjson concession_threshold 4 \
    --arg project_class "$PROJECT_CLASS" \
    "{
       request_id: \$request_id,
       depth: \$depth,
       adversaries: \$adversaries,
       target: \$target,
       sources: {
         principles: \$principles,
         accumulated_phases: \$accumulated_phases
       },
       concession_threshold: \$concession_threshold,
       project_class: \$project_class
     }")"

  # 7. Write envelope to inbox (atomic via tmp+mv)
  TMP_INBOX="$(mktemp "${INBOX_PATH}.XXXXXX")"
  printf "%s\n" "$ENVELOPE" > "$TMP_INBOX"
  mv "$TMP_INBOX" "$INBOX_PATH"
  ac_log_info "envelope written to inbox: ${INBOX_PATH}"
fi

# ── Validate envelope ────────────────────────────────────────────────────────
if ! ac_inbox_validate "$ENVELOPE"; then
  echo "architect-critic: envelope validation failed. Fix the envelope and retry." >&2
  exit 1
fi

ac_log_info "envelope validated OK (request_id=${REQUEST_ID})"

echo ""
echo "=== architect-critic: envelope synthesis complete ==="
echo "  request_id : ${REQUEST_ID}"
echo "  mode       : ${MODE}"
DEPTH_DISP="$(printf "%s" "$ENVELOPE" | jq -r ".depth")"
echo "  depth      : ${DEPTH_DISP}"
ADV_DISP="$(printf "%s" "$ENVELOPE" | jq -r ".adversaries | join(\", \")")"
echo "  adversaries: ${ADV_DISP}"
TPATH_DISP="$(printf "%s" "$ENVELOPE" | jq -r ".target.path")"
echo "  spec       : ${TPATH_DISP}"
echo ""

# ── Phase D stub ─────────────────────────────────────────────────────────────
echo "Phase D will run the audit pipeline here"
echo "  (claude-self-audit → codex dispatch → consolidator → outbox → rebuttal cycle → promotion → cost line)"
'
```

After the bash block completes:

- If the envelope synthesized and validated successfully, Phase D will continue from here with the full audit pipeline.
- On validation failure the block already exited non-zero; do not proceed.
