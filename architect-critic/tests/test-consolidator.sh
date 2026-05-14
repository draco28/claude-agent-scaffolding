#!/usr/bin/env bash
# test-consolidator.sh — unit tests for lib/consolidator.sh
# ~15 tests covering: empty+empty, claude-only, no-overlap, exact-match dedup,
# agreed-by-both, divergences (claude flagged / codex flagged), gaps concat,
# adversaries_used, and edge cases.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"
# shellcheck source=../lib/_helpers.sh
source "$PLUGIN_ROOT/lib/_helpers.sh"
# shellcheck source=../lib/consolidator.sh
source "$PLUGIN_ROOT/lib/consolidator.sh"

echo "=== test-consolidator.sh ==="

# ---------------------------------------------------------------------------
# 1. empty + empty → empty result; adversaries_used = ["claude"]
# ---------------------------------------------------------------------------
echo ""
echo "-- 1. empty+empty → empty result, adversaries_used=[\"claude\"] --"
(
  claude_audit='{"challenges":[],"gaps":[]}'
  codex_audit='{"challenges":[],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec on empty inputs"
    exit 1
  fi
  ch_count=$(echo "$result" | jq -r '.challenges | length')
  gap_count=$(echo "$result" | jq -r '.gaps | length')
  div_count=$(echo "$result" | jq -r '.divergences | length')
  adv=$(echo "$result" | jq -r '.adversaries_used | join(",")')
  if [[ "$ch_count" == "0" ]]; then
    echo "  ✓ empty+empty: challenges=0"
  else
    echo "  ✗ expected challenges=0, got $ch_count"; exit 1
  fi
  if [[ "$gap_count" == "0" ]]; then
    echo "  ✓ empty+empty: gaps=0"
  else
    echo "  ✗ expected gaps=0, got $gap_count"; exit 1
  fi
  if [[ "$div_count" == "0" ]]; then
    echo "  ✓ empty+empty: divergences=0"
  else
    echo "  ✗ expected divergences=0, got $div_count"; exit 1
  fi
  if [[ "$adv" == "claude" ]]; then
    echo "  ✓ empty+empty: adversaries_used=[claude] (codex empty = skipped)"
  else
    echo "  ✗ expected adversaries_used=[claude], got $adv"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+4)); else FAIL=$((FAIL+4)); fi

# ---------------------------------------------------------------------------
# 2. claude-only + empty codex → only claude's items, source=claude,
#    adversaries_used=["claude"]
# ---------------------------------------------------------------------------
echo ""
echo "-- 2. claude-only + empty codex → source=claude, adversaries_used=[claude] --"
(
  claude_audit='{"challenges":[{"severity":"premise","text":"Missing rollback strategy","references":["Phase 3"]}],"gaps":[{"text":"No monitoring plan","severity":"info"}]}'
  codex_audit='{"challenges":[],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec"; exit 1
  fi
  ch_count=$(echo "$result" | jq -r '.challenges | length')
  source=$(echo "$result" | jq -r '.challenges[0].source')
  adv=$(echo "$result" | jq -r '.adversaries_used | join(",")')
  gap_source=$(echo "$result" | jq -r '.gaps[0].source')
  if [[ "$ch_count" == "1" ]]; then
    echo "  ✓ claude-only: 1 challenge kept"
  else
    echo "  ✗ expected 1 challenge, got $ch_count"; exit 1
  fi
  if [[ "$source" == "claude" ]]; then
    echo "  ✓ claude-only: challenge source=claude"
  else
    echo "  ✗ expected source=claude, got $source"; exit 1
  fi
  if [[ "$adv" == "claude" ]]; then
    echo "  ✓ claude-only: adversaries_used=[claude]"
  else
    echo "  ✗ expected adversaries_used=[claude], got $adv"; exit 1
  fi
  if [[ "$gap_source" == "claude" ]]; then
    echo "  ✓ claude-only: gap source=claude"
  else
    echo "  ✗ expected gap source=claude, got $gap_source"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+4)); else FAIL=$((FAIL+4)); fi

# ---------------------------------------------------------------------------
# 3. claude + codex with no overlap → both kept, both tagged correctly
# ---------------------------------------------------------------------------
echo ""
echo "-- 3. no overlap → both kept, both tagged --"
(
  claude_audit='{"challenges":[{"severity":"premise","text":"Claude challenge A","references":["Phase 1"]}],"gaps":[]}'
  codex_audit='{"challenges":[{"severity":"gap","text":"Codex challenge B","references":["Phase 2"]}],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec"; exit 1
  fi
  ch_count=$(echo "$result" | jq -r '.challenges | length')
  claude_src=$(echo "$result" | jq -r '.challenges[] | select(.source=="claude") | .source')
  codex_src=$(echo "$result" | jq -r '.challenges[] | select(.source=="codex") | .source')
  adv=$(echo "$result" | jq -r '.adversaries_used | sort | join(",")')
  if [[ "$ch_count" == "2" ]]; then
    echo "  ✓ no-overlap: 2 challenges kept"
  else
    echo "  ✗ expected 2 challenges, got $ch_count"; exit 1
  fi
  if [[ "$claude_src" == "claude" ]]; then
    echo "  ✓ no-overlap: claude challenge tagged source=claude"
  else
    echo "  ✗ claude challenge missing source=claude"; exit 1
  fi
  if [[ "$codex_src" == "codex" ]]; then
    echo "  ✓ no-overlap: codex challenge tagged source=codex"
  else
    echo "  ✗ codex challenge missing source=codex"; exit 1
  fi
  if [[ "$adv" == "claude,codex" ]]; then
    echo "  ✓ no-overlap: adversaries_used=[claude,codex]"
  else
    echo "  ✗ expected adversaries_used=[claude,codex], got $adv"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+4)); else FAIL=$((FAIL+4)); fi

# ---------------------------------------------------------------------------
# 4. exact-match dedup → 1 item kept (same severity, text, refs)
# ---------------------------------------------------------------------------
echo ""
echo "-- 4. exact-match dedup → 1 item kept --"
(
  same_text="Missing rollback plan"
  claude_audit="{\"challenges\":[{\"severity\":\"premise\",\"text\":\"$same_text\",\"references\":[\"Phase 3\"]}],\"gaps\":[]}"
  codex_audit="{\"challenges\":[{\"severity\":\"premise\",\"text\":\"$same_text\",\"references\":[\"Phase 3\"]}],\"gaps\":[]}"
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec"; exit 1
  fi
  ch_count=$(echo "$result" | jq -r '.challenges | length')
  if [[ "$ch_count" == "1" ]]; then
    echo "  ✓ exact-match dedup: 1 challenge (deduped from 2)"
  else
    echo "  ✗ expected 1 challenge after dedup, got $ch_count"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 5. exact-match dedup → agreed_by_both=true when sources differ
# ---------------------------------------------------------------------------
echo ""
echo "-- 5. exact-match dedup: agreed_by_both=true when sources differ --"
(
  same_text="Authentication not covered in spec"
  claude_audit="{\"challenges\":[{\"severity\":\"gap\",\"text\":\"$same_text\",\"references\":[\"Phase 5\"]}],\"gaps\":[]}"
  codex_audit="{\"challenges\":[{\"severity\":\"gap\",\"text\":\"$same_text\",\"references\":[\"Phase 5\"]}],\"gaps\":[]}"
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  agreed=$(echo "$result" | jq -r '.challenges[0].agreed_by_both')
  if [[ "$agreed" == "true" ]]; then
    echo "  ✓ dedup with differing sources: agreed_by_both=true"
  else
    echo "  ✗ expected agreed_by_both=true, got $agreed"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 6. divergence: claude flagged Phase 2, codex did not → Phase 2 in divergences
# ---------------------------------------------------------------------------
echo ""
echo "-- 6. claude flagged Phase 2, codex didn't → divergence --"
(
  claude_audit='{"challenges":[{"severity":"premise","text":"Phase 2 lacks a rollback","references":["Phase 2"]}],"gaps":[]}'
  codex_audit='{"challenges":[{"severity":"gap","text":"Some unrelated issue","references":["Phase 5"]}],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec"; exit 1
  fi
  div_count=$(echo "$result" | jq -r '.divergences | length')
  div_between=$(echo "$result" | jq -r '.divergences[0].between | sort | join(",")')
  div_ref=$(echo "$result" | jq -r '.divergences[].references[]' 2>/dev/null | grep -c "Phase 2" || true)
  if [[ "$div_count" -ge 1 ]]; then
    echo "  ✓ claude-flagged-only: divergence detected"
  else
    echo "  ✗ expected ≥1 divergence, got $div_count"; exit 1
  fi
  if [[ "$div_between" == "claude,codex" ]]; then
    echo "  ✓ divergence.between=[claude,codex]"
  else
    echo "  ✗ expected between=[claude,codex], got $div_between"; exit 1
  fi
  if [[ "$div_ref" -ge 1 ]]; then
    echo "  ✓ divergence references include Phase 2"
  else
    echo "  ✗ expected Phase 2 in divergence references"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+3)); else FAIL=$((FAIL+3)); fi

# ---------------------------------------------------------------------------
# 7. divergence: codex flagged Phase 3, claude did not → Phase 3 in divergences
# ---------------------------------------------------------------------------
echo ""
echo "-- 7. codex flagged Phase 3, claude didn't → divergence --"
(
  claude_audit='{"challenges":[{"severity":"gap","text":"Unrelated claude issue","references":["Phase 1"]}],"gaps":[]}'
  codex_audit='{"challenges":[{"severity":"premise","text":"Phase 3 missing error handling","references":["Phase 3"]}],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec"; exit 1
  fi
  div_count=$(echo "$result" | jq -r '.divergences | length')
  div_ref=$(echo "$result" | jq -r '.divergences[].references[]' 2>/dev/null | grep -c "Phase 3" || true)
  if [[ "$div_count" -ge 1 ]]; then
    echo "  ✓ codex-flagged-only: divergence detected"
  else
    echo "  ✗ expected ≥1 divergence, got $div_count"; exit 1
  fi
  if [[ "$div_ref" -ge 1 ]]; then
    echo "  ✓ divergence references include Phase 3"
  else
    echo "  ✗ expected Phase 3 in divergence references"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+2)); else FAIL=$((FAIL+2)); fi

# ---------------------------------------------------------------------------
# 8. gaps concatenated without dedup (1 from claude + 1 from codex → 2 total)
# ---------------------------------------------------------------------------
echo ""
echo "-- 8. gaps concatenated without dedup (1+1→2) --"
(
  claude_audit='{"challenges":[],"gaps":[{"text":"Gap from claude","severity":"info"}]}'
  codex_audit='{"challenges":[],"gaps":[{"text":"Gap from codex","severity":"warning"}]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_consolidator_merge returned $ec"; exit 1
  fi
  gap_count=$(echo "$result" | jq -r '.gaps | length')
  claude_gap_src=$(echo "$result" | jq -r '.gaps[] | select(.source=="claude") | .source')
  codex_gap_src=$(echo "$result" | jq -r '.gaps[] | select(.source=="codex") | .source')
  if [[ "$gap_count" == "2" ]]; then
    echo "  ✓ gaps: 2 total (1 claude + 1 codex)"
  else
    echo "  ✗ expected 2 gaps, got $gap_count"; exit 1
  fi
  if [[ "$claude_gap_src" == "claude" ]]; then
    echo "  ✓ gaps: claude gap tagged source=claude"
  else
    echo "  ✗ claude gap missing source=claude"; exit 1
  fi
  if [[ "$codex_gap_src" == "codex" ]]; then
    echo "  ✓ gaps: codex gap tagged source=codex"
  else
    echo "  ✗ codex gap missing source=codex"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+3)); else FAIL=$((FAIL+3)); fi

# ---------------------------------------------------------------------------
# 9. gaps: identical gap text from both sources → NOT deduped (2 kept)
# ---------------------------------------------------------------------------
echo ""
echo "-- 9. identical gaps not deduped → 2 kept --"
(
  same_gap="Auth flow undocumented"
  claude_audit="{\"challenges\":[],\"gaps\":[{\"text\":\"$same_gap\",\"severity\":\"info\"}]}"
  codex_audit="{\"challenges\":[],\"gaps\":[{\"text\":\"$same_gap\",\"severity\":\"info\"}]}"
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  gap_count=$(echo "$result" | jq -r '.gaps | length')
  if [[ "$gap_count" == "2" ]]; then
    echo "  ✓ gaps: identical text not deduped (2 kept)"
  else
    echo "  ✗ expected 2 gaps (no dedup), got $gap_count"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 10. adversaries_used: both audits non-empty → ["claude","codex"]
# ---------------------------------------------------------------------------
echo ""
echo "-- 10. adversaries_used=[claude,codex] when both non-empty --"
(
  claude_audit='{"challenges":[{"severity":"gap","text":"Claude item","references":["Phase 1"]}],"gaps":[]}'
  codex_audit='{"challenges":[{"severity":"gap","text":"Codex item","references":["Phase 2"]}],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  adv=$(echo "$result" | jq -r '.adversaries_used | sort | join(",")')
  if [[ "$adv" == "claude,codex" ]]; then
    echo "  ✓ adversaries_used=[claude,codex] when both have content"
  else
    echo "  ✗ expected [claude,codex], got $adv"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 11. adversaries_used: empty codex challenges+gaps → ["claude"]
# ---------------------------------------------------------------------------
echo ""
echo "-- 11. adversaries_used=[claude] when codex empty --"
(
  claude_audit='{"challenges":[{"severity":"gap","text":"Claude item","references":["Phase 1"]}],"gaps":[]}'
  codex_audit='{"challenges":[],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  adv=$(echo "$result" | jq -r '.adversaries_used | join(",")')
  if [[ "$adv" == "claude" ]]; then
    echo "  ✓ adversaries_used=[claude] when codex empty"
  else
    echo "  ✗ expected adversaries_used=[claude], got $adv"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 12. no divergence when both flag the same reference (deduped/agreed)
# ---------------------------------------------------------------------------
echo ""
echo "-- 12. no divergence when both flag same reference (agreed) --"
(
  same_text="Phase 4 lacks rate limiting"
  claude_audit="{\"challenges\":[{\"severity\":\"premise\",\"text\":\"$same_text\",\"references\":[\"Phase 4\"]}],\"gaps\":[]}"
  codex_audit="{\"challenges\":[{\"severity\":\"premise\",\"text\":\"$same_text\",\"references\":[\"Phase 4\"]}],\"gaps\":[]}"
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  div_count=$(echo "$result" | jq -r '.divergences | length')
  if [[ "$div_count" == "0" ]]; then
    echo "  ✓ no divergence when both agree on same reference/text"
  else
    echo "  ✗ expected 0 divergences, got $div_count"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 13. output is valid JSON with required keys
# ---------------------------------------------------------------------------
echo ""
echo "-- 13. output is valid JSON with required keys --"
(
  claude_audit='{"challenges":[{"severity":"gap","text":"Some challenge","references":["Phase 1"]}],"gaps":[]}'
  codex_audit='{"challenges":[],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  has_challenges=$(echo "$result" | jq 'has("challenges")' 2>/dev/null)
  has_gaps=$(echo "$result" | jq 'has("gaps")' 2>/dev/null)
  has_divergences=$(echo "$result" | jq 'has("divergences")' 2>/dev/null)
  has_adv=$(echo "$result" | jq 'has("adversaries_used")' 2>/dev/null)
  if [[ "$has_challenges" == "true" && "$has_gaps" == "true" && "$has_divergences" == "true" && "$has_adv" == "true" ]]; then
    echo "  ✓ output has all required keys: challenges, gaps, divergences, adversaries_used"
  else
    echo "  ✗ missing required keys: challenges=$has_challenges gaps=$has_gaps divergences=$has_divergences adversaries_used=$has_adv"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 14. dedup key is case-insensitive normalized text + sorted refs
#     "Phase 3" refs sorted same as ["Phase 3"] — single ref edge case
# ---------------------------------------------------------------------------
echo ""
echo "-- 14. dedup: refs sorted before grouping (order-independent) --"
(
  # Same challenge but refs in different order
  claude_audit='{"challenges":[{"severity":"gap","text":"Auth gap","references":["Phase 3","Phase 1"]}],"gaps":[]}'
  codex_audit='{"challenges":[{"severity":"gap","text":"Auth gap","references":["Phase 1","Phase 3"]}],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ch_count=$(echo "$result" | jq -r '.challenges | length')
  if [[ "$ch_count" == "1" ]]; then
    echo "  ✓ dedup: refs sorted → same challenge deduped (different ref order)"
  else
    echo "  ✗ expected 1 challenge (deduped), got $ch_count"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 15. multi-challenge merge: 2 from claude + 2 from codex, 1 shared → 3 total
# ---------------------------------------------------------------------------
echo ""
echo "-- 15. multi-challenge: 2+2 with 1 shared → 3 total --"
(
  claude_audit='{"challenges":[{"severity":"premise","text":"Shared challenge","references":["Phase 1"]},{"severity":"gap","text":"Claude-only challenge","references":["Phase 2"]}],"gaps":[]}'
  codex_audit='{"challenges":[{"severity":"premise","text":"Shared challenge","references":["Phase 1"]},{"severity":"alternative","text":"Codex-only challenge","references":["Phase 3"]}],"gaps":[]}'
  result=$(ac_consolidator_merge "$claude_audit" "$codex_audit" 2>/dev/null)
  ch_count=$(echo "$result" | jq -r '.challenges | length')
  if [[ "$ch_count" == "3" ]]; then
    echo "  ✓ multi-challenge: 3 total (1 deduped shared + 2 unique)"
  else
    echo "  ✗ expected 3 challenges, got $ch_count"; exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

report_results
