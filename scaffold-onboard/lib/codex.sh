#!/usr/bin/env bash
# scaffold-onboard/lib/codex.sh
# SS-5.1 — optional Codex synthesizer backend. Mechanical adapter around the
# externally-installed codex-plugin-cc companion (`codex-companion.mjs`). The
# agent owns every semantic judgment (the synthesis brief is the prompt; the
# orchestrator judges complete-vs-failed); these helpers are real-command legs
# only: resolve-a-path, run-a-command, parse-json, check-exit.
#
# Ported from scaffold-dev/lib/codex.sh (SS-5), MINUS the implementer-only legs:
# synthesis writes its artifact directly to the manifest-routed output path, so
# there is NO git worktree and NO no-commit verify. The dispatch target is the
# OUTPUT ARTIFACT'S REPO ROOT (sf_codex_target_root) so sandbox=workspace-write
# covers the write.
#
# LOAD-BEARING (SS-4 lesson): bin/sf runs `set -euo pipefail` and dispatches
# these via `sf codex_<verb>`. Every external command is captured set-e-safe
# (`if out="$(cmd)"; then rc=0; else rc=$?; fi`) and the wait loop avoids bare
# `(( … ))` (which returns non-zero — and aborts under set -e — when the
# expression evaluates to 0). Invoke from skill prose as `sf codex_<verb> …`.
#
# State coupling (companion keys job state by sha256(git-toplevel) under
# $CLAUDE_PLUGIN_DATA): every helper `cd`s into <target-root> before any node
# call, and the caller must keep $CLAUDE_PLUGIN_DATA stable across dispatch+polls.
#
# Overrides (testing):
#   SCAFFOLD_CODEX_COMPANION   absolute path to a companion .mjs (wins outright)
#   SCAFFOLD_CODEX_CACHE_DIRS  colon-separated plugin-cache roots to glob
#   CODEX_HOME                 trusted-projects config root (default ~/.codex)

set -u

_SF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sf_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SF_LIB_DIR/_helpers.sh"
fi

# Default plugin-cache roots searched for the companion when no override is set.
_sf_codex_default_cache_dirs() {
  echo "${HOME}/.claude/plugins/cache"
  echo "${HOME}/.claude/plugins/marketplaces"
  echo "${CODEX_HOME:-$HOME/.codex}/plugins/cache"
}

# _sf_codex_version_gt <a> <b> — true (rc=0) when version <a> sorts AFTER <b>.
# Pure-bash field-wise compare (macOS/BSD `sort` lacks GNU `sort -V`).
_sf_codex_version_gt() {
  local a="$1" b="$2"
  [[ -z "$b" ]] && return 0

  local IFS=.
  local -a av=() bv=()
  read -ra av <<<"$a"
  read -ra bv <<<"$b"

  local max="${#av[@]}"
  [[ "${#bv[@]}" -gt "$max" ]] && max="${#bv[@]}"

  local i ai bi
  for ((i = 0; i < max; i++)); do
    ai="${av[$i]:-0}"
    bi="${bv[$i]:-0}"
    [[ "$ai" =~ ^([0-9]+) ]] && ai="${BASH_REMATCH[1]}" || ai=0
    [[ "$bi" =~ ^([0-9]+) ]] && bi="${BASH_REMATCH[1]}" || bi=0
    if (( 10#$ai > 10#$bi )); then return 0; fi
    if (( 10#$ai < 10#$bi )); then return 1; fi
  done

  [[ "$a" > "$b" ]]
}

# sf_codex_resolve_companion
# Echoes the absolute path to codex-companion.mjs + rc=0, or fails loud (rc=1)
# with remediation. SCAFFOLD_CODEX_COMPANION (if set) wins; else glob the newest
# version across the cache roots (cache layout codex/<version>/scripts + the
# marketplace layout plugins/codex/scripts).
sf_codex_resolve_companion() {
  if [[ -n "${SCAFFOLD_CODEX_COMPANION:-}" ]]; then
    if [[ -f "$SCAFFOLD_CODEX_COMPANION" ]]; then
      echo "$SCAFFOLD_CODEX_COMPANION"
      return 0
    fi
    sf_log_error "sf_codex_resolve_companion: SCAFFOLD_CODEX_COMPANION points at a missing file: $SCAFFOLD_CODEX_COMPANION"
    return 1
  fi

  local roots=()
  if [[ -n "${SCAFFOLD_CODEX_CACHE_DIRS:-}" ]]; then
    local IFS=":"
    for d in $SCAFFOLD_CODEX_CACHE_DIRS; do roots+=("$d"); done
  else
    while IFS= read -r d; do roots+=("$d"); done < <(_sf_codex_default_cache_dirs)
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

  # Prefer the cache layout's NEWEST version. Compare the <version> segment alone
  # so the cache/marketplace path prefix can't defeat the version order.
  if [[ "${#cache_matches[@]}" -gt 0 ]]; then
    local best="" best_v="" v
    for m in "${cache_matches[@]}"; do
      v="$(printf '%s' "$m" | sed -nE 's#.*/openai-codex/codex/([^/]+)/scripts/codex-companion\.mjs$#\1#p')"
      if _sf_codex_version_gt "$v" "$best_v"; then
        best="$m"
        best_v="$v"
      fi
    done
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

  sf_log_error "sf_codex_resolve_companion: codex-plugin-cc companion not found. Install OpenAI's codex plugin (/plugin install codex from the openai-codex marketplace), or set SCAFFOLD_CODEX_COMPANION to the absolute codex-companion.mjs path."
  return 1
}

# sf_codex_target_root <out-path>  (SS-5.1, NEW)
# Echo the repo root Codex should run in so sandbox=workspace-write covers the
# write to <out-path>: the git toplevel containing the (possibly not-yet-created)
# output path, else its nearest existing ancestor dir. rc=1 if none resolvable.
sf_codex_target_root() {
  local out="${1:-}"
  if [[ -z "$out" ]]; then
    sf_log_error "sf_codex_target_root: output path required"; return 1
  fi
  local dir; dir="$(dirname "$out")"
  while [[ -n "$dir" && "$dir" != "/" && ! -d "$dir" ]]; do dir="$(dirname "$dir")"; done
  if [[ ! -d "$dir" ]]; then
    sf_log_error "sf_codex_target_root: no existing ancestor dir for: $out"; return 1
  fi
  local root
  if root="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$root" ]]; then
    echo "$root"; return 0
  fi
  ( cd "$dir" && pwd -P )
}

# _sf_codex_dir_trusted <dir>
# 0 = under a trusted project root; 1 = positively outside all trusted roots
# (config present with ≥1 trusted project); 2 = undetermined (no config / none).
_sf_codex_dir_trusted() {
  local dir="$1"
  local config="${CODEX_HOME:-$HOME/.codex}/config.toml"
  [[ -f "$config" ]] || return 2

  local dir_real
  dir_real="$(cd "$dir" 2>/dev/null && pwd -P)" || dir_real="$dir"

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
    if [[ "$dir_real" == "$p" || "$dir_real" == "$p"/* ]]; then
      return 0
    fi
  done <<<"$trusted"
  return 1
}

# sf_codex_preflight <target-root>
# Hard gate before dispatch. rc=0 ready; rc=1 unavailable (with remediation).
# Hard-fails on: companion missing, setup not-ready (codex uninstalled / not
# authed), or target-root positively outside all trusted roots. Trust that
# can't be determined (no codex config) warns and proceeds (approval=never path).
sf_codex_preflight() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    sf_log_error "sf_codex_preflight: target-root path required"
    return 1
  fi

  local companion
  if ! companion="$(sf_codex_resolve_companion)"; then
    return 1
  fi

  local out
  if out="$(cd "$root" && node "$companion" setup --json 2>&1)"; then :; else
    sf_log_error "sf_codex_preflight: \`setup\` failed: $out"
    return 1
  fi

  local ready
  ready="$(printf '%s' "$out" | jq -r '.ready // false' 2>/dev/null || echo false)"
  if [[ "$ready" != "true" ]]; then
    local codex_ok auth_ok
    codex_ok="$(printf '%s' "$out" | jq -r '.codex.available // false' 2>/dev/null || echo false)"
    auth_ok="$(printf '%s' "$out" | jq -r '.auth.loggedIn // false' 2>/dev/null || echo false)"
    if [[ "$codex_ok" != "true" ]]; then
      sf_log_error "sf_codex_preflight: Codex CLI not available. Install it (https://github.com/openai/codex) and ensure \`codex --version\` works."
    elif [[ "$auth_ok" != "true" ]]; then
      sf_log_error "sf_codex_preflight: Codex not authenticated. Run \`codex login\` (or \`codex login --with-api-key\`), then retry."
    else
      sf_log_error "sf_codex_preflight: Codex not ready: $out"
    fi
    return 1
  fi

  local trust_rc=0
  if _sf_codex_dir_trusted "$root"; then trust_rc=0; else trust_rc=$?; fi
  case "$trust_rc" in
    1)
      sf_log_error "sf_codex_preflight: target root is outside every Codex-trusted project root: $root. Add it to ~/.codex/config.toml ([projects.\"<path>\"] trust_level = \"trusted\") or route the artifact into a trusted repo."
      return 1
      ;;
    2)
      sf_log_warn "sf_codex_preflight: could not verify trust for $root (no ~/.codex/config.toml projects); proceeding under approval=never. If Codex stalls on a trust prompt, add it to trusted projects."
      ;;
  esac

  return 0
}

_sf_codex_require_value() {
  local fn="$1" flag="$2" value="${3:-}"
  if [[ -z "$value" || "$value" == --* ]]; then
    sf_log_error "$fn: missing value for $flag"
    return 1
  fi
  return 0
}

_sf_codex_require_nonnegative_int() {
  local fn="$1" flag="$2" value="${3:-}"
  if ! _sf_codex_require_value "$fn" "$flag" "$value"; then
    return 1
  fi
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    sf_log_error "$fn: $flag must be a non-negative integer: $value"
    return 1
  fi
  return 0
}

# sf_codex_dispatch <target-root> <prompt-file> [--model M] [--effort E] [--resume-last|--resume|--fresh]
# Launches a background, write-capable Codex task carrying the prompt-file.
# Echoes the job-id + rc=0, or rc=1 on failure.
sf_codex_dispatch() {
  local root="${1:-}" pf="${2:-}"
  shift 2 2>/dev/null || true
  if [[ -z "$root" || -z "$pf" ]]; then
    sf_log_error "sf_codex_dispatch: usage: sf codex_dispatch <target-root> <prompt-file> [--model M] [--effort E] [--resume-last|--resume|--fresh]"
    return 1
  fi
  if [[ ! -f "$pf" ]]; then
    sf_log_error "sf_codex_dispatch: prompt-file not found: $pf"
    return 1
  fi
  # Absolutize the prompt-file (the companion resolves it relative to its cwd).
  local pf_abs
  pf_abs="$(cd "$(dirname "$pf")" && pwd)/$(basename "$pf")"

  local model="" effort="" resume_last=0 fresh=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)
        if ! _sf_codex_require_value "sf_codex_dispatch" "$1" "${2:-}"; then return 1; fi
        model="$2"; shift 2 ;;
      --effort)
        if ! _sf_codex_require_value "sf_codex_dispatch" "$1" "${2:-}"; then return 1; fi
        effort="$2"; shift 2 ;;
      --resume-last|--resume) resume_last=1; shift ;;
      --fresh) fresh=1; shift ;;
      *) sf_log_error "sf_codex_dispatch: unknown arg: $1"; return 1 ;;
    esac
  done
  if [[ "$resume_last" -eq 1 && "$fresh" -eq 1 ]]; then
    sf_log_error "sf_codex_dispatch: Choose either --resume-last/--resume or --fresh."
    return 1
  fi

  local companion
  if ! companion="$(sf_codex_resolve_companion)"; then
    return 1
  fi

  local args=(task --background --write --prompt-file "$pf_abs" --json)
  [[ "$resume_last" -eq 1 ]] && args+=(--resume-last)
  [[ "$fresh" -eq 1 ]] && args+=(--fresh)
  [[ -n "$model" ]]  && args+=(--model "$model")
  [[ -n "$effort" ]] && args+=(--effort "$effort")

  local out
  if out="$(cd "$root" && node "$companion" "${args[@]}" 2>&1)"; then :; else
    sf_log_error "sf_codex_dispatch: launch failed: $out"
    return 1
  fi

  local job_id
  job_id="$(printf '%s' "$out" | jq -r '.jobId // empty' 2>/dev/null || echo "")"
  if [[ -z "$job_id" ]]; then
    sf_log_error "sf_codex_dispatch: no jobId in launch output: $out"
    return 1
  fi
  echo "$job_id"
  return 0
}

# _sf_codex_mtime <file> — epoch mtime (macOS + GNU), or empty.
_sf_codex_mtime() {
  local v=""
  if v="$(stat -c %Y "$1" 2>/dev/null)" && [[ "$v" =~ ^[0-9]+$ ]]; then
    echo "$v"
    return 0
  fi
  if v="$(stat -f %m "$1" 2>/dev/null)" && [[ "$v" =~ ^[0-9]+$ ]]; then
    echo "$v"
    return 0
  fi
  echo ""
}

# sf_codex_wait <target-root> <job-id> [--poll N] [--stall N] [--cap N]
# Polls the background job to a terminal disposition. ALWAYS rc=0 (non-throwing
# so the orchestrator keeps control); echoes one token:
#   completed | failed | cancelled | stalled | capped | error
# stalled/capped also issue `cancel` (best-effort) before returning.
sf_codex_wait() {
  local root="${1:-}" job="${2:-}"
  shift 2 2>/dev/null || true
  if [[ -z "$root" || -z "$job" ]]; then
    sf_log_error "sf_codex_wait: usage: sf codex_wait <target-root> <job-id> [--poll N] [--stall N] [--cap N]"
    echo "error"; return 0
  fi
  local poll=45 stall=300 cap=1200
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --poll)
        if ! _sf_codex_require_nonnegative_int "sf_codex_wait" "$1" "${2:-}"; then echo "error"; return 0; fi
        poll="$2"; shift 2 ;;
      --stall)
        if ! _sf_codex_require_nonnegative_int "sf_codex_wait" "$1" "${2:-}"; then echo "error"; return 0; fi
        stall="$2"; shift 2 ;;
      --cap)
        if ! _sf_codex_require_nonnegative_int "sf_codex_wait" "$1" "${2:-}"; then echo "error"; return 0; fi
        cap="$2"; shift 2 ;;
      *) sf_log_error "sf_codex_wait: unknown arg: $1"; echo "error"; return 0 ;;
    esac
  done

  local companion
  if ! companion="$(sf_codex_resolve_companion)"; then echo "error"; return 0; fi

  local start now elapsed status out logfile lmtime since
  start="$(date +%s)"
  while :; do
    if out="$(cd "$root" && node "$companion" status "$job" --json 2>&1)"; then :; else
      sf_log_error "sf_codex_wait: status call failed: $out"
      echo "error"; return 0
    fi
    status="$(printf '%s' "$out" | jq -r '.job.status // empty' 2>/dev/null || echo "")"
    case "$status" in
      completed|done) echo "completed"; return 0 ;;
      failed|cancelled) echo "$status"; return 0 ;;
      ""|null) sf_log_error "sf_codex_wait: unparseable status: $out"; echo "error"; return 0 ;;
    esac

    # Stall heuristic: job-log mtime unchanged for > stall seconds.
    logfile="$(printf '%s' "$out" | jq -r '.job.logFile // empty' 2>/dev/null || echo "")"
    now="$(date +%s)"
    if [[ -n "$logfile" && -f "$logfile" ]]; then
      lmtime="$(_sf_codex_mtime "$logfile")"
      if [[ -n "$lmtime" ]]; then
        since=$(( now - lmtime ))
        if [[ "$since" -gt "$stall" ]]; then
          _sf_codex_cancel "$root" "$companion" "$job"
          echo "stalled"; return 0
        fi
      fi
    fi

    # Wall-cap.
    elapsed=$(( now - start ))
    if [[ "$elapsed" -ge "$cap" ]]; then
      _sf_codex_cancel "$root" "$companion" "$job"
      echo "capped"; return 0
    fi

    if [[ "$poll" -gt 0 ]]; then sleep "$poll"; fi
  done
}

# _sf_codex_cancel <target-root> <companion> <job> — best-effort cancel + confirm.
_sf_codex_cancel() {
  local root="$1" companion="$2" job="$3" out
  if out="$(cd "$root" && node "$companion" cancel "$job" --json 2>&1)"; then :; else
    sf_log_warn "sf_codex_wait: cancel reported non-zero (job may already be terminal): $out"
  fi
  # One confirming status read (avoid the cancel→read race); result ignored.
  ( cd "$root" && node "$companion" status "$job" --json >/dev/null 2>&1 ) || true
}

# sf_codex_result <target-root> <job-id>
# Reads the finished job and echoes the fenced {mode,…} JSON object Codex was
# instructed to emit (the synthesis return shape: {mode, output_path,
# ids_minted, ids_cited, summary}). rc=0 + compact JSON on success; rc=1 when no
# parseable {mode,…} block is present (caller re-dispatches once / hard-fails).
sf_codex_result() {
  local root="${1:-}" job="${2:-}"
  if [[ -z "$root" || -z "$job" ]]; then
    sf_log_error "sf_codex_result: usage: sf codex_result <target-root> <job-id>"
    return 1
  fi

  local companion
  if ! companion="$(sf_codex_resolve_companion)"; then return 1; fi

  local out
  if out="$(cd "$root" && node "$companion" result "$job" --json 2>&1)"; then :; else
    sf_log_error "sf_codex_result: result call failed: $out"
    return 1
  fi

  local raw
  raw="$(printf '%s' "$out" | jq -r '.storedJob.result.rawOutput // .storedJob.result.codex.stdout // empty' 2>/dev/null || echo "")"
  if [[ -z "$raw" ]]; then
    sf_log_error "sf_codex_result: no rawOutput in result payload"
    return 1
  fi

  # Extract the LAST fenced ```json … ``` (or bare ```) block from the prose.
  # Ignore non-JSON fences so transcripts/examples before the final return do
  # not desynchronize the fence state.
  local block
  block="$(printf '%s\n' "$raw" | awk '
    function fence_tag(line, t) {
      t=line
      sub(/^```[[:space:]]*/, "", t)
      sub(/[[:space:]]*$/, "", t)
      return tolower(t)
    }
    /^```[[:space:]]*([[:alnum:]_-]+)?[[:space:]]*$/ {
      if (infence) {
        if (keep) last=buf
        infence=0; keep=0; buf=""
      } else {
        infence=1
        tag=fence_tag($0)
        keep=(tag=="" || tag=="json")
        buf=""
      }
      next
    }
    infence && keep { buf = buf $0 "\n" }
    END { printf "%s", last }
  ')"
  if [[ -z "$block" ]]; then
    sf_log_error "sf_codex_result: no fenced JSON block in Codex output"
    return 1
  fi

  if ! printf '%s' "$block" | jq -e '.mode' >/dev/null 2>&1; then
    sf_log_error "sf_codex_result: fenced block is not a {mode,…} object"
    return 1
  fi
  printf '%s' "$block" | jq -c .
  return 0
}
