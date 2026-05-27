#!/usr/bin/env bash
# Tests for Codex/Claude interoperability helpers.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/agents.sh"
source "$HERE/../lib/routing.sh"
source "$HERE/../lib/interop.sh"

test_agents_merge_preserves_user_content() {
  echo "test_agents_merge_preserves_user_content:"
  setup_tmp_repo
  cat > AGENTS.md <<'EOF'
# Project Agents

Keep this local instruction.
EOF
  sf_agents_merge_managed_section AGENTS.md "$PWD/.workspace/pairing.json"
  assert_file_contains AGENTS.md 'Keep this local instruction'
  assert_file_contains AGENTS.md 'scaffold-onboard:codex:start'
  sf_agents_merge_managed_section AGENTS.md "$PWD/.workspace/pairing.json"
  local count
  count="$(grep -c 'scaffold-onboard:codex:start' AGENTS.md)"
  assert_eq "managed section is replaced, not duplicated" "1" "$count"
}

test_interop_check_then_repair() {
  echo "test_interop_check_then_repair:"
  setup_tmp_workspace_init foo personal no
  cd "$TMP_AI_WORKSPACE"
  set +e
  local before
  before="$(sf_interop_check 2>/dev/null)"
  local rc=$?
  :
  assert_eq "check fails before repair" "1" "$rc"
  if echo "$before" | grep -q 'missing:routing.agents_md'; then
    PASS=$((PASS+1)); echo "  ✓ reports missing routing.agents_md"
  else
    FAIL=$((FAIL+1)); echo "  ✗ missing routing.agents_md not reported: $before"
  fi

  sf_interop_repair >/dev/null
  local after
  after="$(sf_interop_check)"
  assert_eq "check ready after repair" "ready:claude-codex-workspace" "$after"
  assert_file_contains "$TMP_AI_WORKSPACE/AGENTS.md" 'scaffold-onboard:codex:start'
  assert_file_exists "$TMP_AI_WORKSPACE/.workspace/locks"
  local roadmap
  roadmap="$(jq -r '.routing.roadmap' "$TMP_MANIFEST")"
  assert_eq "repair adds routing.roadmap" "canonical" "$roadmap"
}

test_agents_repair_preserves_existing_agents_content() {
  echo "test_agents_repair_preserves_existing_agents_content:"
  setup_tmp_workspace_init bar personal yes
  cd "$TMP_AI_WORKSPACE"
  printf '%s\n' '# Existing AGENTS' 'Do not remove this.' > AGENTS.md
  sf_interop_repair >/dev/null
  assert_file_contains "$TMP_AI_WORKSPACE/AGENTS.md" 'Do not remove this'
  assert_file_contains "$TMP_AI_WORKSPACE/AGENTS.md" 'scaffold-onboard:codex:start'
}

test_agents_merge_preserves_user_content
test_interop_check_then_repair
test_agents_repair_preserves_existing_agents_content

report_results
