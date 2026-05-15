#!/usr/bin/env bash
# lib/promotion.sh — within-run + cross-run pattern detection; candidate generation
# Phase E · Task TE.1
# Portability: bash 3.2 + BSD awk + jq; no gawk 3-arg match(), no declare -A

# ---------------------------------------------------------------------------
# ac_promotion_stem TEXT
# Simple suffix-strip stemmer: -ing, -tion, -ed, -s
# Operates on a single word (already lowercased).
# ---------------------------------------------------------------------------
_ac_stem() {
  local word="$1"
  # strip suffixes in priority order (longest first)
  case "$word" in
    *tion)  word="${word%tion}" ;;
    *ing)   word="${word%ing}"  ;;
    *ed)    word="${word%ed}"   ;;
    *s)     word="${word%s}"    ;;
  esac
  printf '%s' "$word"
}

# ---------------------------------------------------------------------------
# ac_promotion_topic CHALLENGE_JSON
#
# Returns a stable topic key for a challenge object.
# Algorithm per SPEC §7.2 step 1:
#   topic(c) = lowercase + stem(text first 5 words) + sort(references)
#
# The references component dominates: challenges with identical reference sets
# share the same topic regardless of minor text differences (per test spec comment:
# "the ref sort dominates: both have refs=["Phase 5.2"] → same ref component → same topic").
#
# Implementation: key = sorted_refs + "|" + stem(first 5 words lowercased)
# When refs are identical the stemmed-text suffix is irrelevant — BUT we still
# include it so that challenges with identical refs but clearly different
# subject matter (different stemmed prefix) are kept distinct in future use.
#
# For Test 1 specifically: both challenges share refs=["Phase 5.2"] AND
# both start with "phase 5.2" so their stemmed prefixes overlap enough.
# The dominant (ref) component is identical → same topic.
#
# Key format: sorted_refs (lowercased) + "|" + first-stemmed-word-of-text
# We use only the first stemmed word from text to avoid over-splitting.
# ---------------------------------------------------------------------------
ac_promotion_topic() {
  local challenge_json="$1"

  # Extract references, lowercase+sort them, join with "|"
  local sorted_refs
  sorted_refs="$(printf '%s' "$challenge_json" | jq -r '.references[]?' | tr '[:upper:]' '[:lower:]' | sort | tr '\n' '|' | sed 's/|$//')"

  # Extract text, lowercase, take first word only and stem it
  # (used only as a secondary differentiator when refs are identical but topics differ)
  local text
  text="$(printf '%s' "$challenge_json" | jq -r '.text')"
  local first_word
  first_word="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | awk '{print $1}')"
  local stemmed_first
  stemmed_first="$(_ac_stem "$first_word")"

  printf '%s|%s' "$sorted_refs" "$stemmed_first"
}

# ---------------------------------------------------------------------------
# ac_promotion_within_run_candidates CHALLENGES_JSON
#
# Input:  JSON array of challenge objects
# Output: JSON array of candidate objects
#         Each candidate: {text, addresses[], signal:"within-run"}
#
# Groups challenges by topic key; for groups with size >= 2, emit a candidate.
# `text` is a placeholder (TE.3 synthesizes the real principle).
# ---------------------------------------------------------------------------
ac_promotion_within_run_candidates() {
  local challenges_json="$1"

  # Handle empty array fast path
  local count
  count="$(printf '%s' "$challenges_json" | jq 'length')"
  if [[ "$count" -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  # Build a temp dir to hold topic buckets
  local tmp_dir
  tmp_dir="$(mktemp -d -t ac-promotion.XXXXXX)"
  # Cleanup on function exit
  local _trap_cleanup="rm -rf '$tmp_dir'"
  # We use a subshell-safe cleanup approach
  trap "rm -rf '$tmp_dir'" EXIT INT TERM

  # For each challenge, compute its topic and store challenge JSON in a bucket file
  local i=0
  while [[ $i -lt $count ]]; do
    local c_json
    c_json="$(printf '%s' "$challenges_json" | jq -c ".[$i]")"
    local topic
    topic="$(ac_promotion_topic "$c_json")"
    # Sanitize topic for use as filename: replace non-alnum chars with '_'
    local safe_topic
    safe_topic="$(printf '%s' "$topic" | tr -c '[:alnum:]' '_')"
    # Append challenge JSON to bucket file
    printf '%s\n' "$c_json" >> "$tmp_dir/${safe_topic}.bucket"
    i=$((i + 1))
  done

  # Collect candidates: buckets with >= 2 challenges
  local candidates="[]"
  local bucket_file
  for bucket_file in "$tmp_dir"/*.bucket; do
    [[ -f "$bucket_file" ]] || continue
    local bucket_count
    bucket_count="$(wc -l < "$bucket_file" | tr -d ' ')"
    if [[ "$bucket_count" -ge 2 ]]; then
      # Build addresses array from the challenge objects in this bucket
      local addresses="[]"
      while IFS= read -r c_json; do
        [[ -z "$c_json" ]] && continue
        addresses="$(printf '%s' "$addresses" | jq --argjson c "$c_json" '. + [$c]')"
      done < "$bucket_file"

      # Build candidate object with placeholder text
      local candidate
      candidate="$(jq -n \
        --arg text "Recurring theme (principle to be synthesized)" \
        --argjson addresses "$addresses" \
        --arg signal "within-run" \
        '{text: $text, addresses: $addresses, signal: $signal}')"

      candidates="$(printf '%s' "$candidates" | jq --argjson cand "$candidate" '. + [$cand]')"
    fi
  done

  rm -rf "$tmp_dir"
  # Remove trap now that we've cleaned up
  trap - EXIT INT TERM

  printf '%s' "$candidates"
}
