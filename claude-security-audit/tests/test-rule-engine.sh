#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/rule-engine.sh"

_csa_failed=0

# Helper to create a rule file with the standard contract.
_make_rule() {
  local path="$1"; local rid="$2"; local body="$3"
  cat > "$path" << EOF
RULE_ID="$rid"
RULE_NAME="$rid"
RULE_ASPECT="test"
RULE_SEVERITY="low"
RULE_DESCRIPTION="Test rule"
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="false"
RULE_REMEDIATION="n/a"
detect() {
$body
}
EOF
}

# 1. Zero rules dir → no findings
test_engine_zero_rules() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  printf 'x\n' > "$tmp/target.txt"
  local out; out="$(csa_rule_engine_scan_files /dev/null "$tmp/target.txt" 2>/dev/null)"
  # /dev/null sourced fine but has no detect() → SCANNER-001
  # The "zero rules" intent is different: no rule files at all. We test via scan_files
  # with a no-op rule:
  _make_rule "$tmp/noop.sh" "NOOP-001" '  return 0'
  out="$(csa_rule_engine_scan_files "$tmp/noop.sh" "$tmp/target.txt" 2>/dev/null)"
  assert_eq "" "$out"
}

# 2. Rule + clean target = empty findings
test_engine_all_clean() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re2.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  _make_rule "$tmp/clean.sh" "CLEAN-001" '  return 0'
  printf 'benign\n' > "$tmp/t.txt"
  local out; out="$(csa_rule_engine_scan_files "$tmp/clean.sh" "$tmp/t.txt" 2>/dev/null)"
  assert_eq "" "$out"
}

# 3. One finding (representative)
test_engine_one_finding() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re3.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  _make_rule "$tmp/fire.sh" "TEST-001" '  jq -nc --arg f "$1" "{rule_id: \"TEST-001\", file: \$f, line: 1, offset: 0, preview: \"x\", severity: \"low\"}"'
  printf 'hello\n' > "$tmp/target.txt"
  local out; out="$(csa_rule_engine_scan_files "$tmp/fire.sh" "$tmp/target.txt" 2>/dev/null)"
  assert_contains "$out" "TEST-001"
}

# 4. Multiple findings from one rule
test_engine_multiple_same_rule() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re4.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  _make_rule "$tmp/m.sh" "MULTI-001" '  for i in 1 2 3; do jq -nc --arg f "$1" --arg i "$i" "{rule_id: \"MULTI-001\", file: \$f, line: (\$i|tonumber), offset: 0, preview: \"x\", severity: \"low\"}"; done'
  printf 'x\n' > "$tmp/t.txt"
  local out; out="$(csa_rule_engine_scan_files "$tmp/m.sh" "$tmp/t.txt" 2>/dev/null)"
  local count; count="$(printf '%s\n' "$out" | grep -c MULTI-001)"
  assert_eq "3" "$count"
}

# 5. Multiple rules
test_engine_multiple_rules() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re5.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  _make_rule "$tmp/r1.sh" "R1-001" '  jq -nc --arg f "$1" "{rule_id: \"R1-001\", file: \$f, line: 1, offset: 0, preview: \"a\", severity: \"low\"}"'
  _make_rule "$tmp/r2.sh" "R2-001" '  jq -nc --arg f "$1" "{rule_id: \"R2-001\", file: \$f, line: 1, offset: 0, preview: \"b\", severity: \"low\"}"'
  printf 'x\n' > "$tmp/t.txt"
  local o1; o1="$(csa_rule_engine_scan_files "$tmp/r1.sh" "$tmp/t.txt" 2>/dev/null)"
  local o2; o2="$(csa_rule_engine_scan_files "$tmp/r2.sh" "$tmp/t.txt" 2>/dev/null)"
  assert_contains "$o1" "R1-001" || return 1
  assert_contains "$o2" "R2-001" || return 1
}

# 6. Rule fails to source → SCANNER-001 (T2-G)
test_engine_rule_fails_to_source_emits_SCANNER_001() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re6.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  # Syntax error rule:
  cat > "$tmp/broken.sh" << 'EOF'
this is not valid bash {{{
EOF
  printf 'x\n' > "$tmp/t.txt"
  local out; out="$(csa_rule_run_one "$tmp/broken.sh" "$tmp/t.txt" 2>/dev/null)"
  assert_contains "$out" "SCANNER-001"
}

# 7. detect() exits non-zero → SCANNER-002 (T2-G)
test_engine_rule_detect_nonzero_emits_SCANNER_002() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re7.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  _make_rule "$tmp/bad.sh" "BAD-001" '  return 1'
  printf 'x\n' > "$tmp/t.txt"
  local out; out="$(csa_rule_run_one "$tmp/bad.sh" "$tmp/t.txt" 2>/dev/null)"
  assert_contains "$out" "SCANNER-002"
}

# 8. 3+ SCANNER-002 → banner on stderr (T2-G)
test_engine_3_plus_scanner_002_emits_banner() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-re8.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  mkdir -p "$tmp/rules/test"
  for n in 1 2 3 4; do
    _make_rule "$tmp/rules/test/bad$n.sh" "BAD-00$n" '  return 1'
  done
  mkdir -p "$tmp/project/.claude"
  echo '{}' > "$tmp/project/.claude/settings.json"

  source "$CSA_LIB_DIR/enumerate-targets.sh"
  local stderr
  stderr="$(CSA_RULES_DIR="$tmp/rules" HOME=/nonexistent csa_rule_engine_scan_all "$tmp/project" 2>&1 >/dev/null)"
  assert_contains "$stderr" "rule(s) failed during scan"
}

csa_test_run test_engine_zero_rules                                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_all_clean                                        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_one_finding                                      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_multiple_same_rule                               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_multiple_rules                                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_rule_fails_to_source_emits_SCANNER_001           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_rule_detect_nonzero_emits_SCANNER_002            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_engine_3_plus_scanner_002_emits_banner                  || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
