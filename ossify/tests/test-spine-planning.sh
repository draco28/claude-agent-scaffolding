#!/usr/bin/env bash
# Spine-planning shell-out contract (Plan B task 8).
#
# Every assertion here guards a claim plan-spine's PROSE makes about the `oss`
# surface it shells out to. Driven through the REAL dispatcher binary (which
# runs `set -euo pipefail`) rather than by sourcing, because the skill body
# calls `oss <subcommand>` and a sourced-only test never exercises strict mode,
# arg passthrough, or rc propagation.
#
# Prose anchors:
#   SKILL.md §4a/§4c, §8d, §8e, §9   and   references/{demo-authoring,
#   demo-amendments,fake-ledger-discipline,cross-repo,decomposition}.md
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; export OSS_STATE_FILE="$TMP/state.json"

"$OSS" init spine-planning-demo >/dev/null
"$OSS" release_add "MVP" "a trader can place a paper trade" >/dev/null
"$OSS" spine_add r0 "order ticket" flesh >/dev/null

# --- §3 pre-flight: `oss get` is `jq -r` WITHOUT `-e`, so a `select` that matches
# nothing exits 0 with EMPTY output. The skill body resolves the target spine by
# testing the output, not the rc, precisely because of this - an `oss get … || …`
# guard would never fire and the skill would plan against a typo'd spine id.
# If `oss get` ever grows `-e`, this test is what says the prose may be relaxed.
t_capture "$OSS" get '.spines[] | select(.id == "r0.s1") | .class'
t_assert_rc 0 "get on an existing spine is rc 0"
t_assert_eq "flesh" "$T_OUT" "get reads the class plan-release recorded"
t_capture "$OSS" get '.spines[] | select(.id == "r9.s9") | .class'
t_assert_rc 0 "get on a MISSING spine is still rc 0 (no -e)"
t_assert_eq "" "$T_OUT" "...and the miss shows up only as empty output"
t_capture "$OSS" get '.spines[] | select(.id == "r0.s1") | .release'
t_assert_eq "r0" "$T_OUT" "get resolves the spine's release for the ledger-budget read"

# --- §4a / cross-repo.md §1: work items carry exactly one target_repo, default
# canonical, explicit override honored - through the real binary.
t_capture "$OSS" work_item_add r0.s1 "order-ticket form"
t_assert_eq "r0.s1.w1" "$T_OUT" "dispatcher: work_item_add mints r0.s1.w1"
t_capture "$OSS" get '.work_items[0].target_repo'
t_assert_eq "canonical" "$T_OUT" "dispatcher: target_repo defaults to canonical"
t_capture "$OSS" work_item_add r0.s1 "paper-fill adapter" private_core
t_assert_eq "r0.s1.w2" "$T_OUT" "dispatcher: second work item minted"
t_capture "$OSS" get '.work_items[1].target_repo'
t_assert_eq "private_core" "$T_OUT" "dispatcher: explicit target_repo stored"

# §4a: an unknown spine id is rc 7 and writes nothing (the body tells the skill
# to resolve the spine at pre-flight instead of minting against a typo).
t_capture "$OSS" get '.work_items | length'; WI_BEFORE="$T_OUT"
t_capture "$OSS" work_item_add r9.s9 "ghost"
t_assert_rc 7 "dispatcher: work_item_add against unknown spine is rc 7"
t_capture "$OSS" get '.work_items | length'
t_assert_eq "$WI_BEFORE" "$T_OUT" "no phantom work item after unknown-spine rejection"

# --- §8d / demo-authoring.md §6: auto: lines bind command + expected, and the
# expected grammar is exactly exit:<n> | contains:<str>.
t_capture "$OSS" ledger_add_auto r0.s1 "paper order round-trips" "true" "exit:0"
t_assert_rc 0 "dispatcher: auto line with exit: expected accepted"
AUTO1="$T_OUT"
t_capture "$OSS" ledger_add_auto r0.s1 "bench reports p50" "true" "contains:p50"
t_assert_rc 0 "dispatcher: auto line with contains: expected accepted"
AUTO2="$T_OUT"
t_capture "$OSS" ledger_add_auto r0.s1 "unbound" "true" "under 40ms"
t_assert_rc 2 "dispatcher: comparison-shaped expected rejected (grammar has no comparison form)"
t_capture "$OSS" ledger_add_auto r0.s1 "unbound" "true" "exit0"
t_assert_rc 2 "dispatcher: malformed expected rejected"

# --- §8d / demo-authoring.md §3.5: the inspector-phrasing floor is a PREFIX-ONLY
# backstop. Both halves of that claim are load-bearing for the skill's prose:
#   (a) the three banned prefixes are rejected rc 2, case-insensitively;
#   (b) inspector lines that do NOT start with one are ACCEPTED by the lib.
# (b) is why the prose says the judgment lives in the skill, not in the lib -
# if the lib ever grew a substring check, the prose would be overstating the
# gap and this test is what tells us.
t_capture "$OSS" ledger_add_user r0.s1 "inspect the SQLite schema" "schema visible"
t_assert_rc 2 "dispatcher: 'inspect ' prefix rejected"
t_capture "$OSS" ledger_add_user r0.s1 "View the order record" "record visible"
t_assert_rc 2 "dispatcher: 'view ' prefix rejected (case-insensitive)"
t_capture "$OSS" ledger_add_user r0.s1 "OPEN the generated file" "file visible"
t_assert_rc 2 "dispatcher: 'open ' prefix rejected (uppercase)"
t_capture "$OSS" get '[.demo_ledger[] | select(.type=="user")] | length'
t_assert_eq "0" "$T_OUT" "no user line written by any rejected call"

for evader in \
  "Lets the user open the settings file" \
  "review the generated schema" \
  "confirm the audit table exists" \
  "check that the record was written"
do
  t_capture "$OSS" ledger_add_user r0.s1 "$evader" "outcome"
  t_assert_rc 0 "prefix-only backstop ACCEPTS an inspector line that does not start with a banned word: '$evader'"
done

# ...and a genuine journey line whose outcome is visible is accepted too - the
# false-reject guard in demo-authoring.md §3.3 has nothing mechanical fighting it.
# Deliberately phrased in a domain no eval fixture uses: this file must never
# hand the journey-line-floor eval a ready-made answer if the eval's read path
# ever widens past skills/.
t_capture "$OSS" ledger_add_user r0.s1 "reschedule a delivery to a later slot and see the tracking page show the new window" "the delivery moves to the chosen slot"
t_assert_rc 0 "dispatcher: verb + visible-outcome journey line accepted"
USER1="$T_OUT"

# --- §8e / demo-amendments.md §1-2: amendments are keyed by the printed LINE ID,
# archive rather than delete, and record by-spine + reason.
t_capture "$OSS" get '.demo_ledger | length'; LEDGER_BEFORE="$T_OUT"
t_capture "$OSS" ledger_supersede "$AUTO1" r0.s1 "the order ticket replaced the CLI entry point"
t_assert_rc 0 "dispatcher: supersede by line id ok"
t_capture "$OSS" ledger_retire "$USER1" r0.s1 "the CSV export flow was removed by this spine"
t_assert_rc 0 "dispatcher: retire by line id ok"
t_capture "$OSS" get '.demo_ledger | length'
t_assert_eq "$LEDGER_BEFORE" "$T_OUT" "amended lines are archived, not deleted (ledger length unchanged)"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].status"
t_assert_eq "superseded" "$T_OUT" "superseded status recorded"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$AUTO1\")][0].status_by"
t_assert_eq "r0.s1" "$T_OUT" "superseding spine recorded"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$USER1\")][0].status"
t_assert_eq "retired" "$T_OUT" "retired status recorded"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$USER1\")][0].status_reason"
t_assert_eq "the CSV export flow was removed by this spine" "$T_OUT" "retire reason recorded"

# an amended auto: line stops costing runtime; the un-amended one still counts.
t_capture "$OSS" ledger_active_auto
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "only the un-amended auto line stays active"
t_assert_eq "$AUTO2" "$(printf '%s' "$T_OUT" | jq -r '.[0].id')" "the surviving active auto line is the un-amended one"

# an unknown line id is rc 7 and writes nothing.
t_capture "$OSS" ledger_supersede d999 r0.s1 "typo'd id"
t_assert_rc 7 "dispatcher: amendment against unknown line id is rc 7"

# --- §9 / fake-ledger-discipline.md §1: channel is validated against
# real|fake|deferred; anything else is rc 2 with no record written.
t_capture "$OSS" fake_add "coach-llm" fake "shell for the skeleton" "first real strategy iteration" r1
t_assert_rc 0 "dispatcher: fake channel accepted"
t_capture "$OSS" fake_add "positions-store" deferred "in-memory for r0; the journey claims no durability" "first multi-session use" r1
t_assert_rc 0 "dispatcher: deferred channel accepted"
t_capture "$OSS" fake_add "broker-adapter" real "replaced this spine" "n/a" r1
t_assert_rc 0 "dispatcher: real channel accepted"
t_capture "$OSS" get '.fakes | length'; FAKES_BEFORE="$T_OUT"
t_capture "$OSS" fake_add "broker-adapter" stub "x" "y" r1
t_assert_rc 2 "dispatcher: channel outside real|fake|deferred is rc 2"
t_capture "$OSS" get '.fakes | length'
t_assert_eq "$FAKES_BEFORE" "$T_OUT" "no phantom fake after invalid-channel rejection"
t_capture "$OSS" get '.fakes[0].replacement_trigger'
t_assert_eq "first real strategy iteration" "$T_OUT" "replacement trigger stored"
t_capture "$OSS" get '.fakes[0].expiry_release'
t_assert_eq "r1" "$T_OUT" "expiry release stored"

# --- §4c: touch_check's rc is INVERTED on purpose (0 = matched, 1 = clean) and
# it prints one line per match. The skill body branches on this; reading it
# backwards inverts the whole judge, so assert all three shapes through the
# real binary (strict mode included).
"$OSS" bone_add ADR-0002 "hexagonal domain boundary" "src/domain/**" "revisit at v1" >/dev/null
"$OSS" risk_gate_add live-money "src/adapters/broker/**" "paper-env,human-confirm,audit-trail" >/dev/null
t_capture "$OSS" touch_check src/domain/order.rs
t_assert_rc 0 "dispatcher: touch_check rc 0 == MATCHED"
t_assert_contains "$T_OUT" "bone ADR-0002" "touch_check names the matched bone on stdout"
t_capture "$OSS" touch_check src/adapters/broker/order.rs
t_assert_rc 0 "dispatcher: risk-gate surface also matches"
t_assert_contains "$T_OUT" "risk_gate live-money" "touch_check names the matched risk gate on stdout"
t_capture "$OSS" touch_check README.md docs/notes.md
t_assert_rc 1 "dispatcher: touch_check rc 1 == CLEAN"
t_capture "$OSS" touch_check README.md src/domain/order.rs
t_assert_rc 0 "dispatcher: any match in the path set is rc 0 (decomposition re-check passes the union)"
# rc 2 = "could not check" is the third arm the two-branch `if` in §4c cannot
# see: it must never be folded into rc 1, or an inconclusive judge reads as a
# clean verdict and the spine keeps the permissive class.
t_capture "$OSS" touch_check
t_assert_rc 2 "dispatcher: touch_check with zero paths is rc 2 (inconclusive), never rc 1 (clean)"

# --- state stays replayable after every spine-planning mutation above.
t_capture oss_state_replay "$OSS_STATE_FILE"
t_assert_rc 0 "replay clean after spine-planning ops"
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "ok: shape" "doctor shape green after spine-planning ops"

unset OSS_STATE_FILE
rm -rf "$TMP"
t_summary
