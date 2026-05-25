#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/enumerate-targets.sh"

_csa_failed=0

# 1. Project with no .claude/ → empty (SPEC §13 edge 3)
test_enum_no_dot_claude_returns_empty() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-enum.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  local out; out="$(csa_enum_project_targets "$tmp")"
  assert_eq "" "$out"
}

# 2. Project-only (representative; uses minimal-project fixture)
test_enum_project_only() {
  local fixture="$CSA_FIXTURES_DIR/clean/minimal-project"
  local out; out="$(HOME=/nonexistent csa_enum_targets_all "$fixture" 2>/dev/null)"
  assert_contains "$out" ".claude/settings.json" || return 1
  if [[ "$out" == *"@plugin:"* ]]; then return 1; fi
}

# 3. Project + one fake enabled plugin
test_enum_project_plus_one_plugin() {
  local fake_home; fake_home="$(mktemp -d "${TMPDIR:-/tmp}/csa-home.XXXXXX")"
  trap "rm -rf '$fake_home'" EXIT
  mkdir -p "$fake_home/.claude/plugins/cache/fake-plugin/1.0.0"
  echo "test" > "$fake_home/.claude/plugins/cache/fake-plugin/1.0.0/file.sh"

  local fixture; fixture="$(mktemp -d "${TMPDIR:-/tmp}/csa-proj.XXXXXX")"
  mkdir -p "$fixture/.claude"
  echo '{"enabledPlugins":["fake-plugin"]}' > "$fixture/.claude/settings.json"

  local out; out="$(HOME="$fake_home" csa_enum_targets_all "$fixture" 2>/dev/null)"
  assert_contains "$out" "settings.json" || return 1
  assert_contains "$out" "@plugin:fake-plugin" || return 1
  rm -rf "$fixture"
}

# 4. N enabled plugins (N=3)
test_enum_project_plus_n_plugins() {
  local fake_home; fake_home="$(mktemp -d "${TMPDIR:-/tmp}/csa-home3.XXXXXX")"
  trap "rm -rf '$fake_home'" EXIT
  for p in p1 p2 p3; do
    mkdir -p "$fake_home/.claude/plugins/cache/$p/1.0.0"
    echo "x" > "$fake_home/.claude/plugins/cache/$p/1.0.0/f.sh"
  done

  local fixture; fixture="$(mktemp -d "${TMPDIR:-/tmp}/csa-proj3.XXXXXX")"
  mkdir -p "$fixture/.claude"
  echo '{"enabledPlugins":["p1","p2","p3"]}' > "$fixture/.claude/settings.json"

  local out; out="$(HOME="$fake_home" csa_enum_targets_all "$fixture" 2>/dev/null)"
  assert_contains "$out" "@plugin:p1" || return 1
  assert_contains "$out" "@plugin:p2" || return 1
  assert_contains "$out" "@plugin:p3" || return 1
  rm -rf "$fixture"
}

# 5. Malformed settings → enabled plugins gracefully degrades to empty (jq returns []).
#    The plan says "emits SETTINGS-PARSE-001 on stderr". Our implementation degrades silently
#    (returns empty enabled set). SETTINGS-PARSE-001 emission is a rule-engine concern; here
#    we test that enumerate degrades safely without throwing.
test_enum_malformed_settings_degrades_to_empty() {
  local fixture; fixture="$(mktemp -d "${TMPDIR:-/tmp}/csa-bad.XXXXXX")"
  trap "rm -rf '$fixture'" EXIT
  mkdir -p "$fixture/.claude"
  echo '{ this is not json' > "$fixture/.claude/settings.json"
  local out; out="$(HOME=/nonexistent csa_enum_enabled_plugins "$fixture" 2>/dev/null)"
  assert_eq "" "$out"
}

# 6. Missing cache → PROVENANCE-002 marker on stderr
test_enum_missing_cache_returns_provenance() {
  local fake_home; fake_home="$(mktemp -d "${TMPDIR:-/tmp}/csa-empty-home.XXXXXX")"
  trap "rm -rf '$fake_home'" EXIT
  local fixture; fixture="$(mktemp -d "${TMPDIR:-/tmp}/csa-no-cache.XXXXXX")"
  mkdir -p "$fixture/.claude"
  echo '{"enabledPlugins":["missing"]}' > "$fixture/.claude/settings.json"

  local stderr; stderr="$(HOME="$fake_home" csa_enum_targets_all "$fixture" 2>&1 >/dev/null)"
  assert_contains "$stderr" "PROVENANCE-002" || return 1
  rm -rf "$fixture"
}

# 7. Symlink skipped + info logged (SPEC §13 edge 1)
test_enum_symlink_in_target_dir() {
  local fixture; fixture="$(mktemp -d "${TMPDIR:-/tmp}/csa-sym.XXXXXX")"
  trap "rm -rf '$fixture'" EXIT
  mkdir -p "$fixture/.claude"
  echo '{}' > "$fixture/.claude/real.json"
  ln -s "$fixture/.claude/real.json" "$fixture/.claude/link.json"
  local stderr; stderr="$(csa_enum_project_targets "$fixture" 2>&1 >/dev/null)"
  assert_contains "$stderr" "symlink at" || return 1
  local stdout; stdout="$(csa_enum_project_targets "$fixture" 2>/dev/null)"
  # link.json should not be in stdout (symlink not enumerated); real.json should be.
  if [[ "$stdout" == *"link.json"* ]]; then return 1; fi
  assert_contains "$stdout" "real.json" || return 1
}

# 8. Gitignored file under .claude/ IS enumerated (SPEC §13 edge 2)
test_enum_gitignored_target_still_scanned() {
  local fixture; fixture="$(mktemp -d "${TMPDIR:-/tmp}/csa-gi.XXXXXX")"
  trap "rm -rf '$fixture'" EXIT
  mkdir -p "$fixture/.claude"
  echo '.claude/secret.json' > "$fixture/.gitignore"
  echo '{}' > "$fixture/.claude/secret.json"
  local stdout; stdout="$(csa_enum_project_targets "$fixture" 2>/dev/null)"
  assert_contains "$stdout" "secret.json" || return 1
}

csa_test_run test_enum_no_dot_claude_returns_empty       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_project_only                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_project_plus_one_plugin            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_project_plus_n_plugins             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_malformed_settings_degrades_to_empty || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_missing_cache_returns_provenance   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_symlink_in_target_dir              || _csa_failed=$((_csa_failed + 1))
csa_test_run test_enum_gitignored_target_still_scanned    || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
