#!/usr/bin/env bash
# test-commands.sh — command body smoke + behaviour tests (Phase C, Task TC.5)
# ~12 tests covering /critique, /critique-list, /promote-principle, /principles-list
#
# Strategy: extract the first ```bash block from each commands/*.md file and
# run it via `bash -c` with CLAUDE_PLUGIN_ROOT + CLAUDE_PLUGIN_DATA mocked.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/_helpers.sh"

# ---------------------------------------------------------------------------
# Helper: extract the inner script from the first ```bash ... ``` block.
# Command bodies use: bash -c '...script...'
# We strip the first line (bash -c ') and last line (') to get the raw script.
# ---------------------------------------------------------------------------
extract_full_bash_block() {
  local mdfile="$1"
  awk '
    /^```bash$/ { in_block=1; next }
    /^```$/     { if (in_block) { in_block=0 } }
    in_block    { print }
  ' "$mdfile"
}

# ---------------------------------------------------------------------------
# Helper: run a command body with given arguments.
# Env vars CLAUDE_PLUGIN_ROOT + CLAUDE_PLUGIN_DATA must already be exported.
# Usage: run_command <cmd-basename> [args...]
# Returns exit code of the inner script; stdout/stderr passed through.
#
# Strategy (v0.1.2): command bodies use `$ARGUMENTS` for their raw arg string
# (Claude Code substitutes at template render time). Tests simulate that by
# setting RAW_ARGS_FROM_CLAUDE env var — the command body env-var-bridges this
# into the inner bash -c block, sidestepping Claude Code's $N substitution.
# ---------------------------------------------------------------------------
run_command() {
  local cmd_name="$1"; shift
  local raw_args="$*"
  local script
  script="$(extract_full_bash_block "$PLUGIN_ROOT/commands/${cmd_name}.md")"
  # Substitute $ARGUMENTS with the actual raw args string (template render sim).
  # Use a control char as delimiter to avoid escaping concerns.
  local rendered
  rendered="$(printf "%s" "$script" | awk -v args="$raw_args" '
    { gsub(/\$ARGUMENTS/, args); print }
  ')"
  bash -c "$rendered"
}

# ---------------------------------------------------------------------------
# Setup shared tmp repo (sets CLAUDE_PLUGIN_DATA + cds into tmp git repo)
# ---------------------------------------------------------------------------
setup_tmp_repo
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Create a tiny spec file in the repo so tests that need a readable spec find one.
SPEC_FILE="$TMP_DIR/repo/MASTER-SPEC.md"
cp "$TESTS_DIR/fixtures/master-specs/tiny-spec.md" "$SPEC_FILE"

# ---------------------------------------------------------------------------
# TC.5-T1: /critique synth-from-defaults produces a valid envelope
# ---------------------------------------------------------------------------
echo "TC.5-T1: /critique synth-from-defaults produces a valid envelope"

out1="$(run_command critique --spec "$SPEC_FILE" 2>/dev/null)"
# The summary block should print request_id and depth
echo "$out1" | grep -q "request_id" \
  && PASS=$((PASS+1)) && echo "  ✓ output contains request_id" \
  || { FAIL=$((FAIL+1)); echo "  ✗ output missing request_id"; }

echo "$out1" | grep -q "depth" \
  && PASS=$((PASS+1)) && echo "  ✓ output contains depth" \
  || { FAIL=$((FAIL+1)); echo "  ✗ output missing depth"; }

# Envelope must have been written to inbox
INBOX_DIR="$CLAUDE_PLUGIN_DATA/inbox"
INBOX_COUNT="$(ls "$INBOX_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$INBOX_COUNT" -ge 1 ]]; then
  echo "  ✓ inbox envelope written"; PASS=$((PASS+1))
else
  echo "  ✗ inbox envelope not written"; FAIL=$((FAIL+1))
fi

# Envelope must be valid JSON
FIRST_ENVELOPE="$(ls "$INBOX_DIR"/*.json 2>/dev/null | head -1)"
if [[ -n "$FIRST_ENVELOPE" ]] && jq -e . "$FIRST_ENVELOPE" >/dev/null 2>&1; then
  echo "  ✓ envelope is valid JSON"; PASS=$((PASS+1))
else
  echo "  ✗ envelope is not valid JSON"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# TC.5-T2: /critique with explicit args overrides defaults
# ---------------------------------------------------------------------------
echo "TC.5-T2: /critique explicit --depth + --spec overrides"

out2="$(run_command critique --depth premise-audit --spec "$SPEC_FILE" 2>/dev/null)"

# depth should be premise-audit
echo "$out2" | grep -q "premise-audit" \
  && PASS=$((PASS+1)) && echo "  ✓ depth override (premise-audit) shown in output" \
  || { FAIL=$((FAIL+1)); echo "  ✗ depth override not reflected"; }

# spec path should appear in output
echo "$out2" | grep -q "spec" \
  && PASS=$((PASS+1)) && echo "  ✓ spec path shown in output" \
  || { FAIL=$((FAIL+1)); echo "  ✗ spec path missing from output"; }

# ---------------------------------------------------------------------------
# TC.5-T3: /critique with non-existent --spec errors
# ---------------------------------------------------------------------------
echo "TC.5-T3: /critique with non-existent --spec exits non-zero"

NONEXISTENT="$TMP_DIR/does-not-exist/MASTER-SPEC.md"
set +e
run_command critique --spec "$NONEXISTENT" >/dev/null 2>&1
exit3=$?
set -e
if [[ "$exit3" -ne 0 ]]; then
  echo "  ✓ non-existent --spec exits non-zero (exit $exit3)"; PASS=$((PASS+1))
else
  echo "  ✗ non-existent --spec should exit non-zero (got 0)"; FAIL=$((FAIL+1))
fi

# Also check stderr mentions the missing path
err3="$(run_command critique --spec "$NONEXISTENT" 2>&1 || true)"
echo "$err3" | grep -qi "MASTER-SPEC\|No MASTER-SPEC\|not found\|does-not-exist\|not readable" \
  && PASS=$((PASS+1)) && echo "  ✓ non-existent --spec emits error message" \
  || { FAIL=$((FAIL+1)); echo "  ✗ non-existent --spec: no error message on stderr. got: $err3"; }

# ---------------------------------------------------------------------------
# TC.5-T4: /critique-list with empty state shows "No runs yet" / "(no runs yet)"
# ---------------------------------------------------------------------------
echo "TC.5-T4: /critique-list with empty state"

# Reset to a fresh data dir so state is empty
FRESH_DATA="$TMP_DIR/fresh-data"
mkdir -p "$FRESH_DATA"
export CLAUDE_PLUGIN_DATA="$FRESH_DATA"

out4="$(run_command critique-list 2>/dev/null)"
echo "$out4" | grep -qi "no runs yet\|(no runs yet)" \
  && PASS=$((PASS+1)) && echo "  ✓ empty state shows 'no runs yet'" \
  || { FAIL=$((FAIL+1)); echo "  ✗ empty state output: $out4"; }

# Restore to original plugin data
export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"

# ---------------------------------------------------------------------------
# TC.5-T5: /critique-list with N runs shows N rows in correct order
# ---------------------------------------------------------------------------
echo "TC.5-T5: /critique-list with 3 runs shows them newest-first"

# Seed state.json with 3 recent_runs (oldest first in array → newest first in output)
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/state.sh"

ac_state_init

run1='{"request_id":"crit-aaa","completed_at":"2026-05-01T10:00:00Z","depth":"close","adversaries_used":["claude"],"challenge_count":2,"divergence_count":0,"elapsed_ms":5000,"cost_usd":"0.01"}'
run2='{"request_id":"crit-bbb","completed_at":"2026-05-02T10:00:00Z","depth":"premise-audit","adversaries_used":["claude","codex"],"challenge_count":1,"divergence_count":1,"elapsed_ms":3000,"cost_usd":"0.02"}'
run3='{"request_id":"crit-ccc","completed_at":"2026-05-03T10:00:00Z","depth":"close","adversaries_used":["claude"],"challenge_count":3,"divergence_count":0,"elapsed_ms":8000,"cost_usd":"0.00"}'
ac_state_append_recent_run "$run1"
ac_state_append_recent_run "$run2"
ac_state_append_recent_run "$run3"

out5="$(run_command critique-list 2>/dev/null)"

# crit-ccc should appear before crit-aaa (newest first)
pos_ccc="$(echo "$out5" | grep -n "crit-ccc" | cut -d: -f1 | head -1)"
pos_aaa="$(echo "$out5" | grep -n "crit-aaa" | cut -d: -f1 | head -1)"
if [[ -n "$pos_ccc" && -n "$pos_aaa" && "$pos_ccc" -lt "$pos_aaa" ]]; then
  echo "  ✓ newest run (crit-ccc) appears before oldest (crit-aaa)"; PASS=$((PASS+1))
else
  echo "  ✗ order wrong: crit-ccc at line $pos_ccc, crit-aaa at line $pos_aaa"; FAIL=$((FAIL+1))
fi

# All 3 request IDs present
for rid in crit-aaa crit-bbb crit-ccc; do
  echo "$out5" | grep -q "$rid" \
    && PASS=$((PASS+1)) && echo "  ✓ $rid present in list" \
    || { FAIL=$((FAIL+1)); echo "  ✗ $rid missing from list"; }
done

# ---------------------------------------------------------------------------
# TC.5-T6: /critique-list --limit filters correctly
# ---------------------------------------------------------------------------
echo "TC.5-T6: /critique-list --limit 1 shows only most-recent run"

out6="$(run_command critique-list --limit 1 2>/dev/null)"

# Only crit-ccc should appear (most recent)
echo "$out6" | grep -q "crit-ccc" \
  && PASS=$((PASS+1)) && echo "  ✓ --limit 1: newest run (crit-ccc) present" \
  || { FAIL=$((FAIL+1)); echo "  ✗ --limit 1: crit-ccc missing"; }

# crit-aaa should NOT appear (excluded by limit)
echo "$out6" | grep -q "crit-aaa" \
  && { FAIL=$((FAIL+1)); echo "  ✗ --limit 1: crit-aaa should be excluded"; } \
  || { PASS=$((PASS+1)); echo "  ✓ --limit 1: crit-aaa correctly excluded"; }

# ---------------------------------------------------------------------------
# TC.5-T7: /promote-principle scope=user appends to principles.md
# ---------------------------------------------------------------------------
echo "TC.5-T7: /promote-principle scope=user appends to principles.md"

PRINCIPLES_FILE="$CLAUDE_PLUGIN_DATA/principles.md"
touch "$PRINCIPLES_FILE"

run_command promote-principle "Prefer explicit over implicit" --scope user >/dev/null 2>&1

assert_file_contains "$PRINCIPLES_FILE" "Prefer explicit over implicit"

# ---------------------------------------------------------------------------
# TC.5-T8: /promote-principle scope=project errors when no memory-bank
# ---------------------------------------------------------------------------
echo "TC.5-T8: /promote-principle scope=project errors without .claude/memory-bank"

# Make sure we are in a dir WITHOUT .claude/memory-bank
cd "$TMP_DIR/repo"
# No .claude/memory-bank directory here
set +e
out8="$(run_command promote-principle "Some project principle" --scope project 2>&1)"
exit8=$?
set -e

if [[ "$exit8" -ne 0 ]]; then
  echo "  ✓ scope=project without memory-bank exits non-zero"; PASS=$((PASS+1))
else
  echo "  ✗ scope=project without memory-bank should exit non-zero"; FAIL=$((FAIL+1))
fi

echo "$out8" | grep -qi "memory-bank\|project scope" \
  && PASS=$((PASS+1)) && echo "  ✓ scope=project error mentions memory-bank" \
  || { FAIL=$((FAIL+1)); echo "  ✗ scope=project error missing expected message. got: $out8"; }

# ---------------------------------------------------------------------------
# TC.5-T9: /promote-principle scope=project appends to 03-code-patterns.md
# ---------------------------------------------------------------------------
echo "TC.5-T9: /promote-principle scope=project appends to 03-code-patterns.md"

# Create .claude/memory-bank in the tmp repo
cd "$TMP_DIR/repo"
mkdir -p ".claude/memory-bank"
PATTERNS_FILE="$TMP_DIR/repo/.claude/memory-bank/03-code-patterns.md"
touch "$PATTERNS_FILE"

run_command promote-principle "Always guard jq writes atomically" --scope project >/dev/null 2>&1

assert_file_contains "$PATTERNS_FILE" "Always guard jq writes atomically"

# ---------------------------------------------------------------------------
# TC.5-T10: /promote-principle records in state.json's principle_promotions
# ---------------------------------------------------------------------------
echo "TC.5-T10: /promote-principle records in state.json"

STATE_FILE="$CLAUDE_PLUGIN_DATA/state.json"
PROMO_COUNT_BEFORE="$(jq '.principle_promotions | length' "$STATE_FILE" 2>/dev/null || echo 0)"

run_command promote-principle "Record this principle" --scope user >/dev/null 2>&1

PROMO_COUNT_AFTER="$(jq '.principle_promotions | length' "$STATE_FILE" 2>/dev/null || echo 0)"
if [[ "$PROMO_COUNT_AFTER" -gt "$PROMO_COUNT_BEFORE" ]]; then
  echo "  ✓ principle_promotions count increased ($PROMO_COUNT_BEFORE → $PROMO_COUNT_AFTER)"; PASS=$((PASS+1))
else
  echo "  ✗ principle_promotions not updated (before=$PROMO_COUNT_BEFORE, after=$PROMO_COUNT_AFTER)"; FAIL=$((FAIL+1))
fi

# The text should be in the last promotion record
LAST_TEXT="$(jq -r '.principle_promotions[-1].text' "$STATE_FILE" 2>/dev/null || echo "")"
assert_eq "last promotion text" "Record this principle" "$LAST_TEXT"

# ---------------------------------------------------------------------------
# TC.5-T11: /principles-list with empty principles.md prints "(empty)"
# ---------------------------------------------------------------------------
echo "TC.5-T11: /principles-list with empty principles.md prints '(empty)'"

# Create an empty principles.md (header-only, no active principles)
PRINCIPLES_FILE="$CLAUDE_PLUGIN_DATA/principles.md"
printf '# Principles\n# This is a comment line\n' > "$PRINCIPLES_FILE"

# Switch to a blank dir with no MASTER-SPEC.md and no memory-bank
# so all 4 sources are empty and (empty) is printed.
BLANK_DIR="$TMP_DIR/blank-repo"
mkdir -p "$BLANK_DIR"
cd "$BLANK_DIR"
git init -q

out11="$(run_command principles-list 2>/dev/null)"
echo "$out11" | grep -q "(empty)" \
  && PASS=$((PASS+1)) && echo "  ✓ empty principles.md prints '(empty)'" \
  || { FAIL=$((FAIL+1)); echo "  ✗ expected '(empty)' in output. got: $out11"; }

# Return to repo dir for next test
cd "$TMP_DIR/repo"

# ---------------------------------------------------------------------------
# TC.5-T12: /principles-list with all 4 sources renders all sections
# ---------------------------------------------------------------------------
echo "TC.5-T12: /principles-list with all 4 sources renders all sections"

cd "$TMP_DIR/repo"

# Source 1: user-global — write an active principle
printf '# Principles\nDo the right thing\n' > "$PRINCIPLES_FILE"

# Source 2: MASTER-SPEC in cwd (already placed as MASTER-SPEC.md)
# tiny-spec.md has phase markers so ac_principles_load_master_spec_phases will emit content

# Source 3: project patterns
mkdir -p ".claude/memory-bank"
printf 'Use atomic writes everywhere\n' > ".claude/memory-bank/03-code-patterns.md"

# Source 4: project governance
printf 'No force-push to main\n' > ".claude/memory-bank/08-governance.md"

out12="$(run_command principles-list 2>/dev/null)"

echo "$out12" | grep -q "User-global principles" \
  && PASS=$((PASS+1)) && echo "  ✓ User-global principles section present" \
  || { FAIL=$((FAIL+1)); echo "  ✗ User-global principles section missing. output: $out12"; }

echo "$out12" | grep -q "Project patterns" \
  && PASS=$((PASS+1)) && echo "  ✓ Project patterns section present" \
  || { FAIL=$((FAIL+1)); echo "  ✗ Project patterns section missing"; }

echo "$out12" | grep -q "Project governance" \
  && PASS=$((PASS+1)) && echo "  ✓ Project governance section present" \
  || { FAIL=$((FAIL+1)); echo "  ✗ Project governance section missing"; }

# ---------------------------------------------------------------------------
# TF.5: /critique-list cost column rendering (Phase F)
# ---------------------------------------------------------------------------
echo ""
echo "TF.5: /critique-list renders cost column from recent_runs[].cost_usd"
setup_tmp_repo > /dev/null
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/state.sh"
ac_state_init
ac_state_append_recent_run '{"request_id":"crit-cost-test","completed_at":"2026-05-15T10:00:00Z","depth":"close","adversaries_used":["claude","codex"],"challenge_count":2,"divergence_count":1,"elapsed_ms":4500,"cost_usd":"0.18"}'

out_tf5="$(run_command critique-list 2>/dev/null)"
# Cost column should show the value (formatted to 2dp).
echo "$out_tf5" | grep -q "0.18" \
  && PASS=$((PASS+1)) && echo "  ✓ cost_usd value (0.18) appears in output" \
  || { FAIL=$((FAIL+1)); echo "  ✗ cost_usd value missing from output. got: $out_tf5"; }

# ---------------------------------------------------------------------------
report_results
