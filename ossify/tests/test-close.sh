#!/usr/bin/env bash
# close (Task 9) — the router + the work-item close layer.
#
# SCOPE, stated plainly so nobody infers coverage that does not exist.
#
# COVERED here: the mechanical verbs the router's and the gate's prose name,
# driven through `bin/oss` (which runs `set -euo pipefail`, so a strict-mode-only
# fault is visible), plus the two producer/consumer seams this layer sits on —
# the standalone path reconstruction, and the state-recorded merge target.
#
# NOT COVERED, and not coverable by a bash test: **the router itself, the
# three-layer gate's ordering, the halt semantics and the recovery menu are
# prose contracts with no executable surface.** Task 13's bash-block harness
# checks that every `oss` verb they name resolves; beyond that they have no
# automated coverage in this release. An assertion that "each id shape routes to
# its own scope" would be testing `oss id_parse` (already covered in
# test-id.sh), not the router — the router is prose, and a test whose subject is
# a fixture written to satisfy it proves nothing.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"

# Sourced HERE, not beside the first spine-close extraction further down: the
# impl-check halt-loop extraction at §Task-13 runs earlier in the file, and a
# function defined after its first call site is a definition-after-use bug —
# the same ordering class as a guard placed after the mutation it protects.
. "$HERE/lib/blocks.sh"
_extract_block() { # $1=source-md $2=anchor identifying the block $3=out-path
  oss_block_extract "$1" "$2" "$3"
}
for lib in id state manifest commands entities registries ledger demo doctor verify worktree; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
SKILLS="$HERE/../skills"
TMP="$(mktemp -d)"

# ---------------------------------------------------------------------------
# A. Routing mechanics, through the dispatcher.
# ---------------------------------------------------------------------------
t_capture bash "$OSS" id_parse r2.s1.w3
t_assert_rc 0 "dispatcher: a work-item id parses under set -euo pipefail"
t_assert_eq "work_item 2 1 3" "$T_OUT" "id_parse echoes the scope AND the numeric components on ONE line"
t_assert_eq "work_item" "$(printf '%s\n' "$T_OUT" | awk '{print $1}')" "the routing key is the FIRST FIELD of that line"
# The trap the routing prose exists to prevent: a router that equality-tests the
# whole line against the bare scope word falls through every arm and closes
# nothing while reporting success. Assert the whole line is NOT the bare word.
if [ "$T_OUT" = "work_item" ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: id_parse returned a bare scope word - the first-field rule would be untestable"
else
  T_PASS=$((T_PASS+1))
fi

t_capture bash "$OSS" id_parse r2.s1
t_assert_eq "spine 2 1" "$T_OUT" "a spine id parses to scope + components"
t_assert_eq "spine" "$(printf '%s\n' "$T_OUT" | awk '{print $1}')" "spine routes on the first field"
t_capture bash "$OSS" id_parse r2
t_assert_eq "release 2" "$T_OUT" "a release id parses to scope + components"
t_assert_eq "release" "$(printf '%s\n' "$T_OUT" | awk '{print $1}')" "release routes on the first field"

# An unparseable id is rc 1 with EMPTY stdout AND EMPTY stderr - which is why the
# one-line error is the skill's to emit. t_capture merges the two streams, so
# capture them separately here or the stderr half cannot fail.
_UP_OUT="$(bash "$OSS" id_parse "VS-1.1.1" 2>/dev/null)"; _UP_RC=$?
_UP_ERR="$(bash "$OSS" id_parse "VS-1.1.1" 2>&1 >/dev/null)"
t_assert_eq "1" "$_UP_RC" "an unparseable id exits rc 1 through the dispatcher (no strict-mode abort)"
t_assert_eq "" "$_UP_OUT" "...with empty stdout"
t_assert_eq "" "$_UP_ERR" "...and empty stderr - the lib says nothing, so the skill must"

# ---------------------------------------------------------------------------
# B. The fixture, and the standalone path reconstruction the work-item layer
#    performs when it is invoked with an id and nothing else.
# ---------------------------------------------------------------------------
mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
CANON="$TMP/canon"
git -C "$CANON" init -q
git -C "$CANON" config user.email t@t; git -C "$CANON" config user.name t
echo seed > "$CANON/f.txt"; git -C "$CANON" add .; git -C "$CANON" commit -qm seed
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$CANON"},"well_known_paths":{}}
EOF
cd "$TMP/ws"

bash "$OSS" init "close-fixture" >/dev/null
REL="$(bash "$OSS" release_add "first" "a goal")"
SP="$(bash "$OSS" spine_add "$REL" "ledger export" flesh)"
WI="$(bash "$OSS" work_item_add "$SP" "emit the export file")"
SPINE_SLUG="ledger-export"
WI_SLUG="emit-export-file"

AI_ROOT="$(bash "$OSS" repo_root ai_workspace)"
t_assert_eq "$TMP/ws" "$AI_ROOT" "repo_root ai_workspace resolves to the manifest's ai workspace"

# Build the docs tree from the ID GRAMMAR's own layout function, not from a path
# this test invents - so the reconstruction recipe below is cross-checked against
# an independent producer rather than against itself.
SPINE_DIR_REL="$(bash "$OSS" spine_dir "$REL" "$SP" "$SPINE_SLUG")"
case "$SPINE_DIR_REL" in
  /*) T_FAIL=$((T_FAIL+1)); echo "FAIL: spine_dir returned an ABSOLUTE path - the recipe prefixes it with the ai root";;
  *)  T_PASS=$((T_PASS+1));;
esac
mkdir -p "$AI_ROOT/$SPINE_DIR_REL/work-$WI"

# The recipe: id components -> release id + spine id -> glob for the slug.
PARTS="$(bash "$OSS" id_parse "$WI")"
REL_ID="r$(printf '%s\n' "$PARTS" | awk '{print $2}')"
SPINE_ID="$REL_ID.s$(printf '%s\n' "$PARTS" | awk '{print $3}')"
t_assert_eq "$REL" "$REL_ID" "the release id recomposed from id_parse's components matches the minted release id"
t_assert_eq "$SP" "$SPINE_ID" "the spine id recomposed from id_parse's components matches the minted spine id"

MATCHES="$(find "$AI_ROOT/docs/specs/$REL_ID" -maxdepth 1 -type d -name "$SPINE_ID-*" 2>/dev/null)"
NMATCH="$(printf '%s\n' "$MATCHES" | grep -c . || true)"
t_assert_eq "1" "$NMATCH" "the glob finds exactly one spine directory (zero or two is a halt, never head -1)"
RESOLVED_WI_DIR="$MATCHES/work-$WI"
if [ -d "$RESOLVED_WI_DIR" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the standalone reconstruction ($RESOLVED_WI_DIR) does not point at the directory the id grammar names"
fi
# The slug recovery the spine-branch name depends on.
RECOVERED_SLUG="$(basename "$MATCHES")"; RECOVERED_SLUG="${RECOVERED_SLUG#"$SPINE_ID-"}"
t_assert_eq "$SPINE_SLUG" "$RECOVERED_SLUG" "the spine slug is recoverable from the directory name (nothing persists it)"

SPEC="$RESOLVED_WI_DIR/spec.md"
REPORT="$RESOLVED_WI_DIR/report.md"
# The arrow is U+2192; the AC grammar splits on it and an ASCII '->' does not parse.
printf '%s\n' \
  '## 5. Acceptance criteria' \
  '- [ ] AC-1 auto: `true` → expected: exit 0' \
  '- [ ] AC-2 auto: `false` → expected: exit 0' \
  '- [X] AC-3 auto: `echo ready` → expected: output contains ready' \
  '- [ ] AC-4 user: run the export and see the file appear' > "$SPEC"

t_capture bash "$OSS" verify_acs "$SPEC"
t_assert_rc 0 "the resolved spec feeds verify_acs - rc 0, not rc 2 'spec not found'"
# Negative control: drop the slug (the one segment nothing persists) and the same
# call is rc 2. This is what makes the glob load-bearing rather than decorative.
t_capture bash "$OSS" verify_acs "$AI_ROOT/docs/specs/$REL_ID/$SPINE_ID/work-$WI/spec.md"
t_assert_rc 2 "dropping the spine slug yields 'spec not found' rc 2 - the glob is load-bearing"

# Cross-file prose contract: the work-item docs path shape is declared in two
# skills - the lane that WRITES the handoff there and the layer that READS the
# spec back. A drift between them has no runtime signal at all; the close layer
# just resolves to a directory that has never existed.
_PATH_SHAPE='docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>'
for f in "$SKILLS/close/references/work-item-close.md" "$SKILLS/work-item/references/round-orchestration.md"; do
  if grep -Fq "$_PATH_SHAPE" "$f"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $(basename "$f") does not declare the work-item docs path shape '$_PATH_SHAPE'"
  fi
done

# The orphan rule - every references/*.md under a skill must be pointed at from
# that skill's own SKILL.md - is enforced in test-skill-bash-blocks.sh (check 5),
# across all five skills rather than close/ alone. The loop that lived here
# covered 10 of the 43 reference files; two enforcers of one rule is one too
# many, so this one was removed when the harness landed.

# ---------------------------------------------------------------------------
# C. The spine branch, the worktree, and the gate's two mechanical layers.
# ---------------------------------------------------------------------------
BASE_BRANCH="$(git -C "$CANON" rev-parse --abbrev-ref HEAD)"
SPINE_BRANCH="$(bash "$OSS" branch_name "$SP" "$SPINE_SLUG")"
git -C "$CANON" checkout -q -b "$SPINE_BRANCH"
# A commit only the spine branch has, made BEFORE the worktree is spawned -
# otherwise every reachability assertion below is vacuously true.
echo spine-only > "$CANON/spine.txt"
git -C "$CANON" add spine.txt; git -C "$CANON" commit -qm "spine-only commit"

WT="$(bash "$OSS" worktree_add canonical "$WI" "$WI_SLUG" "$SPINE_BRANCH")"
bash "$OSS" work_item_exec "$WI" "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" "$WT" "$(git -C "$WT" rev-parse HEAD)" >/dev/null

# Layer 1 composes: EVERY row verify_acs emits must be grammar-valid to
# verify_step. If the expectation extraction ever drifts (leaving the raw
# '→ expected:' text in the field), every row comes back rc 2 "unrecognized
# expectation" and the whole gate fails closed on every AC - green rows and
# broken rows alike. Neither half's own unit test can see that: they are each
# driven with hand-written arguments.
_ROWS=0; _MALFORMED=0
while IFS="$(printf '\t')" read -r _label _cmd _exp; do
  [ -n "$_label" ] || continue
  _ROWS=$((_ROWS+1))
  bash "$OSS" verify_step "$WT" "$_cmd" "$_exp" >/dev/null 2>&1
  [ $? -eq 2 ] && _MALFORMED=$((_MALFORMED+1))
done < <(bash "$OSS" verify_acs "$SPEC")
t_assert_eq "3" "$_ROWS" "verify_acs emits one row per auto: AC and skips the user: row"
t_assert_eq "0" "$_MALFORMED" "every row verify_acs emits is grammar-valid to verify_step (never rc 2)"

AC2_CMD="$(bash "$OSS" verify_acs "$SPEC" | awk -F'\t' '$1=="AC-2"{print $2}')"
AC2_EXP="$(bash "$OSS" verify_acs "$SPEC" | awk -F'\t' '$1=="AC-2"{print $3}')"
t_assert_eq "false" "$AC2_CMD" "the command field arrives backtick-stripped and directly runnable"
t_assert_eq "exit 0" "$AC2_EXP" "the expectation field is the bare grammar, not the raw '→ expected:' text"
t_capture bash "$OSS" verify_step "$WT" "$AC2_CMD" "$AC2_EXP"
t_assert_rc 1 "a failing row driven with verify_acs's OWN output is rc 1 - distinguishable from a malformed rc 2, which is what lets halt-on-first-fail route to the right recovery option"

# The halt itself, executed FROM THE SHIPPED PROSE rather than from a copy of it
# retyped here. The loop is extracted out of impl-check.md and run under real
# strict mode against a spec whose second row fails and whose third row would
# leave a file behind - so "no later row ran" is a concrete observable, and the
# subject of the assertion is the file the ceremony actually ships.
#
# Both idioms in that block are silently wrong when written the obvious way:
# `oss verify_acs … | while …` puts the loop in a subshell (the halt is lost),
# and `if ! oss verify_step …; then rc=$?` captures the negation's zero (the
# halt never fires). Either mistake sails past a failing AC into layer 2 at rc 0.
SHIM="$TMP/shim"; mkdir -p "$SHIM"
printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$OSS" > "$SHIM/oss"; chmod +x "$SHIM/oss"
HALT_SPEC="$TMP/halt-spec.md"
printf '%s\n' \
  '- [ ] AC-1 auto: `true` → expected: exit 0' \
  '- [ ] AC-2 auto: `false` → expected: exit 0' \
  '- [ ] AC-3 auto: `touch third-row-ran` → expected: exit 0' > "$HALT_SPEC"
HALT_DIR="$TMP/halt-run"; mkdir -p "$HALT_DIR"
BLOCK="$TMP/halt-block.sh"
# Was a hand-rolled awk; now the shared harness like the other ten, so every
# extraction in this file is one `_extract_block <source-var> <anchor> <out>`
# line. test-block-ledger.sh check 4 resolves that source variable back to the
# ledger's file, which it cannot do when the path sits on a different line from
# the anchor.
IMPL_CHECK="$SKILLS/close/references/impl-check.md"
_extract_block "$IMPL_CHECK" 'while IFS=' "$BLOCK"
if grep -q 'verify_step' "$BLOCK" && grep -q 'while IFS=' "$BLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the halt loop from impl-check.md - the assertions below are vacuous"
fi
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; wt='$HALT_DIR'; spec='$HALT_SPEC'; . '$BLOCK'"
t_assert_rc 1 "the shipped halt loop exits nonzero when a row fails - the halt reaches the caller"
t_assert_contains "$T_OUT" "[AC] AC-2" "...tagged [AC] and naming the failing row"
if [ -e "$HALT_DIR/third-row-ran" ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the row AFTER the failure still ran - halt-on-first-fail is not halting"
else
  T_PASS=$((T_PASS+1))
fi

# Layer 2 - report cross-check. Assert the LIB's real message; the
# `[report cross-check]` prefix is the skill's surfacing convention and appears
# in no lib, so a ceremony grepping for it would find nothing forever.
printf '%s\n' '| AC | Status |' '| AC-1 | pass |' '| AC-3 | pass |' > "$REPORT"
t_capture bash "$OSS" report_cross_check "$REPORT" "$SPEC"
t_assert_rc 1 "report_cross_check fails when the report omits an auto: AC"
t_assert_contains "$T_OUT" "oss: report does not account for:" "...with the lib's real message"
t_assert_contains "$T_OUT" "AC-2" "...naming the missing AC"
case "$T_OUT" in
  *'[report cross-check]'*) T_FAIL=$((T_FAIL+1)); echo "FAIL: the lib emitted the skill's surfacing tag - prose may now legitimately grep for it";;
  *) T_PASS=$((T_PASS+1));;
esac
printf '%s\n' '| AC-2 | fail |' >> "$REPORT"
t_capture bash "$OSS" report_cross_check "$REPORT" "$SPEC"
t_assert_rc 0 "...and passes once every auto: AC is accounted for (so the failing case above failed for the stated reason)"

# ---------------------------------------------------------------------------
# D. The merge seam: the target this layer hands `git merge` comes from STATE,
#    written by the execution lane. A merge onto the wrong branch is rc 0.
# ---------------------------------------------------------------------------
# `oss get` is `jq -r`: an absent field prints the four characters `null`, which
# is non-empty. A bare `[ -n "$b" ]` guard passes it straight through to
# `git merge null`, so the guard has to reject the literal too.
STATE_BRANCH="$(bash "$OSS" get ".work_items[] | select(.id==\"$WI\") | .branch")"
if [ -n "$STATE_BRANCH" ] && [ "$STATE_BRANCH" != "null" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work_items[].branch is '$STATE_BRANCH' - close has no merge target and cannot recover one"
fi
t_assert_eq "$(bash "$OSS" work_item_branch "$WI" "$WI_SLUG")" "$STATE_BRANCH" "the recorded merge target matches the id grammar's own branch name"
if git -C "$CANON" rev-parse --verify --quiet "refs/heads/$STATE_BRANCH" >/dev/null; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the recorded merge target '$STATE_BRANCH' does not name a real ref"
fi

echo item > "$WT/item.txt"
git -C "$WT" add item.txt
t_assert_contains "$(git -C "$WT" diff --cached --name-only)" "item.txt" "the staging proof sees a non-empty index before the commit"
git -C "$WT" commit -qm "work item"
WI_SHA="$(git -C "$WT" rev-parse HEAD)"

t_assert_eq "$SPINE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "canonical is parked on the spine branch when the merge runs (the guard's precondition)"
if git -C "$CANON" merge-base --is-ancestor "$WI_SHA" "$SPINE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: fixture is vacuous - the work-item commit is already on the spine branch before the merge"
else
  T_PASS=$((T_PASS+1))
fi
t_capture git -C "$CANON" merge --no-ff -m "merge $WI" "$STATE_BRANCH"
t_assert_rc 0 "merging the STATE-recorded branch onto the parked spine branch succeeds"
if git -C "$CANON" merge-base --is-ancestor "$WI_SHA" "$SPINE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the work-item commit is NOT reachable from the spine branch after the merge"
fi
if git -C "$CANON" merge-base --is-ancestor "$WI_SHA" "$BASE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: negative control is vacuous - the commit reached $BASE_BRANCH without a merge there"
else
  T_PASS=$((T_PASS+1))
fi

# The cleanup-ordering claim work-item-close.md §6 makes, as a contrast rather
# than a single rc: a MERGED work-item branch removes cleanly, an unmerged one
# refuses rc 8. (The standalone rc-8 case is also asserted in test-worktree.sh;
# here it is the pairing that carries the meaning - cleanup can only succeed
# AFTER this layer's merge has landed.)
t_capture bash "$OSS" worktree_remove canonical "$WI"
t_assert_rc 0 "after the merge, worktree_remove succeeds and takes the branch with it"
if git -C "$CANON" show-ref --verify --quiet "refs/heads/$STATE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the merged work-item branch survived cleanup"
else
  T_PASS=$((T_PASS+1))
fi
WI2="$(bash "$OSS" work_item_add "$SP" "second item")"
WT2="$(bash "$OSS" worktree_add canonical "$WI2" "second-item" "$SPINE_BRANCH")"
echo two > "$WT2/two.txt"; git -C "$WT2" add two.txt; git -C "$WT2" commit -qm "unmerged work"
t_capture bash "$OSS" worktree_remove canonical "$WI2"
t_assert_rc 8 "an UNMERGED work-item branch refuses cleanup rc 8 - which is why cleanup runs after the merge, not before"

# ---------------------------------------------------------------------------
# E. Spine close (Task 10). Every block below is EXTRACTED FROM THE SHIPPED
#    PROSE and executed under real strict mode, so the subject of each assertion
#    is the file the ceremony ships rather than a copy retyped here.
#
#    NOT COVERED, and not coverable: "apply-pending runs before the demo" and "a
#    failing demo halts before the critic, the harvest and cleanup" are orderings
#    of prose steps with no executable surface. A script that calls apply-pending
#    then demo_run asserts nothing about the ceremony - it tests a fixture
#    written to pass. Task 13's harness checks that every `oss` verb the prose
#    names resolves; beyond that those orderings have no coverage in this release.
# ---------------------------------------------------------------------------
SPINE_CLOSE="$SKILLS/close/references/spine-close.md"
# `_extract_block` is defined at the TOP of this file (see the note there).
# It delegates to the shared harness (#138), which REFUSES an anchor matching
# more than one block: the old inline awk stopped at the first match, so a
# duplicated anchor bound silently to whichever came first and would have
# silently REBOUND if a block were inserted above it. Every anchor used below
# is asserted unique, and bound to its source file, by test-block-ledger.sh.
OPEN_BLOCK="$TMP/spine-open.sh";  _extract_block "$SPINE_CLOSE" 'work items that are not complete' "$OPEN_BLOCK"
MERGE_BLOCK="$TMP/spine-merge.sh"; _extract_block "$SPINE_CLOSE" 'is-ancestor' "$MERGE_BLOCK"
TOUCH_BLOCK="$TMP/spine-touch.sh"; _extract_block "$SPINE_CLOSE" 'touch_check' "$TOUCH_BLOCK"
for _pair in "$OPEN_BLOCK:work_items" "$MERGE_BLOCK:merge --no-ff" "$TOUCH_BLOCK:touch_check"; do
  _bf="${_pair%%:*}"; _bn="${_pair#*:}"
  if [ -s "$_bf" ] && grep -Fq "$_bn" "$_bf"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract '$_bn' from spine-close.md - the assertions below are vacuous"
  fi
done

# E1. Step 1 refuses and NAMES the offenders. `oss get` is jq -r without -e: a
# select matching nothing exits 0, so a block testing the rc instead of the
# output would close a spine with two unfinished items. Both ids must appear.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; spine_id='$SP'; . '$OPEN_BLOCK'"
t_assert_rc 1 "step 1 halts when a work item is not complete"
t_assert_contains "$T_OUT" "$WI" "...naming the first offender by id"
t_assert_contains "$T_OUT" "$WI2" "...and the second - join(\", \") lists every one, not just the first"
bash "$OSS" work_item_status "$WI" complete >/dev/null
bash "$OSS" work_item_status "$WI2" complete >/dev/null
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; spine_id='$SP'; . '$OPEN_BLOCK'"
t_assert_rc 0 "...and passes once every item is complete (so the refusal above fired for the stated reason)"
t_assert_eq "" "$T_OUT" "...silently - a passing gate says nothing"

# Move the BASE branch forward, the way a sibling spine closing first would.
# This is what makes the changed-path assertions in E5 non-vacuous: with the base
# still at the fork point every candidate computation agrees.
git -C "$CANON" checkout -q "$BASE_BRANCH"
echo sibling > "$CANON/sibling.txt"
git -C "$CANON" add sibling.txt; git -C "$CANON" commit -qm "a sibling spine landed on base"
git -C "$CANON" checkout -q "$SPINE_BRANCH"
SPINE_TIP="$(git -C "$CANON" rev-parse "$SPINE_BRANCH")"
if git -C "$CANON" merge-base --is-ancestor "$SPINE_TIP" "$BASE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: fixture is vacuous - the spine tip is already on $BASE_BRANCH before any spine-close merge"
else
  T_PASS=$((T_PASS+1))
fi

_spine_unreached() { # $1=label ; the spine must NOT have landed on base
  if git -C "$CANON" merge-base --is-ancestor "$SPINE_TIP" "$BASE_BRANCH"; then
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $1 - the spine reached $BASE_BRANCH anyway"
  else
    T_PASS=$((T_PASS+1))
  fi
}

# E2-E5 inject `repo_base_branches`, one "<repo>:<base_branch>" line per hosting
# repo, instead of a bare `base_branch` - Task 9 (#272/#310) turned the once-per-
# spine merge into a loop over every repo hosting the spine's items, keyed off
# `oss get .work_items[].target_repo`. This fixture declares one repo
# ("canonical"), and both $WI and $WI2 default to it, so the block's own loop
# resolves the very same single iteration the old single-repo form ran - the
# assertions below exercise the loop body's guards against that one hosting
# repo, not the multi-repo iteration itself (the same scope note
# round-orchestration.md's `checkout -q -b` row carries in block-ledger.tsv).
# The messages are BYTE-IDENTICAL to the old single-`canonical` wording,
# because the block interpolates the resolved repo NAME ("canonical") in
# exactly the position the old block hardcoded the literal word.

# E2. Canonical parked somewhere other than the spine branch. This is the guard
# the whole step turns on: reading the branch off HEAD instead of deriving it
# makes the switch-back a no-op, the merge "Already up to date" at rc 0, and
# every later step green against a tree the spine never reached. The reachability
# check CANNOT catch it - on a self-merge the tip is trivially its own ancestor.
git -C "$CANON" checkout -q "$BASE_BRANCH"
t_assert_eq "$BASE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "the wrong-branch fixture really is parked off the spine branch (the guard's precondition)"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:$BASE_BRANCH'; . '$MERGE_BLOCK'"
t_assert_rc 1 "a spine close with canonical parked elsewhere halts BEFORE the merge"
t_assert_contains "$T_OUT" "canonical is on '$BASE_BRANCH', not '$SPINE_BRANCH'" "...naming both the branch it found and the branch it derived"
_spine_unreached "wrong-branch halt"

# E3. base_branch unresolvable for the hosting repo. The plan doc's
# spine-context section is the only record of it, so an empty read is
# reachable. Unguarded, `git checkout -q ""` fails at rc 128 and the ceremony
# merges the spine branch into ITSELF at rc 0.
git -C "$CANON" checkout -q "$SPINE_BRANCH"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches=''; . '$MERGE_BLOCK'"
t_assert_rc 1 "an unresolvable base_branch halts"
t_assert_contains "$T_OUT" "no base_branch recorded for $SP" "...naming the spine whose base branch is missing"
t_assert_eq "$SPINE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "...leaving canonical where it was"
_spine_unreached "empty base_branch halt"

# E3b. base_branch naming a branch that does not exist (a typo in the plan doc's
# spine-context line). The checkout fails, and its rc must be read.
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:no-such-base'; . '$MERGE_BLOCK'"
t_assert_rc 1 "a base_branch naming no ref halts"
t_assert_contains "$T_OUT" "cannot check out base branch 'no-such-base'" "...from the checkout's own rc, naming the branch it could not reach"
_spine_unreached "missing base_branch halt"

# E4. base_branch resolving to a TRACKED FILE rather than a branch. `git checkout
# -q <tracked-file>` restores that file and exits 0 WITHOUT moving HEAD, so the
# checkout's rc says nothing - only asserting HEAD actually moved catches it.
git -C "$CANON" rev-parse --verify --quiet "refs/heads/f.txt" >/dev/null \
  && { T_FAIL=$((T_FAIL+1)); echo "FAIL: 'f.txt' names a branch here - the tracked-file case is not what this exercises"; }
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:f.txt'; . '$MERGE_BLOCK'"
t_assert_rc 1 "a base_branch naming a tracked file halts even though the checkout exits 0"
t_assert_contains "$T_OUT" "switch-back left canonical on '$SPINE_BRANCH', not 'f.txt'" "...from the post-checkout HEAD assertion, not from the checkout's rc"
_spine_unreached "tracked-file base_branch halt"

# E5. The happy path, and the changed-path list the touch check reads. Both
# blocks run in ONE shell so $merge_shas really crosses the seam from step 2 to
# step 5 (repo:sha pairs, one per hosting repo - never a bash associative array)
# rather than being handed over by this test.
#
# Two bones make the path computation observable:
#   ADR-0101 covers the file only the SPINE changed  -> must HIT
#   ADR-0102 covers the file only the BASE changed   -> must NOT hit
# `git diff --name-only $base..$spine` after the merge names sibling.txt and NOT
# spine.txt - exactly inverted - so this pair fails loudly on that computation.
bash "$OSS" bone_add ADR-0101 "the surface the spine moved" "spine.txt" >/dev/null
bash "$OSS" bone_add ADR-0102 "a surface the spine never touched" "sibling.txt" >/dev/null
git -C "$CANON" checkout -q "$SPINE_BRANCH"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:$BASE_BRANCH'; . '$MERGE_BLOCK'; . '$TOUCH_BLOCK'"
t_assert_rc 0 "the merge block plus the touch block run clean end to end"
t_assert_eq "$BASE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "the switch-back left canonical on the base branch"
if git -C "$CANON" merge-base --is-ancestor "$SPINE_TIP" "$BASE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the spine tip is NOT reachable from $BASE_BRANCH after the merge"
fi
if git -C "$CANON" cat-file -e "$BASE_BRANCH:spine.txt" 2>/dev/null; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the spine's own file is absent from $BASE_BRANCH - the merge moved a ref but landed no content"
fi
t_assert_contains "$T_OUT" "bone ADR-0101" "the changed-path list contains the file the SPINE changed (the merge's own first-parent diff)"
case "$T_OUT" in
  *"ADR-0102"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: the changed-path list named a file only the BASE branch changed - this is 'git diff \$base..\$spine', which is inverted after the merge";;
  *) T_PASS=$((T_PASS+1));;
esac

# E5b. RESUME. E5 left canonical merged and parked on its base branch - exactly
# the state a close halted at step 5 leaves behind. Re-entering the merge block
# used to be impossible: it asserted HEAD == $spine_branch and halted on a repo
# it had itself finished, and $merge_shas (a shell variable) was gone, so §6's
# touch check had nothing to compute a first-parent diff from. The resume arm
# now lives inside the loop, so this is the same block run twice.
FIRST_MERGE="$(git -C "$CANON" rev-parse "$BASE_BRANCH")"
MERGES_BEFORE="$(git -C "$CANON" rev-list --merges --count "$BASE_BRANCH")"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:$BASE_BRANCH'; . '$MERGE_BLOCK'; printf 'PAIRS%s\n' \"\$merge_shas\""
t_assert_rc 0 "resume: the merge block re-runs clean against an already-landed repo"
t_assert_contains "$T_OUT" "already landed at $FIRST_MERGE" "resume: the landed repo is recognised and its merge sha reconstructed from history"
t_assert_contains "$T_OUT" "canonical:$FIRST_MERGE" "resume: \$merge_shas is repopulated for the landed repo - the touch check reads it"
t_assert_eq "$MERGES_BEFORE" "$(git -C "$CANON" rev-list --merges --count "$BASE_BRANCH")" "resume: no second, spurious merge commit was created"
t_assert_eq "$BASE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "resume: the repo is left on its base branch"

# E5c. A PARTIAL changed-path list must halt, not read as clean. The per-repo
# diff loop used to sit inside a process substitution, so the outer loop saw its
# stdout and never its exit status: a repo failing AFTER an earlier one emitted
# paths contributed nothing silently, `$#` stayed non-zero, and touch_check ran
# over a list missing that repo's changes. The good pair comes FIRST here on
# purpose - that is the ordering the old form could not detect.
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; merge_shas='canonical:$FIRST_MERGE
nosuchrepo:$FIRST_MERGE'; . '$TOUCH_BLOCK'"
t_assert_rc 1 "a repo failing after another already emitted paths halts the touch check"
t_assert_contains "$T_OUT" "INCOMPLETE" "...and says the changed-path list would be incomplete"
case "$T_OUT" in
  *"touch check: clean"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: touch_check reported CLEAN over a partial path list - the exact false negative this guard exists to prevent";;
  *) T_PASS=$((T_PASS+1));;
esac

# E6. touch_check's three exit codes across four cases (zero paths, hit,
# clean, unreadable registry), read straight off the dispatcher.
t_capture bash "$OSS" touch_check
t_assert_rc 2 "touch_check with ZERO paths is rc 2 (could-not-check), NOT rc 1 (clean)"
t_assert_contains "$T_OUT" "needs at least one path" "...saying why"
t_capture bash "$OSS" touch_check spine.txt
t_assert_rc 0 "a path on a registered surface is rc 0 - a HIT, not a failure"
t_assert_eq "bone ADR-0101" "$T_OUT" "...printing the kind and the ref, which is what the reclassification reason quotes"
t_capture bash "$OSS" touch_check docs/unrelated.md
t_assert_rc 1 "a path on no registered surface is rc 1 - clean"
t_assert_eq "" "$T_OUT" "...with nothing on stdout"
BROKEN="$TMP/broken-state.json"; printf '%s\n' '{"schema_version":2}' > "$BROKEN"
t_capture env "OSS_STATE_FILE=$BROKEN" bash "$OSS" touch_check spine.txt
t_assert_rc 2 "a state whose bones registry is unreadable is rc 2 - INCONCLUSIVE, never clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean" "...saying so in the lib's own words"

# E7. The shipped block's rc-2 arm: inconclusive must HALT, not fall through to
# the clean branch. Driven by pointing the block's touch_check at that same
# unreadable state. `merge_shas` is one "<repo>:<sha>" pair - the aggregation
# form §6 now reads, never a bare `merge_sha`/`canonical` pair (Task 9).
MERGE_SHA="$(git -C "$CANON" rev-parse "$BASE_BRANCH")"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c \
  "set -euo pipefail; merge_shas='canonical:$MERGE_SHA'; . '$TOUCH_BLOCK'"
t_assert_rc 1 "the shipped block HALTS on touch_check rc 2 rather than treating it as clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean - halt" "...with the halt naming the reason"

# E8. A merge that changed no paths in the one hosting repo. touch_check would
# answer rc 2 for it, so the block halts BEFORE the call and says which of the
# two rc-2 causes this is.
git -C "$CANON" checkout -q -b empty-spine "$BASE_BRANCH"
echo transient > "$CANON/transient.txt"; git -C "$CANON" add transient.txt
git -C "$CANON" commit -qm "add a file"
git -C "$CANON" rm -q transient.txt; git -C "$CANON" commit -qm "and take it away again"
git -C "$CANON" checkout -q "$BASE_BRANCH"
git -C "$CANON" merge --no-ff empty-spine -m "a spine that netted no change" >/dev/null
EMPTY_MERGE="$(git -C "$CANON" rev-parse HEAD)"
t_assert_eq "" "$(git -C "$CANON" diff --name-only "$EMPTY_MERGE^1" "$EMPTY_MERGE")" "the empty-merge fixture really does change no path (the guard's precondition)"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; merge_shas='canonical:$EMPTY_MERGE'; . '$TOUCH_BLOCK'"
t_assert_rc 1 "a merge that changed no paths halts"
t_assert_contains "$T_OUT" "the merge changed no paths" "...distinguishing the empty-input cause from an unreadable registry"

# ---------------------------------------------------------------------------
# F. Release close (Task 11). The two blocking gates, and THE FIXTURE SET IS THE
#    POINT.
#
#    The gates are read-only selectors, so unlike §E there is a real executable
#    subject here — but a selector test is worthless unless its fixtures
#    DISCRIMINATE. Three defective selectors are each individually green over the
#    obvious fixture pair:
#      * `status == "active"` alone      - green unless a RENEWED fake sits AT its
#                                          expiry (fixture b)
#      * `expiry == release` (identity)  - green unless an outstanding fake sits
#                                          BEFORE the closing release (fixture c)
#      * a STRING comparison of ids      - green until r10, because "r1" <= "r10"
#                                          is true and only "r2" <= "r10" is false
#                                          (fixture f)
#    Every assertion below names a concrete row, not a substring or a bare rc.
# ---------------------------------------------------------------------------
REL2="$(bash "$OSS" release_add "second" "a second goal")"
REL3="$(bash "$OSS" release_add "third" "a third goal")"
REL4="$(bash "$OSS" release_add "fourth" "a fourth goal")"
# Releases mint from r0 - the skeleton IS Release 0 - while spines and work
# items start at 1. The expiry fixtures below are keyed to these real ids, so
# pin the convention rather than assuming the r1-first shape the other two
# levels use.
t_assert_eq "r0" "$REL"  "the first release mints r0 - the skeleton is Release 0"
t_assert_eq "r1" "$REL2" "...and the second r1 (the expiry fixtures below name real releases)"
t_assert_eq "r2" "$REL3" "...and the third r2 - the closing release for the fixture set"
t_assert_eq "r3" "$REL4" "...and the fourth r3 - the at-or-before arm's second vantage point"

# The seven fixtures, built through the real verbs so the STORED shape is the
# subject - not a hand-written state blob that could disagree with what
# fake_add/fake_status actually write.
bash "$OSS" fake_add "f-active-at-r2"  fake "no sandbox yet"  "the vendor ships a sandbox" r2 >/dev/null
bash "$OSS" fake_add "f-renewed-at-r2" fake "no sandbox yet"  "the first live order"       r1 >/dev/null
bash "$OSS" fake_status "f-renewed-at-r2" renewed "still needed, one more release" r2 >/dev/null
bash "$OSS" fake_add "f-active-at-r1"  fake "deferred wiring" "the first second account"   r1 >/dev/null
bash "$OSS" fake_add "f-renewed-to-r5" fake "still too early" "the first paying user"      r1 >/dev/null
bash "$OSS" fake_status "f-renewed-to-r5" renewed "pushed out with a reason" r5 >/dev/null
bash "$OSS" fake_add "f-replaced-at-r2" fake "shell for now"  "the real adapter lands"     r2 >/dev/null
bash "$OSS" fake_status "f-replaced-at-r2" replaced "the real adapter landed in r1.s1" >/dev/null
bash "$OSS" fake_add "f-no-expiry"     fake "never dated"     "nobody wrote a condition"   "" >/dev/null

# PRECONDITIONS. A fixture that does not carry the property under test makes
# every assertion below vacuous - which is exactly how the old plan's fixture
# pair stayed green under the broken selector.
_fk() { bash "$OSS" get ".fakes[] | select(.boundary==\"$1\") | .$2"; }
t_assert_eq "renewed" "$(_fk f-renewed-at-r2 status)"          "fixture (b) really carries status=renewed"
t_assert_eq "r2"      "$(_fk f-renewed-at-r2 expiry_release)"  "...AND its expiry really moved to r2 - both halves, or (b) discriminates nothing"
t_assert_eq "active"  "$(_fk f-active-at-r1 status)"           "fixture (c) is outstanding"
t_assert_eq "r1"      "$(_fk f-active-at-r1 expiry_release)"   "...and expired BEFORE the closing release"
t_assert_eq "renewed" "$(_fk f-renewed-to-r5 status)"          "fixture (d) is renewed"
t_assert_eq "r5"      "$(_fk f-renewed-to-r5 expiry_release)"  "...to a LATER expiry - the renewal that legitimately does not block"
t_assert_eq "replaced" "$(_fk f-replaced-at-r2 status)"        "fixture (e) is the resolving status"
t_assert_eq "r2"      "$(_fk f-replaced-at-r2 expiry_release)" "...AT the closing release - so only .status can be excluding it"

# The r2 close. Assert the EXACT rows, tab-separated, not that output "contains"
# a boundary name.
TAB="$(printf '\t')"
t_capture bash "$OSS" expired_fakes r2
t_assert_rc 1 "expired_fakes returns rc 1 when the blocking set is NON-EMPTY (0=clean is the opposite polarity to touch_check)"
t_assert_eq "4" "$(printf '%s\n' "$T_OUT" | grep -c . || true)" "exactly four fakes block at r2 - a broader or narrower selector moves this number"
t_assert_contains "$T_OUT" "f-active-at-r2${TAB}active${TAB}r2${TAB}the vendor ships a sandbox" "(a) an ACTIVE fake at its expiry blocks, and the row carries boundary/status/expiry/trigger"
t_assert_contains "$T_OUT" "f-renewed-at-r2${TAB}renewed${TAB}r2${TAB}the first live order" "(b) THE DISCRIMINATING FIXTURE: a RENEWED fake at its expiry also blocks - an active-only selector drops exactly this row"
t_assert_contains "$T_OUT" "f-active-at-r1${TAB}active${TAB}r1${TAB}the first second account" "(c) an outstanding fake that expired EARLIER still blocks - an identity comparison drops exactly this row"
t_assert_contains "$T_OUT" "f-no-expiry${TAB}active${TAB}unparseable-expiry" "an expiry that cannot be parsed BLOCKS, marked - it can never fire, so skipping it makes the fake permanent"
case "$T_OUT" in
  *f-renewed-to-r5*) T_FAIL=$((T_FAIL+1)); echo "FAIL: (d) a fake renewed to a LATER expiry blocked - the gate is not reading expiry_release";;
  *) T_PASS=$((T_PASS+1));;
esac
case "$T_OUT" in
  *f-replaced-at-r2*) T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) a REPLACED fake at its expiry blocked - replaced is the only resolving status";;
  *) T_PASS=$((T_PASS+1));;
esac

# (c) again at r3, the framing the at-or-before arm is named for: an r1 expiry
# two releases later.
t_capture bash "$OSS" expired_fakes r3
t_assert_rc 1 "...and at r3's close the gate still blocks"
t_assert_contains "$T_OUT" "f-active-at-r1${TAB}active${TAB}r1" "(c) an r1 expiry still blocks at r3 - at-or-before, not identity"

# (f) THE NUMERIC GUARD. jq evaluates "r2" <= "r10" as FALSE, so a string
# comparison silently stops blocking r2 expiries from the tenth release on.
# "r1" <= "r10" is TRUE, so fixture (c) canNOT catch this - only an r2-at-r10 row
# discriminates, which is why this assertion names f-active-at-r2 specifically.
t_assert_eq "false" "$(jq -n '"r2" <= "r10"')" "the lexicographic trap this fixture exists for is real (the guard's precondition)"
t_capture bash "$OSS" expired_fakes r10
t_assert_rc 1 "the gate blocks at r10"
t_assert_contains "$T_OUT" "f-active-at-r2${TAB}active${TAB}r2" "(f) an r2 expiry blocks at r10 - a STRING comparison drops exactly this row"
t_assert_contains "$T_OUT" "f-renewed-to-r5${TAB}renewed${TAB}r5" "...and the r5 renewal is due by r10 too, so the r10 set is genuinely wider than the r2 set"

# rc 0 = CLEAN, on a state with no outstanding fakes. Captured with stderr
# dropped: OSS_STATE_FILE emits an override notice that t_capture would merge in.
CLEANST="$TMP/clean-state.json"; printf '%s\n' '{"schema_version":2,"fakes":[],"demo_ledger":[]}' > "$CLEANST"
_CL_OUT="$(env "OSS_STATE_FILE=$CLEANST" bash "$OSS" expired_fakes r2 2>/dev/null)"; _CL_RC=$?
t_assert_eq "0" "$_CL_RC" "an empty blocking set is rc 0 - CLEAN (so every rc 1 above fired for the stated reason)"
t_assert_eq "" "$_CL_OUT" "...with nothing on stdout"

# rc 2, both causes, kept distinguishable from rc 1.
t_capture bash "$OSS" expired_fakes "rX"
t_assert_rc 2 "a release argument that is not r<N> is rc 2 - could-not-check, never clean"
t_assert_contains "$T_OUT" "needs a release id of the form r<N>" "...saying why"
t_capture env "OSS_STATE_FILE=$BROKEN" bash "$OSS" expired_fakes r2
t_assert_rc 2 "a state whose fakes registry is unreadable is rc 2 - INCONCLUSIVE, never clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean" "...in the lib's own words"

# (g) The quarantine twin.
bash "$OSS" ledger_add_auto "$SP" "the export still runs"  "true" "exit:0" >/dev/null
bash "$OSS" ledger_add_auto "$SP" "the report still opens" "true" "exit:0" >/dev/null
bash "$OSS" ledger_add_auto "$SP" "the archive still lists" "true" "exit:0" >/dev/null
bash "$OSS" ledger_quarantine d1 "flaky upstream, unrelated to any open spine" r1 >/dev/null
bash "$OSS" ledger_quarantine d2 "raised during this very release" r2 >/dev/null
bash "$OSS" ledger_quarantine d3 "nobody passed a release" "" >/dev/null

# THE FIELD-NAME TRAP, pinned so nobody "fixes" the selector back to `.release`.
# oss_ledger_quarantine builds a payload keyed `release`, but _oss_apply_op
# writes it onto the LINE as `.quarantined_in_release`. A selector written from
# the payload shape reads a key that exists on no line and every quarantine
# escapes at rc 0, forever.
t_assert_eq "r1" "$(bash "$OSS" get '.demo_ledger[] | select(.id=="d1") | .quarantined_in_release')" "the quarantine release is stored as .quarantined_in_release"
t_assert_eq "null" "$(bash "$OSS" get '.demo_ledger[] | select(.id=="d1") | .release')" "...and NOT as .release - the payload key is not the record key"
t_assert_eq "null" "$(bash "$OSS" get '.demo_ledger[] | select(.id=="d3") | .quarantined_in_release')" "an anchorless quarantine records no release key at all (the guard's precondition)"

t_capture bash "$OSS" expired_quarantines r2
t_assert_rc 1 "expired_quarantines is rc 1 when a ticket is owed - same polarity as the fake gate"
t_assert_eq "2" "$(printf '%s\n' "$T_OUT" | grep -c . || true)" "exactly two quarantines block at r2"
t_assert_contains "$T_OUT" "d1${TAB}r1${TAB}flaky upstream, unrelated to any open spine" "(g) a quarantine from an EARLIER release blocks, with its release and reason"
t_assert_contains "$T_OUT" "d3${TAB}no-release-anchor" "an anchorless quarantine blocks - a ticket with no release can never come due"
case "$T_OUT" in
  *d2*) T_FAIL=$((T_FAIL+1)); echo "FAIL: a quarantine raised in THIS release blocked - the comparison must be strictly earlier, or a close can never quarantine anything";;
  *) T_PASS=$((T_PASS+1));;
esac
_QC_OUT="$(env "OSS_STATE_FILE=$CLEANST" bash "$OSS" expired_quarantines r2 2>/dev/null)"; _QC_RC=$?
t_assert_eq "0" "$_QC_RC" "an empty quarantine set is rc 0 - CLEAN"
t_assert_eq "" "$_QC_OUT" "...with nothing on stdout"
t_capture bash "$OSS" expired_quarantines "r"
t_assert_rc 2 "a malformed release argument is rc 2 on the quarantine gate too"

# ---------------------------------------------------------------------------
# F2. The shipped branch blocks, EXTRACTED FROM THE PROSE and run under real
#     strict mode. The polarity is inverted relative to touch_check, so the arm
#     the ceremony actually branches on is the thing worth executing.
# ---------------------------------------------------------------------------
RELEASE_CLOSE="$SKILLS/close/references/release-close.md"
PATCH_LANE="$SKILLS/close/references/patch-lane.md"
SPINEGATE_BLOCK="$TMP/rel-spinegate.sh"; _extract_block "$RELEASE_CLOSE" 'spines that are not closed' "$SPINEGATE_BLOCK"
FAKEGATE_BLOCK="$TMP/rel-fakegate.sh";   _extract_block "$RELEASE_CLOSE" 'expired_fakes' "$FAKEGATE_BLOCK"
QUARGATE_BLOCK="$TMP/rel-quargate.sh";   _extract_block "$RELEASE_CLOSE" 'expired_quarantines' "$QUARGATE_BLOCK"
PATCH_BLOCK="$TMP/patch-touch.sh";       _extract_block "$PATCH_LANE"    'touch_check'         "$PATCH_BLOCK"
for _pair in "$SPINEGATE_BLOCK:open_spines" "$FAKEGATE_BLOCK:expired_fakes" "$QUARGATE_BLOCK:expired_quarantines" "$PATCH_BLOCK:touch_check"; do
  _bf="${_pair%%:*}"; _bn="${_pair#*:}"
  if [ -s "$_bf" ] && grep -Fq "$_bn" "$_bf"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract '$_bn' - the assertions below are vacuous"
  fi
done

# Step 1's gate. `oss get` is jq -r without -e, so a select matching nothing
# exits 0 - a block testing the rc closes a release with every spine still open.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='$REL'; . '$SPINEGATE_BLOCK'"
t_assert_rc 1 "step 1 halts when a spine is not closed"
t_assert_contains "$T_OUT" "$SP (planned)" "...naming the offender AND its status - planned and active are different problems"
bash "$OSS" spine_status "$SP" closed >/dev/null
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='$REL'; . '$SPINEGATE_BLOCK'"
t_assert_rc 0 "...and passes once every spine is closed (so the refusal above fired for the stated reason)"
t_assert_eq "" "$T_OUT" "...silently. This is also the strict-mode trap: the block's LAST command is the abandoned test, and an '[ -n ] && echo' form would return 1 here and abort a clean close"

# The abandoned arm: not closed, but neither a silent pass nor a hard halt.
SP_AB="$(bash "$OSS" spine_add "$REL" "a spine we gave up on" flesh)"
bash "$OSS" spine_status "$SP_AB" abandoned >/dev/null
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='$REL'; . '$SPINEGATE_BLOCK'"
t_assert_rc 0 "an abandoned spine does NOT hard-halt the release (it never reaches a close, so a refusal would be permanent)"
t_assert_contains "$T_OUT" "contains abandoned spines: $SP_AB" "...but it IS surfaced by name for an explicit confirmation - abandoned is not closed"

# Both blocking gates' branch arms, through the shipped case statements.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='r2'; . '$FAKEGATE_BLOCK'"
t_assert_rc 1 "the shipped fake-gate block HALTS on rc 1 - it does not read rc 1 as 'clean' the way a touch_check-shaped copy would"
t_assert_contains "$T_OUT" "f-renewed-at-r2" "...printing the blocking rows, including the renewed one"
t_assert_contains "$T_OUT" "replace or explicitly renew each" "...and naming the only two unblocks"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$CLEANST" bash -c "set -euo pipefail; rel='r2'; . '$FAKEGATE_BLOCK'"
t_assert_rc 0 "...and proceeds on rc 0"
t_assert_contains "$T_OUT" "fake expiry: clean" "...saying so"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c "set -euo pipefail; rel='r2'; . '$FAKEGATE_BLOCK'"
t_assert_rc 1 "the shipped block HALTS on rc 2 rather than degrading to clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean - halt" "...with the halt naming the reason"

t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='r2'; . '$QUARGATE_BLOCK'"
t_assert_rc 1 "the shipped quarantine block halts on an owed ticket"
t_assert_contains "$T_OUT" "quarantines owed from an earlier release" "...naming the finding"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c "set -euo pipefail; rel='r2'; . '$QUARGATE_BLOCK'"
t_assert_rc 1 "...and halts on rc 2 too"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean - halt" "...distinguishing could-not-check from a real finding"

# The patch lane's mechanical two thirds. rc 0 is a HIT here - the opposite of
# the two gates above - so running the block proves the arms are not copied.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; . '$PATCH_BLOCK' spine.txt"
t_assert_rc 0 "the patch-lane block runs clean over a path on a declared surface"
t_assert_contains "$T_OUT" "it is a spine, not a patch" "...and routes a bone-touching path AWAY from the lane (touch_check rc 0 is a HIT)"
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; . '$PATCH_BLOCK' docs/unrelated.md"
t_assert_contains "$T_OUT" "the mechanical two thirds pass" "...and lets a path on no declared surface through (rc 1 is clean)"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c "set -euo pipefail; . '$PATCH_BLOCK' spine.txt"
t_assert_contains "$T_OUT" "route it as a spine" "...and resolves an INCONCLUSIVE check AGAINST the permissive lane"

# ---------------------------------------------------------------------------
# W1/W2: the two WRONG-BRANCH guards, which had zero executable coverage.
#
# A merge onto the wrong branch succeeds at rc 0. That shape caused three
# separate P0s in this series, and the guards written to stop it were themselves
# untested: deleting either left all 24 test files green. Both blocks are
# EXTRACTED from the shipped prose (never retyped) and run under real
# `set -euo pipefail`, so the subject is the artifact an agent will execute.
# ---------------------------------------------------------------------------
WIC="$SKILLS/close/references/work-item-close.md"
ROUND="$SKILLS/work-item/references/round-orchestration.md"

W_GUARD="$TMP/wi-guard.sh"; _extract_block "$WIC" 'abbrev-ref' "$W_GUARD"
W_CUT="$TMP/spine-cut.sh";  _extract_block "$ROUND" 'checkout -q -b' "$W_CUT"
for _pair in "$W_GUARD:rev-parse --abbrev-ref" "$W_CUT:checkout -q -b"; do
  _bf="${_pair%%:*}"; _bn="${_pair#*:}"
  if [ -s "$_bf" ] && grep -Fq "$_bn" "$_bf"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract '$_bn' - the W1/W2 assertions below are vacuous"
  fi
done

# Both blocks resolve `canonical` via `oss repo_root`, so a caller-injected
# value is overwritten. Shim the resolver verbs to point at the scratch repo
# and delegate everything else to the real dispatcher. $3 doubles as the `oss
# get` return for whichever call site is under test: W1's guard now makes TWO
# `oss get` calls (Task 9, #272/#310 - `.target_repo` first, to resolve the
# item's own repo, then `.branch`), and only the second is $3's job - the
# first must answer "canonical" regardless of $3 so the guard's own
# `oss repo_root "$target_repo"` call lands on the first case arm below,
# exactly as W2's per-repo loop (round-orchestration.md §2) already needs for
# its one `target_repo` value to iterate. A case arm matching on the literal
# substring "target_repo" wins over the generic `"get "*` arm (case tries arms
# in order), so it answers BOTH calls the same way without knowing which test
# is running - and it does not disturb W2, whose own $3 was already
# "canonical" for the exact query this arm now intercepts.
_wshim() { # $1=dir-to-return $2=spine-branch $3=wi-branch-or-repo $4=shim-dir
  mkdir -p "$4"
  { printf '#!/usr/bin/env bash\ncase "$1 $2" in\n'
    printf '  "repo_root canonical") echo %s ;;\n' "$1"
    printf '  "branch_name "*)       echo %s ;;\n' "$2"
    printf '  *"target_repo"*)       echo canonical ;;\n'
    printf '  "get "*)               echo %s ;;\n' "$3"
    printf '  *) exec bash "%s" "$@" ;;\nesac\n' "$OSS"
  } > "$4/oss"; chmod +x "$4/oss"
}

# W1 — the work-item merge guard fires when canonical is parked elsewhere.
W1="$TMP/w1"; mkdir -p "$W1"; git -C "$W1" init -q
git -C "$W1" config user.email t@t; git -C "$W1" config user.name t
echo seed > "$W1/f"; git -C "$W1" add .; git -C "$W1" commit -qm seed
W1_BASE="$(git -C "$W1" rev-parse --abbrev-ref HEAD)"
git -C "$W1" branch "spine/r0.s1-ledger-export"
# A REAL work-item worktree with a REAL staged change, so the block can proceed
# past `git commit` and actually reach the merge. Without this the block dies on
# the placeholder commit and the rc assertion below passes for the wrong reason —
# the merge never runs, so removing the guard changes nothing observable.
W1_WT="$TMP/w1-wt"
git -C "$W1" worktree add -q -b "work/r0.s1.w1-emit" "$W1_WT" "spine/r0.s1-ledger-export"
echo emitted > "$W1_WT/export.txt"; git -C "$W1_WT" add export.txt
t_assert_eq "$W1_BASE" "$(git -C "$W1" rev-parse --abbrev-ref HEAD)" \
  "W1 setup: canonical is parked on the base branch, not the spine branch (the guard's precondition)"
t_assert_contains "$(git -C "$W1_WT" diff --cached --name-only)" "export.txt" \
  "W1 setup: the worktree has a staged change, so the block reaches the merge rather than dying at commit"
_wshim "$W1" "spine/r0.s1-ledger-export" "work/r0.s1.w1-emit" "$TMP/shim-w1"

t_capture env "PATH=$TMP/shim-w1:$PATH" bash -c \
  "set -euo pipefail; wi='r0.s1.w1'; wt='$W1_WT'; spine_id='r0.s1'; spine_slug='ledger-export'; . '$W_GUARD'"
t_assert_rc 1 "W1: the merge block HALTS when canonical is not on the spine branch"
t_assert_contains "$T_OUT" "not 'spine/r0.s1-ledger-export'" "W1: ...naming the branch it expected"
# THE LOAD-BEARING ASSERTION. A merge onto the wrong branch succeeds at rc 0, so
# an rc-only check cannot see it. Assert the base branch tip did not move: with
# the guard deleted the merge lands here and this is what goes red.
t_assert_eq "seed" "$(git -C "$W1" show -s --format=%s "$W1_BASE")" \
  "W1: the base branch tip is UNCHANGED - nothing was merged onto the wrong branch"
t_assert_eq "" "$(git -C "$W1" log --oneline "$W1_BASE" --grep='merge r0.s1.w1' 2>/dev/null)" \
  "W1: ...and no work-item merge commit exists on it"

# W2 — the spine cut must (a) CHECK OUT the branch rather than merely
# creating it, and (b) cut from wherever the repo is CURRENTLY parked
# (HEAD) - NOT from a planned base recorded in the spine plan. `git branch`
# leaves the repo on its previous branch and every downstream step still
# returns rc 0, which is precisely how the spine silently never receives the
# work. Reading the PLANNED base out of SPINE.md instead of HEAD is a known,
# disclosed limitation deferred to #133 - 07a0bd8 reverted an attempt at
# doing that here - and this block deliberately does NOT have that coverage
# (see this file's block-ledger.tsv row for the same disclaimer).
W2="$TMP/w2"; mkdir -p "$W2"; git -C "$W2" init -q
git -C "$W2" config user.email t@t; git -C "$W2" config user.name t
echo seed > "$W2/f"; git -C "$W2" add .; git -C "$W2" commit -qm seed
W2_BASE="$(git -C "$W2" rev-parse --abbrev-ref HEAD)"
# Park canonical on a branch carrying a commit the default branch does not, so
# "cut from HEAD" is observably distinct from "cut from the default branch" and
# the sha assertion below cannot pass by coincidence.
git -C "$W2" checkout -q -b w2-parked
echo parked > "$W2/parked.txt"; git -C "$W2" add parked.txt
git -C "$W2" commit -qm parked
W2_PARKED_SHA="$(git -C "$W2" rev-parse w2-parked)"
# "canonical" is the value the per-repo loop's `oss get ... | .target_repo`
# must yield here - the loop calls `oss repo_root "$repo"` on whatever comes
# back, and only "canonical" resolves through this shim's first case arm.
_wshim "$W2" "spine/r0.s9-demo" "canonical" "$TMP/shim-w2"
# RUN IT WITH NOTHING INJECTED. An earlier revision of this test passed
# `base_branch=...` into the block, which made it blind to the block not
# assigning the variable at all - the lane then halted on every fresh run and
# every assertion here still passed. Under `set -u` a self-sufficient block is
# the thing under test, so supply it nothing.
t_capture env "PATH=$TMP/shim-w2:$PATH" bash -c "set -euo pipefail; . '$W_CUT'"
t_assert_rc 0 "W2: the shipped spine cut runs clean on a clean canonical with NOTHING injected"
t_assert_eq "spine/r0.s9-demo" "$(git -C "$W2" rev-parse --abbrev-ref HEAD)" \
  "W2: ...and leaves canonical CHECKED OUT on the spine branch - 'git branch' alone would leave it on w2-parked"
t_assert_eq "$W2_PARKED_SHA" "$(git -C "$W2" rev-parse spine/r0.s9-demo)" \
  "W2: ...cut from the branch canonical was parked on (v0.2 limitation; issue 133 moves this to SPINE.md)"

# W2b — resuming is NOT supported in this release. An existing spine branch halts
# rather than being re-cut or half-reused: branch reuse alone gets one step
# further and then dies at `worktree_add` rc 8 for every already-spawned item.
t_capture env "PATH=$TMP/shim-w2:$PATH" bash -c "set -euo pipefail; . '$W_CUT'"
t_assert_rc 1 "W2b: a second run HALTS because the spine branch already exists"
t_assert_contains "$T_OUT" "already exists" "W2b: ...naming the collision"
t_assert_contains "$T_OUT" "133" "W2b: ...and pointing at the resume issue"

# W2c — a DETACHED HEAD has no branch name to record, so the lane must halt
# rather than cut a spine whose base_branch would be the literal string "HEAD".
W2C="$TMP/w2c"; mkdir -p "$W2C"; git -C "$W2C" init -q
git -C "$W2C" config user.email t@t; git -C "$W2C" config user.name t
echo seed > "$W2C/f"; git -C "$W2C" add .; git -C "$W2C" commit -qm seed
git -C "$W2C" checkout -q --detach HEAD
_wshim "$W2C" "spine/r0.s9-demo" "canonical" "$TMP/shim-w2c"
t_capture env "PATH=$TMP/shim-w2c:$PATH" bash -c "set -euo pipefail; . '$W_CUT'"
t_assert_rc 1 "W2c: a DETACHED HEAD halts - there is no branch name to record as base_branch"
t_assert_contains "$T_OUT" "DETACHED HEAD" "W2c: ...naming the condition"
t_assert_eq "" "$(git -C "$W2C" branch --list 'spine/*')" \
  "W2c: ...and cut no spine branch on the way out"

# ---------------------------------------------------------------------------
# D1-D4: the cumulative-demo MEASUREMENT block. Timing is advisory; the demo
# result is the gate. Written as a bare `oss demo_run` with the budget report
# after it, the block's status becomes the trailing echo's — so a FAILING demo
# returns 0 and the close walks past the one gate it must not. Same shape as the
# W1/W2 wrong-branch class: the failure is invisible to an rc-only reading, so
# these assert the re-raised status, not just that the block ran.
# ---------------------------------------------------------------------------
CUMDEMO="$SKILLS/close/references/cumulative-demo.md"
# Anchor on `elapsed=`, not on `demo_rc`: the anchor has to survive the very
# regression these tests exist to catch, or removing the status capture would
# make the block unfindable and the failure would read as "vacuous" instead of
# as the wrong behaviour it is.
DEMO_BLOCK="$TMP/cum-demo.sh"; _extract_block "$CUMDEMO" 'elapsed=' "$DEMO_BLOCK"
if [ -s "$DEMO_BLOCK" ] && grep -Fq 'oss demo_run' "$DEMO_BLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the demo measurement block - D1-D4 are vacuous"
fi

_dshim() { # $1=budget-to-echo $2=demo_run-rc $3=shim-dir
  mkdir -p "$3"
  { printf '#!/usr/bin/env bash\ncase "$1" in\n'
    printf '  get)      echo %s ;;\n' "$1"
    printf '  demo_run) exit %s ;;\n' "$2"
    printf '  *) exec bash "%s" "$@" ;;\nesac\n' "$OSS"
  } > "$3/oss"; chmod +x "$3/oss"
}

_dshim '60s' 0 "$TMP/shim-d0"
t_capture env "PATH=$TMP/shim-d0:$PATH" bash -c ". '$DEMO_BLOCK'"
t_assert_rc 0 "D1: a PASSING cumulative demo leaves the measurement block green"
t_assert_contains "$T_OUT" "within the 60s budget" "D1: ...and reports the timing"

# THE LOAD-BEARING ASSERTION. Drop the `|| demo_rc=$?` capture and the re-raise
# and this is the one that goes red - D1 stays green either way.
_dshim '60s' 1 "$TMP/shim-d1"
t_capture env "PATH=$TMP/shim-d1:$PATH" bash -c ". '$DEMO_BLOCK'"
t_assert_rc 1 "D2: a FAILING cumulative demo RE-RAISES its status - the close gate does not pass"
t_assert_contains "$T_OUT" "within the 60s budget" "D2: ...after the timing was still reported"
t_assert_contains "$T_OUT" "FAILED rc 1" "D2: ...naming the failure"

# D3 - the runner's exact status survives rather than being flattened to 1, and
# the no-budget branch does not mask it.
_dshim 'null' 3 "$TMP/shim-d3"
t_capture env "PATH=$TMP/shim-d3:$PATH" bash -c ". '$DEMO_BLOCK'"
t_assert_rc 3 "D3: the runner's exact status survives an absent budget"
t_assert_contains "$T_OUT" "no budget recorded" "D3: ...with the no-budget branch still taken"

# D4 - the capture must also survive `errexit`, where an unprotected `oss
# demo_run` would abort the block before the timing is ever reported.
_dshim '60s' 1 "$TMP/shim-d4"
t_capture env "PATH=$TMP/shim-d4:$PATH" bash -c "set -euo pipefail; . '$DEMO_BLOCK'"
t_assert_rc 1 "D4: the same failing demo re-raises under errexit"
t_assert_contains "$T_OUT" "within the 60s budget" "D4: ...and the timing is still reported first"

cd /; rm -rf "$TMP"

# A FLOOR ON THE ASSERTION COUNT. Every check in test-block-ledger.sh proves
# this file EXTRACTS and SOURCES each covered block; none of them can see the
# behavioural assertions around that being deleted, and a file whose assertions
# are gone reports pass=0 fail=0 and exits 0. The floor is what makes wholesale
# removal loud. Raise it when the file grows; never lower it to make a run go
# green. (Codex P2 round 3 on PR #144.)
if [ "$T_PASS" -lt 180 ]; then
  echo "FAIL: test-close.sh ran only $T_PASS assertions (floor 180) - assertions were removed, not just skipped"
  T_FAIL=$((T_FAIL+1))
fi
t_summary
