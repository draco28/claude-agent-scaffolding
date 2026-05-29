#!/usr/bin/env bash
# Tests for lib/roadmap.sh — project-roadmap.json CRUD + ROADMAP.md rendering.
# Per SPEC §7 (scaffold-onboard v0.2) + PLAN T3.2.
#
# Coverage map (25 assertions targeted; lands at ~28):
#   - Base CRUD (5)
#   - Render + ID convention + idempotence (5)
#   - Re-run protocol modes — SPEC §7.5 (8)
#   - Size-class detection — SPEC §7.3 (6)
#   - Mutations array (6)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/routing.sh"
source "$HERE/../lib/roadmap.sh"

ANCHOR_DIR="$HERE"

# Per-test setup: fresh CLAUDE_PLUGIN_DATA + cwd outside any manifest tree.
# (Each test calls teardown_roadmap before exit.)
setup_roadmap() {
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  TMP_DIR="$(mktemp -d -t scaffold-onboard-roadmap.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo"
  # Guard against ancestor pairing.json (would bend manifest-routing behavior).
  local probe="$TMP_DIR" has=0
  while [[ "$probe" != "/" ]]; do
    [[ -f "$probe/.workspace/pairing.json" ]] && { has=1; break; }
    probe="$(dirname "$probe")"
  done
  if [[ "$has" == "1" ]]; then
    echo "  ! warning: ancestor pairing.json found; routing tests will pick that up" >&2
  fi
}

teardown_roadmap() {
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  TMP_DIR=""
}

# ============================================================================
# Base CRUD (5 assertions)
# ============================================================================

test_state_init_creates_schema() {
  echo "test_state_init_creates_schema:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  local path; path="$(sf_roadmap_state_path)"
  assert_file_exists "$path"
  # 1 — schema_version present
  local sv; sv="$(jq -r '.schema_version' "$path")"
  assert_eq "schema_version is 1" "1" "$sv"
  # 2 — empty arrays
  local phases_len sprints_len slices_len muts_len
  phases_len="$(jq -r '.phases | length' "$path")"
  sprints_len="$(jq -r '.sprints | length' "$path")"
  slices_len="$(jq -r '.vertical_slices | length' "$path")"
  muts_len="$(jq -r '.mutations | length' "$path")"
  assert_eq "phases/sprints/slices/mutations all empty arrays" "0 0 0 0" \
    "$phases_len $sprints_len $slices_len $muts_len"
  teardown_roadmap
}

test_write_phase_appends() {
  echo "test_write_phase_appends:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "Lay the platform groundwork"
  local path; path="$(sf_roadmap_state_path)"
  local name; name="$(jq -r '.phases[0].name' "$path")"
  local horizon; horizon="$(jq -r '.phases[0].horizon' "$path")"
  # 3 — phase entry written
  assert_eq "phases[0].name == Foundation" "Foundation" "$name"
  assert_eq "phases[0].horizon == Q3 2026" "Q3 2026" "$horizon"
  teardown_roadmap
}

test_write_sprint_appends_with_phase_id() {
  echo "test_write_sprint_appends_with_phase_id:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "..."
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "Stand up CI + first deploy"
  local path; path="$(sf_roadmap_state_path)"
  local sid pid name
  sid="$(jq -r '.sprints[0].id' "$path")"
  pid="$(jq -r '.sprints[0].phase_id' "$path")"
  name="$(jq -r '.sprints[0].name' "$path")"
  # 4 — sprint id + phase_id + name
  assert_eq "sprint id/phase_id/name correct" "1.1|1|Bootstrap" "$sid|$pid|$name"
  teardown_roadmap
}

test_write_slice_appends_with_sprint_id() {
  echo "test_write_slice_appends_with_sprint_id:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "..."
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "..."
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "First deploy" "Pipeline → preview env"
  local path; path="$(sf_roadmap_state_path)"
  local id spid name
  id="$(jq -r '.vertical_slices[0].id' "$path")"
  spid="$(jq -r '.vertical_slices[0].sprint_id' "$path")"
  name="$(jq -r '.vertical_slices[0].name' "$path")"
  # 5 — slice id + sprint_id + name
  assert_eq "slice id/sprint_id/name correct" "VS-1.1.1|1.1|First deploy" "$id|$spid|$name"
  teardown_roadmap
}

test_write_slice_accepts_trace_arrays() {
  echo "test_write_slice_accepts_trace_arrays:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "..."
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "..."
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "First deploy" "Pipeline → preview env" \
    '["FR-1","FR-2"]' '["NFR-1"]' '["BACKLOG-1"]'
  local path; path="$(sf_roadmap_state_path)"
  local traces
  traces="$(jq -r '.vertical_slices[0] | (.traces_fr | join(",")) + "|" + (.traces_nfr | join(",")) + "|" + (.traces_backlog | join(","))' "$path")"
  assert_eq "trace arrays stored on slice" "FR-1,FR-2|NFR-1|BACKLOG-1" "$traces"
  teardown_roadmap
}

test_write_slice_preserves_traces_when_legacy_update_omits_them() {
  echo "test_write_slice_preserves_traces_when_legacy_update_omits_them:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "..."
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "..."
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "First deploy" "Pipeline → preview env" \
    '["FR-1"]' '["NFR-1"]' '["BACKLOG-1"]'
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "Renamed deploy" "Updated summary"
  local path; path="$(sf_roadmap_state_path)"
  local traces name
  name="$(jq -r '.vertical_slices[0].name' "$path")"
  traces="$(jq -r '.vertical_slices[0] | (.traces_fr | join(",")) + "|" + (.traces_nfr | join(",")) + "|" + (.traces_backlog | join(","))' "$path")"
  assert_eq "legacy update still updates slice name" "Renamed deploy" "$name"
  assert_eq "legacy update preserves trace arrays" "FR-1|NFR-1|BACKLOG-1" "$traces"
  teardown_roadmap
}

test_checkpoint_set_get_roundtrip() {
  echo "test_checkpoint_set_get_roundtrip:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.B"
  local got; got="$(sf_roadmap_read_checkpoint)"
  # 6 — checkpoint set→get round-trip
  assert_eq "checkpoint round-trip R1.B" "R1.B" "$got"
  teardown_roadmap
}

# ============================================================================
# Render + ID convention (5 assertions)
# ============================================================================

# Helper: seed a small valid state (1 phase, 1 sprint, 1 slice) for render tests.
_seed_minimal_state() {
  sf_roadmap_state_init "$1"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "Platform groundwork"
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "Stand up CI + first deploy"
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "First deploy" "Pipeline → preview env"
}

test_render_writes_roadmap_md() {
  echo "test_render_writes_roadmap_md:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  # Render — no manifest in this tree, so output lands at cwd/ROADMAP.md
  sf_roadmap_render
  # 7 — file created
  assert_file_exists "ROADMAP.md"
  teardown_roadmap
}

# #20 — H1 carries the project name (no empty "# ROADMAP — ") and the overview
# never ships the literal angle-bracket stub.
test_render_h1_has_project_name() {
  echo "test_render_h1_has_project_name:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  sf_roadmap_render
  assert_file_contains "ROADMAP.md" '^# demo-proj — Roadmap$'
  teardown_roadmap
}

test_render_no_overview_stub() {
  echo "test_render_no_overview_stub:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  sf_roadmap_render
  if grep -q '3-paragraph summary of project shape' "ROADMAP.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ literal overview stub still present"
  else
    PASS=$((PASS+1)); echo "  ✓ no literal overview stub"
  fi
  teardown_roadmap
}

test_render_contains_phase_heading() {
  echo "test_render_contains_phase_heading:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  sf_roadmap_render
  # 8 — Phase heading at level 2
  assert_file_contains "ROADMAP.md" '^## Phase 1: Foundation'
  teardown_roadmap
}

test_render_contains_sprint_heading() {
  echo "test_render_contains_sprint_heading:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  sf_roadmap_render
  # 9 — Sprint heading at level 3
  assert_file_contains "ROADMAP.md" '^### Sprint 1.1: Bootstrap'
  teardown_roadmap
}

test_render_contains_slice_heading() {
  echo "test_render_contains_slice_heading:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  sf_roadmap_render
  # 10 — VS heading at level 4
  assert_file_contains "ROADMAP.md" '^#### VS-1.1.1: First deploy'
  teardown_roadmap
}

test_render_contains_traceability_block() {
  echo "test_render_contains_traceability_block:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "Platform groundwork"
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "Stand up CI + first deploy"
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "First deploy" "Pipeline → preview env" \
    '["FR-1"]' '["NFR-1"]' '["BACKLOG-1"]'
  sf_roadmap_render
  assert_file_contains "ROADMAP.md" "##### Traceability"
  assert_file_contains "ROADMAP.md" "FR: FR-1"
  assert_file_contains "ROADMAP.md" "NFR: NFR-1"
  assert_file_contains "ROADMAP.md" "Backlog: BACKLOG-1"
  teardown_roadmap
}

test_traceability_report_lists_covered_and_unassigned() {
  echo "test_traceability_report_lists_covered_and_unassigned:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  mkdir -p docs
  cat > docs/SRS.md <<'EOF'
# SRS
- **FR-1** — First requirement.
- **FR-2** — Second requirement.
- **NFR-1** — First non-functional requirement.
- **NFR-2** — Second non-functional requirement.
EOF
  cat > docs/BACKLOG.md <<'EOF'
# Backlog
### BACKLOG-1 — First story
### BACKLOG-2 — Second story
EOF
  sf_roadmap_write_phase 1 "Foundation" "Q3 2026" "Platform groundwork"
  sf_roadmap_write_sprint "1.1" 1 "Bootstrap" "Stand up CI + first deploy"
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "First deploy" "Pipeline → preview env" \
    '["FR-1"]' '["NFR-1"]' '["BACKLOG-1"]'
  local report
  report="$(sf_roadmap_traceability_report)"
  case "$report" in
    *"FR-1: VS-1.1.1"*) PASS=$((PASS+1)); echo "  ✓ covered FR listed" ;;
    *) FAIL=$((FAIL+1)); echo "  ✗ covered FR missing"; printf '%s\n' "$report" | sed 's/^/    /' ;;
  esac
  case "$report" in
    *"FR-2: unassigned"*) PASS=$((PASS+1)); echo "  ✓ unassigned FR listed" ;;
    *) FAIL=$((FAIL+1)); echo "  ✗ unassigned FR missing"; printf '%s\n' "$report" | sed 's/^/    /' ;;
  esac
  case "$report" in
    *"NFR-1: VS-1.1.1"*) PASS=$((PASS+1)); echo "  ✓ covered NFR listed" ;;
    *) FAIL=$((FAIL+1)); echo "  ✗ covered NFR missing"; printf '%s\n' "$report" | sed 's/^/    /' ;;
  esac
  case "$report" in
    *"BACKLOG-2: unassigned"*) PASS=$((PASS+1)); echo "  ✓ unassigned backlog listed" ;;
    *) FAIL=$((FAIL+1)); echo "  ✗ unassigned backlog missing"; printf '%s\n' "$report" | sed 's/^/    /' ;;
  esac
  teardown_roadmap
}

test_render_idempotent_no_diff() {
  echo "test_render_idempotent_no_diff:"
  setup_roadmap
  _seed_minimal_state "demo-proj"
  sf_roadmap_render
  cp ROADMAP.md ROADMAP.md.first
  sf_roadmap_render
  # 11 — Second render byte-identical to first
  if diff -q ROADMAP.md ROADMAP.md.first >/dev/null; then
    PASS=$((PASS+1)); echo "  ✓ second render byte-identical to first"
  else
    FAIL=$((FAIL+1)); echo "  ✗ re-render diverged:"; diff ROADMAP.md ROADMAP.md.first | sed 's/^/    /'
  fi
  teardown_roadmap
}

# ============================================================================
# Re-run protocol — SPEC §7.5 (8 assertions)
# ============================================================================

test_rerun_mode_no_state_is_initial() {
  echo "test_rerun_mode_no_state_is_initial:"
  setup_roadmap
  # No state file at all.
  local mode; mode="$(sf_roadmap_detect_rerun_mode)"
  # 12
  assert_eq "no state → initial" "initial" "$mode"
  teardown_roadmap
}

test_rerun_mode_add_phase() {
  echo "test_rerun_mode_add_phase:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  local mode; mode="$(sf_roadmap_detect_rerun_mode --add-phase)"
  # 13
  assert_eq "checkpoint=R1.C-complete + --add-phase → add-phase" "add-phase" "$mode"
  teardown_roadmap
}

test_rerun_mode_add_sprint() {
  echo "test_rerun_mode_add_sprint:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  local mode; mode="$(sf_roadmap_detect_rerun_mode --add-sprint 1)"
  # 14
  assert_eq "checkpoint=R1.C-complete + --add-sprint 1 → add-sprint" "add-sprint" "$mode"
  teardown_roadmap
}

test_rerun_mode_add_slice() {
  echo "test_rerun_mode_add_slice:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  local mode; mode="$(sf_roadmap_detect_rerun_mode --add-slice 1.1)"
  # 15
  assert_eq "checkpoint=R1.C-complete + --add-slice 1.1 → add-slice" "add-slice" "$mode"
  teardown_roadmap
}

test_rerun_mode_refine_slice() {
  echo "test_rerun_mode_refine_slice:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  local mode; mode="$(sf_roadmap_detect_rerun_mode --refine-slice VS-1.1.1)"
  # 16
  assert_eq "checkpoint=R1.C-complete + --refine-slice VS-1.1.1 → refine-slice" "refine-slice" "$mode"
  teardown_roadmap
}

test_rerun_mode_reorganize() {
  echo "test_rerun_mode_reorganize:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  local mode; mode="$(sf_roadmap_detect_rerun_mode --reorganize)"
  # 17
  assert_eq "checkpoint=R1.C-complete + --reorganize → reorganize" "reorganize" "$mode"
  teardown_roadmap
}

test_rerun_mode_reorganize_no_state_fails() {
  echo "test_rerun_mode_reorganize_no_state_fails:"
  setup_roadmap
  # No state file. --reorganize without prior state is defensive-reject (T1.4 default).
  local out rc
  set +e
  out="$(sf_roadmap_detect_rerun_mode --reorganize 2>/dev/null)"
  rc=$?
  set -e 2>/dev/null || true
  # 18 — return code 1 (defensive default)
  assert_eq "no state + --reorganize → rc=1" "1" "$rc"
  teardown_roadmap
}

test_rerun_mode_no_flag_with_state_is_initial() {
  echo "test_rerun_mode_no_flag_with_state_is_initial:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  # No flags. Behavior choice (per task spec): echo "initial" (skill body will
  # prompt user to disambiguate; helper defaults conservatively).
  local mode; mode="$(sf_roadmap_detect_rerun_mode)"
  # 19
  assert_eq "state present + no flags → initial (skill body re-prompts)" "initial" "$mode"
  teardown_roadmap
}

# ============================================================================
# Size-class detection — SPEC §7.3 (6 assertions)
# ============================================================================

test_count_nodes_empty_state() {
  echo "test_count_nodes_empty_state:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  local n; n="$(sf_roadmap_count_nodes)"
  # 20
  assert_eq "empty state → 0 nodes" "0" "$n"
  teardown_roadmap
}

test_count_nodes_phases_only() {
  echo "test_count_nodes_phases_only:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "P1" "..." "..."
  sf_roadmap_write_phase 2 "P2" "..." "..."
  sf_roadmap_write_phase 3 "P3" "..." "..."
  sf_roadmap_write_phase 4 "P4" "..." "..."
  local n; n="$(sf_roadmap_count_nodes)"
  # 21 — counts at least phases (could be phases-only if no sprints; or estimate)
  assert_eq "4 phases (no sprints/slices) → 4 nodes" "4" "$n"
  teardown_roadmap
}

test_count_nodes_phases_and_sprints() {
  echo "test_count_nodes_phases_and_sprints:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "P1" "..." "..."
  sf_roadmap_write_phase 2 "P2" "..." "..."
  sf_roadmap_write_sprint "1.1" 1 "S1" "..."
  sf_roadmap_write_sprint "1.2" 1 "S2" "..."
  sf_roadmap_write_sprint "2.1" 2 "S3" "..."
  local n; n="$(sf_roadmap_count_nodes)"
  # 22 — 2 phases + 3 sprints = 5 nodes
  assert_eq "2 phases + 3 sprints → 5 nodes" "5" "$n"
  teardown_roadmap
}

test_count_nodes_full_hierarchy() {
  echo "test_count_nodes_full_hierarchy:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  # 4 phases × 3 sprints × 4 slices = 4+12+48 = 64 nodes
  local p s k
  for p in 1 2 3 4; do
    sf_roadmap_write_phase "$p" "P$p" "..." "..."
    for s in 1 2 3; do
      sf_roadmap_write_sprint "$p.$s" "$p" "S$p.$s" "..."
      for k in 1 2 3 4; do
        sf_roadmap_write_slice "VS-$p.$s.$k" "$p.$s" "VS$p.$s.$k" "..."
      done
    done
  done
  local n; n="$(sf_roadmap_count_nodes)"
  # 23 — exact count 4+12+48 = 64
  assert_eq "4 phases × 3 sprints × 4 slices → 64 nodes" "64" "$n"
  teardown_roadmap
}

test_size_class_large_above_50() {
  echo "test_size_class_large_above_50:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  # 60 nodes → "large" per SPEC §7.3 (>50 triggers continue/split/reduce prompt)
  local p s k
  for p in 1 2 3 4; do
    sf_roadmap_write_phase "$p" "P$p" "..." "..."
    for s in 1 2 3; do
      sf_roadmap_write_sprint "$p.$s" "$p" "S$p.$s" "..."
      for k in 1 2 3 4; do
        sf_roadmap_write_slice "VS-$p.$s.$k" "$p.$s" "VS$p.$s.$k" "..."
      done
    done
  done
  # Above: 4+12+48 = 64 (>50, <100)
  local class; class="$(sf_roadmap_size_class)"
  # 24
  assert_eq "64 nodes → size class 'large'" "large" "$class"
  teardown_roadmap
}

test_size_class_split_above_100() {
  echo "test_size_class_split_above_100:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  # Need >100 nodes. 5 phases × 4 sprints × 5 slices = 5+20+100 = 125
  local p s k
  for p in 1 2 3 4 5; do
    sf_roadmap_write_phase "$p" "P$p" "..." "..."
    for s in 1 2 3 4; do
      sf_roadmap_write_sprint "$p.$s" "$p" "S$p.$s" "..."
      for k in 1 2 3 4 5; do
        sf_roadmap_write_slice "VS-$p.$s.$k" "$p.$s" "VS$p.$s.$k" "..."
      done
    done
  done
  # 5+20+100 = 125 (>100)
  local class; class="$(sf_roadmap_size_class)"
  # 25
  assert_eq "125 nodes → size class 'split'" "split" "$class"
  teardown_roadmap
}

test_size_class_normal_below_50() {
  echo "test_size_class_normal_below_50:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  # 4 phases × 2 sprints × 3 slices = 4+8+24 = 36 (<50)
  local p s k
  for p in 1 2 3 4; do
    sf_roadmap_write_phase "$p" "P$p" "..." "..."
    for s in 1 2; do
      sf_roadmap_write_sprint "$p.$s" "$p" "S$p.$s" "..."
      for k in 1 2 3; do
        sf_roadmap_write_slice "VS-$p.$s.$k" "$p.$s" "VS$p.$s.$k" "..."
      done
    done
  done
  local class; class="$(sf_roadmap_size_class)"
  # 26
  assert_eq "36 nodes → size class 'normal'" "normal" "$class"
  teardown_roadmap
}

# ============================================================================
# Mutations array (6 assertions)
# ============================================================================

test_mutations_empty_on_init() {
  echo "test_mutations_empty_on_init:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  local path; path="$(sf_roadmap_state_path)"
  local len; len="$(jq -r '.mutations | length' "$path")"
  # 27
  assert_eq "mutations empty after init" "0" "$len"
  teardown_roadmap
}

test_mutation_append_adds_entry() {
  echo "test_mutation_append_adds_entry:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_add_mutation "add-slice" "VS-1.1.3" "Emerged from VS-1.1.2 closing"
  local path; path="$(sf_roadmap_state_path)"
  local len; len="$(jq -r '.mutations | length' "$path")"
  # 28
  assert_eq "one mutation after append" "1" "$len"
  teardown_roadmap
}

test_mutation_entry_has_required_fields() {
  echo "test_mutation_entry_has_required_fields:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_add_mutation "add-slice" "VS-1.1.3" "Emerged from VS-1.1.2"
  local path; path="$(sf_roadmap_state_path)"
  local mode target note ts
  mode="$(jq -r '.mutations[0].mode' "$path")"
  target="$(jq -r '.mutations[0].target' "$path")"
  note="$(jq -r '.mutations[0].note' "$path")"
  ts="$(jq -r '.mutations[0].timestamp' "$path")"
  # 29 — all four fields populated
  local fields_ok=1
  [[ "$mode" == "add-slice" ]]              || fields_ok=0
  [[ "$target" == "VS-1.1.3" ]]             || fields_ok=0
  [[ "$note" == "Emerged from VS-1.1.2" ]]  || fields_ok=0
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || fields_ok=0
  if [[ "$fields_ok" == "1" ]]; then
    PASS=$((PASS+1)); echo "  ✓ mutation has mode/target/note/timestamp"
  else
    FAIL=$((FAIL+1))
    echo "  ✗ mutation field check failed: mode='$mode' target='$target' note='$note' ts='$ts'"
  fi
  teardown_roadmap
}

test_mutations_accumulate_in_order() {
  echo "test_mutations_accumulate_in_order:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_add_mutation "add-phase"  "Phase 5"   "Scope grew"
  sf_roadmap_add_mutation "add-sprint" "Sprint 2.3" "Mid-phase insertion"
  sf_roadmap_add_mutation "refine-slice" "VS-2.1.1" "Better demo criteria"
  local path; path="$(sf_roadmap_state_path)"
  local len modes
  len="$(jq -r '.mutations | length' "$path")"
  modes="$(jq -r '[.mutations[].mode] | join(",")' "$path")"
  # 30 — 3 entries in insertion order
  assert_eq "3 mutations in order" "3|add-phase,add-sprint,refine-slice" "$len|$modes"
  teardown_roadmap
}

# For the "initial-mode write_slice does NOT add mutation" / "non-initial DOES":
# the SPEC says non-initial-mode WRITES append mutations. The lib does NOT
# auto-append from write_slice (skill body explicitly calls sf_roadmap_add_mutation
# in non-initial mode). Test that:
#   (a) write_slice alone never auto-appends (always — that's the contract)
#   (b) explicit add_mutation does append
# This matches the lib being a pure CRUD layer + skill body managing mutation logic.

test_write_slice_never_auto_appends_mutation() {
  echo "test_write_slice_never_auto_appends_mutation:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_write_phase 1 "P1" "..." "..."
  sf_roadmap_write_sprint "1.1" 1 "S1" "..."
  sf_roadmap_write_slice "VS-1.1.1" "1.1" "Slice1" "..."
  local path; path="$(sf_roadmap_state_path)"
  local len; len="$(jq -r '.mutations | length' "$path")"
  # 31 — write_slice during init does NOT auto-append to mutations
  assert_eq "write_slice in initial mode → mutations still empty" "0" "$len"
  teardown_roadmap
}

test_write_slice_plus_explicit_mutation_logs_audit() {
  echo "test_write_slice_plus_explicit_mutation_logs_audit:"
  setup_roadmap
  sf_roadmap_state_init "demo-proj"
  sf_roadmap_set_checkpoint "R1.C-complete"
  sf_roadmap_write_phase 1 "P1" "..." "..."
  sf_roadmap_write_sprint "1.1" 1 "S1" "..."
  # Simulate "add-slice" mode: skill writes the slice AND logs the mutation.
  sf_roadmap_write_slice "VS-1.1.3" "1.1" "Emerged" "From VS-1.1.2 closing"
  sf_roadmap_add_mutation "add-slice" "VS-1.1.3" "Emerged from VS-1.1.2 closing"
  local path; path="$(sf_roadmap_state_path)"
  local slices_len muts_len
  slices_len="$(jq -r '.vertical_slices | length' "$path")"
  muts_len="$(jq -r '.mutations | length' "$path")"
  # 32 — non-initial-mode write+mutation pair logged correctly
  assert_eq "slice written + mutation logged" "1|1" "$slices_len|$muts_len"
  teardown_roadmap
}

test_project_scoped_roadmap_paths_differ() {
  echo "test_project_scoped_roadmap_paths_differ:"
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  TMP_DIR="$(mktemp -d -t scaffold-onboard-roadmap-project.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a" "$TMP_DIR/project-b"
  git -C "$TMP_DIR/project-a" init -q
  git -C "$TMP_DIR/project-b" init -q
  cd "$TMP_DIR/project-a"
  local path_a
  path_a="$(sf_roadmap_state_path)"
  cd "$TMP_DIR/project-b"
  local path_b
  path_b="$(sf_roadmap_state_path)"
  if [[ "$path_a" != "$path_b" ]]; then
    PASS=$((PASS+1)); echo "  ✓ two projects get different roadmap state paths"
  else
    FAIL=$((FAIL+1)); echo "  ✗ project roadmap paths collide: $path_a"
  fi
  teardown_roadmap
}

test_project_scoped_roadmap_writes_are_isolated() {
  echo "test_project_scoped_roadmap_writes_are_isolated:"
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  TMP_DIR="$(mktemp -d -t scaffold-onboard-roadmap-project.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a" "$TMP_DIR/project-b"
  git -C "$TMP_DIR/project-a" init -q
  git -C "$TMP_DIR/project-b" init -q
  cd "$TMP_DIR/project-a"
  sf_roadmap_state_init "project-a"
  sf_roadmap_write_phase 1 "A Phase" "Q3" "A summary"
  cd "$TMP_DIR/project-b"
  sf_roadmap_state_init "project-b"
  sf_roadmap_write_phase 1 "B Phase" "Q4" "B summary"
  local b_name
  b_name="$(jq -r '.phases[0].name' "$(sf_roadmap_state_path)")"
  cd "$TMP_DIR/project-a"
  local a_name
  a_name="$(jq -r '.phases[0].name' "$(sf_roadmap_state_path)")"
  assert_eq "project A roadmap remains isolated" "A Phase" "$a_name"
  assert_eq "project B roadmap remains isolated" "B Phase" "$b_name"
  teardown_roadmap
}

test_roadmap_state_init_records_project_root() {
  echo "test_roadmap_state_init_records_project_root:"
  setup_roadmap
  local root
  root="$(sf_project_identity_root)"
  sf_roadmap_state_init "demo-proj"
  local got
  got="$(jq -r '.project_root' "$(sf_roadmap_state_path)")"
  assert_eq "roadmap state records project_root" "$root" "$got"
  teardown_roadmap
}

test_legacy_roadmap_migrates_when_legacy_onboarding_matches() {
  echo "test_legacy_roadmap_migrates_when_legacy_onboarding_matches:"
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  TMP_DIR="$(mktemp -d -t scaffold-onboard-roadmap-project.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a"
  git -C "$TMP_DIR/project-a" init -q
  cd "$TMP_DIR/project-a"
  local root legacy_onboarding legacy_roadmap scoped
  root="$(sf_project_identity_root)"
  legacy_onboarding="$(sf_state_legacy_path)"
  legacy_roadmap="$(sf_roadmap_legacy_state_path)"
  jq -n --arg root "$root" '{status: "complete", current_phase: 10, project_root: $root, answers: {}}' > "$legacy_onboarding"
  jq -n '{
    schema_version: "1",
    started_at: "2026-05-28T00:00:00Z",
    checkpoint: "R1.B",
    elapsed_min: 0,
    project_name: "legacy-roadmap",
    phases: [],
    sprints: [],
    vertical_slices: [],
    mutations: []
  }' > "$legacy_roadmap"
  scoped="$(sf_roadmap_state_path)"
  assert_file_exists "$scoped"
  assert_eq "matching legacy roadmap migrates checkpoint" "R1.B" "$(jq -r '.checkpoint' "$scoped")"
  assert_eq "migrated roadmap gains project_root" "$root" "$(jq -r '.project_root' "$scoped")"
  assert_file_exists "$legacy_roadmap"
  teardown_roadmap
}

test_legacy_roadmap_ignored_when_legacy_onboarding_mismatches() {
  echo "test_legacy_roadmap_ignored_when_legacy_onboarding_mismatches:"
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  TMP_DIR="$(mktemp -d -t scaffold-onboard-roadmap-project.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a"
  git -C "$TMP_DIR/project-a" init -q
  cd "$TMP_DIR/project-a"
  local legacy_onboarding legacy_roadmap scoped
  legacy_onboarding="$(sf_state_legacy_path)"
  legacy_roadmap="$(sf_roadmap_legacy_state_path)"
  jq -n '{status: "complete", current_phase: 10, project_root: "/not/this/project", answers: {}}' > "$legacy_onboarding"
  jq -n '{
    schema_version: "1",
    started_at: "2026-05-28T00:00:00Z",
    checkpoint: "R1.B",
    elapsed_min: 0,
    project_name: "foreign-roadmap",
    phases: [],
    sprints: [],
    vertical_slices: [],
    mutations: []
  }' > "$legacy_roadmap"
  scoped="$(sf_project_data_dir)/project-roadmap.json"
  assert_eq "mismatched legacy roadmap leaves mode new" "new" "$(sf_roadmap_state_mode)"
  assert_file_missing "$scoped"
  assert_file_exists "$legacy_roadmap"
  teardown_roadmap
}

# ============================================================================
# Run all tests
# ============================================================================

echo "=== test-roadmap.sh ==="
# Base CRUD
test_state_init_creates_schema                    # 1, 2
test_write_phase_appends                          # 3, 4
test_write_sprint_appends_with_phase_id           # 5
test_write_slice_appends_with_sprint_id           # 6
test_write_slice_accepts_trace_arrays
test_write_slice_preserves_traces_when_legacy_update_omits_them
test_checkpoint_set_get_roundtrip                 # 7
# Render + ID
test_render_writes_roadmap_md                     # 8
test_render_h1_has_project_name                   # 8b (#20)
test_render_no_overview_stub                      # 8c (#20)
test_render_contains_phase_heading                # 9
test_render_contains_sprint_heading               # 10
test_render_contains_slice_heading                # 11
test_render_contains_traceability_block
test_traceability_report_lists_covered_and_unassigned
test_render_idempotent_no_diff                    # 12
# Re-run protocol
test_rerun_mode_no_state_is_initial               # 13
test_rerun_mode_add_phase                         # 14
test_rerun_mode_add_sprint                        # 15
test_rerun_mode_add_slice                         # 16
test_rerun_mode_refine_slice                      # 17
test_rerun_mode_reorganize                        # 18
test_rerun_mode_reorganize_no_state_fails         # 19
test_rerun_mode_no_flag_with_state_is_initial     # 20
# Size-class
test_count_nodes_empty_state                      # 21
test_count_nodes_phases_only                      # 22
test_count_nodes_phases_and_sprints               # 23
test_count_nodes_full_hierarchy                   # 24
test_size_class_large_above_50                    # 25
test_size_class_split_above_100                   # 26
test_size_class_normal_below_50                   # 27
# Mutations
test_mutations_empty_on_init                      # 28
test_mutation_append_adds_entry                   # 29
test_mutation_entry_has_required_fields           # 30
test_mutations_accumulate_in_order                # 31
test_write_slice_never_auto_appends_mutation      # 32
test_write_slice_plus_explicit_mutation_logs_audit # 33
test_project_scoped_roadmap_paths_differ
test_project_scoped_roadmap_writes_are_isolated
test_roadmap_state_init_records_project_root
test_legacy_roadmap_migrates_when_legacy_onboarding_matches
test_legacy_roadmap_ignored_when_legacy_onboarding_mismatches

report_results
