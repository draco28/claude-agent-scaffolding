#!/usr/bin/env bash
# test-e2e.sh — end-to-end smoke for the architect-critic /critique pipeline (Phase G).
# Three scenarios:
#   TG.1: empty repo + manual /critique (no scaffold-onboard, no MASTER-SPEC discovery)
#   TG.2: onboarded repo + /critique --phase 5 (premise-audit depth)
#   TG.3: full close-depth audit + rebuttal + promotion paths
#
# All scenarios use mock-codex (via PATH override) + claude-self-audit mock
# (via ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK env hook) for hermetic execution.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/_helpers.sh"
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/state.sh"
source "$PLUGIN_ROOT/lib/principles.sh"
source "$PLUGIN_ROOT/lib/inbox.sh"
source "$PLUGIN_ROOT/lib/codex.sh"
source "$PLUGIN_ROOT/lib/consolidator.sh"
source "$PLUGIN_ROOT/lib/scorer.sh"
source "$PLUGIN_ROOT/lib/outbox.sh"
source "$PLUGIN_ROOT/lib/cost.sh"
source "$PLUGIN_ROOT/lib/promotion.sh"

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

echo "=== test-e2e.sh ==="

# Helper: build a request envelope, write to inbox, return request_id.
# Args: <depth> <spec_path> <phase_id_or_empty> <adversaries_json>
build_request_envelope() {
  local depth="$1" spec="$2" phase_id="$3" adv="$4"
  local now="$(date -u +"%Y-%m-%dT%H%M%S")"
  local rid="crit-${now}-test-$$.$RANDOM"
  local pfile="$(ac_principles_path)"
  local target_json
  if [[ -n "$phase_id" ]]; then
    target_json="$(jq -n --arg p "$spec" --argjson pid "$phase_id" \
      '{type:"master-spec-phase",path:$p,phase_id:$pid}')"
  else
    target_json="$(jq -n --arg p "$spec" '{type:"master-spec-full",path:$p}')"
  fi
  local inbox="$(ac_inbox_dir)"
  mkdir -p "$inbox"
  jq -n \
    --arg rid "$rid" \
    --arg depth "$depth" \
    --argjson adv "$adv" \
    --argjson target "$target_json" \
    --arg pfile "$pfile" \
    '{request_id:$rid, depth:$depth, adversaries:$adv, target:$target,
      sources:{principles:$pfile, accumulated_phases:[1,2,3,4,5,6,7,8,9,10]},
      concession_threshold:4, project_class:"CLI tool"}' \
    > "$inbox/${rid}.json"
  echo "$rid"
}

# Helper: write a mock claude-self-audit response to a tmp path, return path.
mock_claude_audit_to_tmp() {
  local payload_json="$1"
  local tmp="$(mktemp)"
  printf '%s' "$payload_json" > "$tmp"
  echo "$tmp"
}

# ---------------------------------------------------------------------------
# TG.1: empty repo + manual /critique synth-mode
# ---------------------------------------------------------------------------

echo ""
echo "--- TG.1: manual /critique in empty repo with mock-codex (close depth) ---"

setup_tmp_repo > /dev/null
ac_state_init
ac_principles_seed
TINY_SPEC="$PLUGIN_ROOT/tests/fixtures/master-specs/tiny-spec.md"

# Set up mocks: codex via PATH; claude-self via env var; promotion mock to skip claude reasoning.
setup_mock_codex 3-challenges.json
CLAUDE_MOCK="$(mock_claude_audit_to_tmp '{"challenges":[{"severity":"premise","text":"Phase 5.2 missing rollback","references":["Phase 5.2"]}],"gaps":[]}')"
export ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK="$CLAUDE_MOCK"

# Build envelope inline (mimicking what manual /critique would synthesize).
RID="$(build_request_envelope "close" "$TINY_SPEC" "" '["claude","codex"]')"

# Read inbox, validate.
INBOX_JSON="$(ac_inbox_read "$RID")"
ac_inbox_validate "$INBOX_JSON" > /dev/null 2>&1
assert_eq "TG.1: inbox envelope validates" "0" "$?"

# Compose principles.
PRINCIPLES="$(ac_principles_compose "$TINY_SPEC" "1,2,3,4,5,6,7,8,9,10")"
[[ -n "$PRINCIPLES" ]] && PASS=$((PASS+1)) && echo "  ✓ TG.1: principles composed (non-empty)" || { FAIL=$((FAIL+1)); echo "  ✗ TG.1: principles empty"; }

# Claude audit (mocked).
CLAUDE_AUDIT="$(cat "$CLAUDE_MOCK")"
[[ -n "$CLAUDE_AUDIT" ]] && PASS=$((PASS+1)) && echo "  ✓ TG.1: claude-audit mock loaded" || { FAIL=$((FAIL+1)); echo "  ✗ TG.1: claude-audit empty"; }

# Codex audit (mocked via PATH).
CODEX_AUDIT="$(ac_codex_audit "test prompt" 2>/dev/null)"
CODEX_CH="$(printf '%s' "$CODEX_AUDIT" | jq '.challenges | length' 2>/dev/null || echo 0)"
assert_eq "TG.1: codex audit returns 3 challenges" "3" "$CODEX_CH"

# Consolidate.
CONS="$(ac_consolidator_merge "$CLAUDE_AUDIT" "$CODEX_AUDIT")"
CONS_CH="$(printf '%s' "$CONS" | jq '.challenges | length')"
[[ "$CONS_CH" -ge 3 ]] && PASS=$((PASS+1)) && echo "  ✓ TG.1: consolidator merged ≥3 challenges" || { FAIL=$((FAIL+1)); echo "  ✗ TG.1: consolidator output insufficient: $CONS_CH"; }

# Outbox write.
ac_outbox_write "$RID" "$CONS" 5000 "0.12"
assert_file_exists "$(ac_outbox_dir)/${RID}.json"

# State recorded.
ac_state_append_recent_run "$(jq -n --arg rid "$RID" '{request_id:$rid, completed_at:"2026-05-15T00:00:00Z", depth:"close", adversaries_used:["claude","codex"], challenge_count:4, divergence_count:0, elapsed_ms:5000, cost_usd:"0.12"}')"
RECENT="$(ac_state_read | jq '.recent_runs | length')"
assert_eq "TG.1: recent_run recorded" "1" "$RECENT"

rm -f "$CLAUDE_MOCK"
unset ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK

# ---------------------------------------------------------------------------
# TG.2: onboarded repo + /critique --phase 5 (premise-audit, claude-only)
# ---------------------------------------------------------------------------

echo ""
echo "--- TG.2: /critique --phase 5 on onboarded repo (premise-audit) ---"

setup_tmp_repo > /dev/null
ac_state_init
ac_principles_seed
TINY_SPEC="$PLUGIN_ROOT/tests/fixtures/master-specs/tiny-spec.md"

# Simulate onboarded repo: .onboarding-state.json present
mkdir -p .claude
printf '{"project_class":"CLI tool","current_phase":5}\n' > .claude/.onboarding-state.json

CLAUDE_MOCK="$(mock_claude_audit_to_tmp '{"challenges":[{"severity":"premise","text":"Phase 5 lacks decision rubric","references":["Phase 5.1"]}],"gaps":[]}')"
export ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK="$CLAUDE_MOCK"

# Build phase-5 premise-audit envelope, no codex.
RID="$(build_request_envelope "premise-audit" "$TINY_SPEC" 5 '["claude"]')"

INBOX_JSON="$(ac_inbox_read "$RID")"
PHASE_ID="$(printf '%s' "$INBOX_JSON" | jq -r '.target.phase_id')"
assert_eq "TG.2: envelope phase_id=5" "5" "$PHASE_ID"

DEPTH="$(printf '%s' "$INBOX_JSON" | jq -r '.depth')"
assert_eq "TG.2: depth=premise-audit" "premise-audit" "$DEPTH"

# claude-only — no codex dispatch needed.
CLAUDE_AUDIT="$(cat "$CLAUDE_MOCK")"
CONS="$(ac_consolidator_merge "$CLAUDE_AUDIT" '{}')"
ADV="$(printf '%s' "$CONS" | jq -r '.adversaries_used | join(",")')"
assert_eq "TG.2: adversaries_used = claude only" "claude" "$ADV"

ac_outbox_write "$RID" "$CONS" 1200 "0.00"
assert_file_exists "$(ac_outbox_dir)/${RID}.json"

rm -f "$CLAUDE_MOCK"
unset ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK

# ---------------------------------------------------------------------------
# TG.3: full close-depth audit + rebuttal scoring + promotion offer/decline paths
# ---------------------------------------------------------------------------

echo ""
echo "--- TG.3: full audit cycle — consolidator + scorer + promotion ---"

setup_tmp_repo > /dev/null
ac_state_init
ac_principles_seed
TINY_SPEC="$PLUGIN_ROOT/tests/fixtures/master-specs/tiny-spec.md"

# Three challenges in current run, two sharing a topic — triggers within-run candidate.
CURRENT_CHALLENGES='[
  {"severity":"premise","text":"Missing rollback path for migration","references":["Phase 5.2"]},
  {"severity":"gap","text":"Missing rollback strategy for state changes","references":["Phase 5.2"]},
  {"severity":"alternative","text":"Consider event-sourcing for audit trail","references":["Phase 4.1"]}
]'

# Consolidator merges with empty codex (claude-only).
CONS="$(ac_consolidator_merge "$(jq -n --argjson c "$CURRENT_CHALLENGES" '{challenges:$c,gaps:[]}')" '{}')"
CH_COUNT="$(printf '%s' "$CONS" | jq '.challenges | length')"
[[ "$CH_COUNT" -ge 2 ]] && PASS=$((PASS+1)) && echo "  ✓ TG.3: consolidator preserved ≥2 challenges" || { FAIL=$((FAIL+1)); echo "  ✗ TG.3: ch count: $CH_COUNT"; }

# Within-run candidate detection.
WR="$(ac_promotion_within_run_candidates "$CURRENT_CHALLENGES")"
WR_LEN="$(printf '%s' "$WR" | jq 'length')"
assert_eq "TG.3: within-run detected 1 candidate (rollback cluster)" "1" "$WR_LEN"

# Cross-run: no prior runs → no candidates.
CR="$(ac_promotion_cross_run_candidates "$CURRENT_CHALLENGES")"
CR_LEN="$(printf '%s' "$CR" | jq 'length')"
assert_eq "TG.3: cross-run empty (no prior runs)" "0" "$CR_LEN"

# Filter suppressed: none declined yet, all pass.
ALL="$(jq -n --argjson w "$WR" --argjson c "$CR" '$w + $c')"
FILTERED="$(ac_promotion_filter_suppressed "$ALL")"
FILTERED_LEN="$(printf '%s' "$FILTERED" | jq 'length')"
assert_eq "TG.3: 1 candidate not suppressed" "1" "$FILTERED_LEN"

# Accept path: promote to principles.md
CAND_TEXT="Every state-change operation needs a documented rollback"
ac_state_append_promotion "auto" "$CAND_TEXT" "user"
PFILE="$(ac_principles_path)"
printf "%s [promoted %s source:auto]\n" "$CAND_TEXT" "$(date -u +%Y-%m-%d)" >> "$PFILE"
assert_file_contains "$PFILE" "rollback"

PROMO_LEN="$(ac_state_read | jq '.principle_promotions | length')"
assert_eq "TG.3: promotion recorded in state.json" "1" "$PROMO_LEN"

# Decline path on a fresh candidate.
ac_promotion_record_decline "Some other principle"
DEC_LEN="$(ac_state_read | jq '.declined_candidates | length')"
assert_eq "TG.3: decline recorded with suppression" "1" "$DEC_LEN"

# Rebuttal scoring integration: high score concedes, low score restates.
ARCHITECT_CRITIC_SCORER_MOCK=5 SCORE="$(ac_scorer_score_rebuttal "X" "Y")"
DEC="$(ac_scorer_decide "$SCORE")"
assert_eq "TG.3: score=5 → concede" "concede" "$DEC"

ARCHITECT_CRITIC_SCORER_MOCK=3 SCORE="$(ac_scorer_score_rebuttal "X" "Y")"
DEC="$(ac_scorer_decide "$SCORE")"
assert_eq "TG.3: score=3 → restate" "restate" "$DEC"

# Cost line format
COST="$(ac_cost_compute 1000 500)"
[[ -n "$COST" ]] && PASS=$((PASS+1)) && echo "  ✓ TG.3: cost computed: \$${COST}" || { FAIL=$((FAIL+1)); echo "  ✗ TG.3: cost empty"; }

OUT="$(ac_cost_print "$COST" "0")"
echo "$OUT" | grep -q "spent on this audit" \
  && PASS=$((PASS+1)) && echo "  ✓ TG.3: cost line formatted per OQ-3" \
  || { FAIL=$((FAIL+1)); echo "  ✗ TG.3: cost line format wrong: $OUT"; }

report_results
