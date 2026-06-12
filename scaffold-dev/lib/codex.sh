#!/usr/bin/env bash
# scaffold-dev/lib/codex.sh
# SS-5 — optional Codex implementer backend. Mechanical adapter around the
# externally-installed codex-plugin-cc companion (`codex-companion.mjs`). The
# agent owns every semantic judgment (prompt authoring, clarification decisions,
# report judgment); these helpers are real-command-execution legs only:
# resolve-a-path, run-a-command, parse-json, check-exit, compare-HEAD.
#
# LOAD-BEARING (SS-4 lesson): bin/sd runs `set -euo pipefail` and dispatches
# these via `sd codex_<verb>`. Every external command is captured set-e-safe
# (`if out="$(cmd)"; then rc=0; else rc=$?; fi`) and the wait loop avoids bare
# `(( … ))` (which returns non-zero — and aborts under set -e — when the
# expression evaluates to 0). Invoke from skill prose as `sd codex_<verb> …`.
#
# State coupling (companion keys job state by sha256(git-toplevel) under
# $CLAUDE_PLUGIN_DATA): every helper `cd`s into <worktree> before any node call,
# and the caller must keep $CLAUDE_PLUGIN_DATA stable across dispatch + polls.
#
# Overrides (testing):
#   SCAFFOLD_CODEX_COMPANION   absolute path to a companion .mjs (wins outright)
#   SCAFFOLD_CODEX_CACHE_DIRS  colon-separated plugin-cache roots to glob
#   CODEX_HOME                 trusted-projects config root (default ~/.codex)

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# Default plugin-cache roots searched for the companion when no override is set.
_sd_codex_default_cache_dirs() {
  echo "${HOME}/.claude/plugins/cache"
  echo "${HOME}/.claude/plugins/marketplaces"
  echo "${CODEX_HOME:-$HOME/.codex}/plugins/cache"
}

# sd_codex_resolve_companion
# Echoes the absolute path to codex-companion.mjs + rc=0, or fails loud (rc=1)
# with remediation. SCAFFOLD_CODEX_COMPANION (if set) wins; else glob the newest
# version across the cache roots (cache layout codex/<version>/scripts + the
# marketplace layout plugins/codex/scripts), newest by `sort -V`.
sd_codex_resolve_companion() {
  if [[ -n "${SCAFFOLD_CODEX_COMPANION:-}" ]]; then
    if [[ -f "$SCAFFOLD_CODEX_COMPANION" ]]; then
      echo "$SCAFFOLD_CODEX_COMPANION"
      return 0
    fi
    sd_log_error "sd_codex_resolve_companion: SCAFFOLD_CODEX_COMPANION points at a missing file: $SCAFFOLD_CODEX_COMPANION"
    return 1
  fi

  local roots=()
  if [[ -n "${SCAFFOLD_CODEX_CACHE_DIRS:-}" ]]; then
    local IFS=":"
    for d in $SCAFFOLD_CODEX_CACHE_DIRS; do roots+=("$d"); done
  else
    while IFS= read -r d; do roots+=("$d"); done < <(_sd_codex_default_cache_dirs)
  fi

  local cache_matches=() mkt_matches=() root m
  for root in "${roots[@]+"${roots[@]}"}"; do
    [[ -z "$root" || ! -d "$root" ]] && continue
    # Cache layout: <root>/openai-codex/codex/<version>/scripts/codex-companion.mjs
    for m in "$root"/openai-codex/codex/*/scripts/codex-companion.mjs; do
      [[ -f "$m" ]] && cache_matches+=("$m")
    done
    # Marketplace layout: <root>/openai-codex/plugins/codex/scripts/codex-companion.mjs
    for m in "$root"/openai-codex/plugins/codex/scripts/codex-companion.mjs; do
      [[ -f "$m" ]] && mkt_matches+=("$m")
    done
  done

  # Prefer the cache layout's NEWEST version. Sort by the <version> segment ALONE
  # (extracted from the path) so the cache/marketplace path prefix can't defeat the
  # version order — `sort -V` on full paths would pick "marketplaces" over "cache"
  # lexically regardless of version.
  if [[ "${#cache_matches[@]}" -gt 0 ]]; then
    local best
    best="$(for m in "${cache_matches[@]}"; do
      v="$(printf '%s' "$m" | sed -nE 's#.*/openai-codex/codex/([^/]+)/scripts/codex-companion\.mjs$#\1#p')"
      printf '%s\t%s\n' "$v" "$m"
    done | sort -V | tail -n1 | cut -f2-)"
    if [[ -n "$best" ]]; then
      echo "$best"
      return 0
    fi
  fi

  # Fall back to the marketplace (unversioned) layout only when no cache copy exists.
  if [[ "${#mkt_matches[@]}" -gt 0 ]]; then
    echo "${mkt_matches[0]}"
    return 0
  fi

  sd_log_error "sd_codex_resolve_companion: codex-plugin-cc companion not found. Install OpenAI's codex plugin (/plugin install codex from the openai-codex marketplace), or set SCAFFOLD_CODEX_COMPANION to the absolute codex-companion.mjs path."
  return 1
}

# _sd_codex_worktree_trusted <worktree>
# 0 = under a trusted project root; 1 = positively outside all trusted roots
# (config present with ≥1 trusted project); 2 = undetermined (no config / none).
_sd_codex_worktree_trusted() {
  local wt="$1"
  local config="${CODEX_HOME:-$HOME/.codex}/config.toml"
  [[ -f "$config" ]] || return 2

  local wt_real
  wt_real="$(cd "$wt" 2>/dev/null && pwd -P)" || wt_real="$wt"

  local trusted
  trusted="$(awk '
    /^\[projects\."/ { line=$0; sub(/^\[projects\."/, "", line); sub(/"\].*$/, "", line); cur=line; next }
    /^\[/ { cur=""; next }
    /trust_level[[:space:]]*=[[:space:]]*"trusted"/ { if (cur!="") print cur }
  ' "$config")"
  [[ -z "$trusted" ]] && return 2

  local p
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if [[ "$wt_real" == "$p" || "$wt_real" == "$p"/* ]]; then
      return 0
    fi
  done <<<"$trusted"
  return 1
}

# sd_codex_preflight <worktree>
# Hard gate before dispatch. rc=0 ready; rc=1 unavailable (with remediation).
# Hard-fails on: companion missing, setup not-ready (codex uninstalled / not
# authed), or worktree positively outside all trusted roots. Worktree-trust that
# can't be determined (no codex config) warns and proceeds (approval=never path).
sd_codex_preflight() {
  local wt="${1:-}"
  if [[ -z "$wt" ]]; then
    sd_log_error "sd_codex_preflight: worktree path required"
    return 1
  fi

  local companion
  if ! companion="$(sd_codex_resolve_companion)"; then
    return 1
  fi

  local out
  if out="$(cd "$wt" && node "$companion" setup --json 2>&1)"; then :; else
    sd_log_error "sd_codex_preflight: \`setup\` failed: $out"
    return 1
  fi

  local ready
  ready="$(printf '%s' "$out" | jq -r '.ready // false' 2>/dev/null || echo false)"
  if [[ "$ready" != "true" ]]; then
    local codex_ok auth_ok
    codex_ok="$(printf '%s' "$out" | jq -r '.codex.available // false' 2>/dev/null || echo false)"
    auth_ok="$(printf '%s' "$out" | jq -r '.auth.loggedIn // false' 2>/dev/null || echo false)"
    if [[ "$codex_ok" != "true" ]]; then
      sd_log_error "sd_codex_preflight: Codex CLI not available. Install it (https://github.com/openai/codex) and ensure \`codex --version\` works."
    elif [[ "$auth_ok" != "true" ]]; then
      sd_log_error "sd_codex_preflight: Codex not authenticated. Run \`codex login\` (or \`codex login --with-api-key\`), then retry."
    else
      sd_log_error "sd_codex_preflight: Codex not ready: $out"
    fi
    return 1
  fi

  local trust_rc=0
  if _sd_codex_worktree_trusted "$wt"; then trust_rc=0; else trust_rc=$?; fi
  case "$trust_rc" in
    1)
      sd_log_error "sd_codex_preflight: worktree is outside every Codex-trusted project root: $wt. Add it to ~/.codex/config.toml ([projects.\"<path>\"] trust_level = \"trusted\") or place worktrees under a trusted root."
      return 1
      ;;
    2)
      sd_log_warn "sd_codex_preflight: could not verify worktree trust (no ~/.codex/config.toml projects); proceeding under approval=never. If Codex stalls on a trust prompt, add $wt to trusted projects."
      ;;
  esac

  return 0
}

# sd_codex_dispatch <worktree> <prompt-file> [--model M] [--effort E]
# Launches a background, write-capable Codex task carrying the prompt-file.
# Echoes the job-id + rc=0, or rc=1 on failure.
sd_codex_dispatch() {
  local wt="${1:-}" pf="${2:-}"
  shift 2 2>/dev/null || true
  if [[ -z "$wt" || -z "$pf" ]]; then
    sd_log_error "sd_codex_dispatch: usage: sd codex_dispatch <worktree> <prompt-file> [--model M] [--effort E]"
    return 1
  fi
  if [[ ! -f "$pf" ]]; then
    sd_log_error "sd_codex_dispatch: prompt-file not found: $pf"
    return 1
  fi
  # Absolutize the prompt-file (the companion resolves it relative to its cwd).
  local pf_abs
  pf_abs="$(cd "$(dirname "$pf")" && pwd)/$(basename "$pf")"

  local model="" effort=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)  model="${2:-}"; shift 2 ;;
      --effort) effort="${2:-}"; shift 2 ;;
      *) sd_log_error "sd_codex_dispatch: unknown arg: $1"; return 1 ;;
    esac
  done

  local companion
  if ! companion="$(sd_codex_resolve_companion)"; then
    return 1
  fi

  local args=(task --background --write --prompt-file "$pf_abs" --json)
  [[ -n "$model" ]]  && args+=(--model "$model")
  [[ -n "$effort" ]] && args+=(--effort "$effort")

  local out
  if out="$(cd "$wt" && node "$companion" "${args[@]}" 2>&1)"; then :; else
    sd_log_error "sd_codex_dispatch: launch failed: $out"
    return 1
  fi

  local job_id
  job_id="$(printf '%s' "$out" | jq -r '.jobId // empty' 2>/dev/null || echo "")"
  if [[ -z "$job_id" ]]; then
    sd_log_error "sd_codex_dispatch: no jobId in launch output: $out"
    return 1
  fi
  echo "$job_id"
  return 0
}

# _sd_codex_mtime <file> — epoch mtime (macOS + GNU), or empty.
_sd_codex_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo ""
}

# sd_codex_wait <worktree> <job-id> [--poll N] [--stall N] [--cap N]
# Polls the background job to a terminal disposition. ALWAYS rc=0 (non-throwing
# so the orchestrator keeps control); echoes one token:
#   completed | failed | cancelled | stalled | capped | error
# stalled/capped also issue `cancel` (best-effort) before returning.
sd_codex_wait() {
  local wt="${1:-}" job="${2:-}"
  shift 2 2>/dev/null || true
  if [[ -z "$wt" || -z "$job" ]]; then
    sd_log_error "sd_codex_wait: usage: sd codex_wait <worktree> <job-id> [--poll N] [--stall N] [--cap N]"
    echo "error"; return 0
  fi
  local poll=45 stall=300 cap=1200
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --poll)  poll="${2:-45}";   shift 2 ;;
      --stall) stall="${2:-300}"; shift 2 ;;
      --cap)   cap="${2:-1200}";  shift 2 ;;
      *) sd_log_error "sd_codex_wait: unknown arg: $1"; echo "error"; return 0 ;;
    esac
  done

  local companion
  if ! companion="$(sd_codex_resolve_companion)"; then echo "error"; return 0; fi

  local start now elapsed status out logfile lmtime since
  start="$(date +%s)"
  while :; do
    if out="$(cd "$wt" && node "$companion" status "$job" --json 2>&1)"; then :; else
      sd_log_error "sd_codex_wait: status call failed: $out"
      echo "error"; return 0
    fi
    status="$(printf '%s' "$out" | jq -r '.job.status // empty' 2>/dev/null || echo "")"
    case "$status" in
      completed|failed|cancelled) echo "$status"; return 0 ;;
      ""|null) sd_log_error "sd_codex_wait: unparseable status: $out"; echo "error"; return 0 ;;
    esac

    # Stall heuristic: job-log mtime unchanged for > stall seconds.
    logfile="$(printf '%s' "$out" | jq -r '.job.logFile // empty' 2>/dev/null || echo "")"
    now="$(date +%s)"
    if [[ -n "$logfile" && -f "$logfile" ]]; then
      lmtime="$(_sd_codex_mtime "$logfile")"
      if [[ -n "$lmtime" ]]; then
        since=$(( now - lmtime ))
        if [[ "$since" -gt "$stall" ]]; then
          _sd_codex_cancel "$wt" "$companion" "$job"
          echo "stalled"; return 0
        fi
      fi
    fi

    # Wall-cap.
    elapsed=$(( now - start ))
    if [[ "$elapsed" -ge "$cap" ]]; then
      _sd_codex_cancel "$wt" "$companion" "$job"
      echo "capped"; return 0
    fi

    if [[ "$poll" -gt 0 ]]; then sleep "$poll"; fi
  done
}

# _sd_codex_cancel <worktree> <companion> <job> — best-effort cancel + confirm.
_sd_codex_cancel() {
  local wt="$1" companion="$2" job="$3" out
  if out="$(cd "$wt" && node "$companion" cancel "$job" --json 2>&1)"; then :; else
    sd_log_warn "sd_codex_wait: cancel reported non-zero (job may already be terminal): $out"
  fi
  # One confirming status read (avoid the cancel→read race); result ignored.
  ( cd "$wt" && node "$companion" status "$job" --json >/dev/null 2>&1 ) || true
}

# sd_codex_result <worktree> <job-id>
# Reads the finished job and echoes the fenced {mode,…} JSON object Codex was
# instructed to emit. rc=0 + compact JSON on success; rc=1 when no parseable
# {mode,…} block is present (caller routes to the malformed-return menu).
sd_codex_result() {
  local wt="${1:-}" job="${2:-}"
  if [[ -z "$wt" || -z "$job" ]]; then
    sd_log_error "sd_codex_result: usage: sd codex_result <worktree> <job-id>"
    return 1
  fi

  local companion
  if ! companion="$(sd_codex_resolve_companion)"; then return 1; fi

  local out
  if out="$(cd "$wt" && node "$companion" result "$job" --json 2>&1)"; then :; else
    sd_log_error "sd_codex_result: result call failed: $out"
    return 1
  fi

  local raw
  raw="$(printf '%s' "$out" | jq -r '.storedJob.result.rawOutput // .storedJob.result.codex.stdout // empty' 2>/dev/null || echo "")"
  if [[ -z "$raw" ]]; then
    sd_log_error "sd_codex_result: no rawOutput in result payload"
    return 1
  fi

  # Extract the LAST fenced ```json … ``` (or bare ```) block from the prose.
  local block
  block="$(printf '%s\n' "$raw" | awk '
    /^```([jJ][sS][oO][nN])?[[:space:]]*$/ { if (infence) { infence=0 } else { infence=1; buf="" }; next }
    infence { buf = buf $0 "\n"; last = buf }
    END { printf "%s", last }
  ')"
  if [[ -z "$block" ]]; then
    sd_log_error "sd_codex_result: no fenced JSON block in Codex output"
    return 1
  fi

  if ! printf '%s' "$block" | jq -e '.mode' >/dev/null 2>&1; then
    sd_log_error "sd_codex_result: fenced block is not a {mode,…} object"
    return 1
  fi
  printf '%s' "$block" | jq -c .
  return 0
}

# sd_codex_verify_nocommit <worktree> <baseline-head>
# Asserts Codex did not commit (HEAD == baseline). rc=1 + "commit-violation" if
# HEAD moved. rc=0 if HEAD unchanged, echoing "ok-dirty" (working tree/stage has
# changes) or "ok-clean" (no changes) so the call site can decide: a clean tree
# is fine for a gaps-surfaced return but suspect for mode:complete.
sd_codex_verify_nocommit() {
  local wt="${1:-}" baseline="${2:-}"
  if [[ -z "$wt" || -z "$baseline" ]]; then
    sd_log_error "sd_codex_verify_nocommit: usage: sd codex_verify_nocommit <worktree> <baseline-head>"
    return 2
  fi

  local head
  if head="$(git -C "$wt" rev-parse HEAD 2>&1)"; then :; else
    sd_log_error "sd_codex_verify_nocommit: cannot read HEAD in $wt: $head"
    return 2
  fi

  if [[ "$head" != "$baseline" ]]; then
    sd_log_error "sd_codex_verify_nocommit: Codex moved HEAD (committed) — baseline=$baseline head=$head"
    echo "commit-violation"
    return 1
  fi

  local porcelain
  porcelain="$(git -C "$wt" status --porcelain 2>/dev/null || echo "")"
  if [[ -n "$porcelain" ]]; then
    echo "ok-dirty"
  else
    echo "ok-clean"
  fi
  return 0
}
