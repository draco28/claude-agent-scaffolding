#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/entities.sh"; . "$HERE/../lib/ledger.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" concurrency-demo >/dev/null

# Server-side mint OVERRIDES a caller-supplied stale/duplicate id: the whole
# point of moving minting inside the lock is that a caller can never inject an
# id (two racing callers can't both win r0). Payload deliberately carries a
# bogus id:"r99" — the minted id must replace it.
t_capture oss_state_mutate "$S" add_release \
  '{"name":"x","goal":"y","status":"planned","created_at":"2026-01-01T00:00:00Z","id":"r99"}' release
t_assert_rc 0 "minted add_release ok"
t_assert_eq "r0" "$T_OUT" "server-side mint returns r0 (ignores caller id r99)"
t_capture oss_state_read "$S" '.releases[0].id'
t_assert_eq "r0" "$T_OUT" "stored release id is the minted r0, not the stale r99"

# Second release mints r1 (distinct id, no collision).
t_capture oss_state_mutate "$S" add_release \
  '{"name":"z","goal":"w","status":"planned","created_at":"2026-01-01T00:00:00Z"}' release
t_assert_eq "r1" "$T_OUT" "second release mints r1"
t_capture oss_state_read "$S" '[.releases[].id] | join(",")'
t_assert_eq "r0,r1" "$T_OUT" "release ids are distinct r0,r1"

# Demo-line counter minting inside the lock.
oss_entity_add_spine "$S" r0 "sk" bone canonical >/dev/null
t_capture oss_ledger_add_auto "$S" r0.s1 "core loop runs" "bash -c 'exit 0'" "exit:0"
t_assert_eq "d1" "$T_OUT" "first demo line mints d1"
t_capture oss_ledger_add_auto "$S" r0.s1 "second" "bash -c 'exit 0'" "exit:0"
t_assert_eq "d2" "$T_OUT" "second demo line mints d2"
t_capture oss_state_read "$S" '.counters.demo_line'
t_assert_eq "2" "$T_OUT" "demo_line counter is 2"

# Replay stays clean across all mint-path mutations.
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay clean after minted mutations"

rm -rf "$TMP"
t_summary
