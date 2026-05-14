#!/usr/bin/env bash
# architect-critic lib/consolidator.sh
# Implements the consolidator algorithm per SPEC §7.1:
#   step 1 — concat + source-tag challenges from both audits
#   step 2 — exact-match dedup by (severity, text-normalized, references-sorted)
#            mark agreed_by_both=true when sources differ and text matches
#   step 3 — divergence detection: refs flagged by one side but not the other
#   step 4 — gaps concat + source-tag (no dedup)
#   output — {challenges, gaps, divergences, adversaries_used}
#
# macOS-portable: bash 3.2, BSD awk, jq (no gawk, no declare -A)

# ac_consolidator_merge <claude_audit_json> <codex_audit_json>
# Prints the consolidated JSON envelope to stdout.
# Returns 0 on success, 1 on jq parse failure.
ac_consolidator_merge() {
  local claude_audit="$1"
  local codex_audit="$2"

  # Validate inputs are parseable JSON
  if ! echo "$claude_audit" | jq -e . >/dev/null 2>&1; then
    ac_log_error "consolidator: claude_audit is not valid JSON"
    return 1
  fi
  if ! echo "$codex_audit" | jq -e . >/dev/null 2>&1; then
    ac_log_error "consolidator: codex_audit is not valid JSON"
    return 1
  fi

  # Determine adversaries_used:
  # codex is considered "used" only if codex_audit has non-empty challenges OR non-empty gaps
  local codex_ch_count codex_gap_count
  codex_ch_count=$(echo "$codex_audit" | jq -r '.challenges | length' 2>/dev/null || echo 0)
  codex_gap_count=$(echo "$codex_audit" | jq -r '.gaps | length' 2>/dev/null || echo 0)

  local adversaries_used_json
  if [[ "$codex_ch_count" -gt 0 || "$codex_gap_count" -gt 0 ]]; then
    adversaries_used_json='["claude","codex"]'
  else
    adversaries_used_json='["claude"]'
  fi

  # Use jq to do the heavy lifting: tag sources, dedup, detect divergences, concat gaps.
  # Note: use ($x | not) not (not $x) — jq BINDING syntax limitation.
  local result
  result=$(jq -n \
    --argjson claude_audit "$claude_audit" \
    --argjson codex_audit "$codex_audit" \
    --argjson adversaries_used "$adversaries_used_json" \
    '
    # Helper: normalize text for dedup (lowercase, trim whitespace)
    def normalize_text(t):
      t | ascii_downcase | ltrimstr(" ") | rtrimstr(" ");

    # Helper: sort and join references array for dedup key
    def refs_key(refs):
      if refs == null then ""
      else (refs | sort | join("|"))
      end;

    # Helper: compute dedup key for a challenge
    def dedup_key(c):
      (c.severity // "") + "|" + normalize_text(c.text // "") + "|" + refs_key(c.references // []);

    # Step 1: tag challenges with source
    ($claude_audit.challenges // [] | map(. + {source: "claude"})) as $claude_ch |
    ($codex_audit.challenges // []  | map(. + {source: "codex"}))  as $codex_ch |

    # Collect all references by source for divergence detection
    ($claude_ch | [.[].references // [] | .[]] | unique) as $claude_refs |
    ($codex_ch  | [.[].references // [] | .[]] | unique) as $codex_refs |

    # Step 2: dedup — group by dedup_key; keep first; mark agreed_by_both when sources differ
    ($claude_ch + $codex_ch) as $all_ch |

    ($all_ch | group_by(dedup_key(.))) as $groups |
    ($groups | map(
      if length == 1 then .[0]
      else
        (map(.source) | unique) as $srcs |
        .[0] + (if ($srcs | length) > 1 then {agreed_by_both: true} else {} end)
      end
    )) as $challenges_deduped |

    # Identify per-source dedup key sets for divergence detection
    ($claude_ch | map(dedup_key(.)) | unique) as $claude_keys |
    ($codex_ch  | map(dedup_key(.)) | unique) as $codex_keys |

    # Step 3: divergence detection
    # For each deduped challenge: if agreed_by_both → skip.
    # If only in claude AND refs not in codex refs → divergence.
    # If only in codex  AND refs not in claude refs → divergence.
    [
      $challenges_deduped[] |
      . as $ch |
      dedup_key($ch) as $k |
      ($ch.references // []) as $refs |
      ([$claude_keys[] | select(. == $k)] | length > 0) as $in_claude |
      ([$codex_keys[]  | select(. == $k)] | length > 0) as $in_codex |
      ($in_codex | not) as $not_in_codex |
      ($in_claude | not) as $not_in_claude |
      if ($ch | has("agreed_by_both")) then empty
      elif ($in_claude and $not_in_codex) then
        ($refs | map(
          . as $r |
          ([$codex_refs[] | select(. == $r)] | length)
        ) | add // 0) as $codex_ref_hits |
        if $codex_ref_hits == 0 then
          {
            between: ["claude","codex"],
            text: ("Claude flagged but codex did not: " + ($ch.text // "")),
            references: $refs
          }
        else empty
        end
      elif ($in_codex and $not_in_claude) then
        ($refs | map(
          . as $r |
          ([$claude_refs[] | select(. == $r)] | length)
        ) | add // 0) as $claude_ref_hits |
        if $claude_ref_hits == 0 then
          {
            between: ["claude","codex"],
            text: ("Codex flagged but claude did not: " + ($ch.text // "")),
            references: $refs
          }
        else empty
        end
      else empty
      end
    ] as $divergences |

    # Step 4: gaps concat + tag, no dedup
    (($claude_audit.gaps // [] | map(. + {source: "claude"})) +
     ($codex_audit.gaps  // [] | map(. + {source: "codex"}))) as $gaps_combined |

    # Output envelope per SPEC §6.2
    {
      challenges: $challenges_deduped,
      gaps: $gaps_combined,
      divergences: $divergences,
      adversaries_used: $adversaries_used
    }
    ' 2>/dev/null)

  if [[ $? -ne 0 || -z "$result" ]]; then
    ac_log_error "consolidator: jq merge failed"
    return 1
  fi

  echo "$result"
  return 0
}
