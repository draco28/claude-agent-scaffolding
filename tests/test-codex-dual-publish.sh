#!/usr/bin/env bash
# Validate the Codex v0 dual-publishing contract.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$ROOT/.agents/plugins/marketplace.json"
V0_PLUGINS="ai-mentor architect-critic workspace-init scaffold-onboard scaffold-dev claude-security-audit"
DEFERRED_PLUGINS="scaffold"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

json_get() {
  jq -r "$1" "$2" 2>/dev/null
}

assert_file() {
  if [[ -f "$1" ]]; then pass "$2"; else fail "$2"; fi
}

assert_jq() {
  local expr="$1"
  local file="$2"
  local label="$3"
  if jq -e "$expr" "$file" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

assert_jq_plugin() {
  local plugin="$1"
  local expr="$2"
  local file="$3"
  local label="$4"
  if jq -e --arg p "$plugin" "$expr" "$file" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

printf 'Codex dual-publish contract\n'

assert_file "$MARKETPLACE" "Codex marketplace exists at .agents/plugins/marketplace.json"

if [[ -f "$MARKETPLACE" ]]; then
  assert_jq '.name == "claude-agent-scaffolding-codex"' "$MARKETPLACE" "marketplace has Codex-specific name"
  assert_jq '.interface.displayName == "Claude Agent Scaffolding for Codex"' "$MARKETPLACE" "marketplace has display name"

  for plugin in $V0_PLUGINS; do
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p)' "$MARKETPLACE" "marketplace includes $plugin"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .policy.installation == "AVAILABLE"' "$MARKETPLACE" "$plugin installation policy is AVAILABLE"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .policy.authentication == "ON_INSTALL"' "$MARKETPLACE" "$plugin auth policy is ON_INSTALL"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .source.source == "local"' "$MARKETPLACE" "$plugin source is local"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .source.path == ("./" + $p)' "$MARKETPLACE" "$plugin source path points to top-level plugin directory"
  done

  for plugin in $DEFERRED_PLUGINS; do
    if jq -e --arg p "$plugin" '.plugins[] | select(.name == $p)' "$MARKETPLACE" >/dev/null 2>&1; then
      fail "marketplace excludes deferred/deprecated plugin $plugin"
    else
      pass "marketplace excludes deferred/deprecated plugin $plugin"
    fi
  done
fi

for plugin in $V0_PLUGINS; do
  manifest="$ROOT/$plugin/.codex-plugin/plugin.json"
  assert_file "$manifest" "$plugin Codex manifest exists"
  [[ -f "$manifest" ]] || continue

  assert_jq_plugin "$plugin" '.name == $p' "$manifest" "$plugin manifest name matches directory"
  assert_jq '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$manifest" "$plugin manifest has semver version"
  # Codex manifest version MUST match the Claude manifest — a release bump that
  # touches only .claude-plugin/plugin.json leaves Codex installs on the old
  # version (scaffold-onboard drifted 0.3.3 → through 0.3.4/0.3.5 unnoticed
  # because nothing enforced parity). Guard against silent recurrence.
  claude_manifest="$ROOT/$plugin/.claude-plugin/plugin.json"
  cv="$(json_get '.version' "$claude_manifest")"
  xv="$(json_get '.version' "$manifest")"
  if [[ -n "$cv" && "$cv" == "$xv" ]]; then
    pass "$plugin codex manifest version ($xv) matches claude manifest"
  else
    fail "$plugin codex manifest version ($xv) != claude manifest ($cv)"
  fi
  assert_jq '.skills == "./skills/"' "$manifest" "$plugin manifest exposes skills"
  assert_jq '.interface.displayName | type == "string" and length > 0' "$manifest" "$plugin has displayName"
  assert_jq '.interface.shortDescription | type == "string" and length > 0' "$manifest" "$plugin has shortDescription"
  assert_jq '.interface.longDescription | type == "string" and length > 0' "$manifest" "$plugin has longDescription"
  assert_jq '.interface.developerName | type == "string" and length > 0' "$manifest" "$plugin has developerName"
  assert_jq '.interface.category | type == "string" and length > 0' "$manifest" "$plugin has interface category"
  assert_jq '.interface.capabilities | type == "array" and length > 0' "$manifest" "$plugin declares capabilities"
  assert_jq 'has("hooks") | not' "$manifest" "$plugin manifest omits unsupported hooks field"
  assert_jq 'has("apps") | not' "$manifest" "$plugin manifest omits apps unless .app.json exists"
  assert_jq 'has("mcpServers") | not' "$manifest" "$plugin manifest omits mcpServers unless .mcp.json exists"
done

for plugin in $DEFERRED_PLUGINS; do
  if [[ -f "$ROOT/$plugin/.codex-plugin/plugin.json" ]]; then
    fail "$plugin has no Codex manifest in v0"
  else
    pass "$plugin has no Codex manifest in v0"
  fi
done

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
