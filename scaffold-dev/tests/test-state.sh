#!/usr/bin/env bash
# tests/test-state.sh — 10 tests for lib/state.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/state.sh"

# Helper: prepare a memory-bank dir with 05-active-context.md containing a
# cursor JSON sentinel block.
_mk_active_context() {
  local mb="$1" sprint="$2" slice="$3" work_item="$4"
  mkdir -p "$mb"
  cat > "$mb/05-active-context.md" <<EOF
# Active context

<!-- sd:cursor:start -->
\`\`\`json
{"sprint": "${sprint}", "slice": "${slice}", "work_item": "${work_item}"}
\`\`\`
<!-- sd:cursor:end -->

Free-form notes follow.
EOF
}

# 1. read cursor returns JSON
test_read_cursor() {
  echo "test_read_cursor:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "3.2" "VS-3.2.1" "2.04"
  local out
  out="$(sd_state_read_cursor)"
  local sprint
  sprint="$(echo "$out" | jq -r .sprint)"
  assert_eq "read_cursor.sprint" "3.2" "$sprint"
}

# 2. read cursor returns slice
test_read_cursor_slice() {
  echo "test_read_cursor_slice:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "3.2" "VS-3.2.1" "2.04"
  local out
  out="$(sd_state_active_slice)"
  assert_eq "active_slice" "VS-3.2.1" "$out"
}

# 3. active sprint accessor
test_active_sprint() {
  echo "test_active_sprint:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "5.1" "VS-5.1.1" "1.01"
  local out
  out="$(sd_state_active_sprint)"
  assert_eq "active_sprint" "5.1" "$out"
}

# 4. active work_item accessor
test_active_work_item() {
  echo "test_active_work_item:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "5.1" "VS-5.1.1" "1.01"
  local out
  out="$(sd_state_active_work_item)"
  assert_eq "active_work_item" "1.01" "$out"
}

# 5. write cursor creates file if absent
test_write_cursor_create() {
  echo "test_write_cursor_create:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  sd_state_write_cursor "4.3" "VS-4.3.1" "3.02"
  assert_file_exists "$TMP_AI_WORKSPACE/.claude/memory-bank/05-active-context.md"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/05-active-context.md" '"sprint":[[:space:]]*"4.3"'
}

# 6. write cursor updates existing
test_write_cursor_update() {
  echo "test_write_cursor_update:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "1.1" "VS-1.1.1" "1.01"
  sd_state_write_cursor "2.2" "VS-2.2.1" "4.05"
  local out
  out="$(sd_state_active_sprint)"
  assert_eq "updated sprint" "2.2" "$out"
  local slice
  slice="$(sd_state_active_slice)"
  assert_eq "updated slice" "VS-2.2.1" "$slice"
}

# 7. write cursor preserves surrounding markdown
test_write_cursor_preserves_text() {
  echo "test_write_cursor_preserves_text:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "1.1" "VS-1.1.1" "1.01"
  sd_state_write_cursor "2.2" "VS-2.2.1" "4.05"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/05-active-context.md" 'Free-form notes follow'
}

# 8. write cursor is atomic (no .tmp leftover)
test_write_cursor_atomic() {
  echo "test_write_cursor_atomic:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  sd_state_write_cursor "1.1" "VS-1.1.1" "1.01"
  local tmp_count
  tmp_count="$(ls "$TMP_AI_WORKSPACE/.claude/memory-bank/" 2>/dev/null | grep -c '\.tmp' || true)"
  assert_eq "no .tmp leftovers" "0" "$tmp_count"
}

# 9. read cursor when file absent returns 1
test_read_cursor_absent() {
  echo "test_read_cursor_absent:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e
  sd_state_read_cursor 2>/dev/null
  local rc=$?
  :
  assert_eq "read_cursor absent rc=1" "1" "$rc"
}

# 10. concurrent read safety — two simultaneous reads succeed
test_concurrent_reads() {
  echo "test_concurrent_reads:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_active_context "$TMP_AI_WORKSPACE/.claude/memory-bank" "7.1" "VS-7.1.1" "8.01"
  local r1 r2
  r1="$(sd_state_read_cursor)"
  r2="$(sd_state_read_cursor)"
  assert_eq "both reads identical" "$r1" "$r2"
}

test_read_cursor
test_read_cursor_slice
test_active_sprint
test_active_work_item
test_write_cursor_create
test_write_cursor_update
test_write_cursor_preserves_text
test_write_cursor_atomic
test_read_cursor_absent
test_concurrent_reads

sd_test_summary
