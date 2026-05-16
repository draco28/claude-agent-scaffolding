---
description: Manually promote a principle to your user-global or project-scoped principles file
argument-hint: "\"<principle text>\" [--scope user|project]"
allowed-tools: Bash, Read, Edit
---

# /promote-principle

Promote a principle text to the user-global or project-scoped principles file, with atomic append and state.json recording.

```bash
# $ARGUMENTS bridge — Claude Code substitutes $N at template time, so we parse
# from the raw arg string instead of bash positionals (v0.1.1 bug fix).
RAW_ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"

source "${PLUGIN_ROOT}/lib/_helpers.sh"
source "${PLUGIN_ROOT}/lib/state.sh"

# ── Argument parsing ────────────────────────────────────────────────────────
RAW_ARGS="${RAW_ARGS_FROM_CLAUDE:-}"

# Scope: extract --scope value (default user)
SCOPE="$(printf "%s" "$RAW_ARGS" | sed -nE "s|.*--scope[= ]+([a-zA-Z]+).*|\\1|p" | head -1)"
[[ -z "$SCOPE" ]] && SCOPE="user"

# Text: strip the --scope flag+value, take the remainder (first quoted segment
# or everything that is not a flag). User typically types: /promote-principle "..." --scope X
TEXT="$(printf "%s" "$RAW_ARGS" | sed -E "s|--scope[= ]+[a-zA-Z]+||" | sed -E "s|^[[:space:]]+||; s|[[:space:]]+$||")"

# Strip outer quotes if present
TEXT="${TEXT#\"}"
TEXT="${TEXT%\"}"

# ── Validation ────────────────────────────────────────────────────────────
if [[ -z "$TEXT" ]]; then
  ac_log_error "principle text required"
  exit 1
fi

# Check single-line (no newlines). Use wc -l rather than $'\n' ANSI-C
# quoting, which would break the outer bash -c single-quoting (v0.1.2 fix).
if [[ "$(printf "%s" "$TEXT" | wc -l | tr -d " ")" != "0" ]]; then
  ac_log_error "principle must be a single line"
  exit 1
fi

# Check length <= 200 chars
if [[ ${#TEXT} -gt 200 ]]; then
  ac_log_error "principle must be <= 200 characters (got ${#TEXT})"
  exit 1
fi

# Check scope
if [[ "$SCOPE" != "user" && "$SCOPE" != "project" ]]; then
  ac_log_error "scope must be user or project (got $SCOPE)"
  exit 1
fi

# ── Determine target file ──────────────────────────────────────────────────
TARGET_FILE=""

if [[ "$SCOPE" == "user" ]]; then
  DATA_DIR="$(ac_data_dir)"
  mkdir -p "$DATA_DIR"
  TARGET_FILE="${DATA_DIR}/principles.md"
else  # project scope
  # Check if .claude/memory-bank exists
  if [[ ! -d ".claude/memory-bank" ]]; then
    ac_log_error "project scope requires .claude/memory-bank directory. Run /scaffold-project first or use --scope user"
    exit 1
  fi
  TARGET_FILE=".claude/memory-bank/03-code-patterns.md"
fi

# ── Atomic append ──────────────────────────────────────────────────────────
LOCK_FILE="${TARGET_FILE}.lock"
PROMO_DATE="$(date -u +"%Y-%m-%d")"
ANNOTATION=" [promoted $PROMO_DATE source:manual]"

ac_lock_acquire "$LOCK_FILE" || {
  ac_log_error "could not acquire lock on $TARGET_FILE"
  exit 1
}

# Create file if missing (for project scope)
if [[ ! -f "$TARGET_FILE" ]]; then
  mkdir -p "$(dirname "$TARGET_FILE")"
  touch "$TARGET_FILE"
fi

# Append principle with annotation
printf "%s%s\n" "$TEXT" "$ANNOTATION" >> "$TARGET_FILE"
APPEND_RC=$?

ac_lock_release "$LOCK_FILE"

if [[ $APPEND_RC -ne 0 ]]; then
  ac_log_error "failed to append principle to $TARGET_FILE"
  exit 1
fi

# ── Record in state.json ───────────────────────────────────────────────────
ac_state_init

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

ac_lock_acquire "$(ac_data_dir)/state.lock" || {
  ac_log_warn "could not acquire state.lock to record promotion"
  # Append already succeeded, so continue
}

# Append to principle_promotions array in state.json
STATE_FILE="$(ac_state_path)"
ac_guarded_jq_write "$STATE_FILE" \
  --arg ts "$TIMESTAMP" \
  --arg src "manual" \
  --arg txt "$TEXT" \
  --arg scp "$SCOPE" \
  ".principle_promotions += [{\"timestamp\":\$ts,\"source\":\$src,\"text\":\$txt,\"scope\":\$scp}]" \
  "$STATE_FILE" || ac_log_warn "could not record promotion in state.json"

ac_lock_release "$(ac_data_dir)/state.lock"

# ── Confirmation ───────────────────────────────────────────────────────────
echo "✓ Principle promoted to $SCOPE scope"
echo "  Text: $TEXT"
echo "  File: $TARGET_FILE"
'
```
