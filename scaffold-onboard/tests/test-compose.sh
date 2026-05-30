#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/compose.sh"

# v0.2 test-compose.sh — 24 tests (16 retained from v0.1.0 baseline + 8 new).
# Removed: 15 IPC tests (sf_compose_build_critic_request +
# sf_compose_read_critic_response — functions dropped per SPEC §12.3).
# Adapted: tests previously asserting plugins.architect-critic in composition.json
# now assert that key is ABSENT (per SPEC §12.2 — ac detection is filesystem-only).

# Build a fake plugin install dir at $TMP_DIR/fake-plugins/<name>
mk_fake_plugin() {
  local name="$1"; shift
  local dir="$TMP_DIR/fake-plugins/$name"
  mkdir -p "$dir"
  local rel
  for rel in "$@"; do
    mkdir -p "$dir/$(dirname "$rel")"
    : > "$dir/$rel"
  done
  echo "$dir"
}

# Build a fake architect-critic v0.2 layout under a cache root.
# Layout: <root>/<marketplace>/architect-critic/<version>/skills/critiquing-spec/SKILL.md
mk_fake_ac_v02_cache() {
  local root="$1"
  local skill_dir="$root/marketplace-fake/architect-critic/0.2.0/skills/critiquing-spec"
  mkdir -p "$skill_dir"
  : > "$skill_dir/SKILL.md"
}

# Build a legacy v0.1.x architect-critic layout (no skills/ dir) to confirm
# binary contract — it should still resolve as "absent".
mk_fake_ac_v01_legacy() {
  local root="$1"
  local plugin_dir="$root/marketplace-fake/architect-critic/0.1.3"
  mkdir -p "$plugin_dir"
  : > "$plugin_dir/principles.md"
  # No skills/critiquing-spec/SKILL.md — that's the whole point.
}

# ---------- RETAINED: probe behavior (ai-mentor + superpowers) ----------

test_detect_ai_mentor_present() {
  echo "test_detect_ai_mentor_present:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-foo" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  if [[ "$found" == *"ai-mentor-foo"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ ai-mentor detected: $found"
  else
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor not detected: $found"
  fi
}

test_detect_ai_mentor_absent() {
  echo "test_detect_ai_mentor_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  assert_eq "ai-mentor absent → empty" "" "$found"
}

test_detect_ai_mentor_codex_cache_layout() {
  echo "test_detect_ai_mentor_codex_cache_layout:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/codex-cache/mp/ai-mentor/2.0.0/skills/grill-me"
  : > "$TMP_DIR/codex-cache/mp/ai-mentor/2.0.0/skills/grill-me/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/codex-cache"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  if [[ "$found" == *"ai-mentor"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ ai-mentor detected in Codex cache layout"
  else
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor not detected in Codex cache layout: $found"
  fi
}

test_detect_superpowers() {
  echo "test_detect_superpowers:"
  setup_tmp_repo
  mk_fake_plugin "superpowers" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_superpowers)"
  if [[ "$found" == *"superpowers"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ superpowers detected"
  else
    FAIL=$((FAIL+1)); echo "  ✗ superpowers not detected: $found"
  fi
}

test_detect_brainstorming_available() {
  echo "test_detect_brainstorming_available:"
  setup_tmp_repo
  mk_fake_plugin "superpowers" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local available
  available="$(sf_compose_brainstorming_available)"
  assert_eq "brainstorming available" "true" "$available"
}

test_detect_brainstorming_unavailable() {
  echo "test_detect_brainstorming_unavailable:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local available
  available="$(sf_compose_brainstorming_available)"
  assert_eq "brainstorming unavailable" "false" "$available"
}

test_composition_refresh_with_plugins() {
  echo "test_composition_refresh_with_plugins:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-x" "state.json"
  mk_fake_plugin "superpowers-z" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  assert_file_exists "$path"
  local mentor_installed sp_installed ac_key
  mentor_installed="$(jq -r '.plugins["ai-mentor"].installed' "$path")"
  sp_installed="$(jq -r '.plugins["superpowers"].installed' "$path")"
  # v0.2 contract: ai-mentor + superpowers tracked here; architect-critic NOT
  # (per SPEC §12.2 — detection is filesystem-only).
  ac_key="$(jq -r '.plugins | has("architect-critic")' "$path")"
  if [[ "$mentor_installed" == "true" && "$sp_installed" == "true" && "$ac_key" == "false" ]]; then
    PASS=$((PASS+1)); echo "  ✓ refresh records ai-mentor + superpowers; omits architect-critic"
  else
    FAIL=$((FAIL+1)); echo "  ✗ refresh wrong: mentor=$mentor_installed sp=$sp_installed ac_present=$ac_key"
  fi
}

# PR #27 / Codex #1: scaffold-dev must be detected and recorded so the
# has_scaffold_plugin gate (and the slice-workflow command block) actually fires.
test_detect_scaffold_dev() {
  echo "test_detect_scaffold_dev:"
  setup_tmp_repo
  mk_fake_plugin "scaffold-dev" ".claude-plugin/plugin.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found; found="$(sf_compose_detect_scaffold_dev)"
  if [[ -n "$found" ]]; then PASS=$((PASS+1)); echo "  ✓ scaffold-dev detected"; else FAIL=$((FAIL+1)); echo "  ✗ scaffold-dev not detected"; fi
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  assert_eq "scaffold-dev recorded installed" "true" "$(jq -r '.plugins["scaffold-dev"].installed' "$path")"
  if sf_compose_is_installed "scaffold-dev"; then PASS=$((PASS+1)); echo "  ✓ is_installed scaffold-dev"; else FAIL=$((FAIL+1)); echo "  ✗ is_installed scaffold-dev failed"; fi
}

# The probe must key on the full "scaffold-dev" prefix — a bare "scaffold" prefix
# would false-match scaffold-onboard itself (the original bug surface).
test_detect_scaffold_dev_not_matched_by_onboard() {
  echo "test_detect_scaffold_dev_not_matched_by_onboard:"
  setup_tmp_repo
  mk_fake_plugin "scaffold-onboard" ".claude-plugin/plugin.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  assert_eq "scaffold-onboard must NOT satisfy the scaffold-dev probe" "" "$(sf_compose_detect_scaffold_dev)"
}

test_composition_refresh_no_plugins() {
  echo "test_composition_refresh_no_plugins:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  local mentor_installed
  mentor_installed="$(jq -r '.plugins["ai-mentor"].installed' "$path")"
  assert_eq "ai-mentor absent" "false" "$mentor_installed"
}

test_composition_is_installed_helper() {
  echo "test_composition_is_installed_helper:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  # ai-mentor → installed (helper returns 0); architect-critic absent from
  # composition.json schema in v0.2 → helper returns 1.
  if sf_compose_is_installed "ai-mentor" && ! sf_compose_is_installed "architect-critic"; then
    PASS=$((PASS+1)); echo "  ✓ is_installed helper: ai-mentor=true, architect-critic=false"
  else
    FAIL=$((FAIL+1)); echo "  ✗ is_installed helper returned wrong values"
  fi
}

# ---------- RETAINED: mentor hints (source-aware refresh + sticky overrides) ----------

test_mentor_hint_phase_5() {
  echo "test_mentor_hint_phase_5:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-q" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  if echo "$hint" | grep -q "grill-me"; then
    PASS=$((PASS+1)); echo "  ✓ phase 5 emits /grill-me hint"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 5 hint missing: $hint"
  fi
}

test_mentor_hint_phase_2() {
  echo "test_mentor_hint_phase_2:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-q" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 2)"
  assert_eq "phase 2 no hint" "" "$hint"
}

test_mentor_hint_without_install() {
  echo "test_mentor_hint_without_install:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  assert_eq "no install, no hint" "" "$hint"
}

# ---------- RETAINED: sticky user overrides ----------

test_user_override_disable_mentor() {
  echo "test_user_override_disable_mentor:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  sf_compose_set_override "disable_mentor_suggestions" true
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  assert_eq "override disables hint" "" "$hint"
}

test_user_override_survives_refresh() {
  echo "test_user_override_survives_refresh:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  sf_compose_set_override "disable_critic" true
  sf_compose_refresh  # second refresh — should preserve overrides
  local v
  v="$(jq -r '.user_overrides.disable_critic' "$CLAUDE_PLUGIN_DATA/composition.json")"
  assert_eq "override preserved" "true" "$v"
}

# ---------- RETAINED: jq failure + lock helpers ----------

test_compose_jq_failure_preserves_existing() {
  echo "test_compose_jq_failure_preserves_existing:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins/ai-mentor-x"
  : > "$TMP_DIR/fake-plugins/ai-mentor-x/state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  jq '.sentinel = "preserved"' "$path" > "${path}.new" && mv "${path}.new" "$path"
  mkdir -p "$TMP_DIR/badbin"
  cat > "$TMP_DIR/badbin/jq" <<'BAD_JQ'
#!/bin/sh
exit 1
BAD_JQ
  chmod +x "$TMP_DIR/badbin/jq"
  local rc
  set +e
  PATH="$TMP_DIR/badbin:$PATH" sf_compose_set_override disable_critic true 2>/dev/null
  rc=$?
  set -e 2>/dev/null || true
  if [[ $rc -ne 0 ]] && grep -q '"sentinel"' "$path" 2>/dev/null; then
    PASS=$((PASS+1)); echo "  ✓ jq failure preserved existing composition.json"
  else
    FAIL=$((FAIL+1)); echo "  ✗ jq failure clobbered composition.json (rc=$rc)"
  fi
}

test_compose_concurrent_lock_serializes() {
  echo "test_compose_concurrent_lock_serializes:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-x" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh

  ( sf_compose_set_override disable_critic true ) &
  local pidA=$!
  ( sf_compose_refresh ) &
  local pidB=$!
  wait $pidA $pidB

  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  local v=""
  if jq -e . "$path" > /dev/null 2>&1; then
    v="$(jq -r '.user_overrides.disable_critic // "absent"' "$path")"
  fi
  if [[ "$v" == "true" ]]; then
    PASS=$((PASS+1)); echo "  ✓ composition.json well-formed + override preserved through concurrent writes"
  else
    FAIL=$((FAIL+1)); echo "  ✗ concurrent writes corrupted file or lost override (override=$v)"
  fi
}

# ---------- NEW: critic skill resolution + filesystem probe (per SPEC §12.4) ----------

test_detect_architect_critic_v02_present() {
  echo "test_detect_architect_critic_v02_present:"
  setup_tmp_repo
  mk_fake_ac_v02_cache "$TMP_DIR/ac-cache"
  export SF_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/ac-cache"
  local out rc
  set +e
  out="$(sf_compose_detect_architect_critic)"
  rc=$?
  set -e 2>/dev/null || true
  # Single combined assertion: echo + rc together signal a successful v0.2 probe.
  if [[ "$out" == "v0.2" && "$rc" -eq 0 ]]; then
    PASS=$((PASS+1)); echo "  ✓ v0.2 SKILL.md present → echoes v0.2 + returns 0"
  else
    FAIL=$((FAIL+1)); echo "  ✗ v0.2 probe wrong: out=$out rc=$rc"
  fi
}

test_detect_architect_critic_absent() {
  echo "test_detect_architect_critic_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/ac-cache"
  export SF_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/ac-cache"
  local out rc
  set +e
  out="$(sf_compose_detect_architect_critic)"
  rc=$?
  set -e 2>/dev/null || true
  if [[ "$out" == "absent" && "$rc" -eq 1 ]]; then
    PASS=$((PASS+1)); echo "  ✓ no SKILL.md → echoes absent + returns 1"
  else
    FAIL=$((FAIL+1)); echo "  ✗ absent probe wrong: out=$out rc=$rc"
  fi
}

test_detect_architect_critic_legacy_v01_is_absent() {
  echo "test_detect_architect_critic_legacy_v01_is_absent:"
  # Binary contract: legacy v0.1.x (principles.md only, no skills/ dir) must
  # resolve as "absent" — Skill(architect-critic:critique) can't resolve against
  # v0.1.x anyway, and v0.2 is a hard breaking change per its SPEC §3 NG1.
  setup_tmp_repo
  mk_fake_ac_v01_legacy "$TMP_DIR/ac-cache"
  export SF_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/ac-cache"
  local out rc
  set +e
  out="$(sf_compose_detect_architect_critic)"
  rc=$?
  set -e 2>/dev/null || true
  if [[ "$out" == "absent" && "$rc" -eq 1 ]]; then
    PASS=$((PASS+1)); echo "  ✓ legacy v0.1.x (no skills/) → absent (binary contract)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ legacy fallback leaked: out=$out rc=$rc"
  fi
}

test_resolve_critic_skill_v02() {
  echo "test_resolve_critic_skill_v02:"
  setup_tmp_repo
  mk_fake_ac_v02_cache "$TMP_DIR/ac-cache"
  export SF_COMPOSE_AC_CACHE_DIRS="$TMP_DIR/ac-cache"
  local out
  out="$(sf_compose_resolve_critic_skill)"
  assert_eq "resolves to critiquing-spec when v0.2 present" "critiquing-spec" "$out"
}

# ---------- NEW: marker assertions — SKILL.md bodies reference the helpers ----------

test_onboarding_skill_references_probe_helper() {
  echo "test_onboarding_skill_references_probe_helper:"
  local skill_md
  skill_md="$HERE/../skills/onboarding-project/SKILL.md"
  assert_file_contains "$skill_md" "sf_compose_detect_architect_critic"
}

test_onboarding_skill_references_critiquing_spec() {
  echo "test_onboarding_skill_references_critiquing_spec:"
  local skill_md
  skill_md="$HERE/../skills/onboarding-project/SKILL.md"
  assert_file_contains "$skill_md" "architect-critic:critiquing-spec"
}

test_roadmap_skill_references_probe_helper() {
  echo "test_roadmap_skill_references_probe_helper:"
  local skill_md
  skill_md="$HERE/../skills/planning-project-roadmap/SKILL.md"
  assert_file_contains "$skill_md" "sf_compose_detect_architect_critic"
}

test_roadmap_skill_references_target_roadmap_close() {
  echo "test_roadmap_skill_references_target_roadmap_close:"
  local skill_md
  skill_md="$HERE/../skills/planning-project-roadmap/SKILL.md"
  assert_file_contains "$skill_md" "target=roadmap, depth=close"
}

# Retained (16):
test_detect_ai_mentor_present
test_detect_ai_mentor_absent
test_detect_ai_mentor_codex_cache_layout
test_detect_superpowers
test_detect_brainstorming_available
test_detect_brainstorming_unavailable
test_composition_refresh_with_plugins
test_detect_scaffold_dev
test_detect_scaffold_dev_not_matched_by_onboard
test_composition_refresh_no_plugins
test_composition_is_installed_helper
test_mentor_hint_phase_5
test_mentor_hint_phase_2
test_mentor_hint_without_install
test_user_override_disable_mentor
test_user_override_survives_refresh
test_compose_jq_failure_preserves_existing
test_compose_concurrent_lock_serializes

# New — critic detection (4):
test_detect_architect_critic_v02_present
test_detect_architect_critic_absent
test_detect_architect_critic_legacy_v01_is_absent
test_resolve_critic_skill_v02

# New — marker assertions (4):
test_onboarding_skill_references_probe_helper
test_onboarding_skill_references_critiquing_spec
test_roadmap_skill_references_probe_helper
test_roadmap_skill_references_target_roadmap_close

report_results
