#!/usr/bin/env bash
# The executable-prose gate (#138), skeleton layer.
#
# It does NOT execute every operative block - 40 are still deferred and the
# ledger says so by name. What it DOES guarantee is that no block can be added,
# removed, or re-fenced without someone classifying it, and that every anchor a
# test extracts on is a real, unique identity.
#
# The four defect classes this is scaffolding for were all parse-clean:
# a quoted wildcard, a cut from the wrong base, a discarded rc, and a guard
# variable nothing assigned. See tests/lib/blocks.sh for the full account.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSS_TREE="$(cd "$HERE/.." && pwd)"
LEDGER="$HERE/block-ledger.tsv"
. "$HERE/lib/blocks.sh"

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $*"; }

echo "-- ossify tree: $OSS_TREE"

# ---------------------------------------------------------------------------
# check 1 - the ledger parses, and every row is one of the three known types.
# ---------------------------------------------------------------------------
rows=0
while IFS=$'\t' read -r kind file c4 c5 c6; do
  case "$kind" in ''|'#'*) continue ;; esac
  rows=$((rows+1))
  case "$kind" in
    O) [ -n "${c5:-}" ] || fail "O row for $file has no covered-by" ;;
    D|I) case "${c4:-}" in ''|*[!0-9]*) fail "$kind row for $file has a non-numeric count: '${c4:-}'" ;; esac ;;
    H) [ -n "${c4:-}" ] || fail "H row for $file has no digest" ;;
    *) fail "unknown ledger row type '$kind' (expected O, D, I or H)" ;;
  esac
done < "$LEDGER"
[ "$rows" -gt 0 ] && pass || fail "check 1: the ledger is empty - every assertion below would be vacuous"
echo "-- check 1: $rows ledger rows"

# ---------------------------------------------------------------------------
# check 2 - THE COMPLETENESS INVARIANT.
# Per file: O-rows + D-count + I-count must equal the blocks actually present.
# This is what makes uncovered surface DECLARED rather than assumed, and what
# turns any inserted or deleted block into a red test until it is classified.
# ---------------------------------------------------------------------------
declare_counted() { # $1=file ; echoes "O D I" totals from the ledger
  awk -F'\t' -v f="$1" '
    $1=="O" && $2==f { o++ }
    $1=="D" && $2==f { d += $3 }
    $1=="I" && $2==f { i += $3 }
    END { print (o+0), (d+0), (i+0) }
  ' "$LEDGER"
}

# Enumerate every shipped markdown file that HAS a bash block, from the tree -
# never from the ledger. Driving this loop off the ledger would make a file
# that is missing from the ledger entirely invisible, which is the one gap this
# check exists to close.
shipped=0; accounted=0
while IFS= read -r rel; do
  actual="$(oss_block_count "$OSS_TREE/$rel")"
  [ "$actual" -gt 0 ] || continue
  shipped=$((shipped+1))
  read -r o d i <<<"$(declare_counted "$rel")"
  sum=$((o+d+i))
  if [ "$sum" -eq "$actual" ]; then
    accounted=$((accounted+actual)); pass
  else
    fail "check 2: $rel has $actual blocks but the ledger accounts for $sum (O=$o D=$d I=$i) - classify the difference"
  fi
done < <(cd "$OSS_TREE" && find skills commands agents -name '*.md' | sort)

echo "-- check 2: $shipped files with blocks, $accounted blocks accounted for"

# check 2b - THE REVERSE DIRECTION. The walk above visits the tree, so deleting
# a file whole removes it from the walk and its D/I rows are simply never read.
# Verified: `rm commands/close.md` left 47 files / 159 blocks and fail=0,
# because the count stayed above the floor. (Codex P2 on PR #144.)
# Every path the ledger names must therefore still exist.
while IFS= read -r lf; do
  if [ -f "$OSS_TREE/$lf" ]; then pass; else
    fail "check 2b: the ledger names $lf, which no longer exists - delete its rows or restore the file"
  fi
done < <(awk -F'\t' '/^[ODI]\t/ {print $2}' "$LEDGER" | sort -u)

# check 2c - the same-count SWAP the completeness invariant cannot see.
# A per-file digest over block BODIES: change any block's content and this goes
# red, even when the block count is identical. Prose edits around blocks do not
# churn it. The expected value is printed on mismatch so updating is mechanical.
digests=0
while IFS=$'\t' read -r _kind file want _rest; do
  digests=$((digests+1))
  got="$(oss_block_digest "$OSS_TREE/$file" 2>/dev/null || echo MISSING)"
  if [ "$got" = "$want" ]; then pass; else
    fail "check 2c: $file block bodies changed (ledger $want, tree $got) - re-read its blocks, confirm the O/D/I split still holds, then update the H row"
  fi
done < <(grep -E '^H'$'\t' "$LEDGER" || true)
echo "-- check 2c: $digests per-file block digests"
if [ "$digests" -eq "$shipped" ]; then pass; else fail "check 2c: $digests digest rows for $shipped files with blocks - every such file needs an H row"; fi
# A floor, not just a per-file equality: if the enumeration itself broke and
# produced zero files, every per-file assertion above would be vacuously true.
if [ "$shipped" -ge 40 ]; then pass; else fail "check 2: only $shipped files enumerated - the file walk is broken, the per-file checks above are vacuous"; fi

# ---------------------------------------------------------------------------
# check 3 - every O-row anchor resolves to EXACTLY ONE block.
# The pre-#138 extractor stopped at the first match, so a non-unique anchor
# bound silently to whichever block came first - and would silently REBIND if a
# block were inserted above it. An anchor that is not unique is not an identity.
# ---------------------------------------------------------------------------
anchors=0
while IFS=$'\t' read -r kind file anchor covered_by _guards; do
  [ "$kind" = "O" ] || continue
  anchors=$((anchors+1))
  n="$(oss_block_matches "$OSS_TREE/$file" "$anchor")"
  case "$n" in
    1) pass ;;
    0) fail "check 3: anchor '$anchor' matches NO block in $file - the extraction it names is vacuous" ;;
    *) fail "check 3: anchor '$anchor' matches $n blocks in $file - not an identity" ;;
  esac
done < <(grep -E '^O' "$LEDGER" || true)
# Report the count, not a verdict. An earlier form said "each resolving
# uniquely" unconditionally, which printed a false claim directly beneath its
# own failures - the same prose-contradicts-behaviour class this gate exists
# to catch.
echo "-- check 3: $anchors covered-block anchors checked for unique resolution"
if [ "$anchors" -ge 10 ]; then pass; else fail "check 3: only $anchors anchors found - the O-row grep is broken, check 3 is vacuous"; fi

# ---------------------------------------------------------------------------
# check 4 - every covered-by claim is real: the named test file exists AND
# actually mentions the anchor. A ledger that claims coverage a test does not
# provide is worse than an honest D row.
# ---------------------------------------------------------------------------
while IFS=$'\t' read -r kind file anchor covered_by _guards; do
  [ "$kind" = "O" ] || continue
  # covered-by is ossify-relative, like every other path in the ledger.
  t="$OSS_TREE/$covered_by"
  if [ ! -f "$t" ]; then
    fail "check 4: $file claims coverage by '$covered_by', which does not exist"
    continue
  fi
  # COMMENT LINES DO NOT COUNT, and this is not fussiness. Verified by
  # mutation: repointing test-close.sh's cumulative-demo extraction from
  # `elapsed=` to `demo_rc` left the ledger's claim satisfied, because the
  # comment ABOVE the call - the one explaining the anchor rule - still said
  # `elapsed=`. A plain grep certified coverage that had just been removed.
  #
  # The anchor must appear on a line that ALSO carries an extraction construct.
  # Matching the anchor anywhere in the test file is far too weak: `is-ancestor`
  # occurs on SEVEN non-comment lines of test-close.sh, only one of which is the
  # extraction, so repointing that one left check 4 green with the coverage
  # gone. (Codex P2 on PR #144 - the same class as the comment bug below, one
  # level deeper.) Both extraction forms in use are accepted: the shared
  # `oss_block_extract`/`_extract_block` call, and impl-check's inline
  # `awk ... buf ~ /anchor/`.
  #
  # Comment lines still do not count. Verified by mutation: repointing the
  # cumulative-demo extraction from `elapsed=` to `demo_rc` left the claim
  # satisfied, because the COMMENT above the call - the one explaining the
  # anchor rule - still said `elapsed=`.
  #
  # ONE awk pass, deliberately NOT `grep -v '#' | grep -Fq`. Under this file's
  # `set -o pipefail`, the downstream `grep -q` exits on its first match and
  # SIGPIPEs the upstream grep, so the pipeline reports failure for a line that
  # genuinely matched. That form failed a TRUE coverage claim.
  # `index()` is a literal substring test, so anchors containing regex
  # metacharacters compare as themselves.
  if awk -v a="$anchor" '
       index($0,a) && $0 !~ /^[[:space:]]*#/ &&
       (index($0,"_extract_block") || index($0,"oss_block_extract") || index($0,"buf ~")) { found=1; exit }
       END { exit !found }' "$t"; then pass; else
    fail "check 4: $covered_by never EXTRACTS on anchor '$anchor' claimed for $file - the coverage claim is false"
  fi
done < <(grep -E '^O' "$LEDGER" || true)

# ---------------------------------------------------------------------------
# check 5 - the harness itself works. A self-test, because every check above
# rests on oss_block_extract, and an extractor that silently returns nothing
# would make the whole file pass while testing air.
# ---------------------------------------------------------------------------
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
cat > "$FIX/f.md" <<'EOF'
prose
```bash
alpha_marker=1
echo one
```
more prose
```bash
beta_marker=2
echo two
```
```bash
alpha_marker=3
echo three
```
EOF
[ "$(oss_block_count "$FIX/f.md")" = 3 ] && pass || fail "check 5: block count on the fixture is not 3"

out="$FIX/o.sh"
if oss_block_extract "$FIX/f.md" 'beta_marker' "$out" >/dev/null 2>&1 && grep -q 'echo two' "$out"; then pass
else fail "check 5: extracting a unique anchor failed"; fi

# ambiguity must be rc 2 and must NOT be reported as vacuous
oss_block_extract "$FIX/f.md" 'alpha_marker' "$FIX/amb.sh" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass || fail "check 5: a duplicated anchor returned rc $rc, expected 2 (ambiguous)"

# a missing anchor must be rc 1 (vacuous), distinct from ambiguity
oss_block_extract "$FIX/f.md" 'nothing_matches_this' "$FIX/miss.sh" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && pass || fail "check 5: a missing anchor returned rc $rc, expected 1 (vacuous)"

echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
