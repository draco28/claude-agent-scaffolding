#!/usr/bin/env bash
# Validate the Codex v0 dual-publishing contract.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$ROOT/.agents/plugins/marketplace.json"
CLAUDE_MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
DEFERRED_PLUGINS="scaffold"

# TWO SOURCES, COMPARED — not one source trusted.
#
# This began as a hand-maintained ninth plugin list and was one-directional: a
# plugin added to both marketplaces but missed in the list got zero coverage while
# CI reported ALL GREEN. Deriving the list from the Codex marketplace closed that
# and opened its mirror image — a plugin DELETED from the Codex marketplace simply
# vanished from every loop, and the suite passed while the Claude marketplace and
# the plugin's own manifests still published it.
#
# Neither marketplace can be the sole authority, because the failure being caught
# is one of them disagreeing with the other. So the expectation is derived from the
# Claude marketplace minus the explicitly deferred plugins, the Codex marketplace is
# compared against it as a set, and only that verified set is walked afterwards.
EXPECTED_PLUGINS="$(jq -r --arg deferred "$DEFERRED_PLUGINS" '
  ($deferred | split(" ")) as $skip
  | [.plugins[].name | select(. as $n | $skip | index($n) | not)] | sort | join(" ")
' "$CLAUDE_MARKETPLACE" 2>/dev/null)"
CODEX_PLUGINS="$(jq -r '[.plugins[].name] | sort | join(" ")' "$MARKETPLACE" 2>/dev/null)"
V0_PLUGINS="$EXPECTED_PLUGINS"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

# An empty expectation would make every loop below iterate zero times and report
# ALL GREEN having checked nothing. Fail closed before any of them run.
if [[ -z "${EXPECTED_PLUGINS// /}" ]]; then
  fail "expected plugin set derived from $CLAUDE_MARKETPLACE is non-empty"
  printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
  exit 1
fi
pass "expected plugin set derived from the Claude marketplace ($(printf '%s' "$EXPECTED_PLUGINS" | wc -w | tr -d ' ') plugins, minus deferred)"

# The deferred plugin ships on Claude and deliberately not on Codex, so it must be
# excluded from the expectation rather than assumed absent from it.
for deferred in $DEFERRED_PLUGINS; do
  case " $EXPECTED_PLUGINS " in
    *" $deferred "*) fail "deferred plugin '$deferred' is excluded from the expected Codex set" ;;
    *)               pass "deferred plugin '$deferred' is excluded from the expected Codex set" ;;
  esac
done

# SET PARITY, BOTH DIRECTIONS. Each half catches a different real mistake: a
# missing entry is a plugin that stopped being validated, an extra one is a plugin
# published to Codex that nothing else in the repo knows about.
missing=""; extra=""
for want in $EXPECTED_PLUGINS; do
  case " $CODEX_PLUGINS " in *" $want "*) ;; *) missing="$missing $want" ;; esac
done
for have in $CODEX_PLUGINS; do
  case " $EXPECTED_PLUGINS " in *" $have "*) ;; *) extra="$extra $have" ;; esac
done
if [[ -z "$missing" ]]; then pass "every expected plugin is published to the Codex marketplace"
else fail "every expected plugin is published to the Codex marketplace" "absent from Codex:$missing"; fi
if [[ -z "$extra" ]]; then pass "the Codex marketplace publishes nothing beyond the expected set"
else fail "the Codex marketplace publishes nothing beyond the expected set" "unexpected in Codex:$extra"; fi

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

# --- SKILL.md frontmatter must parse as valid YAML (issue #35) ---
# The repo dual-publishes SKILL.md to Claude Code AND Codex; Codex's loader
# (Ruby Psych) skips any skill whose frontmatter fails to parse. Unquoted
# description: values containing ': ' (colon-space) parse as a nested mapping
# and raise Psych::SyntaxError. Assert every published SKILL.md frontmatter
# block parses. This is a mechanical parse check, not semantic linting.
assert_yaml_frontmatter() {
  local file="$1" label="$2" fm ruby_bin
  # Resolve Ruby via PATH (works with version managers / non-/usr/bin installs, e.g. mise
  # in CI). Preflight Ruby + Psych so a missing toolchain fails loudly rather than masquerading
  # as a YAML parse error.
  ruby_bin="$(command -v ruby || true)"
  if [[ -z "$ruby_bin" ]] || ! "$ruby_bin" -e 'require "psych"' >/dev/null 2>&1; then
    fail "$label (ruby+Psych unavailable on PATH — cannot validate frontmatter)"
    return
  fi
  # Extract the frontmatter block: lines between the first '---' and the next '---'.
  fm="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' "$file")"
  if [[ -z "$fm" ]]; then
    fail "$label (no frontmatter block found)"
    return
  fi
  if printf '%s\n' "$fm" | "$ruby_bin" -ryaml -e 'Psych.parse($stdin.read)' >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
}

for plugin in $V0_PLUGINS; do
  [[ -d "$ROOT/$plugin/skills" ]] || continue
  while IFS= read -r skill_md; do
    skill_name="$(basename "$(dirname "$skill_md")")"
    assert_yaml_frontmatter "$skill_md" "$plugin/$skill_name SKILL.md frontmatter parses as YAML"
  done < <(find "$ROOT/$plugin/skills" -name SKILL.md 2>/dev/null | sort)
done

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
