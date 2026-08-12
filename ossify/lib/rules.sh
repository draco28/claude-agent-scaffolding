#!/usr/bin/env bash
# oss rules_validate - the mcrule block validator behind `doctor`'s machine-
# checkable-rule authoring (spec §9.1, the `doctor` entry's third surface).
#
# The DSL is carried VERBATIM from scaffold-onboard's R2 mcrule grammar - same
# HTML sentinels, same four types, same required/optional field sets. That is
# deliberate and load-bearing: `03-code-patterns.md` is the same artifact in
# both stacks, a project mid-migration can hold rules authored by either, and a
# field set that drifted by one name would make each stack silently skip the
# other's blocks.
#
# SCOPE, narrow on purpose. This validates a block's SHAPE: every line is
# `key: value`, the type is known, every required field is present, and no field
# is unknown for that type. It does NOT evaluate the rule against a codebase.
# The evaluator is its own v0.3 item and stays separate - shape is a mechanical
# fact and belongs in a tested lib, while "is this the right rule for this
# project" is judgment and belongs in the skill body. Holding the deterministic
# half to parse-validity is the recorded agent-review-over-deterministic-gates
# principle applied, not an accident of where the scope line fell.
#
# Bash 3.2 (what macOS ships): no `declare -A`, so the type map is three
# parallel indexed arrays. Index order is the contract between them.

_OSS_RULE_TYPES=(banned_imports coverage_floor style_invariants required_pattern)
_OSS_RULE_REQUIRED=("forbid" "paths threshold" "forbid_pattern" "require_pattern")
_OSS_RULE_OPTIONAL=("in where" "" "in exclude where" "in exclude where")

# The known-type list as data, so prose and error messages never hand-maintain a
# second copy of it that can drift from the arrays above.
oss_rules_types() { printf '%s\n' "${_OSS_RULE_TYPES[@]}"; }

# rc 0 = the block is well-formed. rc 1 = it is not, and stderr names WHICH
# field and WHICH type, because "invalid block" alone sends the author back to
# re-read the grammar instead of to the one line that is wrong. rc 2 = usage.
#
# Every conditional below is written in a TESTED position. `bin/oss` runs
# `set -euo pipefail` while the tests source this file without it, so a bare
# `[ ... ] && x=1` inside a loop body is green when sourced and aborts the
# dispatcher on its first false evaluation - the exact strict-mode split this
# repo has shipped twice.
oss_rules_validate_block() { # $1=type $2=body ; rc 0 valid, 1 invalid, 2 usage
  local type="${1:-}" body="${2:-}"
  local i n idx="" line stripped key present=" " req pk known found required_str optional_str

  [ -n "$type" ] || { echo "oss: rules_validate needs a rule type" >&2; return 2; }
  [ -n "$body" ] || { echo "oss: rules_validate needs a block body" >&2; return 2; }

  n=${#_OSS_RULE_TYPES[@]}; i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${_OSS_RULE_TYPES[$i]}" = "$type" ]; then idx="$i"; fi
    i=$((i+1))
  done
  if [ -z "$idx" ]; then
    echo "oss: unknown rule type '$type' (known: ${_OSS_RULE_TYPES[*]})" >&2
    return 1
  fi

  # Shape pass. A line that is not `key: value` is rejected before any field
  # logic runs - otherwise a body of free prose reports as "missing required
  # field", which points the author at the wrong problem.
  while IFS= read -r line; do
    stripped="${line#"${line%%[![:space:]]*}"}"
    [ -n "$stripped" ] || continue
    case "$stripped" in
      *:*) key="${stripped%%:*}" ;;
      *) echo "oss: malformed rule line (expected 'key: value'): $stripped" >&2; return 1 ;;
    esac
    case "$key" in
      *[!a-zA-Z0-9_]*|"") echo "oss: malformed rule key '$key' (letters, digits and _ only)" >&2; return 1 ;;
    esac
    present="$present$key "
    # `<<<"$body"`, and the reason is NOT the one it looks like. An unquoted
    # `<<EOF` / $body / EOF is equivalent here - measured, not reasoned:
    # a heredoc expands its SOURCE text once and does not re-scan the
    # substituted value, so a body holding `require_pattern: '$HOME/x'` survives
    # verbatim under both forms. The herestring is chosen for being one line
    # instead of three. Nothing downstream depends on the choice, so do not add
    # a test claiming to discriminate them - there is no observable difference
    # to assert, and a test that cannot fail reads as coverage.
  done <<<"$body"

  required_str="${_OSS_RULE_REQUIRED[$idx]}"
  optional_str="${_OSS_RULE_OPTIONAL[$idx]}"

  for req in $required_str; do
    case "$present" in
      *" $req "*) ;;
      *) echo "oss: rule type '$type' requires field '$req'" >&2; return 1 ;;
    esac
  done

  # An UNKNOWN field is an error, not a shrug. A typo'd `forbid_patern` that
  # validated would author a block the evaluator later skips for having no
  # required field - green here, silently unenforced forever after.
  for pk in $present; do
    found=0
    for known in $required_str $optional_str; do
      if [ "$pk" = "$known" ]; then found=1; fi
    done
    if [ "$found" -eq 0 ]; then
      echo "oss: unknown field '$pk' for rule type '$type' (allowed: $required_str $optional_str)" >&2
      return 1
    fi
  done
  return 0
}
