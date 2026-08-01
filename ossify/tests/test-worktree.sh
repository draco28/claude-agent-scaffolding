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

cd /; rm -rf "$TMP"
t_summary
