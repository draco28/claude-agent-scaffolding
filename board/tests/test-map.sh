#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
MAP="$HERE/../lib/map.jq"; F="$HERE/fixtures/state"
m() { jq -f "$MAP" "$1" | jq -r "$2"; }

t_capture m "$F/empty.json" '.milestones|length';   t_assert_eq 0 "$T_OUT" "empty: no milestones"
t_capture m "$F/empty.json" '.issues|length';       t_assert_eq 0 "$T_OUT" "empty: no issues"

t_capture m "$F/pulse-trader.json" '.milestones|length'; t_assert_eq 2 "$T_OUT" "pt: 2 milestones"
t_capture m "$F/pulse-trader.json" '[.issues[]|select(.task_type=="Spine")]|length';     t_assert_eq 5 "$T_OUT" "pt: 5 spines"
t_capture m "$F/pulse-trader.json" '[.issues[]|select(.task_type=="Work item")]|length'; t_assert_eq 8 "$T_OUT" "pt: 8 work items"
t_capture m "$F/pulse-trader.json" '.milestones[0].title';  t_assert_eq "r0 — Release 0" "$T_OUT" "milestone title uses em dash"
t_capture m "$F/pulse-trader.json" '.milestones[0].status'; t_assert_eq "completed" "$T_OUT" "closed release -> completed milestone"
t_capture m "$F/pulse-trader.json" '.issues[]|select(.key=="r1.s1.w1")|.parent_key'; t_assert_eq "r1.s1" "$T_OUT" "work item parent"
t_capture m "$F/pulse-trader.json" '.issues[]|select(.key=="r1.s1.w1")|.status';     t_assert_eq "complete" "$T_OUT" "complete stays complete"
t_capture m "$F/pulse-trader.json" '.issues[]|select(.key=="r1.s1")|.milestone_key'; t_assert_eq "r1" "$T_OUT" "spine carries its release"
t_capture m "$F/pulse-trader.json" '.issues[]|select(.key=="r1.s1")|.label';         t_assert_eq "spine:bone" "$T_OUT" "spine label from class"
t_capture m "$F/pulse-trader.json" '([.issues[].task_type]|index("Work item")) > ([.issues[].task_type]|rindex("Spine"))'; t_assert_eq "true" "$T_OUT" "spines precede work items"

t_capture m "$F/dag.json" '.relations|length';            t_assert_eq 3 "$T_OUT" "dag: 3 edges"
t_capture m "$F/dag.json" '.relations[2]|"\(.from_key)>\(.to_key)"'; t_assert_eq "r1.s3>r1.s2" "$T_OUT" "dag: edge order preserved"
t_capture m "$F/dag.json" '.issues[]|select(.key=="r1.s2.w1")|.status'; t_assert_eq "complete" "$T_OUT" "closed item -> complete"
t_capture m "$F/dag.json" '.milestones[0].status';          t_assert_eq "in-progress" "$T_OUT" "active release -> in-progress"
t_capture m "$F/dag.json" '.milestones[0].target_ms';       t_assert_eq "1787220000000" "$T_OUT" "target_ms from created_at (2026-08-20T10:00:00Z)"
t_capture m "$F/dag.json" '.issues[]|select(.key=="r1.s2.w1")|.description'; t_assert_contains "$T_OUT" "spine/r1.s2/w1" "item description carries branch"
t_capture m "$F/dag.json" '.milestones[0].description | contains("goal: g\n\nexit criteria:")'; t_assert_eq "true" "$T_OUT" "milestone description keeps the blank line before exit criteria"

# known-answer negative: flip one status, exactly that entity changes
jq '.spines[1].status="abandoned"' "$F/dag.json" > /tmp/dag-mut.json
t_capture m /tmp/dag-mut.json '.issues[]|select(.key=="r1.s2")|.status'; t_assert_eq "abandoned" "$T_OUT" "mutation: s2 abandoned"
t_capture m /tmp/dag-mut.json '.issues[]|select(.key=="r1.s1")|.status'; t_assert_eq "complete"  "$T_OUT" "mutation: s1 untouched"
t_summary
