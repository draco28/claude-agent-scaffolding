#!/usr/bin/env bash
#
# code-judo — invocation and frontmatter lint
#
# Asserts each skill declares the same thing on both surfaces it ships to.
#
# skills/*/SKILL.md — the Claude Code contract:
#   - YAML frontmatter fenced by ---
#   - exactly one `name` and exactly one `description` (a duplicate key means a
#     YAML loader and this lint can disagree about what the skill declares)
#   - `name` is kebab-case and matches its directory
#   - `description` is non-empty and ≤1024 chars (Claude Code's limit)
#   - NO `version` field, NO `when_to_use` field
#   - the ONLY optional field is `disable-model-invocation`, and no other key
#     may appear at all
#   - the two human-invoked-only skills carry `disable-model-invocation: true`,
#     and the two model-invocable skills do NOT carry the key
#
# commands/<name>.md — the surface a user actually types:
#   - a command exists per skill, and carries the same posture as its skill
#
# skills/*/agents/openai.yaml — the Codex contract, which is a SEPARATE
# declaration because Codex does not read `disable-model-invocation`:
#   - the file matches one of exactly TWO shapes, byte for byte once the two
#     quoted strings are blanked: with a `policy:` block, or without one
#
# Posture is DERIVED, never listed here. A skill is human-invoked-only if its
# description says so, and the lint then requires all three surfaces to agree:
# the description prose, the frontmatter flag, and the Codex policy block. A
# hand list of which skills are human-only is the same drift class as #385, and
# it fails OPEN — a fifth skill nobody adds to the list is silently treated as
# model-invocable. Deriving it means a fifth skill is checked the day it lands,
# and flipping a posture takes three deliberate edits that show up in the diff.
#
# The Codex file is compared by SHAPE rather than parsed. An earlier version
# grepped for `allow_implicit_invocation: false` and passed when the key sat at
# the wrong nesting entirely — under `interface:` instead of `policy:`. Shape
# comparison has no indentation semantics to get wrong.
#
# Usage:   bash code-judo/tests/test-frontmatter-lint.sh
# Exit:    0 if every skill passes every check; 1 if any check fails.
# Deps:    bash 3.2+ (no GNU-isms), awk. No jq, no yq.

set -u  # failures are counted explicitly; do not `set -e`

# Lengths below are counted in BYTES, and the locale is pinned so they stay
# bytes. awk's length() counts characters in a UTF-8 locale and bytes in C, so
# an unpinned run measures a description containing an em-dash differently on
# two machines — and the limit being checked is itself a byte limit.
LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$PLUGIN_ROOT/skills"
COMMANDS_DIR="$PLUGIN_ROOT/commands"

PASS=0
FAIL=0

if [ -t 1 ]; then
  GREEN=$(printf '\033[32m'); RED=$(printf '\033[31m'); DIM=$(printf '\033[2m'); RST=$(printf '\033[0m')
else
  GREEN=""; RED=""; DIM=""; RST=""
fi

pass() { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$GREEN" "$RST" "$1"; }
fail() {
  FAIL=$((FAIL+1))
  printf '  %s✗%s %s\n' "$RED" "$RST" "$1"
  [ -n "${2:-}" ] && printf '      %s%s%s\n' "$DIM" "$2" "$RST"
  return 0
}

# Frontmatter block: the lines between the first two `---` fences.
extract_frontmatter() {
  awk '
    BEGIN { state = 0 }
    /^---[[:space:]]*$/ {
      if (state == 0) { state = 1; next }
      else if (state == 1) { state = 2; exit }
    }
    state == 1 { print }
  ' "$1"
}

# Key names, one per line. Flat YAML only, which is the convention here.
extract_keys() {
  printf '%s\n' "$1" | awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    {
      idx = index($0, ":")
      if (idx == 0) next
      key = substr($0, 1, idx - 1)
      sub(/^[[:space:]]+/, "", key)
      sub(/[[:space:]]+$/, "", key)
      if (key != "") print key
    }
  '
}

# Raw value of one key, as a single line (everything after the first colon).
extract_value() {
  printf '%s\n' "$1" | awk -v k="$2" '
    {
      idx = index($0, ":")
      if (idx == 0) next
      this_key = substr($0, 1, idx - 1)
      this_val = substr($0, idx + 1)
      sub(/^[[:space:]]+/, "", this_key)
      sub(/[[:space:]]+$/, "", this_key)
      if (this_key == k) {
        sub(/^[[:space:]]+/, "", this_val)
        sub(/[[:space:]]+$/, "", this_val)
        print this_val
        exit
      }
    }
  '
}

count_key() {
  printf '%s\n' "$1" | awk -v k="$2" '$0 == k { n++ } END { print n+0 }'
}

is_kebab_case() {
  case "$1" in
    "" ) return 1 ;;
    -*|*-) return 1 ;;
    *[!a-z0-9-]* ) return 1 ;;
    *) return 0 ;;
  esac
}

# A skill declares its own posture in the description users actually read.
# That prose is the source; the frontmatter flag and the Codex policy block are
# the two machine-readable restatements of it, and all three must agree.
HUMAN_ONLY_MARKER="Human-invoked only."

describes_human_only() {
  case "$1" in
    *"$HUMAN_ONLY_MARKER"*) return 0 ;;
    *) return 1 ;;
  esac
}

check_skill() {
  skill_md="$1"
  skill_name="$(basename "$(dirname "$skill_md")")"
  rel_path="skills/$skill_name/SKILL.md"

  printf '\n%s%s%s\n' "$DIM" "── $rel_path ──" "$RST"

  fm="$(extract_frontmatter "$skill_md")"
  if [ -z "$fm" ]; then
    fail "$rel_path: has YAML frontmatter fenced by ---" "no frontmatter block found"
    return 0
  fi
  pass "$rel_path: has YAML frontmatter fenced by ---"

  keys="$(extract_keys "$fm")"

  # Required keys, exactly once each. A duplicate is not a harmless typo: extract_value
  # below reads the FIRST occurrence, while a YAML loader may reject the document or take
  # the last — so a repeated key means this lint and the thing that consumes the file can
  # disagree about what the skill declares.
  n_name="$(count_key "$keys" name)"
  if [ "$n_name" -eq 1 ]; then
    pass "$rel_path: exactly one 'name'"
  else
    fail "$rel_path: exactly one 'name'" "found $n_name"
  fi
  n_desc="$(count_key "$keys" description)"
  if [ "$n_desc" -eq 1 ]; then
    pass "$rel_path: exactly one 'description'"
  else
    fail "$rel_path: exactly one 'description'" "found $n_desc"
  fi

  # Banned keys.
  if [ "$(count_key "$keys" version)" -eq 0 ]; then
    pass "$rel_path: no 'version'"
  else
    fail "$rel_path: no 'version'" "skill frontmatter carries no version; the plugin manifest owns versioning"
  fi
  if [ "$(count_key "$keys" when_to_use)" -eq 0 ]; then
    pass "$rel_path: no 'when_to_use'"
  else
    fail "$rel_path: no 'when_to_use'" "fold it into description"
  fi

  # Control for the loosening: nothing outside the allowed set may appear.
  unknown="$(printf '%s\n' "$keys" | awk '
    NF && $0 != "name" && $0 != "description" && $0 != "disable-model-invocation"
  ' | awk '{ printf "%s%s", sep, $0; sep = ", " }')"
  if [ -z "$unknown" ]; then
    pass "$rel_path: no unknown frontmatter keys"
  else
    fail "$rel_path: no unknown frontmatter keys" "found: [$unknown]"
  fi

  # name.
  name_val="$(extract_value "$fm" name)"
  if is_kebab_case "$name_val"; then
    pass "$rel_path: 'name' is kebab-case ('$name_val')"
  else
    fail "$rel_path: 'name' is kebab-case" "name='$name_val'"
  fi
  if [ "$name_val" = "$skill_name" ]; then
    pass "$rel_path: 'name' matches directory"
  else
    fail "$rel_path: 'name' matches directory" "directory='$skill_name' but name='$name_val'"
  fi

  # description. Reject the YAML shapes this lint does not read rather than
  # measuring them wrong: a folded (>) or literal (|) scalar puts the real text
  # on following lines, where extract_value never looks, so the length check
  # would silently pass on a 3000-character description by measuring the empty
  # remainder of the first line. A documented refusal of exotic input beats a
  # check that quietly stops checking.
  desc_val="$(extract_value "$fm" description)"
  case "$desc_val" in
    ">"*|"|"*)
      fail "$rel_path: 'description' is a single-line plain scalar" \
        "starts with '${desc_val%%[![:space:]]*}${desc_val:0:1}' — folded and literal block scalars are not supported here; put the description on one line"
      ;;
    *)
      pass "$rel_path: 'description' is a single-line plain scalar"
      ;;
  esac
  desc_len=$(printf '%s' "$desc_val" | awk '{ total += length($0) } END { print total+0 }')  # bytes; LC_ALL=C above
  if [ "$desc_len" -eq 0 ]; then
    fail "$rel_path: 'description' is non-empty" "empty"
  elif [ "$desc_len" -le 1024 ]; then
    pass "$rel_path: 'description' length ${desc_len}/1024"
  else
    fail "$rel_path: 'description' length ≤1024" "actual=${desc_len} (over by $((desc_len-1024)))"
  fi

  # Invocation posture — derived from the description, then asserted in BOTH
  # directions against the frontmatter flag.
  dmi_count="$(count_key "$keys" disable-model-invocation)"
  dmi_val="$(extract_value "$fm" disable-model-invocation)"
  if describes_human_only "$desc_val"; then
    if [ "$dmi_count" -eq 1 ] && [ "$dmi_val" = "true" ]; then
      pass "$rel_path: description says human-invoked only, and the flag agrees"
    else
      fail "$rel_path: description says human-invoked only, and the flag agrees" \
        "description carries '$HUMAN_ONLY_MARKER' but disable-model-invocation is count=$dmi_count value='$dmi_val'"
    fi
  else
    if [ "$dmi_count" -eq 0 ]; then
      pass "$rel_path: description does not claim human-invoked only, and no flag is set"
    else
      fail "$rel_path: description does not claim human-invoked only, and no flag is set" \
        "the flag is set to '$dmi_val' but the description never tells the user this skill cannot be triggered"
    fi
  fi
}

# Codex reads skills/<name>/agents/openai.yaml, not the frontmatter flag. The
# file is compared by SHAPE: blank the two quoted strings, then require an exact
# match against one of two literals. Nothing to mis-parse, nothing to nest wrong.
codex_shape() {
  sed -e 's/"[^"]*"/<STR>/g' -e 's/[[:space:]]*$//' "$1"
}

CODEX_SHAPE_OPEN='interface:
  display_name: <STR>
  short_description: <STR>'

CODEX_SHAPE_DENIED="$CODEX_SHAPE_OPEN
policy:
  allow_implicit_invocation: false"

check_codex_policy() {
  skill_name="$1"
  human_only="$2"
  yaml="$SKILLS_DIR/$skill_name/agents/openai.yaml"
  rel="skills/$skill_name/agents/openai.yaml"

  if [ ! -f "$yaml" ]; then
    fail "$rel: exists" "every skill declares its Codex interface here"
    return 0
  fi

  actual="$(codex_shape "$yaml")"
  if [ "$human_only" = "yes" ]; then
    expected="$CODEX_SHAPE_DENIED"
    label="$rel: exact denied shape, matching the description and the flag"
  else
    expected="$CODEX_SHAPE_OPEN"
    label="$rel: exact open shape, matching the description and the flag"
  fi

  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label" "shape mismatch; got:
$actual"
  fi
}

# A command file carries `disable-model-invocation` too, so it is a fourth
# place the posture is declared and a fourth place it can drift. The command
# is what a user actually types, so a command that is model-invocable while its
# skill is not defeats the whole restriction.
check_command_posture() {
  skill_name="$1"
  human_only="$2"
  cmd="$COMMANDS_DIR/$skill_name.md"
  rel="commands/$skill_name.md"

  [ -f "$cmd" ] || { fail "$rel: exists" "every skill is reachable by a command of the same name"; return 0; }

  fm="$(extract_frontmatter "$cmd")"
  n="$(count_key "$(extract_keys "$fm")" disable-model-invocation)"
  v="$(extract_value "$fm" disable-model-invocation)"
  if [ "$human_only" = "yes" ]; then
    if [ "$n" -eq 1 ] && [ "$v" = "true" ]; then
      pass "$rel: human-invoked only, matching its skill"
    else
      fail "$rel: human-invoked only, matching its skill" \
        "count=$n value='$v' — the skill cannot be model-triggered but this command can"
    fi
  else
    if [ "$n" -eq 0 ]; then
      pass "$rel: model-invocable, matching its skill"
    else
      fail "$rel: model-invocable, matching its skill" "found the key with value '$v'"
    fi
  fi
}

printf '%scode-judo frontmatter lint%s\n' "$DIM" "$RST"
printf '%sskills dir: %s%s\n' "$DIM" "$SKILLS_DIR" "$RST"

if [ ! -d "$SKILLS_DIR" ]; then
  printf '%s✗%s skills directory missing at %s\n' "$RED" "$RST" "$SKILLS_DIR"
  exit 1
fi

found_any=0
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [ -e "$skill_md" ] || continue
  found_any=1
  check_skill "$skill_md"
  skill_dir_name="$(basename "$(dirname "$skill_md")")"
  skill_desc="$(extract_value "$(extract_frontmatter "$skill_md")" description)"
  if describes_human_only "$skill_desc"; then posture=yes; else posture=no; fi
  check_codex_policy "$skill_dir_name" "$posture"
  check_command_posture "$skill_dir_name" "$posture"
done

if [ "$found_any" -eq 0 ]; then
  printf '\n%s✗%s no skills found under %s/*/SKILL.md\n' "$RED" "$RST" "$SKILLS_DIR"
  exit 1
fi

printf '\n%s──%s %d passed, %d failed\n' "$DIM" "$RST" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
