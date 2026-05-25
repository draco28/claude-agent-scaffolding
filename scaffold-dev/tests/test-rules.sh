#!/usr/bin/env bash
# tests/test-rules.sh — 8 tests for lib/rules.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/rules.sh"

# 1. sd_rules_load returns 0 when scaffold-onboard sibling is present (monorepo)
test_load_sibling_present() {
  echo "test_load_sibling_present:"
  set +e
  sd_rules_load 2>/dev/null
  local rc=$?
  :
  assert_eq "load sibling rc=0" "0" "$rc"
}

# 2. After load, sf_rules_parse is defined
test_load_defines_sf_rules_parse() {
  echo "test_load_defines_sf_rules_parse:"
  sd_rules_load 2>/dev/null || true
  if declare -F sf_rules_parse >/dev/null 2>&1; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') sf_rules_parse defined"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') sf_rules_parse not defined"
  fi
}

# 3. graceful absence — when SD_RULES_FORCE_ABSENT=1, returns 1
test_load_absent_graceful() {
  echo "test_load_absent_graceful:"
  set +e
  SD_RULES_FORCE_ABSENT=1 sd_rules_load 2>/dev/null
  local rc=$?
  :
  assert_eq "force-absent rc=1" "1" "$rc"
}

# 4. rules_check on file list with no rule file returns 0 (no rules → pass)
test_check_no_rules() {
  echo "test_check_no_rules:"
  setup_tmp_repo
  echo "" > files.txt
  echo "src/x.py" > files.txt
  set +e
  sd_rules_check "$(cat files.txt)" 2>/dev/null
  local rc=$?
  :
  assert_eq "no rules → rc=0" "0" "$rc"
}

# 5. rules_check on banned_imports rule — file violates → rc=1
test_check_banned_imports_violation() {
  echo "test_check_banned_imports_violation:"
  setup_tmp_repo
  # Create a memory-bank file with a banned_imports mcrule.
  mkdir -p memory-bank
  cat > memory-bank/03-code-patterns.md <<'EOF'
## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
forbid: requests
where: src/
<!-- mcrule:end -->
EOF
  # Create a file that violates.
  mkdir -p src
  cat > src/bad.py <<'EOF'
import requests
EOF
  export SD_RULES_FILE="$(pwd)/memory-bank/03-code-patterns.md"
  set +e
  sd_rules_check "src/bad.py" 2>/dev/null
  local rc=$?
  :
  unset SD_RULES_FILE
  assert_eq "violation rc=1" "1" "$rc"
}

# 6. rules_check on banned_imports — file clean → rc=0
test_check_banned_imports_clean() {
  echo "test_check_banned_imports_clean:"
  setup_tmp_repo
  mkdir -p memory-bank
  cat > memory-bank/03-code-patterns.md <<'EOF'
## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
forbid: requests
where: src/
<!-- mcrule:end -->
EOF
  mkdir -p src
  echo "import json" > src/good.py
  export SD_RULES_FILE="$(pwd)/memory-bank/03-code-patterns.md"
  set +e
  sd_rules_check "src/good.py" 2>/dev/null
  local rc=$?
  :
  unset SD_RULES_FILE
  assert_eq "clean rc=0" "0" "$rc"
}

# 7. rules_check with multiple files in list
test_check_multi_files() {
  echo "test_check_multi_files:"
  setup_tmp_repo
  mkdir -p memory-bank src
  cat > memory-bank/03-code-patterns.md <<'EOF'
## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
forbid: requests
where: src/
<!-- mcrule:end -->
EOF
  echo "import json" > src/a.py
  echo "import requests" > src/b.py
  export SD_RULES_FILE="$(pwd)/memory-bank/03-code-patterns.md"
  set +e
  sd_rules_check "$(printf 'src/a.py\nsrc/b.py')" 2>/dev/null
  local rc=$?
  :
  unset SD_RULES_FILE
  assert_eq "one violation among many rc=1" "1" "$rc"
}

# 8. rules_check fallback to AC-only when scaffold-onboard absent
test_check_fallback_ac_only() {
  echo "test_check_fallback_ac_only:"
  set +e
  SD_RULES_FORCE_ABSENT=1 sd_rules_check "src/x.py" 2>/dev/null
  local rc=$?
  :
  # Fallback returns 0 (no rules to check) per spec.
  assert_eq "fallback rc=0" "0" "$rc"
}

test_load_sibling_present
test_load_defines_sf_rules_parse
test_load_absent_graceful
test_check_no_rules
test_check_banned_imports_violation
test_check_banned_imports_clean
test_check_multi_files
test_check_fallback_ac_only

sd_test_summary
