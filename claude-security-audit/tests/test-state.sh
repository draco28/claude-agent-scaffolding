#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"

_csa_failed=0

# Shared sandbox — create once for the whole test file.
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT

# ---------------------------------------------------------------------------
# 1. init creates schema_version=2 file
# ---------------------------------------------------------------------------
test_init_creates_schema_v2() {
  local root="$_CSA_TMP/t01"
  mkdir -p "$root"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"
  [[ -f "$state_file" ]] || { printf '    state.json not created\n' >&2; return 1; }
  local sv; sv="$(jq -r '.schema_version' "$state_file")"
  assert_eq "2" "$sv" "schema_version must be 2" || return 1
}

# ---------------------------------------------------------------------------
# 2. read missing file returns empty object
# ---------------------------------------------------------------------------
test_read_missing_returns_empty_object() {
  local root="$_CSA_TMP/t02"
  mkdir -p "$root"
  # Do NOT call csa_state_init — file should be absent.
  local out; out="$(csa_state_read "$root")"
  # Must be valid JSON (jq parses it without error).
  printf '%s' "$out" | jq '.' >/dev/null 2>&1 || { printf '    output is not valid JSON: %s\n' "$out" >&2; return 1; }
  # Must be the empty object literal (or at least jq-type == "object").
  local t; t="$(printf '%s' "$out" | jq -r 'type')"
  assert_eq "object" "$t" "csa_state_read missing file must return object" || return 1
}

# ---------------------------------------------------------------------------
# 3. record_audit appends to history
# ---------------------------------------------------------------------------
test_record_audit_appends_to_history() {
  local root="$_CSA_TMP/t03"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  csa_state_record_audit "$root" 1 ".claude/audits/2026-05-25-01.md" ""

  local state_file; state_file="$(csa_state_path "$root")"
  local len; len="$(jq '.audit_history | length' "$state_file")"
  assert_eq "1" "$len" "audit_history length must be 1 after first record_audit" || return 1
}

# ---------------------------------------------------------------------------
# 4. record_audit updates findings registry
# ---------------------------------------------------------------------------
test_record_audit_updates_findings_registry() {
  local root="$_CSA_TMP/t04"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  local findings_jsonl
  findings_jsonl='{"finding_uid":"FUID-abcd1234","rule_id":"PERM-003","severity":"medium","file":".claude/settings.json","display_id":"SA-2026-05-25-01-001"}'

  csa_state_record_audit "$root" 1 ".claude/audits/2026-05-25-01.md" "$findings_jsonl"

  local state_file; state_file="$(csa_state_path "$root")"
  local fuid; fuid="$(jq -r '.findings["FUID-abcd1234"].rule_id // empty' "$state_file")"
  assert_eq "PERM-003" "$fuid" "finding FUID-abcd1234 must appear in findings registry" || return 1
}

# ---------------------------------------------------------------------------
# 5. record_applied_fix appends to applied_fixes
# ---------------------------------------------------------------------------
test_record_applied_fix_appends() {
  local root="$_CSA_TMP/t05"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  csa_state_record_applied_fix "$root" "FUID-abcd1234" "SA-2026-05-25-01-001" "PERM-003" "claude-code" "Narrowed allow list"

  local state_file; state_file="$(csa_state_path "$root")"
  local len; len="$(jq '.applied_fixes | length' "$state_file")"
  assert_eq "1" "$len" "applied_fixes length must be 1" || return 1

  local stored_fuid; stored_fuid="$(jq -r '.applied_fixes[0].finding_uid' "$state_file")"
  assert_eq "FUID-abcd1234" "$stored_fuid" "applied_fixes[0].finding_uid must match" || return 1
}

# ---------------------------------------------------------------------------
# 6. GC evicts finding absent for > 10 runs (gap = 11)
# ---------------------------------------------------------------------------
test_gc_evicts_after_10_run_absence() {
  local root="$_CSA_TMP/t06"
  mkdir -p "$root/.claude/audits"

  # Craft state.json directly: finding last_run_index = 5, current run = 16 → gap 11.
  local state_file; state_file="$(csa_state_path "$root")"
  jq -n '{
    schema_version: 2,
    last_audit: null,
    self_integrity: {
      state_mtime_at_last_audit: 0,
      suppressions_mtime_at_last_audit: 0,
      git_tracked_check: { state_json_tracked: false, suppressions_json_tracked: false, checked_at: null }
    },
    findings: {
      "FUID-evict001": {
        rule_id: "PERM-003",
        severity: "medium",
        file: ".claude/settings.json",
        first_seen: "2026-01-01T00:00:00Z",
        last_seen: "2026-01-01T00:00:00Z",
        seen_in_runs: 1,
        last_run_index: 5,
        last_display_id: "SA-old"
      }
    },
    audit_history: [],
    applied_fixes: []
  }' > "$state_file"

  csa_state_gc_findings "$root" 16

  local present; present="$(jq -r '.findings["FUID-evict001"] // "null"' "$state_file")"
  assert_eq "null" "$present" "finding must be evicted when gap > 10" || return 1
}

# ---------------------------------------------------------------------------
# 7. GC keeps finding within 10-run window (gap = 10, NOT > 10)
# ---------------------------------------------------------------------------
test_gc_keeps_within_10_run_window() {
  local root="$_CSA_TMP/t07"
  mkdir -p "$root/.claude/audits"

  local state_file; state_file="$(csa_state_path "$root")"
  jq -n '{
    schema_version: 2,
    last_audit: null,
    self_integrity: {
      state_mtime_at_last_audit: 0,
      suppressions_mtime_at_last_audit: 0,
      git_tracked_check: { state_json_tracked: false, suppressions_json_tracked: false, checked_at: null }
    },
    findings: {
      "FUID-keep001": {
        rule_id: "PERM-003",
        severity: "medium",
        file: ".claude/settings.json",
        first_seen: "2026-01-01T00:00:00Z",
        last_seen: "2026-01-01T00:00:00Z",
        seen_in_runs: 1,
        last_run_index: 5,
        last_display_id: "SA-old"
      }
    },
    audit_history: [],
    applied_fixes: []
  }' > "$state_file"

  # current = 15, gap = 10 (NOT > 10) → should NOT be evicted.
  csa_state_gc_findings "$root" 15

  local rule_id; rule_id="$(jq -r '.findings["FUID-keep001"].rule_id // empty' "$state_file")"
  assert_eq "PERM-003" "$rule_id" "finding must NOT be evicted when gap == 10" || return 1
}

# ---------------------------------------------------------------------------
# 8. First-run tamper check is silent (no state.json)
# ---------------------------------------------------------------------------
test_tamper_check_silent_on_first_run() {
  local root="$_CSA_TMP/t08"
  mkdir -p "$root"
  # No state.json exists.
  local out; out="$(csa_state_check_tamper "$root" 2>&1)"
  assert_eq "" "$out" "tamper check must produce no output on first run" || return 1
}

# ---------------------------------------------------------------------------
# 9. TAMPER-001 fires on state.json mtime drift
# ---------------------------------------------------------------------------
test_tamper_001_fires_on_state_mtime_drift() {
  local root="$_CSA_TMP/t09"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  # Record a real mtime into self_integrity.
  csa_state_update_self_integrity "$root"

  local state_file; state_file="$(csa_state_path "$root")"

  # Change mtime to something in the distant past to force drift.
  touch -m -t 200001010000 "$state_file"

  local out; out="$(csa_state_check_tamper "$root" 2>&1)"
  assert_contains "$out" "TAMPER-001" "TAMPER-001 must fire when state.json mtime drifts" || return 1
}

# ---------------------------------------------------------------------------
# 10. TAMPER-002 fires on suppressions.json mtime drift
# ---------------------------------------------------------------------------
test_tamper_002_fires_on_suppressions_mtime_drift() {
  local root="$_CSA_TMP/t10"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  # Create an empty suppressions.json so update_self_integrity records its mtime.
  local suppressions_file; suppressions_file="$(csa_suppressions_path "$root")"
  printf '{}' > "$suppressions_file"

  csa_state_update_self_integrity "$root"

  # Now change suppression file mtime to something old.
  touch -m -t 200001010000 "$suppressions_file"

  local out; out="$(csa_state_check_tamper "$root" 2>&1)"
  assert_contains "$out" "TAMPER-002" "TAMPER-002 must fire when suppressions.json mtime drifts" || return 1
}

# ---------------------------------------------------------------------------
# 11. bootstrap_gitignore appends entry on existing .gitignore
# ---------------------------------------------------------------------------
test_bootstrap_gitignore_appends_to_existing() {
  local root="$_CSA_TMP/t11"
  mkdir -p "$root"

  # Create a .gitignore that does NOT contain .claude/audits/.
  printf 'node_modules/\n' > "$root/.gitignore"

  csa_state_bootstrap_gitignore "$root"

  local content; content="$(cat "$root/.gitignore")"
  assert_contains "$content" ".claude/audits/" "bootstrap must append .claude/audits/ to existing .gitignore" || return 1
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
csa_test_run test_init_creates_schema_v2                          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_read_missing_returns_empty_object               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_appends_to_history                 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_updates_findings_registry          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_applied_fix_appends                      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_evicts_after_10_run_absence                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_keeps_within_10_run_window                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_check_silent_on_first_run                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_001_fires_on_state_mtime_drift           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_002_fires_on_suppressions_mtime_drift    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_appends_to_existing         || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
