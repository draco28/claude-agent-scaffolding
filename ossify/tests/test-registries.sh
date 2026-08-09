#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/registries.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" reg-demo >/dev/null

t_capture oss_reg_add_bone "$S" ADR-0002 "hexagonal domain boundary" "src/domain/**,src/lib.rs" "revisit at v1"
t_assert_rc 0 "bone added"
t_capture oss_reg_add_risk_gate "$S" live-money "src/adapters/broker/**" "paper-env,kill-switch,human-confirm,audit-trail"
t_assert_rc 0 "risk gate added"
t_capture oss_reg_add_fake "$S" "coach-llm" fake "shell for skeleton" "first real strategy iteration" r1
t_assert_rc 0 "fake added"
t_capture oss_reg_add_feature "$S" "paper trading loop" "user places a paper trade and sees P&L move" flesh journey-map
t_assert_rc 0 "feature added"

# --- D1 fake lifecycle (Task 2, named risk 7): oss_reg_set_fake_status must
# leave expiry_release ALONE when the 5th arg (new expiry) is omitted.
# test-ledger.sh only exercises the WITH-a-new-expiry (renew) path, so that
# half of the contract has no coverage without this.
t_capture oss_reg_set_fake_status "$S" "coach-llm" replaced "swapped for a real model"
t_assert_rc 0 "fake status change without a new expiry ok"
t_capture jq -r '.fakes[] | select(.boundary=="coach-llm") | .status' "$S"
t_assert_eq "replaced" "$T_OUT" "status actually changed"
t_capture jq -r '.fakes[] | select(.boundary=="coach-llm") | .expiry_release' "$S"
t_assert_eq "r1" "$T_OUT" "expiry_release is UNCHANGED when the 5th arg is omitted"

t_capture oss_reg_touch_check "$S" src/domain/dsl/compile.rs
t_assert_rc 0 "domain path matches a bone"; t_assert_contains "$T_OUT" "bone ADR-0002" "bone named"
t_capture oss_reg_touch_check "$S" src/adapters/broker/order.rs
t_assert_rc 0 "broker path matches risk gate"; t_assert_contains "$T_OUT" "risk_gate live-money" "gate named"
t_capture oss_reg_touch_check "$S" README.md
t_assert_rc 1 "clean path matches nothing"

# Fix 2: a bone/risk-gate with no touch surface is legitimate — empty CSV must
# yield an empty [] touch array, not a raw jq --argjson parse failure (rc 4).
t_capture oss_reg_add_bone "$S" ADR-9 "no-touch bone" "" ""
t_assert_rc 0 "no-touch bone added"
t_capture jq -c '.bones[] | select(.adr=="ADR-9") | .touch' "$S"
t_assert_eq "[]" "$T_OUT" "no-touch bone's touch is []"

# --- Final review finding 3: touch_check must distinguish "clean" from "could
# not check". Both were rc 1 with no stdout and no stderr — byte-identical — and
# every documented call site is `if oss touch_check …; then HIT; else CLEAN; fi`,
# so an unreadable state silently classified the spine as `flesh`, the permissive
# class. The judge failed OPEN. rc 2 (usage, the established code in these libs)
# now means inconclusive; rc 0 = matched and rc 1 = clean are unchanged — that
# inversion is deliberate and every caller depends on it.
t_capture oss_reg_touch_check "$S"
t_assert_rc 2 "zero paths is rc 2 (usage), not rc 1 (clean)"
t_assert_contains "$T_OUT" "at least one path" "zero-path usage error names the problem"

printf 'THIS IS NOT VALID JSON\n' > "$TMP/corrupt.json"
t_capture oss_reg_touch_check "$TMP/corrupt.json" src/domain/dsl/compile.rs
t_assert_rc 2 "corrupt state is rc 2 (could not check), not rc 1 (clean)"
t_assert_contains "$T_OUT" "cannot read" "unreadable state says so instead of answering clean"

t_capture oss_reg_touch_check "$TMP/nonexistent.json" src/domain/dsl/compile.rs
t_assert_rc 2 "nonexistent state file is rc 2, not rc 1"

jq 'del(.bones)' "$S" > "$TMP/nobones.json"
t_capture oss_reg_touch_check "$TMP/nobones.json" src/domain/dsl/compile.rs
t_assert_rc 2 "state missing .bones is rc 2, not rc 1"

jq 'del(.risk_gates)' "$S" > "$TMP/nogates.json"
t_capture oss_reg_touch_check "$TMP/nogates.json" src/domain/dsl/compile.rs
t_assert_rc 2 "state missing .risk_gates is rc 2, not rc 1"

# ...and the tightening must NOT turn a legitimately empty registry into
# "inconclusive": a fresh project with no bones and no gates is genuinely CLEAN.
T5="$(mktemp -d)"; S5="$T5/state.json"
oss_state_init "$S5" reg-empty >/dev/null
t_capture oss_reg_touch_check "$S5" src/domain/dsl/compile.rs
t_assert_rc 1 "empty-but-valid registries are CLEAN (rc 1), not inconclusive"
rm -rf "$T5"

rm -rf "$TMP"
t_summary
