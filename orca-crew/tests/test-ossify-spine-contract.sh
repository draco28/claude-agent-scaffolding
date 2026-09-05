#!/usr/bin/env bash
#
# orca-crew — the ossify spine execution seam, mechanical facts only.
#
# The three-layer model is judgment: when the phase activates, who owns what,
# how a plan relay is scored, what happens at depth exceeded. NONE of that is
# asserted here — pinning judgment as dozens of exact prose clauses turns a
# fidelity guard into a prose-freeze that fails on every rewording, which is the
# failure mode `test-fidelity-pins.sh`'s own header exists to prevent. Those
# belong to the semantic rubric.
#
# What IS mechanical, and is asserted:
#
#   - the sidecar's SCHEMA: its version string, its header key set, its three
#     fixed-procedure keys, and its assignment table's column set — each by set
#     equality, so a missing column and an added one are equally red
#   - the reviewer's ABSENCE from that schema (the sidecar is not where the
#     reviewer is chosen), scoped to the template block so prose about reviewer
#     timing cannot satisfy or break it
#   - zero subagent-invocation forms in the activated path's own references
#   - the exact command the spine session is briefed to run
#   - the four parent identities its brief must carry
#   - the line budget these references are held to
#
# Counting is one awk index() pass: `grep -c` counts LINES, and `… | grep -q`
# can fail on a true match under pipefail. Every zero-count has a non-empty
# control beside it.
#
# Usage:   bash orca-crew/tests/test-ossify-spine-contract.sh
# Exit:    0 if every mechanical fact holds; 1 otherwise.
# Deps:    bash 3.2+, awk.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/orchestrate/references"
EXEC_MD="$REF/ossify-execution.md"
BRIEFS_MD="$REF/ossify-briefs.md"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

REF_BUDGET=200          # A3: each new Orca reference stays under about 200 lines

occurrences() {
  if [ -z "${2:-}" ]; then printf 'empty needle\n' >&2; return 1; fi
  [ -f "$1" ] || { printf 'no such file\n' >&2; return 1; }
  awk -v needle="$2" '
    { line = $0
      while ((i = index(line, needle)) > 0) { n++; line = substr(line, i + length(needle)) } }
    END { print n+0 }' "$1"
}

pin() {
  c="$(occurrences "$1" "$2")" || { fail "$3" "unreadable file or empty needle: $1"; return 0; }
  if [ "$c" -eq 1 ]; then pass "$3"
  elif [ "$c" -eq 0 ]; then fail "$3" "not found in ${1##*/} — reworded away, or the pin now spans a line wrap. pin: $2"
  else fail "$3" "found $c times in ${1##*/}; a pin must be unique. pin: $2"
  fi
}

absent() {
  c="$(occurrences "$1" "$2")" || { fail "$3" "unreadable file: $1"; return 0; }
  if [ "$c" -eq 0 ]; then pass "$3"
  else fail "$3" "'$2' occurs $c time(s) in ${1##*/}"; fi
}

nonempty() {
  if [ -s "$1" ]; then pass "$2"
  else fail "$2" "$1 is missing or empty — every zero-count against it would be vacuous"; fi
}

budget() {
  if [ ! -f "$1" ]; then fail "$2" "no such file: $1"; return 0; fi
  n="$(wc -l < "$1" | tr -d ' ')"
  if [ "$n" -le "$REF_BUDGET" ]; then pass "$2 ($n lines)"
  else fail "$2" "$n lines, over the $REF_BUDGET-line reference budget by $((n - REF_BUDGET))"; fi
}

# keys <file> <from-literal> <to-literal-or-empty> -> sorted `key:` names of
# zero-indent `key: value` lines in that span. An empty <to> runs to the first
# line starting with '## ' after the span opened.
keys() {
  awk -v from="$2" -v to="$3" '
    !seen && index($0, from) > 0 { seen = 1; next }
    seen && to != "" && index($0, to) > 0 { exit }
    seen && to == "" && /^## / { exit }
    seen && /^```[[:space:]]*$/ { exit }
    seen && /^[a-z_]+:/ { k = $0; sub(/:.*$/, "", k); print k }
  ' "$1" | LC_ALL=C sort
}

assert_set() { # <observed> <expected space-separated> <label>
  want="$(printf '%s\n' $2 | LC_ALL=C sort)"
  if [ "$1" = "$want" ]; then pass "$3"
  else
    fail "$3" "expected [$(printf '%s' "$want" | tr '\n' ' ')] — observed [$(printf '%s' "$1" | tr '\n' ' ')]"
  fi
}

printf '%sorca-crew — ossify spine execution seam (mechanical)%s\n\n' "$DIM" "$RST"

section "the sidecar schema"

nonempty "$EXEC_MD" "references/ossify-execution.md exists"

pin "$EXEC_MD" 'schema: orca-execution/v1' \
  "the sidecar declares its schema version exactly once"

assert_set "$(keys "$EXEC_MD" '# Orca execution assignments' '')" \
  "schema spine_id spine_plan spine_plan_oid ratification ratified_in_run" \
  "the sidecar header carries exactly its six identity fields"

assert_set "$(keys "$EXEC_MD" '## Fixed procedures' '')" \
  "implementation_plan_gate implementer_entrypoint verifier_procedure" \
  "the fixed-procedure block carries exactly its three keys"

pin "$EXEC_MD" 'implementation_plan_gate: worker-authored/top-orchestrator-approved' \
  "the plan gate's value is byte-exact"
pin "$EXEC_MD" 'implementer_entrypoint: /ossify:work-item $HANDOFF_PATH' \
  "the implementer entry point's value is byte-exact"
pin "$EXEC_MD" 'verifier_procedure: all-claims-work-item-verify/v1' \
  "the verifier procedure's value is byte-exact"

# The assignment table's columns, by set equality: an added reviewer_* or
# spine_* column is as red as a dropped implementer_effort.
hdr="$(awk '/^\| work_item_id \|/ { print; exit }' "$EXEC_MD")"
if [ -n "$hdr" ]; then
  cols="$(printf '%s\n' "$hdr" | tr '|' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | LC_ALL=C sort)"
  assert_set "$cols" \
    "work_item_id implementer_terminal_command implementer_expected_model implementer_effort verifier_terminal_command verifier_expected_model verifier_effort" \
    "the assignment table carries exactly its seven columns"
else
  fail "the assignment table carries exactly its seven columns" "no '| work_item_id |' header row in ossify-execution.md"
fi

section "the reviewer is not in the sidecar"

# Scoped to the template block, so prose stating WHEN the reviewer is chosen
# neither satisfies nor breaks this. Extract it, then assert on the extract.
tmpl="$(mktemp)"
awk '!seen && index($0, "# Orca execution assignments") > 0 { seen = 1 }
     seen { print }
     seen && /^```[[:space:]]*$/ && printed { exit }
     seen { printed = 1 }' "$EXEC_MD" > "$tmpl"
nonempty "$tmpl" "the sidecar template block extracts (control for the counts below)"
for k in 'reviewer_' 'code_review' 'spine_terminal_command' 'spine_expected_model'; do
  absent "$tmpl" "$k" "the sidecar schema carries no '$k' field"
done
rm -f "$tmpl"

section "no subagent invocation in the activated path"

nonempty "$BRIEFS_MD" "references/ossify-briefs.md exists"
for f in "$EXEC_MD" "$BRIEFS_MD"; do
  for form in 'Task(' 'Agent(' 'subagent_type'; do
    absent "$f" "$form" "${f##*/} invokes no subagent ('$form')"
  done
done

section "the spine session's briefed command and identities"

pin "$BRIEFS_MD" '/ossify:run-spine $SPINE_ID --external-executor' \
  "the spine-session brief names the external command shape exactly once"
# SPINE_ID is in this list because the brief's TASK spends it — `/ossify:run-spine
# $SPINE_ID --external-executor` — and a brief that spends a name it never injects
# leaves the worker to rediscover it, which is the one thing the block forbids.
# `SPINE_ID=` is not a substring of `SPINE_TASK_ID=` or `SPINE_DISPATCH_ID=`, so the
# exactly-once count is unambiguous.
for id in PARENT_RUN_ID SPINE_TASK_ID SPINE_DISPATCH_ID SPINE_ID ORCA_EXECUTION_PATH; do
  pin "$BRIEFS_MD" "$id=" "the brief injects $id exactly once"
done

section "reference line budgets"

budget "$EXEC_MD" "ossify-execution.md is within the reference budget"
budget "$BRIEFS_MD" "ossify-briefs.md is within the reference budget"

report
