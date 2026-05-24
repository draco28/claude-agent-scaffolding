#!/usr/bin/env bash
# lib/rules.sh — R2 machine-checkable rules DSL (mcrule) parser + validator + filter
#
# Per SPEC §8 (scaffold-onboard v0.2):
#   §8.1 Storage — rules in `03-code-patterns.md` under "## Machine-checkable rules"
#   §8.2 Grammar — HTML-sentinel `<!-- mcrule:start type=<T> -->` ... `<!-- mcrule:end -->`
#   §8.3 Rule types — banned_imports, coverage_floor, style_invariants, required_pattern
#   §8.4 API     — sf_rules_parse, sf_rules_validate_block, sf_rules_filter
#   §8.5 Extensibility — unknown types warn-and-skip (forward-compat)
#
# Bash 3.2-compatible (macOS-portable): no `declare -A`; type→required-fields map
# is two parallel indexed arrays. BSD awk-compatible: no gawk-only 3-arg match().
# All JSON construction goes through jq.

# Source logging helpers from _helpers.sh.
_sf_rules_source_helpers() {
  local helpers
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh" ]]; then
    helpers="${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
  else
    helpers="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
  fi
  # shellcheck disable=SC1090
  [[ -f "$helpers" ]] && source "$helpers"
}
_sf_rules_source_helpers

# ----------------------------------------------------------------------------
# Type → required / optional / all-known fields map (parallel arrays).
# Indices: 0=banned_imports, 1=coverage_floor, 2=style_invariants, 3=required_pattern
# ----------------------------------------------------------------------------
_SF_RULES_TYPES=(banned_imports coverage_floor style_invariants required_pattern)
_SF_RULES_REQUIRED=(
  "forbid"
  "paths threshold"
  "forbid_pattern"
  "require_pattern"
)
_SF_RULES_OPTIONAL=(
  "in where"
  ""
  "in exclude where"
  "in exclude where"
)

# Returns 0 if $1 is one of the known v0.2 rule types, else 1.
_sf_rules_is_known_type() {
  local t="$1"
  local known
  for known in "${_SF_RULES_TYPES[@]}"; do
    [[ "$known" == "$t" ]] && return 0
  done
  return 1
}

# Echoes the index of $1 in _SF_RULES_TYPES, or empty if not found.
_sf_rules_type_index() {
  local t="$1"
  local i=0
  for known in "${_SF_RULES_TYPES[@]}"; do
    if [[ "$known" == "$t" ]]; then
      echo "$i"
      return 0
    fi
    i=$((i+1))
  done
  return 1
}

# ----------------------------------------------------------------------------
# sf_rules_parse <path_to_patterns_md>
# ----------------------------------------------------------------------------
# Extract every mcrule block from the file and emit a JSON array of objects:
#   [{ "type": "...", "<field>": "...", ... }, ...]
# Unknown types: warning to stderr, block omitted from output (§8.5).
# Malformed blocks (missing end sentinel; missing type= attr): warn + skip.
sf_rules_parse() {
  local path="$1"
  if [[ -z "$path" || ! -f "$path" ]]; then
    sf_log_error "sf_rules_parse: file not found: ${path:-<empty>}"
    return 1
  fi

  # Pass 1: use awk to emit a stream of records.
  # Each block produces a record beginning with "BLOCK <type>\n" and ending
  # with "ENDBLOCK\n". Malformed start sentinels (no type=) emit "WARN ..."
  # records. End-without-start or start-without-end is detected by EOF check.
  local stream
  stream="$(awk '
    BEGIN { in_block = 0; type = ""; saw_start = 0 }
    /<!-- *mcrule:start/ {
      # Extract type=<TOKEN> attribute from start sentinel.
      # BSD awk-safe: use sub() chain on a copy of the line.
      line = $0
      # Detect missing type= attribute.
      if (line !~ /type=[^ >]+/) {
        print "WARN missing-type-attr"
        next
      }
      # Strip everything up to "type=".
      sub(/.*type=/, "", line)
      # Strip whitespace, " -->", or any trailing junk.
      sub(/[ \t].*$/, "", line)
      sub(/-->.*$/, "", line)
      type = line
      in_block = 1
      saw_start = 1
      print "BLOCK " type
      next
    }
    /<!-- *mcrule:end *-->/ {
      if (in_block == 1) {
        print "ENDBLOCK"
        in_block = 0
        type = ""
      }
      # End sentinel outside a block: ignore (defensive).
      next
    }
    in_block == 1 {
      # Body line: YAML-like key: value.
      print "BODY " $0
    }
    END {
      # Unclosed block at EOF → malformed; emit a warning sentinel.
      if (in_block == 1) {
        print "WARN unclosed-block " type
      }
    }
  ' "$path")"

  # Pass 2: walk the stream, building one JSON object per BLOCK..ENDBLOCK pair.
  # Use jq to construct each object; assemble final array with jq -s '.'.
  local json_acc=""
  local cur_type=""
  local cur_fields_json=""
  local in_block=0
  local IFS_OLD="$IFS"
  local line key val tag rest

  # Read line-by-line. Use process substitution so we don't subshell-lose
  # the accumulator vars.
  while IFS= read -r line; do
    tag="${line%% *}"
    rest="${line#* }"
    case "$tag" in
      WARN)
        # rest is e.g. "missing-type-attr" or "unclosed-block <type>"
        sf_log_warn "sf_rules_parse: malformed block — ${rest}"
        ;;
      BLOCK)
        cur_type="$rest"
        cur_fields_json='{}'
        in_block=1
        ;;
      BODY)
        if [[ "$in_block" == "1" ]]; then
          # Parse "key: value" lines; ignore blanks and non-matching lines.
          # Strip leading whitespace.
          local stripped="${rest#"${rest%%[![:space:]]*}"}"
          if [[ -z "$stripped" ]]; then
            continue
          fi
          # Match key:value
          if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            # Trim trailing whitespace from val.
            val="${val%"${val##*[![:space:]]}"}"
            # Build a one-key object and merge.
            cur_fields_json="$(jq -c \
              --arg k "$key" --arg v "$val" \
              '. + {($k): $v}' <<<"$cur_fields_json")"
          fi
        fi
        ;;
      ENDBLOCK)
        if [[ "$in_block" == "1" ]]; then
          if _sf_rules_is_known_type "$cur_type"; then
            local obj
            obj="$(jq -c --arg t "$cur_type" \
              '. + {type: $t} | {type: .type} + (. | del(.type))' \
              <<<"$cur_fields_json")"
            # Append to accumulator (NUL-separated single-object strings,
            # joined later via jq -s '.').
            if [[ -z "$json_acc" ]]; then
              json_acc="$obj"
            else
              json_acc="${json_acc}"$'\n'"${obj}"
            fi
          else
            sf_log_warn "sf_rules_parse: unknown type '${cur_type}' — skipping (forward-compat per §8.5)"
          fi
          in_block=0
          cur_type=""
          cur_fields_json=""
        fi
        ;;
    esac
  done <<<"$stream"
  IFS="$IFS_OLD"

  # Emit JSON array. Empty accumulator → "[]".
  if [[ -z "$json_acc" ]]; then
    echo '[]'
  else
    printf '%s\n' "$json_acc" | jq -s '.'
  fi
}

# ----------------------------------------------------------------------------
# sf_rules_validate_block <body_text> [<type>]
# ----------------------------------------------------------------------------
# Validates one mcrule block's body. Exit 0 if valid; exit 1 + stderr if not.
# Per SPEC §8.4 + SKILL.md §7:
#   - <type> required for schema-aware validation; if omitted, performs
#     shape-only validation (every line is "key: value").
#   - Type-aware: unknown type → exit 1 with stderr warning.
#   - Required fields present → ok; missing required → exit 1.
sf_rules_validate_block() {
  local body="$1"
  local type="${2:-}"

  if [[ -z "$body" ]]; then
    sf_log_error "sf_rules_validate_block: empty body"
    return 1
  fi

  # Collect keys present in body. One key per line.
  local present_keys=""
  local line key
  while IFS= read -r line; do
    local stripped="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$stripped" ]] && continue
    if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
      key="${BASH_REMATCH[1]}"
      present_keys="${present_keys} ${key}"
    else
      sf_log_error "sf_rules_validate_block: malformed line (not key: value): ${stripped}"
      return 1
    fi
  done <<<"$body"

  # If no type arg given, shape-only validation succeeds at this point.
  if [[ -z "$type" ]]; then
    return 0
  fi

  # Type must be known.
  if ! _sf_rules_is_known_type "$type"; then
    sf_log_error "sf_rules_validate_block: unknown rule type '${type}' (expected one of: ${_SF_RULES_TYPES[*]})"
    return 1
  fi

  # Look up required / optional fields for this type.
  local idx
  idx="$(_sf_rules_type_index "$type")"
  local required_str="${_SF_RULES_REQUIRED[$idx]}"
  local optional_str="${_SF_RULES_OPTIONAL[$idx]}"

  # Check every required field is present.
  local req
  for req in $required_str; do
    if [[ " ${present_keys} " != *" ${req} "* ]]; then
      sf_log_error "sf_rules_validate_block: missing required field '${req}' for type '${type}'"
      return 1
    fi
  done

  # Check every present key is either required or optional (no unknown fields).
  local pk
  for pk in $present_keys; do
    local found=0 known
    for known in $required_str $optional_str; do
      if [[ "$pk" == "$known" ]]; then
        found=1
        break
      fi
    done
    if [[ "$found" == "0" ]]; then
      sf_log_error "sf_rules_validate_block: unknown field '${pk}' for type '${type}'"
      return 1
    fi
  done

  return 0
}

# ----------------------------------------------------------------------------
# sf_rules_filter <rules_json> <type>
# ----------------------------------------------------------------------------
# Filter a JSON array (e.g. output of sf_rules_parse) by .type == <type>.
# Always emits a valid JSON array (possibly empty).
sf_rules_filter() {
  local rules_json="$1"
  local type="$2"

  if [[ -z "$rules_json" ]]; then
    echo '[]'
    return 0
  fi
  if [[ -z "$type" ]]; then
    sf_log_error "sf_rules_filter: missing type argument"
    return 1
  fi

  jq --arg t "$type" '[.[] | select(.type == $t)]' <<<"$rules_json"
}
