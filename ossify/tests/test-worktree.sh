#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor worktree; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
git -C "$TMP/canon" init -q
git -C "$TMP/canon" config user.email t@t; git -C "$TMP/canon" config user.name t
echo seed > "$TMP/canon/f.txt"
# A TRACKED .gitignore, because that is the realistic case and it is what makes
# the "does not touch the project's own file" assertion below able to fail.
printf 'node_modules/\n' > "$TMP/canon/.gitignore"
git -C "$TMP/canon" add .; git -C "$TMP/canon" commit -qm seed
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP/ws"

t_capture _oss_repo_root canonical
t_assert_eq "$TMP/canon" "$T_OUT" "canonical repo root resolves"
t_capture _oss_repo_root private_core
t_assert_rc 2 "an unconfigured repo key is rc 2, never a silent canonical default"
t_capture _oss_repo_root nonsense
t_assert_rc 2 "an unknown repo key is rc 2"

# spawn
t_capture oss_worktree_add canonical r0.s1.w1 "add-ticket" "HEAD"
t_assert_rc 0 "worktree_add ok"
WT="$T_OUT"
[ -d "$WT" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir not created"; }
t_assert_eq "$TMP/canon/.worktrees/r0.s1.w1" "$WT" "worktree path convention"
t_assert_eq "work/r0.s1.w1-add-ticket" "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" "work-item branch checked out"

# The worktree root lives inside the repo, so spawning must not leave the repo
# reporting itself dirty. Assert the OUTCOME - a fully empty status - not merely
# that an ignore line was written: a line in the wrong file or with the wrong
# pattern still passes a grep and still leaves `?? .worktrees/` behind. The
# seeded .gitignore below is TRACKED, which is what makes this assertion
# meaningful: an implementation that appends to it instead of to
# .git/info/exclude leaves ` M .gitignore` and fails right here.
t_assert_eq "" "$(git -C "$TMP/canon" status --porcelain)" "spawning leaves the repo status completely clean"
t_assert_eq "node_modules/" "$(cat "$TMP/canon/.gitignore")" "spawning does not touch the .gitignore the PROJECT owns"
t_capture oss_worktree_add canonical r0.s1.w1 "add-ticket" "HEAD"
t_assert_rc 8 "spawning onto an existing worktree path is refused rc 8"
# Idempotent: repeated spawns must not append a duplicate ignore entry.
t_assert_eq "1" "$(grep -cxF '.worktrees/' "$TMP/canon/.git/info/exclude")" "the ignore entry is written exactly once"

# resolve + list
t_capture oss_worktree_resolve canonical r0.s1.w1
t_assert_eq "$WT" "$T_OUT" "worktree_resolve finds it"
t_capture oss_worktree_resolve canonical r0.s1.w9
t_assert_rc 1 "resolve on an unknown work item is rc 1"
t_capture oss_worktree_list canonical
t_assert_contains "$T_OUT" "r0.s1.w1" "worktree_list names it"

# Named risk #7: oss_worktree_add's stdout IS its return value (the abs path).
# A chatty git hook (post-checkout fires on `worktree add`) must never corrupt
# it. Verified empirically: git routes a hook's own stdout onto git's stderr,
# so isolating git's stderr (no `2>&1` inside oss_worktree_add) is what keeps
# this clean - this asserts that behavior directly, on real stdout/stderr fds,
# not through t_capture (which deliberately merges both for test visibility).
mkdir -p "$TMP/canon/.git/hooks"
cat > "$TMP/canon/.git/hooks/post-checkout" <<'HOOK'
#!/bin/sh
echo "hook chatter on stdout"
HOOK
chmod +x "$TMP/canon/.git/hooks/post-checkout"
_hook_stderr="$TMP/hook-stderr.log"
_hook_out="$(oss_worktree_add canonical r0.s1.w2 "hook-check" "HEAD" 2>"$_hook_stderr")"
_hook_rc=$?
rm -f "$TMP/canon/.git/hooks/post-checkout"
if [ "$_hook_rc" -eq 0 ] && [ "$_hook_out" = "$TMP/canon/.worktrees/r0.s1.w2" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: a chatty post-checkout hook corrupted worktree_add's stdout (got '$_hook_out', rc=$_hook_rc)"
fi
oss_worktree_remove canonical r0.s1.w2 >/dev/null 2>&1 || true

# D9: a DIRTY worktree must halt, never be force-discarded.
#
# Measured on git 2.52.0: `git worktree remove` (never called here with
# --force) ALSO refuses on any dirty state on its own, so if the explicit
# `[ -n "$dirty" ]` guard above is neutered, this rc and the file-survival
# assertion below stay green regardless - git's own default is the actual
# backstop against data loss. The one assertion that is genuinely sensitive to
# OUR guard is the next one: without it, the message reverts to git's generic
# "worktree remove failed" text and loses the word "uncommitted". That is real
# coverage (a neutered guard is observably worse - it no longer tells the user
# why, and its generic git fallback text mentions --force, which D9 exists to
# keep users away from) even though it is not a data-loss signal.
echo scratch > "$WT/uncommitted.txt"
t_capture oss_worktree_remove canonical r0.s1.w1
t_assert_rc 8 "removing a dirty worktree is refused rc 8"
t_assert_contains "$T_OUT" "uncommitted" "the refusal names the reason"
[ -f "$WT/uncommitted.txt" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: remove DISCARDED uncommitted work"; }

# D9, the half a "no new commits" case can't prove: `-d` and `-D` only differ
# on an UNMERGED branch. Spawn a second work item, commit inside its worktree
# (clean working tree, but the branch now carries a commit the spine lacks),
# then remove: the worktree comes out clean, so `git worktree remove` succeeds
# - but the branch must survive, because it is unmerged. `-d` refuses and
# halts; only a mutation to `-D` would silently destroy the commit. This is
# also the two-work-items-in-one-spine case from named risk #4.
t_capture oss_worktree_add canonical r0.s1.w3 "second-ticket" "HEAD"
t_assert_rc 0 "second worktree_add ok"
WT2="$T_OUT"
echo work > "$WT2/newfile.txt"
git -C "$WT2" add newfile.txt
git -C "$WT2" commit -qm "unmerged work" >/dev/null
t_capture oss_worktree_remove canonical r0.s1.w3
t_assert_rc 8 "removing a worktree with an unmerged branch is refused rc 8"
t_assert_contains "$T_OUT" "not merged" "the refusal names the unmerged branch"
[ -d "$WT2" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir survived an unmerged-branch removal"; } || T_PASS=$((T_PASS+1))
if git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s1.w3-second-ticket; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: unmerged work-item branch was destroyed"
fi

# clean removal takes the branch with it (the close ceremony asserts no work-* branch remains).
rm "$WT/uncommitted.txt"
t_capture oss_worktree_remove canonical r0.s1.w1
t_assert_rc 0 "clean worktree removes"
[ -d "$WT" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir survived removal"; } || T_PASS=$((T_PASS+1))
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s1.w1-add-ticket \
  && { T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item branch survived removal"; } || T_PASS=$((T_PASS+1))

# Dispatcher-path coverage. bin/oss runs `set -euo pipefail`; everything above
# this line only sourced the libs (no `set -e`), so a strict-mode-only fault
# in worktree.sh would be structurally invisible to it.
t_capture "$OSS" repo_root canonical
t_assert_eq "$TMP/canon" "$T_OUT" "dispatcher: repo_root canonical"
t_capture "$OSS" repo_root private_core
t_assert_rc 2 "dispatcher: unconfigured repo key is rc 2"
t_capture "$OSS" worktree_add canonical r0.s2.w1 "dispatch-ticket" "HEAD"
t_assert_rc 0 "dispatcher: worktree_add ok"
WT3="$T_OUT"
t_assert_eq "$TMP/canon/.worktrees/r0.s2.w1" "$WT3" "dispatcher: worktree path convention"
t_capture "$OSS" worktree_resolve canonical r0.s2.w1
t_assert_eq "$WT3" "$T_OUT" "dispatcher: worktree_resolve finds it"
t_capture "$OSS" worktree_list canonical
t_assert_contains "$T_OUT" "r0.s2.w1" "dispatcher: worktree_list names it"
t_capture "$OSS" worktree_remove canonical r0.s2.w1
t_assert_rc 0 "dispatcher: clean worktree removes"
[ -d "$WT3" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: dispatcher worktree dir survived removal"; } || T_PASS=$((T_PASS+1))

# ---------------------------------------------------------------------------
# The spine-branch lifecycle the execution lane owns: cut AND CHECK OUT the
# spine integration branch, spawn each work item off it, merge each back into
# it. `git branch` without the checkout leaves canonical on its previous
# branch, and then EVERY consequence is rc 0 - the work-item merge lands on the
# wrong branch, spine close's merge is "Already up to date", and the cumulative
# demo measures a tree assembled by accident. So every assertion below is on a
# concrete sha or a reachability fact; the rc is never the evidence.
# ---------------------------------------------------------------------------
BASE_BRANCH="$(git -C "$TMP/canon" rev-parse --abbrev-ref HEAD)"
SPINE_BRANCH="$(oss_id_branch_name r0.s3 "round-lane")"
t_assert_eq "spine/r0.s3-round-lane" "$SPINE_BRANCH" "the spine branch name comes from the id grammar"
git -C "$TMP/canon" checkout -q -b "$SPINE_BRANCH"

# A commit that exists ONLY on the spine branch, made BEFORE any worktree is
# spawned. Without it the spine tip and the base-branch tip are the same commit,
# and every reachability assertion below is vacuously true whichever branch the
# worktree was actually cut from - the fixture would never trip the precondition
# the guard exists for.
echo spine-only > "$TMP/canon/spine.txt"
git -C "$TMP/canon" add spine.txt
git -C "$TMP/canon" commit -qm "spine-only commit"
SPINE_TIP="$(git -C "$TMP/canon" rev-parse HEAD)"
BASE_TIP="$(git -C "$TMP/canon" rev-parse "$BASE_BRANCH")"
if [ "$SPINE_TIP" != "$BASE_TIP" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: fixture is vacuous - the spine tip and $BASE_BRANCH are the same commit"
fi

t_capture oss_worktree_add canonical r0.s3.w1 "first-item" "$SPINE_BRANCH"
t_assert_rc 0 "round-1 item 1 spawns off the spine branch"
WA="$T_OUT"
t_capture "$OSS" worktree_add canonical r0.s3.w2 "second-item" "$SPINE_BRANCH"
t_assert_rc 0 "dispatcher: round-1 item 2 spawns off the spine branch (non-HEAD base under set -euo pipefail)"
WB="$T_OUT"

# Two work items in ONE spine: distinct branches, distinct worktrees.
t_assert_eq "work/r0.s3.w1-first-item" "$(git -C "$WA" rev-parse --abbrev-ref HEAD)" "work item 1 gets its own branch"
t_assert_eq "work/r0.s3.w2-second-item" "$(git -C "$WB" rev-parse --abbrev-ref HEAD)" "work item 2 gets its own branch"
if [ "$WA" != "$WB" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: two work items in one spine share a worktree path"
fi

# Spawned off the SPINE branch, not off the base branch - asserted on the sha
# recorded before the spawn, not re-derived from what the spawn wrote.
t_assert_eq "$SPINE_TIP" "$(git -C "$WA" rev-parse HEAD)" "work item 1's worktree starts at the spine tip, not at $BASE_BRANCH"
t_assert_eq "$SPINE_TIP" "$(git -C "$WB" rev-parse HEAD)" "work item 2's worktree starts at the spine tip too"
t_assert_eq "$SPINE_TIP" "$(git -C "$TMP/canon" merge-base "$SPINE_BRANCH" work/r0.s3.w1-first-item)" "the spine branch is the work-item branch's merge base"

# Unit-level pin on the 4th argument. NOT a lifecycle path - the lane never
# spawns a work item off the base branch. It exists because during the real
# lifecycle canonical's HEAD *is* the spine branch, so an implementation that
# ignored `base` and used HEAD would satisfy every assertion above.
t_capture oss_worktree_add canonical r0.s3.w9 "base-ref-pin" "$BASE_BRANCH"
t_assert_rc 0 "worktree_add accepts an explicit non-HEAD base"
WP="$T_OUT"
t_assert_eq "$BASE_TIP" "$(git -C "$WP" rev-parse HEAD)" "the base-ref argument decides the start point, not canonical's HEAD"

# The merge back, with canonical still parked on the spine branch.
echo w1 > "$WA/w1.txt"
git -C "$WA" add w1.txt
git -C "$WA" commit -qm "work item 1"
W1_SHA="$(git -C "$WA" rev-parse HEAD)"
t_assert_eq "$SPINE_BRANCH" "$(git -C "$TMP/canon" rev-parse --abbrev-ref HEAD)" "canonical is still parked on the spine branch when the merge runs"
t_capture git -C "$TMP/canon" merge --no-ff -m "merge r0.s3.w1" work/r0.s3.w1-first-item
t_assert_rc 0 "the work-item branch merges into the checked-out spine branch"
if git -C "$TMP/canon" merge-base --is-ancestor "$W1_SHA" "$SPINE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the work-item commit is NOT reachable from the spine branch after the merge"
fi
t_assert_eq "w1" "$(cat "$TMP/canon/w1.txt" 2>/dev/null)" "the merged work is present in canonical's tree on the spine branch"

# NEGATIVE CONTROL - this is what the checkout buys, stated as an outcome.
# Park canonical back on the base branch (the pre-correction state, where
# nothing ever checked the spine branch out) and merge the second work item.
# The merge still succeeds; the spine branch still never receives the work.
git -C "$TMP/canon" checkout -q "$BASE_BRANCH"
echo w2 > "$WB/w2.txt"
git -C "$WB" add w2.txt
git -C "$WB" commit -qm "work item 2"
W2_SHA="$(git -C "$WB" rev-parse HEAD)"
t_capture git -C "$TMP/canon" merge --no-ff -m "merge r0.s3.w2" work/r0.s3.w2-second-item
t_assert_rc 0 "merging while parked on $BASE_BRANCH ALSO returns rc 0 - which is why an rc-0 assertion proves nothing"
if git -C "$TMP/canon" merge-base --is-ancestor "$W2_SHA" "$SPINE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: negative control is vacuous - the commit reached the spine branch without the checkout"
else
  T_PASS=$((T_PASS+1))
fi
if git -C "$TMP/canon" merge-base --is-ancestor "$W2_SHA" "$BASE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: negative control did not land the commit on $BASE_BRANCH either"
fi

cd /; rm -rf "$TMP"
t_summary
