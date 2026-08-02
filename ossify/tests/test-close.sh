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

# Every references/*.md under close/ must be pointed at from close/SKILL.md
# itself - a pointer from a sibling reference does not make it reachable. This
# defect has shipped twice on this branch.
for ref in "$SKILLS/close/references"/*.md; do
  if grep -Fq "references/$(basename "$ref")" "$SKILLS/close/SKILL.md"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: close/SKILL.md does not point at references/$(basename "$ref")"
  fi
done

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
awk '/^```bash$/{inb=1;buf="";next}
     /^```$/{if(inb && buf ~ /while IFS=/){printf "%s", buf; exit} inb=0; next}
     inb{buf = buf $0 "\n"}' "$SKILLS/close/references/impl-check.md" > "$BLOCK"
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

cd /; rm -rf "$TMP"
t_summary
