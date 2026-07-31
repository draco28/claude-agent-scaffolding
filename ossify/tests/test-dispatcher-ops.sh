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

# `oss get` takes an explicit state file, so a pre-flight probe cannot be
# hijacked by a stale exported $OSS_STATE_FILE.
OTHER="$TMP/other.json"; OSS_STATE_FILE="$OTHER" "$OSS" init "other-project" >/dev/null 2>&1
t_capture "$OSS" get '.project.name' "$OTHER"
t_assert_eq "other-project" "$T_OUT" "get honors an explicit state-file argument over the env"
t_capture "$OSS" get '.project.name'
t_assert_eq "wrapper-demo" "$T_OUT" "get with no argument still resolves via the env/manifest"

# manifest verbs are reachable through the dispatcher at all.
t_capture "$OSS" manifest_require
t_assert_rc 1 "manifest_require refuses with no manifest on the walk-up path"

# id grammar verbs are reachable, and the work-item branch is DISTINCT from the
# spine branch (oss_id_branch_name) - a work item must not share its spine's ref.
t_capture "$OSS" work_item_branch r0.s1.w2 "add-ticket"
t_assert_eq "work/r0.s1.w2-add-ticket" "$T_OUT" "work-item branch grammar"
t_capture "$OSS" spine_dir r0 r0.s1 "order-ticket"
t_assert_eq "docs/specs/r0/r0.s1-order-ticket" "$T_OUT" "spine dir grammar"

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

# --- D1 (Plan C1 Task 2) dispatcher-path regression: ledger_quarantine's new
# release argument and the new fake_status verb, both added by this task, run
# through the REAL dispatcher binary under set -euo pipefail - the coverage
# added elsewhere for this task only exercises them via sourced lib calls.
FTMP="$(mktemp -d)"; export OSS_STATE_FILE="$FTMP/state.json"
t_capture "$OSS" init fake-status-demo
t_assert_rc 0 "dispatcher: init ok (quarantine/fake_status block)"
t_capture "$OSS" ledger_add_auto r0.s1 "smoke" "true" "exit:0"
t_assert_rc 0 "dispatcher: ledger_add_auto ok"; DL1="$T_OUT"
t_capture "$OSS" ledger_quarantine "$DL1" "flaky upstream" "r1"
t_assert_rc 0 "dispatcher: ledger_quarantine with release arg ok through the real binary"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$DL1\")][0].quarantined_in_release"
t_assert_eq "r1" "$T_OUT" "dispatcher: quarantine's release argument reaches state through the real binary"

t_capture "$OSS" fake_add "broker" fake "no sandbox" "first live order" r1
t_assert_rc 0 "dispatcher: fake_add ok"
t_capture "$OSS" fake_status "broker" renewed "still no sandbox" r2
t_assert_rc 0 "dispatcher: fake_status ok through the real binary"
t_capture "$OSS" get '[.fakes[] | select(.boundary=="broker")][0].expiry_release'
t_assert_eq "r2" "$T_OUT" "dispatcher: fake_status renewal reaches state through the real binary"
t_capture "$OSS" fake_status "broker" bogus "x"
t_assert_rc 2 "dispatcher: fake_status rejects a bad enum through the real binary"

unset OSS_STATE_FILE
rm -rf "$FTMP"

# critic_detect is a pure filesystem probe (no state file, no manifest) - it
# must answer on any machine, installed or not, so the assertion accepts any
# arm of the binary contract but nothing else (an empty/garbage echo, or a
# crash, fails here). v0.3 is included because the rewrite now scans every
# cache and can report it - on a machine with architect-critic >=0.3 installed
# the old v0.2-or-absent-only assertion would fail here.
t_capture oss_cmd_critic_detect
case "$T_OUT" in v0.2|v0.3|absent) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: critic_detect echoes v0.2|v0.3|absent (got '$T_OUT')";; esac

# ...and through the REAL dispatcher binary, which runs `set -euo pipefail`.
# The probe's inner `[ -f "$g" ] && { ...; }` on a non-matching glob is exactly
# the shape that dies under strict mode if written carelessly, and the sourced
# call above (non-strict) would never catch it.
t_capture "$OSS" critic_detect
case "$T_OUT" in v0.2|v0.3|absent) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: dispatcher critic_detect echoes v0.2|v0.3|absent (got '$T_OUT')";; esac

# ...and on a machine with HOME UNSET. Under the dispatcher's `set -u` an
# unguarded `${HOME}` is a fatal expansion error raised before the loop body
# runs, so the probe dies with EMPTY stdout rather than echoing `absent` -
# violating the "must answer on any machine" contract the block above asserts.
# `env -i` is what makes HOME genuinely unset rather than merely empty; PATH is
# carried so the interpreter and jq remain findable.
t_capture env -i PATH="$PATH" bash "$OSS" critic_detect
t_assert_eq "absent" "$T_OUT" "critic_detect still answers when HOME is unset (set -u safety)"

# The remaining two dispatcher wrappers this task added. Both are pure
# pass-throughs, which is exactly why they need a dispatcher-path assertion:
# nothing else in the suite reaches them, so an argument-order slip or a lost
# stdout would ship silently. The close router (Task 9) routes on id_parse's
# output, and branch_name is the spine branch T8/T10 cut and merge.
t_capture "$OSS" branch_name r0.s1 "order-ticket"
t_assert_eq "spine/r0.s1-order-ticket" "$T_OUT" "dispatcher: branch_name keeps id-then-slug order"
# id_parse emits the shape AND the numeric components ("work_item 0 1 2"), not
# the shape alone - assert the whole line so a dropped component is caught too.
t_capture "$OSS" id_parse r0.s1.w2
t_assert_eq "work_item 0 1 2" "$T_OUT" "dispatcher: id_parse reports the id SHAPE the close router routes on"
t_capture "$OSS" id_parse r0.s1
t_assert_eq "spine 0 1" "$T_OUT" "dispatcher: id_parse distinguishes a spine from a work item"

# Hermetic positive case for v0.3: build both directory shapes under a temporary
# CLAUDE_PLUGINS_DIR so the assertion does not depend on the developer's own
# install. HOME=/nonexistent keeps the real ~/.claude/plugins/cache (if any) out
# of the scan, isolating this to the fixture cache only.
CTMP="$(mktemp -d)"
mkdir -p "$CTMP/mk/architect-critic/0.6.0/skills/critiquing-spec" "$CTMP/mk/architect-critic/0.6.0/skills/managing-async-critique"
: > "$CTMP/mk/architect-critic/0.6.0/skills/critiquing-spec/SKILL.md"
: > "$CTMP/mk/architect-critic/0.6.0/skills/managing-async-critique/SKILL.md"
t_capture env HOME=/nonexistent CLAUDE_PLUGINS_DIR="$CTMP" bash "$OSS" critic_detect
t_assert_eq "v0.3" "$T_OUT" "a cache carrying managing-async-critique reports v0.3"
rm -rf "$CTMP"

t_summary
