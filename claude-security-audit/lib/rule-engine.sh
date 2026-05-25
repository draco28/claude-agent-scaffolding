#!/usr/bin/env bash
# lib/rule-engine.sh — runs rule files against target files.
# Per SPEC §8.1 (rule contract) and §12 (T2-G rule-load failure visibility).

# csa_rule_run_one <rule_file> <target_file>
# Sources rule in a subshell, calls detect, emits findings JSONL on stdout.
# On source failure: emits SCANNER-001 (High).
# On detect non-zero exit: emits SCANNER-002 (High).
csa_rule_run_one() {
  local rule_file="$1"; local target_file="$2"
  local rule_id; rule_id="$(basename "$rule_file" .sh)"
  (
    set -u
    if ! source "$rule_file" 2>/dev/null; then
      jq -nc --arg rid "SCANNER-001" --arg f "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "rule failed to load", severity: "high", context: {failed_rule: $f}}'
      return 0
    fi
    if ! declare -f detect >/dev/null; then
      jq -nc --arg rid "SCANNER-001" --arg f "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "rule has no detect() function", severity: "high"}'
      return 0
    fi
    local out ec=0
    out="$(detect "$target_file" 2>/dev/null)" || ec=$?
    if [[ "$ec" -ne 0 ]]; then
      jq -nc --arg rid "SCANNER-002" --arg f "$target_file" --arg r "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "detect() failed", severity: "high", context: {failed_rule: $r, exit_code: '"$ec"'}}'
      return 0
    fi
    printf '%s\n' "$out"
  )
}

# csa_rule_engine_scan_files <rule_file> <target_file_1> [<target_file_2> ...]
csa_rule_engine_scan_files() {
  local rule_file="$1"; shift
  for t in "$@"; do
    csa_rule_run_one "$rule_file" "$t"
  done
}

# csa_rule_engine_scan_all <project_root> [<focus>]
# Discovers all rule files (filtered by focus aspect), runs the matrix.
# Emits SCANNER-002 banner on stderr if 3+ SCANNER-002 findings emerge.
csa_rule_engine_scan_all() {
  local root="$1"; local focus="${2:-all}"
  local rules_glob="$CSA_RULES_DIR"
  if [[ "$focus" != "all" ]]; then
    rules_glob="$CSA_RULES_DIR/$focus"
  fi
  local scanner_002_count=0
  local findings_out; findings_out="$(mktemp)"
  while read -r rule_file; do
    [[ -z "$rule_file" ]] && continue
    while IFS= read -r target_line; do
      [[ -z "$target_line" ]] && continue
      local target="${target_line##*$'\t'}"
      csa_rule_run_one "$rule_file" "$target" >> "$findings_out"
    done < <(csa_enum_targets_all "$root" 2>/dev/null)
  done < <(find "$rules_glob" -name '*.sh' -type f 2>/dev/null)
  cat "$findings_out"
  scanner_002_count="$(grep -c 'SCANNER-002' "$findings_out" 2>/dev/null || echo 0)"
  if [[ "$scanner_002_count" -ge 3 ]]; then
    printf '⚠ %d rule(s) failed during scan; results incomplete. See SCANNER-002 findings.\n' "$scanner_002_count" >&2
  fi
  rm -f "$findings_out"
}
