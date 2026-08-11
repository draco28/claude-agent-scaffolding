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

# THE FENCE STATE MACHINE - shared by every function below, and deliberately
# byte-for-byte in agreement with `test-skill-bash-blocks.sh`'s own extractor
# (see its lines 76-83). Two rules, both learned the hard way:
#
#   EXACT opener, not a prefix. A prefix match also accepts ```bashx, so
#   re-fencing a block to an info-string the real harness does not recognise
#   would preserve both the count and the digest and leave this gate green
#   while the block silently stopped being a bash block.
#   (Codex P2 round 2 on PR #144.)
#
#   ONLY A BARE FENCE CLOSES. A ```bash line appearing INSIDE an already-open
#   ```text or ```markdown fence is content - a doc example quoting a bash
#   fence - not an opener. A stateless matcher counts it as a block, which
#   would force a classification for something the real harness never sees, and
#   would let `oss_block_extract` pull out quoted documentation as if it were
#   shipped code. The two extractors agree at 160 today only because no such
#   nested case exists yet; that is luck, not a guarantee.
#   (Codex P2 round 3 on PR #144.)
#
# Emitted as a string so the five readers cannot drift apart.
_OSS_BLOCK_FSM='
  /^[ \t]*```/ {
    if (inblk) {
      if ($0 ~ /^[ \t]*```[ \t]*$/) { if (isbash) { CLOSE } inblk=0; isbash=0; next }
      # an info-string fence while already inside a block is CONTENT
    } else {
      info=$0; sub(/^[ \t]*```/,"",info); sub(/[ \t]*$/,"",info)
      inblk=1; isbash=(info=="bash"); if (isbash) { OPEN }
      next
    }
  }
  { if (inblk && isbash) { BODY } }
'
_oss_block_awk() { # $1=OPEN $2=CLOSE $3=BODY $4=END ; echoes the awk program
  local p="$_OSS_BLOCK_FSM"
  p="${p//OPEN/$1}"; p="${p//CLOSE/$2}"; p="${p//BODY/$3}"
  printf '%s\nEND { %s }\n' "$p" "$4"
}

oss_block_count() { # $1=md ; echoes the count
  awk "$(_oss_block_awk 'idx++' '' '' 'print idx+0')" "$1"
}

# A digest over a file's BLOCK BODIES ONLY - not the prose around them.
#
# The per-file completeness invariant counts blocks, and a count cannot see a
# same-count SWAP: replace an operative gate with a trivial one-line read and
# the total is unchanged, so the D/I classification silently goes stale while
# the suite stays green. (Codex P2 on PR #144; reproduced by replacing
# fake-expiry.md's expired_fakes gate - pass=77 fail=0.)
#
# Digesting bodies rather than whole files is deliberate: editing the prose
# AROUND a block should not force a reclassification, but editing the block
# itself must.
# BOUNDARIES ARE PART OF THE DIGEST. Concatenating bodies with no separator
# makes the digest blind to a fence MOVE: shift a line from the end of one block
# to the start of the next and the concatenation - and so the cksum - is
# identical, while operative logic has just migrated between two rows with
# different D/I classifications. The per-block marker makes the split itself
# part of what is hashed. (Codex P2 round 3 on PR #144.)
oss_block_digest() { # $1=md ; echoes a stable digest of every block body
  awk "$(_oss_block_awk 'idx++; print "\n--- oss-block " idx " ---"' '' 'print' '')" "$1" \
    | cksum | awk '{print $1"-"$2}'
}

# How many blocks in $1 does the anchor regex match? The old `_extract_block`
# stopped at the FIRST match, so an anchor matching two blocks silently bound to
# whichever came first - and would silently REBIND if a block were inserted
# above it. An anchor that is not unique is not an identity.
oss_block_matches() { # $1=md $2=anchor-regex ; echoes the match count
  awk -v want="$2" "$(_oss_block_awk 'buf=""' 'if (buf ~ want) n++' 'buf = buf $0 "\n"' 'print n+0')" "$1"
}

# Which block INDEX (1-based) does the anchor resolve to? 0 if none.
#
# Two O rows can each resolve uniquely and still name the SAME block: duplicate
# an O row, decrement the file's D or I count to keep the total, and
# completeness, uniqueness, digest and covered-by all stay green while one real
# block drops out of the ledger entirely. Counting O rows as distinct blocks is
# an assumption; this makes it checkable. (Codex P2 round 2 on PR #144.)
oss_block_index_of() { # $1=md $2=anchor-regex ; echoes the 1-based index, or 0
  # NB: awk's `exit` still runs END, so the hit must be recorded in a flag and
  # printed once from END - printing at the match site and again in END emits
  # two lines, which a caller comparing strings reads as neither index.
  awk -v want="$2" "$(_oss_block_awk 'buf=""; idx++' 'if (buf ~ want) { hit=idx; exit }' 'buf = buf $0 "\n"' 'print hit+0')" "$1"
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
  awk -v want="$want" "$(_oss_block_awk 'buf=""' 'if (buf ~ want) { printf "%s", buf; exit }' 'buf = buf $0 "\n"' '')" "$md" > "$out"
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
