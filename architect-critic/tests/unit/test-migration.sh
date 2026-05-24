#!/usr/bin/env bash
# tests/unit/test-migration.sh — tests for lib/migration.sh (v0.1.x → v0.2 migration, Phase 3 Task 3.7)
# Covers: state.json bak rename, inbox/outbox relocation to legacy-v0.1.x/,
# principles.md shipped-defaults prepend with user content preserved,
# fresh install no-op, already-migrated idempotency, .bak collision suffixing.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
LIB_DIR="$PLUGIN_ROOT/lib"

source "$TESTS_DIR/_helpers.sh"
source "$LIB_DIR/_helpers.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/migration.sh"

echo "=== test-migration.sh ==="

# ---------------------------------------------------------------------------
# Helper: prepare an isolated $HOME with a .claude/architect-critic/ dir.
# Echoes the TMP_HOME path. Caller assigns to a variable.
# ---------------------------------------------------------------------------
make_tmp_home() {
  local tmp_home
  tmp_home="$(mktemp -d -t architect-critic-mig-test.XXXXXX)"
  mkdir -p "$tmp_home/.claude/architect-critic"
  echo "$tmp_home"
}

# Schema v1 state.json fixture content (v0.1.3 shape).
V01_STATE_JSON='{"schema_version":1,"in_flight":[{"request_id":"crit-old-001","started_at":"2026-05-01T12:00:00Z"}],"recent_runs":[{"request_id":"crit-old-000","cost_usd":0.0123,"completed_at":"2026-04-30T11:00:00Z"}],"principle_promotions":[],"declined_candidates":[]}'

# ---------------------------------------------------------------------------
# T1: test_detects_v01_state_json — schema_version=1 triggers bak rename
# ---------------------------------------------------------------------------
echo "--- T1: detects v0.1 state.json and renames to .bak ---"
TH1="$(make_tmp_home)"
printf '%s\n' "$V01_STATE_JSON" > "$TH1/.claude/architect-critic/state.json"
HOME="$TH1" ac_migration_check_v01_state > /dev/null
assert_file_exists "$TH1/.claude/architect-critic/state.json.v0.1.3.bak"
# Verify fresh state.json now exists at schema v2
assert_file_exists "$TH1/.claude/architect-critic/state.json"
new_ver="$(jq '.schema_version' "$TH1/.claude/architect-critic/state.json")"
assert_eq "fresh state.json after migration is schema_version 2" "2" "$new_ver"
rm -rf "$TH1"

# ---------------------------------------------------------------------------
# T2: test_renames_old_state_to_bak — .bak preserves original v0.1.3 content
# ---------------------------------------------------------------------------
echo "--- T2: bak file preserves original v0.1.3 content ---"
TH2="$(make_tmp_home)"
printf '%s\n' "$V01_STATE_JSON" > "$TH2/.claude/architect-critic/state.json"
original_sum="$(md5 -q "$TH2/.claude/architect-critic/state.json" 2>/dev/null || md5sum "$TH2/.claude/architect-critic/state.json" | awk '{print $1}')"
HOME="$TH2" ac_migration_check_v01_state > /dev/null
bak_sum="$(md5 -q "$TH2/.claude/architect-critic/state.json.v0.1.3.bak" 2>/dev/null || md5sum "$TH2/.claude/architect-critic/state.json.v0.1.3.bak" | awk '{print $1}')"
assert_eq "bak file content matches original v0.1.3 state.json" "$original_sum" "$bak_sum"
# Also: in_flight field is present in the bak but NOT in the new state.json
has_in_flight_bak="$(jq 'has("in_flight")' "$TH2/.claude/architect-critic/state.json.v0.1.3.bak")"
assert_eq "bak retains in_flight field" "true" "$has_in_flight_bak"
has_in_flight_new="$(jq 'has("in_flight")' "$TH2/.claude/architect-critic/state.json")"
assert_eq "new state.json has no in_flight field" "false" "$has_in_flight_new"
rm -rf "$TH2"

# ---------------------------------------------------------------------------
# T3: test_inbox_outbox_moved_to_legacy — both dirs relocated under legacy-v0.1.x/
# ---------------------------------------------------------------------------
echo "--- T3: inbox/ and outbox/ moved to legacy-v0.1.x/ ---"
TH3="$(make_tmp_home)"
mkdir -p "$TH3/.claude/architect-critic/inbox" "$TH3/.claude/architect-critic/outbox"
printf '{"req":"x"}\n' > "$TH3/.claude/architect-critic/inbox/test-req.json"
printf '{"resp":"y"}\n' > "$TH3/.claude/architect-critic/outbox/test-resp.json"
HOME="$TH3" ac_migration_check_v01_state > /dev/null
# Old locations gone
if [[ ! -d "$TH3/.claude/architect-critic/inbox" ]]; then
  echo "  ✓ inbox/ no longer exists at architect-critic/"; PASS=$((PASS+1))
else
  echo "  ✗ inbox/ still exists at architect-critic/"; FAIL=$((FAIL+1))
fi
if [[ ! -d "$TH3/.claude/architect-critic/outbox" ]]; then
  echo "  ✓ outbox/ no longer exists at architect-critic/"; PASS=$((PASS+1))
else
  echo "  ✗ outbox/ still exists at architect-critic/"; FAIL=$((FAIL+1))
fi
# New locations exist with content preserved
assert_file_exists "$TH3/.claude/architect-critic/legacy-v0.1.x/inbox/test-req.json"
assert_file_exists "$TH3/.claude/architect-critic/legacy-v0.1.x/outbox/test-resp.json"
rm -rf "$TH3"

# ---------------------------------------------------------------------------
# T4: test_principles_preserved_with_shipped_prepended
# ---------------------------------------------------------------------------
echo "--- T4: principles.md preserved + shipped defaults prepended ---"
TH4="$(make_tmp_home)"
cat > "$TH4/.claude/architect-critic/principles.md" <<'EOF'
# My principles

- My custom user principle
EOF
HOME="$TH4" ac_migration_check_v01_state > /dev/null
pfile="$TH4/.claude/architect-critic/principles.md"
assert_file_exists "$pfile"
assert_file_contains "$pfile" "My custom user principle"
assert_file_contains "$pfile" "pp-ghost-notes"
assert_file_contains "$pfile" "migrated from v0.1.x"
# Ensure shipped defaults appear before user content (line-order check)
shipped_line="$(grep -n 'pp-ghost-notes' "$pfile" | head -1 | cut -d: -f1)"
user_line="$(grep -n 'My custom user principle' "$pfile" | head -1 | cut -d: -f1)"
if [[ -n "$shipped_line" && -n "$user_line" && "$shipped_line" -lt "$user_line" ]]; then
  echo "  ✓ shipped defaults appear before user content"; PASS=$((PASS+1))
else
  echo "  ✗ shipped defaults not before user content (shipped=$shipped_line user=$user_line)"; FAIL=$((FAIL+1))
fi
rm -rf "$TH4"

# ---------------------------------------------------------------------------
# T5: test_bak_with_existing_collision — second .bak gets unix-ts suffix
# ---------------------------------------------------------------------------
echo "--- T5: .bak collision appends unix-ts suffix ---"
TH5="$(make_tmp_home)"
printf '%s\n' "$V01_STATE_JSON" > "$TH5/.claude/architect-critic/state.json"
printf '{"older":"existing-bak"}\n' > "$TH5/.claude/architect-critic/state.json.v0.1.3.bak"
HOME="$TH5" ac_migration_check_v01_state > /dev/null
# Original bak unchanged
existing_content="$(cat "$TH5/.claude/architect-critic/state.json.v0.1.3.bak")"
assert_eq "pre-existing .bak preserved unchanged" '{"older":"existing-bak"}' "$existing_content"
# At least one timestamped bak exists
ts_bak_count=0
for f in "$TH5/.claude/architect-critic/state.json.v0.1.3.bak."*; do
  [[ -f "$f" ]] && ts_bak_count=$((ts_bak_count+1))
done
if [[ "$ts_bak_count" -ge 1 ]]; then
  echo "  ✓ at least one timestamped .bak.<unix-ts> exists ($ts_bak_count found)"; PASS=$((PASS+1))
else
  echo "  ✗ no timestamped .bak.<unix-ts> file found"; FAIL=$((FAIL+1))
fi
rm -rf "$TH5"

# ---------------------------------------------------------------------------
# T6: test_no_op_on_fresh_install — empty TMP_HOME → silent no-op
# ---------------------------------------------------------------------------
echo "--- T6: fresh install (no v0.1.x artifacts) is silent no-op ---"
TH6="$(mktemp -d -t architect-critic-mig-fresh.XXXXXX)"
# Intentionally do NOT create .claude/architect-critic/
set +e
HOME="$TH6" ac_migration_check_v01_state > /dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
assert_eq "fresh install exit code is 0" "0" "$rc"
# No .bak created anywhere under TH6
if ! find "$TH6" -name 'state.json.v0.1.3.bak*' 2>/dev/null | grep -q .; then
  echo "  ✓ no .bak files created on fresh install"; PASS=$((PASS+1))
else
  echo "  ✗ unexpected .bak file created on fresh install"; FAIL=$((FAIL+1))
fi
# No legacy dir
if [[ ! -d "$TH6/.claude/architect-critic/legacy-v0.1.x" ]]; then
  echo "  ✓ no legacy-v0.1.x/ dir on fresh install"; PASS=$((PASS+1))
else
  echo "  ✗ legacy-v0.1.x/ dir unexpectedly created"; FAIL=$((FAIL+1))
fi
rm -rf "$TH6"

# ---------------------------------------------------------------------------
# T7: test_idempotent_already_migrated — schema_version=2 → skip bak
# ---------------------------------------------------------------------------
echo "--- T7: idempotent when already migrated (schema_version=2) ---"
TH7="$(make_tmp_home)"
printf '%s\n' '{"schema_version":2,"recent_runs":[],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[],"auto_promote_suppressions":[]}' > "$TH7/.claude/architect-critic/state.json"
original_v2_sum="$(md5 -q "$TH7/.claude/architect-critic/state.json" 2>/dev/null || md5sum "$TH7/.claude/architect-critic/state.json" | awk '{print $1}')"
HOME="$TH7" ac_migration_check_v01_state > /dev/null
# No .bak file should appear
if [[ ! -f "$TH7/.claude/architect-critic/state.json.v0.1.3.bak" ]]; then
  echo "  ✓ no .bak file created when already at schema v2"; PASS=$((PASS+1))
else
  echo "  ✗ .bak created despite schema_version=2"; FAIL=$((FAIL+1))
fi
# State.json unchanged
post_sum="$(md5 -q "$TH7/.claude/architect-critic/state.json" 2>/dev/null || md5sum "$TH7/.claude/architect-critic/state.json" | awk '{print $1}')"
assert_eq "schema v2 state.json unchanged" "$original_v2_sum" "$post_sum"
rm -rf "$TH7"

report_results
