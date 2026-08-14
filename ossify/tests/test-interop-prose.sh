#!/usr/bin/env bash
# The one piece of real LOGIC left in the interop check after it became prose:
# `entry()`, the directory-entry normalizer that decides whether an
# $OSS_STATE_FILE override names the same file the manifest routes to.
#
# WHY THIS BLOCK IS EXECUTED AND THE OTHER THREE ARE NOT. The other blocks in
# `doctor/references/interop-check.md` are single reads whose OUTPUT the prose
# interprets - executing them would test the fixture. This one is a rule with a
# loop in it, and its rule has been wrong in two consecutive review rounds:
#
#   PR #178   a guard built on `-ef` accepted a SYMLINKED override that
#             `mv "$tmp" "$sf"` then detaches. Reverted as a P1.
#   PR #182   round 1: the symlink-only patch still accepted a HARD LINK, which
#             `-L` cannot see and `-ef` calls identical.
#             round 2: the lexical-only overcorrection then FAILED a healthy
#             workspace whose ai_workspace.root is a symlink, and failed a
#             pre-init workspace whose .ossify/ does not exist yet (#168's
#             reported symptom, which lived on this surface).
#
# Three rounds on one rule is this repo's own restructure signal. The rule that
# survives all three - resolve the deepest EXISTING ancestor, keep the final
# component verbatim - is subtle in both directions, so it is pinned here rather
# than declared as debt. Both directions are asserted: the spellings that must
# AGREE and the aliases that must NOT, because a normalizer that collapses
# everything and one that collapses nothing both pass a one-sided test.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/lib/blocks.sh"

# `$SKILLS/` is the ONE root the ledger's check-4 coverage prover resolves — it
# rewrites that prefix to `skills/` and compares against the ledger path. A
# `$HERE/../skills/...` spelling reaches the same file and is NOT accepted, on
# purpose: an unresolvable root could be a fixture or a copy, and then the
# coverage claim would be unprovable rather than false.
SKILLS="$HERE/../skills"
SRC="$SKILLS/doctor/references/interop-check.md"
BLOCK="$(mktemp)"
# Anchored on the comment, which is SCAFFOLDING and survives a rewrite of the
# rule itself - the anchor rule the ledger states. Anchoring on `-ef` or on
# `pwd -P` would make a regression read as "block not found" rather than as
# wrong behaviour.
oss_block_extract "$SRC" 'deepest EXISTING' "$BLOCK"
t_assert_eq "0" "$?" "the entry() block is extractable from the shipped prose"
bash -n "$BLOCK"
t_assert_rc 0 "the shipped entry() block parses"

# shellcheck disable=SC1090
. "$BLOCK"
t_assert_eq "0" "$(declare -F entry >/dev/null 2>&1; echo $?)" "sourcing the block defines entry()"

TMP="$(mktemp -d)"
mkdir -p "$TMP/realws/.ossify"
ln -sfn "$TMP/realws" "$TMP/ws"          # a symlinked ai_workspace.root
PHYS="$(cd "$TMP/realws" && pwd -P)"

# --- MUST AGREE: spellings that name the same directory entry ---------------
echo '{"schema_version":2}' > "$TMP/realws/.ossify/project-state.json"
SYMSPELL="$TMP/ws/.ossify/project-state.json"
PHYSPELL="$TMP/realws/.ossify/project-state.json"

t_assert_eq "$(entry "$PHYSPELL")" "$(entry "$SYMSPELL")" \
  "a SYMLINKED parent and the physical spelling are the same entry (else a healthy workspace fails)"
t_assert_eq "$(entry "$PHYSPELL")" "$(entry "$TMP/ws/./.ossify/project-state.json")" \
  "an interior /./ is not a different entry (#150)"
t_assert_eq "$(entry "$PHYSPELL")" "$(entry "$TMP/ws//.ossify//project-state.json")" \
  "doubled slashes are not a different entry"
t_assert_eq "$PHYS/.ossify/project-state.json" "$(entry "$SYMSPELL")" \
  "the resolved form is the PHYSICAL parent plus the verbatim basename"

# --- MUST DIFFER: aliases that fork on the first write ----------------------
# `mv "$tmp" "$sf"` replaces the directory ENTRY, so an alias that is the same
# inode today is a second history tomorrow. -ef says these are identical; the
# whole point of keeping the basename verbatim is that entry() does not.
ln -sfn "$PHYSPELL" "$TMP/sym-alias.json"
ln "$PHYSPELL" "$TMP/hard-alias.json"
[ "$TMP/sym-alias.json" -ef "$PHYSPELL" ]
t_assert_rc 0 "fixture check: the symlink alias IS the same inode (so -ef would pass it)"
[ "$TMP/hard-alias.json" -ef "$PHYSPELL" ]
t_assert_rc 0 "fixture check: the hard link IS the same inode (so -ef would pass it)"

t_assert_eq "no" "$([ "$(entry "$TMP/sym-alias.json")" = "$(entry "$PHYSPELL")" ] && echo yes || echo no)" \
  "a SYMLINK in the final component is a DIFFERENT entry (PR #178's P1)"
t_assert_eq "no" "$([ "$(entry "$TMP/hard-alias.json")" = "$(entry "$PHYSPELL")" ] && echo yes || echo no)" \
  "a HARD LINK is a DIFFERENT entry - -L cannot see it and -ef calls it identical (PR #182 round 1)"
t_assert_eq "no" "$([ "$(entry "$TMP/other/state.json")" = "$(entry "$PHYSPELL")" ] && echo yes || echo no)" \
  "a genuinely different project is a different entry"

# --- SYMLINK FOLLOWED BY `..` : logical vs physical cd ----------------------
# Bash's default `cd` is LOGICAL - it applies `..` textually before resolving
# symlinks - so `<ws>/link/../state.json` normalizes to `<ws>/state.json` while
# the kernel reads `<other>/state.json`. That is a FALSE ok: with every write
# landing in another project. `pwd -P` does not save it: it reports the physical
# form of wherever `cd` already went, and the logical `..` has been applied by
# then. Only `cd -P` agrees with the kernel. (Codex P1, PR #182 round 3.)
mkdir -p "$TMP/other/sub"
echo '{"who":"OTHER"}' > "$TMP/other/state.json"
ln -sfn "$TMP/other/sub" "$TMP/realws/link"
TRAP="$TMP/ws/link/../state.json"
t_assert_eq '{"who":"OTHER"}' "$(cat "$TRAP")" \
  "fixture check: the kernel really does read the OTHER project at that spelling"
t_assert_eq "no" "$([ "$(entry "$TRAP")" = "$(entry "$TMP/ws/state.json")" ] && echo yes || echo no)" \
  "a symlink followed by .. resolves PHYSICALLY - a logical cd would emit a false ok: here"
t_assert_eq "$(cd -P "$TMP/other" && pwd -P)/state.json" "$(entry "$TRAP")" \
  "...and it resolves to the file the kernel actually reads"

# --- PRE-INIT: the deepest-existing-ancestor walk (#168) --------------------
# The case the check is most often run in, and the one a plain
# `cd "$(dirname)"` cannot handle at all.
rm -rf "$TMP/realws/.ossify"
t_assert_eq "$(entry "$PHYSPELL")" "$(entry "$SYMSPELL")" \
  "pre-init: symlinked and physical spellings still agree with .ossify/ absent (#168)"
t_assert_eq "$PHYS/.ossify/project-state.json" "$(entry "$SYMSPELL")" \
  "pre-init: the missing tail is re-appended verbatim onto the resolved ancestor"
t_assert_eq "no" "$([ "$(entry "$TMP/other/deep/state.json")" = "$(entry "$SYMSPELL")" ] && echo yes || echo no)" \
  "pre-init CONTROL: a different project is still different when neither parent exists"
# The walk must not emit noise - an error on stderr reads as a broken check.
ERRS="$(entry "$TMP/nowhere/deep/state.json" 2>&1 >/dev/null | wc -l | tr -d ' ')"
t_assert_eq "0" "$ERRS" "the ancestor walk is silent on a wholly absent path"

rm -rf "$TMP" "$BLOCK"
t_summary
