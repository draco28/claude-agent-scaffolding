#!/usr/bin/env bash
# tests/test-compose.sh — tests for lib/compose.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/compose.sh"

# Helpers: build a fake cache layout with architect-critic / ai-mentor present.
_mk_ac_cache() {
  local cache="$1"
  mkdir -p "$cache/test-mp/architect-critic/0.2.0/skills/critiquing-spec"
  touch "$cache/test-mp/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md"
}
_mk_mentor_cache() {
  local cache="$1"
  mkdir -p "$cache/test-mp/ai-mentor/2.0.0/skills/grill-me"
  touch "$cache/test-mp/ai-mentor/2.0.0/skills/grill-me/SKILL.md"
}

# 1. detect_architect_critic — present
test_detect_ac_present() {
  echo "test_detect_ac_present:"
  setup_tmp_repo
  _mk_ac_cache "$TMP_DIR/cache"
  local out
  out="$(SD_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/cache" sd_compose_detect_architect_critic)"
  assert_eq "ac detected" "v0.2" "$out"
}

# 2. detect_architect_critic — absent
test_detect_ac_absent() {
  echo "test_detect_ac_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/empty-cache"
  local out
  out="$(SD_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/empty-cache" sd_compose_detect_architect_critic)"
  assert_eq "ac absent" "absent" "$out"
}

# 3. detect_ac returns rc=0 when present
test_detect_ac_rc_present() {
  echo "test_detect_ac_rc_present:"
  setup_tmp_repo
  _mk_ac_cache "$TMP_DIR/cache"
  set +e
  SD_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/cache" sd_compose_detect_architect_critic >/dev/null
  local rc=$?
  :
  assert_eq "rc=0 when present" "0" "$rc"
}

# 4. detect_ac returns rc=1 when absent
test_detect_ac_rc_absent() {
  echo "test_detect_ac_rc_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/empty-cache"
  set +e
  SD_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/empty-cache" sd_compose_detect_architect_critic >/dev/null
  local rc=$?
  :
  assert_eq "rc=1 when absent" "1" "$rc"
}

# 5. detect_ai_mentor — present
test_detect_mentor_present() {
  echo "test_detect_mentor_present:"
  setup_tmp_repo
  _mk_mentor_cache "$TMP_DIR/cache"
  local out
  out="$(SD_COMPOSE_MENTOR_CACHE_DIRS="$TMP_DIR/cache" sd_compose_detect_ai_mentor)"
  assert_eq "mentor detected" "v2.0" "$out"
}

# 6. detect_ai_mentor — absent
test_detect_mentor_absent() {
  echo "test_detect_mentor_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/empty-cache"
  local out
  out="$(SD_COMPOSE_MENTOR_CACHE_DIRS="$TMP_DIR/empty-cache" sd_compose_detect_ai_mentor)"
  assert_eq "mentor absent" "absent" "$out"
}

# 7. warn_critic_absent emits to stderr
test_warn_critic_stderr() {
  echo "test_warn_critic_stderr:"
  local err
  err="$(sd_compose_warn_critic_absent 2>&1 1>/dev/null)"
  assert_contains "warn mentions architect-critic" "architect-critic" "$err"
}

# 8. warn_grillme_absent emits to stderr and mentions ai-mentor
test_warn_grillme_stderr() {
  echo "test_warn_grillme_stderr:"
  local err
  err="$(sd_compose_warn_grillme_absent 2>&1 1>/dev/null)"
  assert_contains "warn mentions ai-mentor" "ai-mentor" "$err"
}

# 9. warn_critic_absent does not emit to stdout
test_warn_critic_silent_stdout() {
  echo "test_warn_critic_silent_stdout:"
  local out
  out="$(sd_compose_warn_critic_absent 2>/dev/null)"
  assert_eq "stdout empty" "" "$out"
}

# 10. detect_ac with multiple cache dirs (colon-separated)
test_detect_ac_multi_dir() {
  echo "test_detect_ac_multi_dir:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/empty"
  _mk_ac_cache "$TMP_DIR/real-cache"
  local out
  out="$(SD_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/empty:$TMP_DIR/real-cache" sd_compose_detect_architect_critic)"
  assert_eq "detected across multiple dirs" "v0.2" "$out"
}

# 11. default cache dirs include Codex cache
test_default_cache_dirs_include_codex() {
  echo "test_default_cache_dirs_include_codex:"
  local out
  out="$(CODEX_HOME="${TMPDIR:-/tmp}/codex-home-test" _sd_compose_default_cache_dirs)"
  assert_contains "default dirs include codex cache" "/codex-home-test/plugins/cache" "$out"
}

test_detect_ac_present
test_detect_ac_absent
test_detect_ac_rc_present
test_detect_ac_rc_absent
test_detect_mentor_present
test_detect_mentor_absent
test_warn_critic_stderr
test_warn_grillme_stderr
test_warn_critic_silent_stdout
test_detect_ac_multi_dir
test_default_cache_dirs_include_codex

sd_test_summary
