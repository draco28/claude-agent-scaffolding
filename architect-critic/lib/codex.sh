#!/usr/bin/env bash
# lib/codex.sh — codex CLI dispatch (v0.2, codex 0.125+ semantics)
#
# Public API:
#   ac_codex_available()
#     Returns 0 if `codex` binary is on PATH, 1 otherwise.
#
#   ac_codex_run_audit <prompt> <output_dir> [--model NAME] [--timeout SECS]
#     Runs codex in v0.2 invocation shape (per SPEC §5.1 step 6):
#         codex exec --json \
#           --output-schema "${PLUGIN_DIR}/templates/output-schema.json" \
#           --output-last-message "${output_dir}/codex-audit-${REQ_ID}.json" \
#           --ignore-user-config --ignore-rules \
#           --skip-git-repo-check \
#           [-c model="<NAME>"] \
#           "<prompt>"
#     - Default timeout: 300s (5 min). Overridable via env
#       ARCHITECT_CRITIC_CODEX_TIMEOUT_S, or the `--timeout SECS` flag (flag wins).
#     - Parses the file written via --output-last-message; validates the JSON
#       has the required schema shape (challenges:[] with text/severity/rationale
#       on each item).
#     - On success: prints the parsed JSON to stdout, returns 0.
#     - On timeout: returns 124 (GNU timeout convention), logs warn,
#       prints empty result {"challenges":[]} to stdout.
#     - On non-zero codex exit, missing/invalid JSON, or schema violation:
#       returns 1, logs warn, prints {"challenges":[]} to stdout.
#
# Env overrides:
#   ARCHITECT_CRITIC_CODEX_TIMEOUT_S   integer seconds (default 300)
#   CLAUDE_PLUGIN_ROOT                 plugin root used to locate output-schema.json;
#                                      falls back to two-levels-up from this file.
#
# Differences from v0.1:
#   - `codex exec` subcommand with positional prompt (v0.1 piped via stdin).
#   - `--json` streaming output (machine-readable JSONL on stdout).
#   - `--output-schema` constrains the model's final answer to a JSON Schema.
#   - `--output-last-message` is the canonical source of the parsed result.
#   - `--ignore-user-config --ignore-rules --skip-git-repo-check` ensure a clean
#     run that doesn't pick up the user's ~/.codex/config.toml, AGENTS.md, or
#     git-repo nuances.
#   - No hardcoded `--model`; respects the user's codex default. The `--model`
#     flag translates to `-c model="<NAME>"`.
#
# Portability — timeout implementation:
#   GNU coreutils' timeout(1) is Linux-native; on macOS it may be installed as
#   gtimeout via Homebrew or absent. We use a portable bash-only background
#   subshell + kill pattern that works on bash 3.2+ (macOS) and bash 4+ (Linux).

# Ensure _helpers.sh is sourced (safe to double-source).
_AC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v ac_log_info >/dev/null 2>&1; then
  # shellcheck source=./_helpers.sh
  source "$_AC_LIB_DIR/_helpers.sh"
fi

# Default timeout in seconds (5 min per SPEC §5.1 step 6).
_AC_CODEX_DEFAULT_TIMEOUT_S=300

# ac_codex_available — returns 0 if codex binary found in PATH, 1 otherwise.
ac_codex_available() {
  command -v codex >/dev/null 2>&1
}

# _ac_codex_schema_path — locate templates/output-schema.json.
# Honors CLAUDE_PLUGIN_ROOT (set by Claude Code); falls back to two levels up
# from this file.
_ac_codex_schema_path() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/templates/output-schema.json" ]]; then
    printf '%s' "${CLAUDE_PLUGIN_ROOT}/templates/output-schema.json"
    return 0
  fi
  local guess
  guess="$(cd "$_AC_LIB_DIR/.." && pwd)/templates/output-schema.json"
  printf '%s' "$guess"
}

# _ac_codex_validate_json <file>
# Minimal jq-based schema validation: file is parseable JSON and contains
# challenges:[] array where each item has text/severity/rationale strings.
# Returns 0 if valid, 1 otherwise.
_ac_codex_validate_json() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  jq -e '
    type == "object" and
    (.challenges | type == "array") and
    (.challenges | all(
      type == "object" and
      (.text | type == "string") and
      (.severity | type == "string") and
      (.rationale | type == "string")
    ))
  ' < "$file" >/dev/null 2>&1
}

# _ac_codex_run_with_timeout <timeout_secs> <output_last_msg_file> <argv...>
# Runs `codex "$@"` in background with a portable timeout watcher.
# Returns the codex exit code on completion, or 124 if timed out.
_ac_codex_run_with_timeout() {
  local timeout_secs="$1"; shift
  local last_msg_file="$1"; shift   # reserved for future use / debug logs
  # Remaining "$@" is the codex argv.

  local codex_ec_file
  codex_ec_file="$(mktemp)" || return 1

  (
    codex "$@" >/dev/null 2>&1
    printf '%d' $? > "$codex_ec_file"
  ) &
  local codex_bgpid=$!

  (sleep "$timeout_secs") &
  local sleep_bgpid=$!

  local winner=""
  local poll_interval=0.2
  while true; do
    if ! kill -0 "$codex_bgpid" 2>/dev/null; then
      winner="codex"; break
    fi
    if ! kill -0 "$sleep_bgpid" 2>/dev/null; then
      winner="timeout"; break
    fi
    sleep "$poll_interval"
  done

  if [[ "$winner" == "codex" ]]; then
    kill "$sleep_bgpid" 2>/dev/null
    wait "$sleep_bgpid" 2>/dev/null
    local ec=0
    [[ -f "$codex_ec_file" ]] && ec="$(cat "$codex_ec_file" 2>/dev/null || echo 1)"
    rm -f "$codex_ec_file"
    return "$ec"
  else
    kill "$codex_bgpid" 2>/dev/null
    wait "$codex_bgpid" 2>/dev/null
    rm -f "$codex_ec_file"
    return 124
  fi
}

# ac_codex_run_audit <prompt> <output_dir> [--model NAME] [--timeout SECS]
ac_codex_run_audit() {
  local prompt="$1"; shift || true
  local output_dir="$1"; shift || true

  local model_override=""
  local timeout_override=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)   model_override="$2"; shift 2 ;;
      --timeout) timeout_override="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$prompt" || -z "$output_dir" ]]; then
    ac_log_warn "ac_codex_run_audit: prompt and output_dir are required"
    printf '%s' '{"challenges":[]}'
    return 1
  fi

  mkdir -p "$output_dir" 2>/dev/null || {
    ac_log_warn "ac_codex_run_audit: cannot create output_dir $output_dir"
    printf '%s' '{"challenges":[]}'
    return 1
  }

  if ! ac_codex_available; then
    ac_log_info "codex not available in PATH; skipping codex audit"
    printf '%s' '{"challenges":[]}'
    return 1
  fi

  local timeout_secs
  if [[ -n "$timeout_override" ]]; then
    timeout_secs="$timeout_override"
  else
    timeout_secs="${ARCHITECT_CRITIC_CODEX_TIMEOUT_S:-$_AC_CODEX_DEFAULT_TIMEOUT_S}"
  fi

  # REQ_ID: timestamp + 6-char random suffix; macOS bash 3.2 compatible.
  local req_id
  req_id="$(date +%s)-$(printf '%06x' $((RANDOM * RANDOM)) | head -c 6)"

  local last_msg_file="${output_dir}/codex-audit-${req_id}.json"
  local schema_path
  schema_path="$(_ac_codex_schema_path)"

  # Build argv. Note: model override uses two arg slots (-c, model="NAME").
  local -a argv
  argv=(
    exec
    --json
    --output-schema "$schema_path"
    --output-last-message "$last_msg_file"
    --ignore-user-config
    --ignore-rules
    --skip-git-repo-check
  )
  if [[ -n "$model_override" ]]; then
    argv+=( -c "model=\"${model_override}\"" )
  fi
  argv+=( "$prompt" )

  _ac_codex_run_with_timeout "$timeout_secs" "$last_msg_file" "${argv[@]}"
  local codex_ec=$?

  if [[ $codex_ec -eq 124 ]]; then
    ac_log_warn "codex timed out after ${timeout_secs}s; falling back to claude-only"
    # Surface partial result if codex wrote anything before being killed.
    if _ac_codex_validate_json "$last_msg_file"; then
      cat "$last_msg_file"
    else
      printf '%s' '{"challenges":[]}'
    fi
    return 124
  fi

  if [[ $codex_ec -ne 0 ]]; then
    ac_log_warn "codex exited with non-zero code ${codex_ec}; falling back to claude-only"
    printf '%s' '{"challenges":[]}'
    return 1
  fi

  if [[ ! -f "$last_msg_file" ]]; then
    ac_log_warn "codex produced no output file; falling back to claude-only"
    printf '%s' '{"challenges":[]}'
    return 1
  fi

  if ! _ac_codex_validate_json "$last_msg_file"; then
    ac_log_warn "codex output failed schema validation; falling back to claude-only"
    printf '%s' '{"challenges":[]}'
    return 1
  fi

  cat "$last_msg_file"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Back-compat shim — v0.1 callers (commands/critique.md) invoke ac_codex_audit.
# Will be removed once all callers migrate to ac_codex_run_audit.
# This shim writes the audit to a tmp dir and emits the JSON to stdout.
# ─────────────────────────────────────────────────────────────────────────────
ac_codex_audit() {
  local prompt_text="${1:-}"
  local tmp_dir
  tmp_dir="$(mktemp -d -t ac-codex-compat.XXXXXX)" || return 1
  # Translate legacy env var name if set without the _S suffix.
  if [[ -z "${ARCHITECT_CRITIC_CODEX_TIMEOUT_S:-}" && -n "${ARCHITECT_CRITIC_CODEX_TIMEOUT:-}" ]]; then
    export ARCHITECT_CRITIC_CODEX_TIMEOUT_S="$ARCHITECT_CRITIC_CODEX_TIMEOUT"
  fi
  local out ec
  out="$(ac_codex_run_audit "$prompt_text" "$tmp_dir")"
  ec=$?
  rm -rf "$tmp_dir"
  if [[ $ec -eq 0 ]]; then
    printf '%s' "$out"
    return 0
  fi
  return 1
}
