#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; export OSS_STATE_FILE="$TMP/state.json"

# init resolves the path from OSS_STATE_FILE (no manifest needed in tests).
t_capture oss_cmd_init "wrapper-demo"
t_assert_rc 0 "oss_cmd_init ok"
t_assert_eq "$OSS_STATE_FILE" "$(ls "$TMP/state.json")" "state created at OSS_STATE_FILE"

t_capture oss_cmd_posture_set "open-core"
t_assert_rc 0 "posture set"
t_capture oss_cmd_get '.project.posture'; t_assert_eq "open-core" "$T_OUT" "posture stored"

t_capture oss_cmd_composition_set "docs/specs/composition"
t_assert_rc 0 "composition set"
t_capture oss_cmd_get '.project.composition_root'; t_assert_eq "docs/specs/composition" "$T_OUT" "composition_root stored"

t_capture oss_cmd_overlay_set '$PULSE_PROMPT_DIR'
t_assert_rc 0 "overlay set"
t_capture oss_cmd_get '.project.overlay_wiring'; t_assert_eq '$PULSE_PROMPT_DIR' "$T_OUT" "overlay stored"

t_capture oss_cmd_release_add "Skeleton" "core loop usable"
t_assert_eq "r0" "$T_OUT" "release via wrapper mints r0"
t_capture oss_cmd_spine_add r0 "walking skeleton" bone
t_assert_eq "r0.s1" "$T_OUT" "spine via wrapper (default target_repo)"
t_capture oss_cmd_get '.spines[0].target_repo'; t_assert_eq "canonical" "$T_OUT" "spine wrapper defaults target_repo to canonical"

t_capture oss_cmd_bone_add "ADR-0002" "hexagonal core" "src/domain/**,src/port.rs" "revisit at MVP"
t_assert_rc 0 "bone added via wrapper"
t_capture oss_cmd_touch_check "src/domain/order.rs"
t_assert_rc 0 "touch check hits the bone glob"
t_assert_contains "$T_OUT" "bone ADR-0002" "touch check names the bone"

# rc-passthrough is intentionally inverted (0 = hit, 1 = clean) - callers
# depend on it, so assert the clean path explicitly, not just the hit path.
t_capture oss_cmd_touch_check "unrelated/clean/path.rs"
t_assert_rc 1 "touch check clean path returns rc 1"

t_capture oss_cmd_ledger_add_auto r0.s1 "core loop runs" "bash -c 'exit 0'" "exit:0"
t_assert_eq "d1" "$T_OUT" "auto demo line via wrapper mints d1"

# replay stays clean through the wrapper-driven mutations + both new ops
# (set_composition, set_overlay).
t_capture oss_state_replay "$OSS_STATE_FILE"
t_assert_rc 0 "replay clean after wrapper ops incl. set_composition + set_overlay"

# --- Dispatcher-path regression (Plan B task 3 review): every assertion
# above sources the libs and calls the oss_cmd_* shell functions in-process,
# which never exercises bin/oss's real `set -euo pipefail`. A masked
# `local sf="$(_oss_resolve_state)"` (dropping the `|| return $?`) only
# misbehaves when the resolve call itself fails, and a lost/redirected
# minted-id stdout would slip past a sourced-only test too. Re-run a
# representative slice of wrappers through the REAL dispatcher binary, on its
# own fresh state file so it doesn't perturb the id/counter sequence the
# assertions above depend on.
DTMP="$(mktemp -d)"; export OSS_STATE_FILE="$DTMP/state.json"

t_capture "$OSS" init dispatcher-demo
t_assert_rc 0 "dispatcher: init ok"

t_capture "$OSS" release_add A B
t_assert_rc 0 "dispatcher: release_add ok"
t_assert_eq "r0" "$T_OUT" "dispatcher: release_add mints r0 through the real binary"

t_capture "$OSS" spine_add r0 sk bone
t_assert_rc 0 "dispatcher: spine_add ok"
t_assert_eq "r0.s1" "$T_OUT" "dispatcher: spine_add mints r0.s1 through the real binary"

t_capture "$OSS" get '.releases[0].id'
t_assert_rc 0 "dispatcher: get ok"
t_assert_eq "r0" "$T_OUT" "dispatcher: get reads back r0"

t_capture "$OSS" spine_add r9 ghost flesh
t_assert_rc 7 "dispatcher: spine_add against unknown release propagates rc 7 (not collapsed) through the real binary"

unset OSS_STATE_FILE
rm -rf "$DTMP"

unset OSS_STATE_FILE
rm -rf "$TMP"
t_summary
