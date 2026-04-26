#!/usr/bin/env bash
#
# scaffold/tests/test-slice-gates.sh — regression suite for lib/slice.sh.
#
# Tests the slice workflow state machine: slug + numbering, slice creation,
# AC parsing from spec files, gate enforcement across all five phase
# transitions, and /slice-verify test-running with mocked test commands.
#
# Isolation: tempdir git repos + CLAUDE_PLUGIN_DATA + trap cleanup.
#
# Usage: bash scaffold/tests/test-slice-gates.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_SLICE="$PLUGIN_ROOT/lib/slice.sh"

TMPDIR_TESTS="$(mktemp -d -t scaffold-slice-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# shellcheck source=../lib/slice.sh
source "$LIB_SLICE"

# Make a test repo and cd into it
make_repo() {
  local d="$TMPDIR_TESTS/$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email t@t && git config user.name t \
    && touch .keep && git add .keep && git commit -q -m init )
  echo "$d"
}

REPO="$(make_repo work)"
cd "$REPO"
sf_init_state >/dev/null

echo ""
echo "── slug + numbering ──"

# Slug normalization
[[ "$(sf_slice_slug 'Auth Rewrite')" == "auth-rewrite" ]] \
  && pass "U1 slug: 'Auth Rewrite' → auth-rewrite" \
  || fail "U1 slug" "got '$(sf_slice_slug 'Auth Rewrite')'"

[[ "$(sf_slice_slug 'Foo!! Bar///Baz')" == "foo-bar-baz" ]] \
  && pass "U2 slug: collapses non-alphanumeric" \
  || fail "U2 slug" "got '$(sf_slice_slug 'Foo!! Bar///Baz')'"

# Number formatting
[[ "$(sf_slice_format_number 4)" == "04" ]] && pass "U3 format_number 4 → 04" || fail "U3 format_number 04"
[[ "$(sf_slice_format_number 99)" == "99" ]] && pass "U4 format_number 99 → 99" || fail "U4 format_number 99"
[[ "$(sf_slice_format_number 100)" == "100" ]] && pass "U5 format_number 100 → 100" || fail "U5 format_number 100"

# Full id
[[ "$(sf_slice_format_id 4 'auth rewrite')" == "slice-04-auth-rewrite" ]] \
  && pass "U6 format_id" \
  || fail "U6 format_id" "got '$(sf_slice_format_id 4 'auth rewrite')'"

# Next number on empty state
[[ "$(sf_slice_next_number)" == "1" ]] && pass "U7 next_number on empty → 1" || fail "U7 next_number 1"

echo ""
echo "── slice creation + state ──"

# C1 — sf_slice_create generates id, file, state
ID="$(sf_slice_create "auth rewrite")"
[[ "$ID" == "slice-01-auth-rewrite" ]] && pass "C1 create slice 1 → slice-01-auth-rewrite" || fail "C1 create slice id" "got '$ID'"

# C2 — spec file written
[[ -r "$REPO/docs/slices/${ID}.md" ]] && pass "C2 spec file created" || fail "C2 spec file"

# C3 — current_slice set
[[ "$(sf_current_slice)" == "$ID" ]] && pass "C3 current_slice updated" || fail "C3 current_slice"

# C4 — phase=spec
[[ "$(sf_slice_phase "$ID")" == "spec" ]] && pass "C4 phase=spec" || fail "C4 phase=spec" "got '$(sf_slice_phase "$ID")'"

# C5 — sf_slice_exists yes
sf_slice_exists "$ID" && pass "C5 sf_slice_exists yes" || fail "C5 sf_slice_exists yes"

# C6 — sf_slice_in_progress yes
sf_slice_in_progress && pass "C6 sf_slice_in_progress yes" || fail "C6 in_progress yes"

# C7 — refuse concurrent slice without --force
out="$(sf_slice_create "another" 2>&1)"
[[ -z "$out" ]] || echo "$out" | grep -q "already in progress" \
  && pass "C7 refuses concurrent slice" \
  || fail "C7 concurrent refuse" "got: $out"

# C8 — --force allows new slice (suspends current)
ID2="$(sf_slice_create "another" --force)"
[[ "$ID2" == "slice-02-another" ]] && pass "C8 --force creates slice 2" || fail "C8 --force" "got '$ID2'"
[[ "$(sf_current_slice)" == "$ID2" ]] && pass "C9 --force updates current_slice" || fail "C9 current after force"

echo ""
echo "── AC parsing from spec file ──"

# Build a spec file with mixed checked/unchecked ACs
cat > "$REPO/docs/slices/${ID2}.md" <<'XEOF'
# Slice 2: another

## Acceptance criteria

- [ ] **AC-1:** First criterion
- [x] **AC-2:** Already passing one
- [ ] **AC-3:** Third
XEOF

# A1 — count_acs
count="$(sf_slice_count_acs "$REPO/docs/slices/${ID2}.md")"
[[ "$count" == "3" ]] && pass "A1 count_acs → 3" || fail "A1 count_acs" "got '$count'"

# A2 — parse_acs returns valid JSON
acs_json="$(sf_slice_parse_acs "$REPO/docs/slices/${ID2}.md")"
echo "$acs_json" | jq -e 'length == 3' >/dev/null && pass "A2 parse_acs valid JSON length 3" || fail "A2 parse_acs"

# A3 — first AC has correct id and pending status
echo "$acs_json" | jq -e '.[0].id == "AC-1" and .[0].status == "pending"' >/dev/null \
  && pass "A3 AC-1 pending" \
  || fail "A3 AC-1 pending" "got: $(echo "$acs_json" | jq '.[0]')"

# A4 — second AC has passing status (was [x])
echo "$acs_json" | jq -e '.[1].id == "AC-2" and .[1].status == "passing"' >/dev/null \
  && pass "A4 AC-2 passing (was [x])" \
  || fail "A4 AC-2 passing" "got: $(echo "$acs_json" | jq '.[1]')"

# A5 — sf_slice_refresh_acs writes to state
sf_slice_refresh_acs "$ID2"
state_count="$(sf_read_state | jq -r ".slices[\"$ID2\"].acceptance_criteria | length")"
[[ "$state_count" == "3" ]] && pass "A5 refresh_acs writes 3 ACs to state" || fail "A5 refresh_acs" "got '$state_count'"

# A6 — empty spec → empty AC list
empty_acs="$(sf_slice_parse_acs "/nonexistent/file.md")"
echo "$empty_acs" | jq -e '. == []' >/dev/null && pass "A6 missing spec → []" || fail "A6 missing spec"

echo ""
echo "── phase gate transitions ──"

# Reset to a clean state for gate tests
REPO2="$(make_repo gates)"
cd "$REPO2"
sf_init_state >/dev/null
ID3="$(sf_slice_create "gate test")"

# G1 — /slice-spec is always allowed (no gate)
sf_slice_phase_spec >/dev/null
[[ "$(sf_slice_phase "$ID3")" == "spec" ]] && pass "G1 phase_spec allowed" || fail "G1 phase_spec"

# G2 — /slice-contract refuses with empty AC list.
# Replace the template-seeded spec file with one that has no ACs.
cat > "$REPO2/docs/slices/${ID3}.md" <<'XEOF'
# Slice 1: gate test

(no acceptance criteria section)
XEOF
out="$(sf_slice_phase_contract 2>&1)"
echo "$out" | grep -q "no acceptance criteria" && pass "G2 contract refuses empty ACs" || fail "G2 contract refuses empty" "got: $out"
[[ "$(sf_slice_phase "$ID3")" == "spec" ]] && pass "G3 phase stayed at spec after refuse" || fail "G3 phase rollback"

# Now add real ACs and try again
cat > "$REPO2/docs/slices/${ID3}.md" <<'XEOF'
# Slice 1: gate test

## Acceptance criteria

- [ ] **AC-1:** Login works
XEOF

# G4 — /slice-contract now succeeds
sf_slice_phase_contract >/dev/null
[[ "$(sf_slice_phase "$ID3")" == "contract" ]] && pass "G4 contract succeeds with ACs" || fail "G4 contract" "got '$(sf_slice_phase "$ID3")'"

# G5 — /slice-implement refuses from contract (must scaffold first)
out="$(sf_slice_phase_implement 2>&1)"
echo "$out" | grep -q "scaffold first" && pass "G5 implement refuses from contract" || fail "G5 implement gate" "got: $out"

# G6 — /slice-scaffold succeeds from contract
sf_slice_phase_scaffold >/dev/null
[[ "$(sf_slice_phase "$ID3")" == "scaffold" ]] && pass "G6 scaffold from contract" || fail "G6 scaffold"

# G7 — /slice-implement succeeds from scaffold
sf_slice_phase_implement >/dev/null
[[ "$(sf_slice_phase "$ID3")" == "implement" ]] && pass "G7 implement from scaffold" || fail "G7 implement"

# G8 — /slice-scaffold from implement is allowed (regression / re-scaffold)
sf_slice_phase_scaffold >/dev/null
[[ "$(sf_slice_phase "$ID3")" == "scaffold" ]] && pass "G8 scaffold re-entry from implement" || fail "G8 re-scaffold"

echo ""
echo "── verify with mocked test command ──"

# Set test_command to a passing dummy command
sf_state_apply ".slices[\"$ID3\"].test_command = \"true\""
sf_state_apply ".slices[\"$ID3\"].phase = \"implement\""

# V1 — /slice-verify with passing command → phase=complete
sf_slice_phase_verify >/dev/null 2>&1
[[ "$(sf_slice_phase "$ID3")" == "complete" ]] && pass "V1 verify with passing command → complete" \
  || fail "V1 verify pass" "got '$(sf_slice_phase "$ID3")'"

# V2 — last_test_result captured exit_code 0
exit_code="$(sf_read_state | jq -r ".slices[\"$ID3\"].last_test_result.exit_code")"
[[ "$exit_code" == "0" ]] && pass "V2 last_test_result.exit_code = 0" || fail "V2 exit_code" "got '$exit_code'"

# V3 — re-verify with failing command → phase=verify (not complete)
sf_state_apply ".slices[\"$ID3\"].test_command = \"false\""
sf_state_apply ".slices[\"$ID3\"].phase = \"implement\""
sf_slice_phase_verify >/dev/null 2>&1
[[ "$(sf_slice_phase "$ID3")" == "verify" ]] && pass "V3 verify with failing command → stays at verify" \
  || fail "V3 verify fail" "got '$(sf_slice_phase "$ID3")'"

# V4 — last_test_result.exit_code != 0
exit_code="$(sf_read_state | jq -r ".slices[\"$ID3\"].last_test_result.exit_code")"
[[ "$exit_code" != "0" ]] && pass "V4 last_test_result.exit_code != 0 on failure" || fail "V4 exit_code != 0"

echo ""
echo "── numbering after multiple slices ──"

# After 2 slices in REPO, next should be 3 (counted across both REPO + REPO2 separately? — no, per-branch isolation)
cd "$REPO"
[[ "$(sf_slice_next_number)" == "3" ]] && pass "N1 next number after 2 slices (REPO) → 3" \
  || fail "N1 next number" "got '$(sf_slice_next_number)'"

cd "$REPO2"
[[ "$(sf_slice_next_number)" == "2" ]] && pass "N2 REPO2 separate count → 2" \
  || fail "N2 REPO2 count" "got '$(sf_slice_next_number)'"

# Summary
TOTAL=$((PASS+FAIL))
echo ""
echo "─────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll %d tests passed.\033[0m\n' "$TOTAL"
  exit 0
else
  printf '\033[31m%d/%d tests failed.\033[0m\n' "$FAIL" "$TOTAL"
  for t in "${FAILED_TESTS[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
