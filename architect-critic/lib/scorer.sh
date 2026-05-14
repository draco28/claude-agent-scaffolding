#!/usr/bin/env bash
# lib/scorer.sh — 1–5 rubric scoring for user rebuttals.
# Implements SPEC §7.3 algorithm: heuristic first, claude-reasoning fallback.
# macOS bash 3.2 compatible.

# ac_scorer_score_rebuttal <challenge_text> <rebuttal_text>
#
# Returns an integer 1–5 on stdout.
#
# Rubric:
#   1 = Bare contradiction
#   2 = Cite-self (points to spec without new info)
#   3 = Partial address
#   4 = Material new info
#   5 = Premise invalidated
#
# Algorithm:
#   Step 1 — heuristic check on truncated rebuttal (first 500 chars):
#     a. length < 20 AND matches /^(no|wrong|disagree|not true)/i → 1
#     b. rebuttal is substring of MASTER-SPEC content → 2
#     c. rebuttal contains words not in MASTER-SPEC → ≥4 (defer to mock/LLM)
#   Step 2 — claude-reasoning fallback (mocked via ARCHITECT_CRITIC_SCORER_MOCK in tests)
#
# Env vars:
#   ARCHITECT_CRITIC_SPEC_PATH  — path to MASTER-SPEC for cite-self + new-fact checks
#   ARCHITECT_CRITIC_SCORER_MOCK — integer 1–5; overrides claude-reasoning fallback score
ac_scorer_score_rebuttal() {
  local challenge_text="$1"
  local rebuttal_text="$2"

  # Truncate rebuttal to first 500 chars (multi-paragraph guard per SPEC §9 edge cases)
  local rebuttal_truncated
  rebuttal_truncated="${rebuttal_text:0:500}"

  local rebuttal_len="${#rebuttal_truncated}"

  # ---- Step 1a: Bare contradiction heuristic --------------------------------
  # length < 20 AND starts with no|wrong|disagree|not true (case-insensitive)
  if [[ "$rebuttal_len" -lt 20 ]]; then
    # bash 3.2 compatible: use grep for case-insensitive regex match
    if printf '%s' "$rebuttal_truncated" | grep -qi '^(no|wrong|disagree|not true)'; then
      printf '%s\n' "1"
      return 0
    fi
    # Also check with extended regex via grep -E for the alternation pattern
    if printf '%s' "$rebuttal_truncated" | grep -qiE '^(no|wrong|disagree|not true)'; then
      printf '%s\n' "1"
      return 0
    fi
  fi

  # ---- Step 1b: Cite-self heuristic -----------------------------------------
  # Check if rebuttal text is a substring of MASTER-SPEC content.
  # Only if ARCHITECT_CRITIC_SPEC_PATH is set and the file is readable.
  local spec_path="${ARCHITECT_CRITIC_SPEC_PATH:-}"
  if [[ -n "$spec_path" && -r "$spec_path" ]]; then
    local spec_content
    spec_content="$(cat "$spec_path")"
    # Check if rebuttal_truncated is a literal substring of spec_content
    # Use bash parameter expansion for substring check (bash 3.2 compatible)
    if [[ "$spec_content" == *"$rebuttal_truncated"* ]]; then
      printf '%s\n' "2"
      return 0
    fi
  fi

  # ---- Step 1c: Material new info heuristic ----------------------------------
  # Check if rebuttal contains words not in the MASTER-SPEC.
  # If spec_path is available, compare word sets; if rebuttal has unique words → ≥4.
  if [[ -n "$spec_path" && -r "$spec_path" ]]; then
    local spec_content
    spec_content="$(cat "$spec_path")"
    # Extract all words from rebuttal (lowercase, alpha only)
    # Use awk for portability (BSD awk compatible, no gawk 3-arg match)
    local has_new_word=0
    # Split rebuttal into words, check each against spec content
    local word
    while IFS= read -r word; do
      [[ -z "$word" ]] && continue
      # Skip very short words (articles, prepositions etc.) to reduce false positives
      [[ "${#word}" -lt 4 ]] && continue
      # Check if this word appears in spec content (case-insensitive)
      if ! printf '%s' "$spec_content" | grep -qi "$word" 2>/dev/null; then
        has_new_word=1
        break
      fi
    done < <(printf '%s\n' "$rebuttal_truncated" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z' '\n')

    if [[ "$has_new_word" -eq 1 ]]; then
      # Has material new info — defer to mock/claude-reasoning for exact score (4 or 5)
      # If no mock set, default to 4 (material new info)
      local mock_score="${ARCHITECT_CRITIC_SCORER_MOCK:-}"
      if [[ -n "$mock_score" ]]; then
        printf '%s\n' "$mock_score"
      else
        printf '%s\n' "4"
      fi
      return 0
    fi
  fi

  # ---- Step 2: claude-reasoning fallback ------------------------------------
  # In production: invoke Claude with the scoring prompt.
  # In tests: respect ARCHITECT_CRITIC_SCORER_MOCK env var.
  local mock_score="${ARCHITECT_CRITIC_SCORER_MOCK:-}"
  if [[ -n "$mock_score" ]]; then
    printf '%s\n' "$mock_score"
    return 0
  fi

  # Production claude-reasoning fallback (deferred to LLM in real usage).
  # For now emit 3 (partial address) as the conservative default when no mock.
  printf '%s\n' "3"
  return 0
}

# ac_scorer_decide <score>
#
# Prints "concede" if score ≥ 4 (T=4 firm threshold, SPEC §9.1 Q4).
# Prints "restate" otherwise.
ac_scorer_decide() {
  local score="$1"
  if [[ "$score" -ge 4 ]]; then
    printf '%s\n' "concede"
  else
    printf '%s\n' "restate"
  fi
}
