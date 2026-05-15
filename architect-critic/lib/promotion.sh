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

# ---------------------------------------------------------------------------
# ac_promotion_cross_run_candidates CURRENT_CHALLENGES_JSON
#
# Input:  JSON array of challenge objects from the current run.
# Output: JSON array of candidate objects with signal:"cross-run".
#
# Algorithm:
#   For each challenge in current_challenges_json, compute its topic via
#   ac_promotion_topic. Count how many challenges in recent_runs[0..19]
#   share that topic. Current challenge counts as 1; if total >= 3 (i.e.
#   >= 2 prior matches), emit a candidate.
#
# Portability: bash 3.2 + jq; uses parallel arrays for topic counting.
# ---------------------------------------------------------------------------
ac_promotion_cross_run_candidates() {
  local current_challenges_json="$1"

  # Fast path: empty current challenges
  local cur_count
  cur_count="$(printf '%s' "$current_challenges_json" | jq 'length')"
  if [[ "$cur_count" -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  # Read recent_runs from state (up to 20 entries)
  local state_json
  state_json="$(ac_state_read)"

  # Build a list of all challenges from recent_runs as one JSON array.
  # Each recent_run may have a .challenges field (array).
  local prior_challenges_json
  prior_challenges_json="$(printf '%s' "$state_json" | jq '[.recent_runs[0:20][].challenges[]?]')"

  local prior_count
  prior_count="$(printf '%s' "$prior_challenges_json" | jq 'length')"

  # Compute topic for each current challenge; store in parallel arrays
  local _cur_topics=()
  local _cur_jsons=()
  local i=0
  while [[ $i -lt $cur_count ]]; do
    local c_json
    c_json="$(printf '%s' "$current_challenges_json" | jq -c ".[$i]")"
    local topic
    topic="$(ac_promotion_topic "$c_json")"
    _cur_topics+=("$topic")
    _cur_jsons+=("$c_json")
    i=$((i + 1))
  done

  # For each unique current topic, count prior matches
  # Use parallel arrays: _lookup_keys[], _lookup_counts[]
  local _lookup_keys=()
  local _lookup_counts=()

  # Count prior challenges per topic
  local j=0
  while [[ $j -lt $prior_count ]]; do
    local p_json
    p_json="$(printf '%s' "$prior_challenges_json" | jq -c ".[$j]")"
    local p_topic
    p_topic="$(ac_promotion_topic "$p_json")"

    # Find if topic already in lookup
    local found=0
    local k=0
    while [[ $k -lt ${#_lookup_keys[@]} ]]; do
      if [[ "${_lookup_keys[$k]}" == "$p_topic" ]]; then
        _lookup_counts[$k]=$(( _lookup_counts[$k] + 1 ))
        found=1
        break
      fi
      k=$((k + 1))
    done
    if [[ $found -eq 0 ]]; then
      _lookup_keys+=("$p_topic")
      _lookup_counts+=(1)
    fi
    j=$((j + 1))
  done

  # For each current challenge topic, look up prior count; if total >= 3, emit candidate
  local candidates="[]"
  local i=0
  while [[ $i -lt $cur_count ]]; do
    local topic="${_cur_topics[$i]}"
    local c_json="${_cur_jsons[$i]}"

    local prior_match=0
    local k=0
    while [[ $k -lt ${#_lookup_keys[@]} ]]; do
      if [[ "${_lookup_keys[$k]}" == "$topic" ]]; then
        prior_match="${_lookup_counts[$k]}"
        break
      fi
      k=$((k + 1))
    done

    # current counts as 1; total = 1 + prior_match; need >= 3
    local total=$(( 1 + prior_match ))
    if [[ $total -ge 3 ]]; then
      local candidate
      candidate="$(jq -n \
        --arg text "Recurring theme (principle to be synthesized)" \
        --argjson addresses "[$c_json]" \
        --arg signal "cross-run" \
        '{text: $text, addresses: $addresses, signal: $signal}')"
      candidates="$(printf '%s' "$candidates" | jq --argjson cand "$candidate" '. + [$cand]')"
    fi
    i=$((i + 1))
  done

  printf '%s' "$candidates"
}

# ac_promotion_synthesize <cluster_json>
#
# Emits either the canned mock principle (when ARCHITECT_CRITIC_PROMOTION_MOCK is set,
# for tests) or the claude-reasoning prompt text Claude would use to synthesize a
# one-line principle from the cluster. Per SPEC §7.2 step 3 — the actual claude-
# reasoning is invoked from /critique's body in Phase E TE.5; this lib just
# builds the prompt string.
ac_promotion_synthesize() {
  local cluster_json="$1"
  if [[ -n "${ARCHITECT_CRITIC_PROMOTION_MOCK:-}" ]]; then
    printf '%s' "$ARCHITECT_CRITIC_PROMOTION_MOCK"
    return 0
  fi
  local addresses
  addresses="$(printf '%s' "$cluster_json" | jq -r '[.addresses[]?.text // .addresses[]?] | map(select(. != null)) | map("  - " + tostring) | join("\n")')"
  cat <<EOF
You are summarizing a recurring critique theme into one short prescriptive principle.
Challenges:
${addresses}
Return a single line, imperative voice, ≤120 chars, no preamble.
EOF
}
