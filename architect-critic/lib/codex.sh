#!/usr/bin/env bash
# lib/codex.sh — codex CLI dispatch with JSON-strict output + portable timeout
#
# Public API:
#   ac_codex_available()              — exits 0 if codex is in PATH, 1 otherwise
#   ac_codex_audit <prompt_text>      — runs codex, jq-parses output; prints JSON to stdout
#                                       returns 0 on success, 1 on any failure
#
# Env overrides (document for README):
#   ARCHITECT_CRITIC_CODEX_TIMEOUT    — integer seconds to wait for codex (default: 180)
#
# Codex invocation:
#   The codex CLI accepts a prompt on stdin and the flag --output-format json
#   to return structured JSON. This is the most common JSON output flag across
#   codex CLI versions. If your codex version uses a different flag (e.g. --no-stream),
#   set ARCHITECT_CRITIC_CODEX_CMD override or update this file.
#
# Portability — timeout implementation:
#   GNU coreutils' timeout(1) is Linux-native; on macOS it may be installed as
#   gtimeout via Homebrew coreutils, or absent entirely. Rather than depending on
#   timeout(1), we use a portable bash-only background subshell + kill pattern:
#     1. Start the codex subprocess in background, redirect its stdout to a tmp file.
#     2. Start a background sleep for $timeout seconds.
#     3. Wait for whichever finishes first via bash job control.
#     4. If codex finishes first: kill the sleep watcher, return codex result.
#     5. If sleep finishes first: kill the codex subprocess, return 1.
#   This approach works on bash 3.2+ (macOS) and bash 4+ (Linux) without
#   any external timeout binary.

# Ensure _helpers.sh is sourced (safe to double-source).
_AC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v ac_log_info >/dev/null 2>&1; then
  # shellcheck source=./_helpers.sh
  source "$_AC_LIB_DIR/_helpers.sh"
fi

# Default timeout in seconds; overridable via env.
_AC_CODEX_DEFAULT_TIMEOUT=180

# ac_codex_available
# Returns 0 if codex binary is found in PATH, 1 otherwise.
ac_codex_available() {
  command -v codex >/dev/null 2>&1
}

# _ac_codex_run_with_timeout <timeout_secs> <prompt_text> <output_file>
# Portable background-subshell + kill timeout implementation.
# Runs: echo "$prompt" | codex --output-format json  (stdout → output_file)
# Returns 0 if codex finished within timeout, exit code of codex on success,
# or 124 if timed out (matching GNU timeout's exit code convention).
_ac_codex_run_with_timeout() {
  local timeout_secs="$1"
  local prompt_text="$2"
  local output_file="$3"

  # Start codex in background; capture its PID.
  # We need its exit code, so run via a subshell that writes exit code to a file.
  local codex_ec_file
  codex_ec_file="$(mktemp)"

  (
    printf '%s' "$prompt_text" | codex --output-format json > "$output_file" 2>&1
    printf '%d' $? > "$codex_ec_file"
  ) &
  local codex_bgpid=$!

  # Start a background sleep watcher.
  (sleep "$timeout_secs") &
  local sleep_bgpid=$!

  # Wait for whichever job finishes first.
  # We poll because bash's 'wait -n' requires bash 4.3+.
  local winner=""
  local poll_interval=0.2
  while true; do
    # Check if codex finished
    if ! kill -0 "$codex_bgpid" 2>/dev/null; then
      winner="codex"
      break
    fi
    # Check if sleep finished (timeout expired)
    if ! kill -0 "$sleep_bgpid" 2>/dev/null; then
      winner="timeout"
      break
    fi
    sleep "$poll_interval"
  done

  if [[ "$winner" == "codex" ]]; then
    # Codex finished; kill the sleep watcher.
    kill "$sleep_bgpid" 2>/dev/null
    wait "$sleep_bgpid" 2>/dev/null
    # Read codex exit code.
    local ec=0
    if [[ -f "$codex_ec_file" ]]; then
      ec="$(cat "$codex_ec_file" 2>/dev/null || echo 1)"
    fi
    rm -f "$codex_ec_file"
    return "$ec"
  else
    # Timeout: kill codex.
    kill "$codex_bgpid" 2>/dev/null
    wait "$codex_bgpid" 2>/dev/null
    rm -f "$codex_ec_file"
    return 124
  fi
}

# ac_codex_audit <prompt_text>
# Pipes prompt_text to codex CLI, jq-parses stdout.
# On success: prints parsed JSON object to stdout, returns 0.
# On any failure (absent / timeout / non-zero exit / non-JSON): returns 1,
#   logs appropriate warning/info to stderr, prints nothing to stdout.
#
# Failures handled:
#   - codex not in PATH        → ac_log_info "codex not available"; return 1
#   - codex exits non-zero     → ac_log_warn "codex exited with code N"; return 1
#   - timeout expires          → ac_log_warn "codex timed out after Ns"; return 1
#   - output is not valid JSON → ac_log_warn "codex output is not valid JSON"; return 1
ac_codex_audit() {
  local prompt_text="$1"
  local timeout_secs="${ARCHITECT_CRITIC_CODEX_TIMEOUT:-$_AC_CODEX_DEFAULT_TIMEOUT}"

  # Check availability first.
  if ! ac_codex_available; then
    ac_log_info "codex not available in PATH; skipping codex audit"
    return 1
  fi

  # Create temp file for codex stdout.
  local output_file
  output_file="$(mktemp)" || {
    ac_log_warn "could not create temp file for codex output"
    return 1
  }

  # Run codex with portable timeout.
  _ac_codex_run_with_timeout "$timeout_secs" "$prompt_text" "$output_file"
  local codex_ec=$?

  if [[ $codex_ec -eq 124 ]]; then
    rm -f "$output_file"
    ac_log_warn "codex timed out after ${timeout_secs}s; falling back to claude-only"
    return 1
  fi

  if [[ $codex_ec -ne 0 ]]; then
    rm -f "$output_file"
    ac_log_warn "codex exited with non-zero code ${codex_ec}; falling back to claude-only"
    return 1
  fi

  # Attempt jq parse of output.
  local parsed_json
  parsed_json="$(jq '.' < "$output_file" 2>/dev/null)"
  local jq_ec=$?

  rm -f "$output_file"

  if [[ $jq_ec -ne 0 ]]; then
    ac_log_warn "codex output is not valid JSON; falling back to claude-only"
    return 1
  fi

  printf '%s' "$parsed_json"
  return 0
}
