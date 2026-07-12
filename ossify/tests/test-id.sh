#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"

t_capture oss_id_parse r1;        t_assert_rc 0 "r1 parses";        t_assert_eq "release 1" "$T_OUT" "release parse"
t_capture oss_id_parse r1.s3;     t_assert_rc 0 "r1.s3 parses";     t_assert_eq "spine 1 3" "$T_OUT" "spine parse"
t_capture oss_id_parse r1.s3.w2;  t_assert_rc 0 "work item parses"; t_assert_eq "work_item 1 3 2" "$T_OUT" "wi parse"
t_capture oss_id_parse VS-1.1.1;  t_assert_rc 1 "old-stack VS- id rejected"
t_capture oss_id_parse r1.w2;     t_assert_rc 1 "malformed id rejected"

t_capture oss_id_branch_name r0.s1 walking-skeleton
t_assert_eq "spine/r0.s1-walking-skeleton" "$T_OUT" "branch name"
t_capture oss_id_release_dir r2
t_assert_eq "docs/specs/r2" "$T_OUT" "release dir"

TMP="$(mktemp -d)"
cat > "$TMP/state.json" <<'EOF'
{"releases":[{"id":"r0"},{"id":"r1"}],"spines":[{"id":"r1.s1"},{"id":"r1.s2"}],"work_items":[{"id":"r1.s2.w1"}]}
EOF
t_capture oss_id_next_release "$TMP/state.json";          t_assert_eq "r2" "$T_OUT" "next release"
t_capture oss_id_next_spine "$TMP/state.json" r1;         t_assert_eq "r1.s3" "$T_OUT" "next spine"
t_capture oss_id_next_work_item "$TMP/state.json" r1.s2;  t_assert_eq "r1.s2.w2" "$T_OUT" "next work item"
rm -rf "$TMP"
t_summary
