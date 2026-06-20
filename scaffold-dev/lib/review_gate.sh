#!/usr/bin/env bash
# scaffold-dev/lib/review_gate.sh
# #39 Phase B — review-gate selector. Resolves whether (and where) an opt-in
# architect-critic async close-depth audit runs at slice/spec close: a
# per-invocation override, else the manifest's optional `.review_gate`, else
# the default `off` (today's behavior, unchanged). Read-with-default only —
# absent field / absent manifest resolve to `off`, so existing projects are
# unchanged and no workspace-init schema change is required.
#
# Values: off | slice_close | spec_close | both
#   off          — no review gate (default; existing sync §7 paths untouched)
#   slice_close  — async close-depth audit at closing-vertical-slice §7
#   spec_close   — async close-depth audit at planning-vertical-slice §7
#                  (upgrades the default author-depth audit to close-depth)
#   both         — both attach points
#
# set -e safety (SS-4): sd_manifest_get returns rc=1 when the field/manifest is
# absent — captured set-e-safe so the (total) default does not abort under the
# dispatcher's `set -euo pipefail`. Mirrors lib/backend.sh.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# sd_review_gate_resolve [--gate <override>]
# Echoes the resolved gate (off | slice_close | spec_close | both). Precedence:
#   --gate override  >  manifest .review_gate  >  off
# rc=0 on a valid gate; rc=1 on an invalid value (typo); rc=2 on bad usage.
sd_review_gate_resolve() {
  local override=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gate)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          sd_log_error "sd_review_gate_resolve: missing value for --gate"
          return 2
        fi
        override="$2"; shift 2 ;;
      *) sd_log_error "sd_review_gate_resolve: unknown arg: $1"; return 2 ;;
    esac
  done

  local resolved=""
  if [[ -n "$override" ]]; then
    resolved="$override"
  else
    local field=""
    if field="$(sd_manifest_get '.review_gate' 2>/dev/null)"; then :; else field=""; fi
    if [[ -n "$field" && "$field" != "null" ]]; then
      resolved="$field"
    else
      resolved="off"
    fi
  fi

  case "$resolved" in
    off|slice_close|spec_close|both)
      echo "$resolved"
      return 0
      ;;
    *)
      sd_log_error "sd_review_gate_resolve: invalid review_gate '$resolved' (expected off|slice_close|spec_close|both)"
      return 1
      ;;
  esac
}

# sd_review_gate_bundle --slice-root DIR --title STR [--diff-root DIR --diff-base REF] [HEADING PATH]...
# Materializes the single review-bundle artifact the async review gate feeds to
# architect-critic, and echoes its absolute path. Mechanical only — the agent
# decides whether/when to call it; this just assembles files reliably.
#
# Why a helper (not prose): the bundle plumbing kept regressing under bot review
# (Codex rounds 3-5) — wrong dir, undefined diff base, empty-diff-in-direct-mode.
# Those are mechanical facts, so they belong in tested bash, not retyped prose.
# Bakes in three invariants:
#   1. written UNDER the slice root (a trusted git root) — never /tmp, so
#      architect-critic's async target-root preflight accepts it;
#   2. the slice diff section is included ONLY when the merge-base range is
#      resolvable AND non-empty (direct-mode merge-base==HEAD yields nothing — #76);
#   3. remaining (HEADING PATH) pairs are appended as "## HEADING" + file contents
#      (a missing file is noted, not fatal).
# rc=0 on success; rc=2 on usage error.
sd_review_gate_bundle() {
  local slice_root="" title="" diff_root="" diff_base=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slice-root) [[ $# -ge 2 ]] || { sd_log_error "sd_review_gate_bundle: missing value for --slice-root"; return 2; }; slice_root="$2"; shift 2 ;;
      --title)      [[ $# -ge 2 ]] || { sd_log_error "sd_review_gate_bundle: missing value for --title"; return 2; }; title="$2"; shift 2 ;;
      --diff-root)  [[ $# -ge 2 ]] || { sd_log_error "sd_review_gate_bundle: missing value for --diff-root"; return 2; }; diff_root="$2"; shift 2 ;;
      --diff-base)  [[ $# -ge 2 ]] || { sd_log_error "sd_review_gate_bundle: missing value for --diff-base"; return 2; }; diff_base="$2"; shift 2 ;;
      --) shift; break ;;
      --*) sd_log_error "sd_review_gate_bundle: unknown flag: $1"; return 2 ;;
      *) break ;;   # first (HEADING PATH) pair
    esac
  done

  if [[ -z "$slice_root" || -z "$title" ]]; then
    sd_log_error "sd_review_gate_bundle: --slice-root and --title are required"
    return 2
  fi
  if [[ ! -d "$slice_root" ]]; then
    sd_log_error "sd_review_gate_bundle: slice-root is not a directory: $slice_root"
    return 2
  fi
  # Fail loud on caller mistakes rather than silently emitting an incomplete bundle:
  # --diff-root/--diff-base must be given together, and section args must be pairs.
  if { [[ -n "$diff_root" ]] && [[ -z "$diff_base" ]]; } || { [[ -z "$diff_root" ]] && [[ -n "$diff_base" ]]; }; then
    sd_log_error "sd_review_gate_bundle: --diff-root and --diff-base must be given together"
    return 2
  fi
  if [[ $(( $# % 2 )) -ne 0 ]]; then
    sd_log_error "sd_review_gate_bundle: section args must be HEADING PATH pairs (odd arg count: $#)"
    return 2
  fi

  local dest="$slice_root/.sd-review-bundle.md"
  {
    printf '# %s\n' "$title"
    if [[ -n "$diff_root" && -n "$diff_base" ]]; then
      local db=""
      db="$(git -C "$diff_root" merge-base "$diff_base" HEAD 2>/dev/null || true)"
      if [[ -n "$db" ]] && ! git -C "$diff_root" diff --quiet "$db..HEAD" 2>/dev/null; then
        printf '\n## Combined diff (%s..HEAD)\n```diff\n' "$db"
        git -C "$diff_root" diff "$db..HEAD" 2>/dev/null || true
        printf '```\n'
      fi
    fi
    while [[ $# -ge 2 ]]; do
      local heading="$1" path="$2"; shift 2
      printf '\n## %s\n' "$heading"
      if [[ -f "$path" ]]; then
        cat "$path"
        printf '\n'
      else
        printf '_(missing: %s)_\n' "$path"
      fi
    done
  } > "$dest"

  echo "$dest"
  return 0
}
