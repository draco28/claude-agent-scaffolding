#!/usr/bin/env bash
# tests/test-e2e.sh — end-to-end lib-API integration tests for scaffold-dev.
#
# Scope: exercises the 11 libs in sequence against fixtures shaped like a
# workspace-init'd dual-repo with scaffold-onboard outputs. Skill bodies are
# NOT invoked here (they require live Claude Code agent dispatch); this file
# tests the lib-API contract the skills compose around.
#
# Layout:
#   T7.1 — minimal sprint fixture (1 sprint × 1 VS × 2 work items)
#   T7.2 — handoff-chain extension (forward + return, sprint cleanup)
#   T7.3 — composition extension (architect-critic + ai-mentor detection)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/worktree.sh"
source "$HERE/../lib/verify.sh"
source "$HERE/../lib/harvest.sh"
source "$HERE/../lib/merge.sh"
source "$HERE/../lib/handoff.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/compose.sh"

PLUGIN_ROOT="$HERE/.."
FIXTURE_MIN="$PLUGIN_ROOT/fixtures/sprint-fixture-minimal"

# setup_test_workspace — bootstrap a dual-repo workspace from the minimal
# fixture. Mirrors workspace-init + scaffold-onboard outputs:
#   - canonical: git repo with main branch + initial README commit
#   - ai-workspace: .workspace/pairing.json, docs/MASTER-SPEC.md,
#                   .claude/memory-bank/{05-active-context,03-code-patterns}.md
#   - canonical: docs/ROADMAP.md
# Exports the same TMP_AI_WORKSPACE / TMP_CANONICAL / TMP_MANIFEST as
# setup_tmp_workspace; adds TMP_SLICE_DIR for the sprint-1 slice spec dir.
setup_test_workspace() {
  setup_tmp_workspace "fixmin"

  # Memory bank — seed 05-active-context with an initial cursor and the
  # 03-code-patterns from the fixture.
  local mb="$TMP_AI_WORKSPACE/.claude/memory-bank"
  mkdir -p "$mb"
  cat > "$mb/05-active-context.md" <<'EOF'
# Active context

<!-- sd:cursor:start -->
```json
{"sprint":"1","slice":"VS-1.1","work_item":"1.01"}
```
<!-- sd:cursor:end -->
EOF
  cp "$FIXTURE_MIN/03-code-patterns.md" "$mb/03-code-patterns.md"

  # MASTER-SPEC under ai_workspace/docs/
  mkdir -p "$TMP_AI_WORKSPACE/docs"
  cp "$FIXTURE_MIN/MASTER-SPEC.md" "$TMP_AI_WORKSPACE/docs/MASTER-SPEC.md"

  # ROADMAP under canonical/docs/ (routing.roadmap == "canonical")
  mkdir -p "$TMP_CANONICAL/docs"
  cp "$FIXTURE_MIN/ROADMAP.md" "$TMP_CANONICAL/docs/ROADMAP.md"

  # Sprint slice dir under ai_workspace (per during_dev.sprint_dir_template).
  TMP_SLICE_DIR="$TMP_AI_WORKSPACE/docs/specs/sprint-1/VS-1.1"
  mkdir -p "$TMP_SLICE_DIR"

  # Patch the manifest's routing.roadmap so sd_manifest_get .routing.roadmap
  # returns the canonical-side relative shape we assert in test 2. The default
  # value from setup_tmp_workspace is "canonical" (a routing-key string), which
  # is what the test asserts.
}

# ---------------------------------------------------------------------------
# T7.1 — minimal sprint fixture (12 assertions)
# ---------------------------------------------------------------------------

test_e2e_minimal_sprint() {
  echo "test_e2e_minimal_sprint:"
  setup_test_workspace
  cd "$TMP_AI_WORKSPACE"

  # Assertion 1 — manifest discovery walks up to .workspace/pairing.json
  local manifest
  manifest="$(sd_manifest_discover)"
  assert_eq "manifest discovered" "$TMP_MANIFEST" "$manifest"

  # Assertion 2 — routing.roadmap reads from manifest
  local roadmap_route
  roadmap_route="$(sd_manifest_get '.routing.roadmap')"
  assert_eq "routing.roadmap == canonical" "canonical" "$roadmap_route"

  # Assertion 3 — initial cursor read from seeded 05-active-context.md
  local cursor sprint
  cursor="$(sd_state_read_cursor)"
  sprint="$(echo "$cursor" | jq -r .sprint)"
  assert_eq "initial cursor sprint == 1" "1" "$sprint"

  # Assertion 4 — sd_worktree_add for work-item 1.01 creates the expected path
  local wt1
  wt1="$(sd_worktree_add "1.01" "VS-1.1" "init-models" 2>/dev/null)"
  assert_eq "wt1 path" "$TMP_CANONICAL/.worktrees/work-1.01-init-models" "$wt1"

  # Assertion 5 — branch name follows the manifest template
  local branches1
  branches1="$(git -C "$TMP_CANONICAL" branch --format='%(refname:short)')"
  assert_contains "branch1 matches template" "slice/sprint-1.1-work-1.01-init-models" "$branches1"

  # Simulate implementer-agent: touch a file in the worktree and stage it.
  echo "Item = struct" > "$wt1/item.txt"
  git -C "$wt1" add item.txt

  # Assertion 6 — sd_verify_auto_step on a passing auto: line
  set +e
  sd_verify_auto_step '- [ ] auto: `true` -> expected: exit 0'
  local vrc=$?
  :
  assert_eq "verify auto-step pass" "0" "$vrc"

  # Drop a report.md under the slice dir for work-item 1.01 with a
  # "Suggestions for memory bank" entry.
  local wi_dir="$TMP_SLICE_DIR/work-1.01-init-models"
  mkdir -p "$wi_dir"
  cat > "$wi_dir/report.md" <<'EOF'
# Report — work-1.01

## Suggestions for memory bank

- target_file: 03-code-patterns.md
  suggestion: Prefer foo() over legacy_foo() — see issue #42.
EOF

  # Assertion 7 — sd_harvest_reports surfaces the seeded suggestion
  local harvested
  harvested="$(sd_harvest_reports "$TMP_SLICE_DIR")"
  local h_count
  h_count="$(echo "$harvested" | jq 'length')"
  assert_eq "harvest_reports count == 1" "1" "$h_count"

  # Assertion 8 — sd_harvest_handoffs returns empty (no handoffs in fixture)
  local h2
  h2="$(sd_harvest_handoffs "VS-1.1")"
  assert_eq "harvest_handoffs empty" "[]" "$h2"

  # Assertion 9 — sd_merge_work_item merges branch into main
  local branch1="slice/sprint-1.1-work-1.01-init-models"
  set +e
  sd_merge_work_item "$wt1" "$branch1" >/dev/null 2>&1
  local mrc=$?
  :
  assert_eq "merge wi1 returns 0" "0" "$mrc"

  # Clean up worktree 1
  sd_worktree_remove "$wt1" >/dev/null 2>&1

  # Repeat for work-item 1.02 — second iteration
  local wt2
  wt2="$(sd_worktree_add "1.02" "VS-1.1" "list-items" 2>/dev/null)"
  echo "list_items = fn" > "$wt2/list.txt"
  git -C "$wt2" add list.txt
  local branch2="slice/sprint-1.1-work-1.02-list-items"
  sd_merge_work_item "$wt2" "$branch2" >/dev/null 2>&1
  sd_worktree_remove "$wt2" >/dev/null 2>&1

  # Assertion 10 — canonical now has 5 commits on main:
  #   initial + 2*(work-item commit + --no-ff merge commit)
  local commit_count
  commit_count="$(git -C "$TMP_CANONICAL" rev-list --count main)"
  assert_eq "main has 5 commits (initial + 2*(impl + merge))" "5" "$commit_count"

  # Assertion 11 — both worktrees removed (only canonical's main checkout remains)
  local wt_list_count
  wt_list_count="$(git -C "$TMP_CANONICAL" worktree list | wc -l | tr -d ' ')"
  assert_eq "worktree list count == 1" "1" "$wt_list_count"

  # Assertion 12 — manifest still readable after the full cycle
  local manifest2
  manifest2="$(sd_manifest_discover)"
  assert_eq "manifest still discoverable" "$TMP_MANIFEST" "$manifest2"
}

test_e2e_minimal_sprint

sd_test_summary
