#!/usr/bin/env bash
# Shared extract-and-execute harness for the shipped prose bash blocks (#138).
#
# WHY THIS EXISTS
# ---------------
# ossify ships 160 fenced bash blocks. `tests/test-skill-bash-blocks.sh` checks
# that they PARSE. Every P1 in PR #130 rounds 4-7 was parse-clean and
# behaviourally wrong:
#
#   round 4  `"output contains ?"*)` quoted the wildcard - the guard rejected
#            every valid AC                                        bash -n clean
#   round 5  the spine was cut from HEAD, not the planned base     bash -n clean
#   round 6  a bare `oss demo_run` discarded its rc - a failing
#            MANDATORY demo returned 0                             bash -n clean
#   round 7  `base_branch` was guarded but never assigned - every
#            fresh /run-spine halted                               bash -n clean
#
# A parse check cannot see any of them. Executing the block catches all four.
#
# THE ANCHOR RULE - the trap this file exists to make unrepeatable
# ----------------------------------------------------------------
# Anchor extraction on a token that SURVIVES the regression being guarded.
#
# #130 round 6 anchored the cumulative-demo block on `demo_rc` - the very thing
# under test. Removing the fix made the block unfindable, so the suite reported
# "vacuous" instead of "wrong behaviour": a red that read like a broken test
# rather than a caught bug. It was re-anchored on `elapsed=`.
#
# Pick the anchor from the block's SCAFFOLDING, never from its FIX.
#
# THE OTHER TRAP - test-injected preconditions
# ---------------------------------------------
# A test that injects the precondition cannot see the code failing to establish
# it. W2 passed `base_branch='w2-planned'` into the extracted block, so it
# validated the guard while blind to nothing assigning the variable. /run-spine
# was dead on every fresh run and the suite was green. Run blocks with NOTHING
# injected under `set -u` wherever the block is supposed to establish its own
# state; inject only what the CALLER genuinely supplies.

# Count fenced bash blocks in a markdown file. Tolerates indented fences, which
# is what `test-skill-bash-blocks.sh`'s own extractor does - the two counts are
# cross-checked by test-block-ledger.sh so a drift in either surfaces.
oss_block_count() { # $1=md ; echoes the count
  awk '/^[[:space:]]*```bash/{n++} END{print n+0}' "$1"
}

# How many blocks in $1 does the anchor regex match? The old `_extract_block`
# stopped at the FIRST match, so an anchor matching two blocks silently bound to
# whichever came first - and would silently REBIND if a block were inserted
# above it. An anchor that is not unique is not an identity.
oss_block_matches() { # $1=md $2=anchor-regex ; echoes the match count
  awk -v want="$2" '
    /^[[:space:]]*```bash/ { inb=1; buf=""; next }
    inb && /^[[:space:]]*```[[:space:]]*$/ { inb=0; if (buf ~ want) n++; next }
    inb { buf = buf $0 "\n" }
    END { print n+0 }
  ' "$1"
}

# Extract the single block matching the anchor into $3.
# rc 0 = extracted, non-empty, and the anchor really is present in the output
# rc 1 = VACUOUS: no match, empty output, or the anchor is missing from it
# rc 2 = AMBIGUOUS: the anchor matches more than one block in the file
#
# rc 1 and rc 2 are deliberately distinct. A caller that folds them together
# reports an ambiguous anchor as "vacuous", which is the same misdiagnosis the
# anchor rule above exists to prevent.
oss_block_extract() { # $1=md $2=anchor-regex $3=out-path
  local md="$1" want="$2" out="$3" n
  [ -f "$md" ] || { echo "block-extract: no such file: $md" >&2; return 1; }
  n="$(oss_block_matches "$md" "$want")"
  if [ "$n" -gt 1 ]; then
    echo "block-extract: anchor '$want' matches $n blocks in $md - not an identity; pick a unique anchor" >&2
    return 2
  fi
  awk -v want="$want" '
    /^[[:space:]]*```bash/ { inb=1; buf=""; next }
    /^[[:space:]]*```[[:space:]]*$/ { if (inb && buf ~ want) { printf "%s", buf; exit } inb=0; next }
    inb { buf = buf $0 "\n" }
  ' "$md" > "$out"
  [ -s "$out" ] || { echo "block-extract: VACUOUS - anchor '$want' found no block in $md" >&2; return 1; }
  # The belt-and-braces half: awk matched, but assert the anchor survives into
  # the written file. A regex that matches the buffer but not the output means
  # the extraction wrote something other than the block that matched.
  if ! grep -Eq -- "$want" "$out"; then
    echo "block-extract: VACUOUS - '$want' matched a block in $md but is absent from the extract" >&2
    return 1
  fi
  return 0
}
