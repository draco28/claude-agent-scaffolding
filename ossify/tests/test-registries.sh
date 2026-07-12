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

rm -rf "$TMP"
t_summary
