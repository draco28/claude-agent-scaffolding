#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
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

unset OSS_STATE_FILE
rm -rf "$TMP"
t_summary
