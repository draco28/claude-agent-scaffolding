# Ossify Core (Plan A of 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build ossify's foundation — plugin scaffold, `oss` dispatcher, ID grammar, and the safety-committed `project-state.json` engine (atomic writes, locking, append-only mutation journal with replay, schema versioning, doctor) plus the auto-demo ledger runner.

**Architecture:** A new `ossify/` plugin in the marketplace repo following the established plugin shape (`bin/` dispatcher → `lib/*.sh` functions → bash test harness). All lifecycle state lives in one `project-state.json` mutated only through a journaled, locked, atomic `oss_state_mutate` path; every higher-level entity operation (releases, spines, bones, demo lines) is a thin payload-builder over that single path. No skills/ceremonies in this plan — Plans B/C build those on these primitives.

**Tech Stack:** bash (BSD/macOS-compatible), jq, git. No new dependencies.

## Global Constraints

- Specs of record: `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` (§9.2 state-safety commitments are BINDING) + `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md`.
- Dispatcher runs `set -euo pipefail`; every lib function must survive strict mode — guard all no-match greps with `|| true` and test through the dispatcher path, not only by sourcing (repo lesson: [[feedback_sd_lib_strict_mode_gotcha]]).
- BSD/macOS portability: `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamps (no GNU flags); `mkdir`-based locks (atomic on all POSIX filesystems); no `readarray`, no `grep -P`.
- ID grammar (settles spec OQ7): release `r<N>` (`^r[0-9]+$`), spine `r<N>.s<K>` (`^r[0-9]+\.s[0-9]+$`), work item `r<N>.s<K>.w<J>` (`^r[0-9]+\.s[0-9]+\.w[0-9]+$`); branch `spine/<spine-id>-<kebab-slug>`; release dir `docs/specs/<release-id>/`; demo-line ids `d<N>` from a state counter. Deliberately no `VS-` shapes.
- Demo lines are stored STRUCTURED in state (type/text/command/expected); the U+2192 arrow is a render-time concern only (Plan C), never parsed from markdown here.
- All state functions take the state-file path as their FIRST argument (no cwd guessing; test-friendly). Callers resolve the path (`<ai_workspace>/.ossify/project-state.json`) — resolution lands in Plan B with manifest wiring.
- ossify is NOT registered in the marketplace manifest in this plan (ship gate is Plan D; avoids surfacing a half-built plugin via /plugin update).
- Work on branch `feat/ossify-core`. Commit per task. All tests green via `bash ossify/tests/run-all.sh` AND the repo root suite before the final task completes.

## Series map (Plans B–D, sketched — detailed after their predecessor ships)

- **Plan B — onboarding + planning skills:** `start` (spec-core onboarding: journey map, skeleton-cut, bones w/ smoke-test pass, posture block, risk gates, lean-bootstrap minimums, critic moment), `plan-release` (feature-map groom, class declaration + critic-veto interpretation w/ fail-closed default, RELEASE.md emission, pilot-evidence wiring), `plan-spine` (decomposition, DAG rounds, demo authoring w/ floor rules, citation fold-in), entry-skill tree + references layout, state-path/manifest resolution, eval fixtures for the planning judges. Spec: ossify §4–§5, §9.1; companion §3.
- **Plan C — execution + close:** work-item execution port (implementer contract unchanged), `close` router (work-item → spine bone/flesh checklists → release), ledger `user:` walkthrough + amendments + release close (pin/publish, docs-increment trigger table, boundary-audit hook point), memory-bank harvest port, patch-lane mechanics, utility commands port (/handoff, /defer, /work-pr, /adr, /flip-adr w/ supersede, /amend-spec w/ architecture lane, /changelog, /runbook), pr_hierarchical port (one PR per touched repo). Spec: ossify §6–§8.
- **Plan D — boundary + ship gate:** workspace-init additive extension (visibility fields, `private_core`, three resolvers, `add-private-core`), multi-repo worktrees + cross-repo dependency overrides, boundary audit (observed-visibility gating, PUBLIC_BOUNDARY rules block, leak-adjacent scan, pre-flip history scan), consolidated eval suite (THE ship gate, spec §13.4), marketplace registration, Forge3D greenfield pilot kickoff + pulse-trader adopt-forward. Spec: companion §4–§6; ossify §10, §13.4.

---

### Task 1: Branch, plugin scaffold, dispatcher, test harness

**Files:**
- Create: `ossify/.claude-plugin/plugin.json`
- Create: `ossify/README.md`
- Create: `ossify/bin/oss`
- Create: `ossify/tests/harness.sh`
- Create: `ossify/tests/run-all.sh`
- Test: `ossify/tests/test-dispatcher.sh`

**Interfaces:**
- Produces: `oss <subcommand> [args...]` dispatcher; subcommands registered as `oss_cmd_<name>` bash functions in sourced libs; `oss help` lists them; unknown subcommand → exit 2. Test harness (exactly the primitives the suite uses — no unused helpers): `t_assert_eq <exp> <got> <msg>`, `t_assert_contains <haystack> <needle> <msg>`, `t_assert_rc <exp-rc> <msg>` (checks `$T_RC` set by `t_capture`), `t_capture <cmd...>` (captures stdout→`$T_OUT`, rc→`$T_RC`, never trips strict mode), `t_summary`.

- [ ] **Step 1: Create the branch**

Run: `git -C /Users/draco/projects/claude-agent-scaffolding checkout -b feat/ossify-core`
Expected: `Switched to a new branch 'feat/ossify-core'`

- [ ] **Step 2: Write the failing dispatcher test**

`ossify/tests/harness.sh`:
```bash
#!/usr/bin/env bash
# Minimal test harness. Source from test files. Never enables -e itself:
# tests must observe failures, not die on them.
T_PASS=0; T_FAIL=0; T_OUT=""; T_RC=0
# Harness is sourced by test files that never enable `set -e`, so command
# substitution captures a non-zero rc without aborting. t_capture does NOT
# touch `set -e` (doing so would make later bare commands abort mid-test).
t_capture() { T_OUT="$("$@" 2>&1)"; T_RC=$?; }
t_assert_eq() { if [ "$1" = "$2" ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (expected '$1' got '$2')"; fi; }
t_assert_contains() { case "$1" in *"$2"*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (no '$2' in output)";; esac; }
t_assert_rc() { t_assert_eq "$1" "$T_RC" "$2"; }
t_summary() { echo "pass=$T_PASS fail=$T_FAIL"; [ "$T_FAIL" -eq 0 ]; }
```

`ossify/tests/test-dispatcher.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSS="$HERE/../bin/oss"

t_capture "$OSS" help
t_assert_rc 0 "oss help exits 0"
t_assert_contains "$T_OUT" "ossify" "help names the plugin"

t_capture "$OSS" definitely-not-a-command
t_assert_rc 2 "unknown subcommand exits 2"

t_summary
```

`ossify/tests/run-all.sh`:
```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$HERE"/test-*.sh; do
  echo "== $t"
  bash "$t" || fail=1
done
[ "$fail" -eq 0 ] && echo "ALL GREEN" || { echo "FAILURES"; exit 1; }
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash ossify/tests/test-dispatcher.sh`
Expected: FAIL lines (oss binary does not exist yet; `t_capture` records rc=127)

- [ ] **Step 4: Write the scaffold + dispatcher**

`ossify/.claude-plugin/plugin.json`:
```json
{
  "name": "ossify",
  "version": "0.1.0-dev",
  "description": "Skeleton-first lifecycle plugin: Skeleton (Release 0) -> MVP -> v1 releases; bone/flesh feature spines; cumulative product demo; bones registry. Phase-1 build in progress; NOT marketplace-registered until the eval ship gate passes."
}
```

`ossify/README.md`:
```markdown
# ossify (phase-1 build, unregistered)

Skeleton-first lifecycle plugin. Specs of record:
- docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md
- docs/superpowers/specs/2026-07-12-public-private-boundary-design.md

Not in marketplace.json until the eval ship gate (spec §13.4) passes.
Dispatcher: `bin/oss`. Tests: `bash tests/run-all.sh`.
```

`ossify/bin/oss`:
```bash
#!/usr/bin/env bash
set -euo pipefail
OSS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for _lib in "$OSS_ROOT"/lib/*.sh; do
  # shellcheck disable=SC1090
  [ -e "$_lib" ] && . "$_lib"
done
oss_cmd_help() {
  echo "ossify dispatcher (oss) - skeleton-first lifecycle plugin"
  echo "subcommands:"
  declare -F | awk '{print $3}' | { grep '^oss_cmd_' || true; } | sed 's/^oss_cmd_/  /'
}
main() {
  local cmd="${1:-help}"; shift || true
  if declare -F "oss_cmd_${cmd}" >/dev/null 2>&1; then
    "oss_cmd_${cmd}" "$@"
  else
    echo "oss: unknown subcommand '${cmd}'" >&2
    oss_cmd_help >&2
    exit 2
  fi
}
main "$@"
```

Run: `chmod +x ossify/bin/oss ossify/tests/*.sh`

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash ossify/tests/test-dispatcher.sh`
Expected: `pass=3 fail=0` (help rc, help content, unknown rc)

- [ ] **Step 6: Commit**

```bash
git add ossify/
git commit -m "feat(ossify): plugin scaffold, oss dispatcher, test harness (Plan A task 1)"
```

---

### Task 2: ID grammar lib (settles spec OQ7)

**Files:**
- Create: `ossify/lib/id.sh`
- Test: `ossify/tests/test-id.sh`

**Interfaces:**
- Produces: `oss_id_valid_release <id>` / `oss_id_valid_spine <id>` / `oss_id_valid_work_item <id>` (rc 0/1); `oss_id_parse <id>` → stdout `release|spine|work_item <r> [s] [w]` or rc 1; `oss_id_next_release <state-file>` / `oss_id_next_spine <state-file> <release-id>` / `oss_id_next_work_item <state-file> <spine-id>` → next id from existing state arrays (max+1, never reuse); `oss_id_branch_name <spine-id> <slug>` → `spine/<spine-id>-<slug>`; `oss_id_release_dir <release-id>` → `docs/specs/<release-id>`.

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-id.sh`:
```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-id.sh`
Expected: FAIL (lib/id.sh missing → source error surfaces as failures)

- [ ] **Step 3: Write the implementation**

`ossify/lib/id.sh`:
```bash
#!/usr/bin/env bash
# ossify ID grammar — single owner (spec §9.2 / OQ7). No VS- shapes.

oss_id_valid_release()   { case "$1" in r[0-9]|r[0-9][0-9]|r[0-9][0-9][0-9]) return 0;; *) return 1;; esac; }
oss_id_valid_spine()     { printf '%s' "$1" | { grep -Eq '^r[0-9]+\.s[0-9]+$' || return 1; }; }
oss_id_valid_work_item() { printf '%s' "$1" | { grep -Eq '^r[0-9]+\.s[0-9]+\.w[0-9]+$' || return 1; }; }

oss_id_parse() {
  local id="$1"
  if oss_id_valid_release "$id"; then
    echo "release ${id#r}"
  elif oss_id_valid_spine "$id"; then
    local r="${id%%.*}" s="${id##*.s}"
    echo "spine ${r#r} ${s}"
  elif oss_id_valid_work_item "$id"; then
    local r="${id%%.*}" rest="${id#*.s}" s="${rest%%.*}" w="${id##*.w}"
    echo "work_item ${r#r} ${s} ${w}"
  else
    return 1
  fi
}

oss_id_branch_name() { echo "spine/$1-$2"; }
oss_id_release_dir() { echo "docs/specs/$1"; }

_oss_id_max_plus_one() { # $1=jq array path, $2=strip-prefix regex, $3=state file
  jq -r "$1[].id" "$3" 2>/dev/null \
    | { grep -E "$2" || true; } \
    | sed -E "s/$2//" \
    | sort -n | tail -1 | awk '{print $1+1}'
}

oss_id_next_release() {
  local n
  n="$(_oss_id_max_plus_one '.releases' '^r' "$1")"
  echo "r${n:-0}"
}
oss_id_next_spine() { # $1=state $2=release-id
  local n
  n="$(jq -r '.spines[].id' "$1" 2>/dev/null \
    | { grep -E "^$2\.s[0-9]+$" || true; } \
    | sed -E 's/^.*\.s//' | sort -n | tail -1 | awk '{print $1+1}')"
  echo "$2.s${n:-1}"
}
oss_id_next_work_item() { # $1=state $2=spine-id
  local n
  n="$(jq -r '.work_items[].id' "$1" 2>/dev/null \
    | { grep -E "^$2\.w[0-9]+$" || true; } \
    | sed -E 's/^.*\.w//' | sort -n | tail -1 | awk '{print $1+1}')"
  echo "$2.w${n:-1}"
}
```

Note: `oss_id_valid_release` uses case-globs (fast path, releases are small integers); spine/work-item use guarded `grep -Eq`. Every grep in this file is no-match-guarded — strict-mode rule.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash ossify/tests/test-id.sh`
Expected: `pass=12 fail=0`

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/id.sh ossify/tests/test-id.sh
git commit -m "feat(ossify): ID grammar lib - r<N>/r<N>.s<K>/r<N>.s<K>.w<J>, settles spec OQ7 (Plan A task 2)"
```

---

### Task 3: State core — init, read, journaled+locked+atomic mutate

**Files:**
- Create: `ossify/lib/state.sh`
- Test: `ossify/tests/test-state-core.sh`

**Interfaces:**
- Produces: `oss_state_init <state-file> <project-name>` (mkdir -p parent; refuses if exists; writes schema v1 skeleton + sibling `<state-file>.base.json` snapshot); `oss_state_read <state-file> <jq-expr>`; `oss_state_mutate <state-file> <op> <payload-json>` — acquires lock dir `<state-file>.lock/`, appends `{seq,op,ts,payload}` to `.mutations`, applies op via `_oss_apply_op`, writes temp+`mv` (atomic), releases lock. rc 3 on lock contention. `_oss_apply_op <op> <payload-json> <state-json-on-stdin>` → new state on stdout (pure jq; shared with replay in Task 4).
- State v1 shape (settles OQ3 fields within the §9.2 envelope):
```json
{"schema_version":1,
 "project":{"name":"","posture":null,"composition_root":null,"overlay_wiring":null},
 "counters":{"demo_line":0},
 "releases":[],"spines":[],"work_items":[],
 "demo_ledger":[],"bones":[],"risk_gates":[],"fakes":[],
 "feature_map":[],"patch_records":[],"class_overrides":[],
 "mutations":[]}
```

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-state-core.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
TMP="$(mktemp -d)"; S="$TMP/.ossify/project-state.json"

t_capture oss_state_init "$S" demo-project
t_assert_rc 0 "init succeeds"
t_capture oss_state_read "$S" '.schema_version';       t_assert_eq "1" "$T_OUT" "schema v1"
t_capture oss_state_read "$S" '.project.name';         t_assert_eq "demo-project" "$T_OUT" "project name"
[ -f "$S.base.json" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: base snapshot missing"; }

t_capture oss_state_init "$S" again
t_assert_rc 1 "re-init refused"

t_capture oss_state_mutate "$S" set_posture '{"posture":"fully-private"}'
t_assert_rc 0 "mutate ok"
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "posture applied"
t_capture oss_state_read "$S" '.mutations | length';   t_assert_eq "1" "$T_OUT" "mutation journaled"
t_capture oss_state_read "$S" '.mutations[0].op';      t_assert_eq "set_posture" "$T_OUT" "op recorded"

mkdir "$S.lock"   # simulate a concurrent holder
t_capture oss_state_mutate "$S" set_posture '{"posture":"fully-open"}'
t_assert_rc 3 "lock contention rc=3"
rmdir "$S.lock"
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "state untouched under contention"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-state-core.sh`
Expected: FAIL (lib/state.sh missing)

- [ ] **Step 3: Write the implementation**

`ossify/lib/state.sh`:
```bash
#!/usr/bin/env bash
# ossify state engine. §9.2 safety commitments: atomic writes, lock file,
# schema_version+migrations, append-only mutations journal.

OSS_STATE_SCHEMA_VERSION=1

_oss_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

oss_state_init() { # $1=state-file $2=project-name
  local sf="$1" name="$2"
  [ -e "$sf" ] && { echo "oss: state already exists: $sf" >&2; return 1; }
  mkdir -p "$(dirname "$sf")"
  jq -n --arg name "$name" --argjson sv "$OSS_STATE_SCHEMA_VERSION" '{
    schema_version:$sv,
    project:{name:$name,posture:null,composition_root:null,overlay_wiring:null},
    counters:{demo_line:0},
    releases:[],spines:[],work_items:[],
    demo_ledger:[],bones:[],risk_gates:[],fakes:[],
    feature_map:[],patch_records:[],class_overrides:[],
    mutations:[]
  }' > "$sf"
  cp "$sf" "$sf.base.json"
}

oss_state_read() { jq -r "$2" "$1"; }

# Pure transform: op+payload applied to state on stdin -> new state on stdout.
# Shared by mutate (live) and replay (Task 4). Every new op lands HERE only.
_oss_apply_op() { # $1=op $2=payload-json
  local op="$1" payload="$2"
  case "$op" in
    set_posture)
      jq --argjson p "$payload" '.project.posture = $p.posture' ;;
    *)
      echo "oss: unknown op '$op'" >&2; return 4 ;;
  esac
}

oss_state_mutate() { # $1=state-file $2=op $3=payload-json
  local sf="$1" op="$2" payload="$3" lock="$1.lock" tmp seq ts
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating; retry or run 'oss doctor'" >&2
    return 3
  fi
  # shellcheck disable=SC2064
  trap "rmdir '$lock' 2>/dev/null || true" RETURN 2>/dev/null || true
  tmp="$(mktemp "${sf}.tmp.XXXXXX")"
  seq="$(jq '.mutations | length' "$sf")"
  ts="$(_oss_now)"
  if ! jq --arg op "$op" --arg ts "$ts" --argjson seq "$seq" --argjson payload "$payload" \
      '.mutations += [{seq:$seq,op:$op,ts:$ts,payload:$payload}]' "$sf" \
      | _oss_apply_op "$op" "$payload" > "$tmp"; then
    rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true; return 4
  fi
  # refuse to install an empty/invalid result (pipeline failure guard)
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true
    echo "oss: mutation produced invalid state; aborted (original untouched)" >&2
    return 4
  fi
  mv "$tmp" "$sf"
  rmdir "$lock" 2>/dev/null || true
}
```

Note: `trap ... RETURN` is bash-only and guarded — on bash <4 trap RETURN in sourced context can be flaky, so the lock is ALSO explicitly released on every exit path; the trap is belt-and-suspenders. The journal append happens in the same jq pipeline as the apply, so journal and effect commit atomically together via one `mv`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash ossify/tests/test-state-core.sh`
Expected: `pass=11 fail=0`

- [ ] **Step 5: Run the dispatcher-path smoke (strict-mode rule)**

Run: `ossify/bin/oss help`
Expected: exit 0, subcommand list (state.sh sources cleanly under `set -euo pipefail`)

- [ ] **Step 6: Commit**

```bash
git add ossify/lib/state.sh ossify/tests/test-state-core.sh
git commit -m "feat(ossify): journaled+locked+atomic state core, schema v1 (Plan A task 3)"
```

---

### Task 4: Mutation replay + drift detection

**Files:**
- Modify: `ossify/lib/state.sh` (append functions)
- Test: `ossify/tests/test-state-replay.sh`

**Interfaces:**
- Produces: `oss_state_replay <state-file>` — reconstructs state from `<state-file>.base.json` by re-applying every journaled mutation through `_oss_apply_op`; compares (`jq -S`) against the live file; rc 0 identical, rc 5 + diff summary on drift. This is the §9.2 "replay capability" commitment and doctor's drift primitive.

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-state-replay.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"

oss_state_init "$S" replay-demo >/dev/null
oss_state_mutate "$S" set_posture '{"posture":"open-core"}'
oss_state_mutate "$S" set_posture '{"posture":"fully-private"}'

t_capture oss_state_replay "$S"
t_assert_rc 0 "replay reproduces live state"

jq '.project.posture = "tampered"' "$S" > "$S.x" && mv "$S.x" "$S"   # out-of-band edit
t_capture oss_state_replay "$S"
t_assert_rc 5 "tamper detected as drift"
t_assert_contains "$T_OUT" "drift" "drift named in output"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-state-replay.sh`
Expected: FAIL (`oss_state_replay: command not found` captured)

- [ ] **Step 3: Append the implementation to `ossify/lib/state.sh`**

```bash
oss_state_replay() { # $1=state-file ; rc 0 = clean, 5 = drift
  local sf="$1" base="$1.base.json" rebuilt live n i op payload seq_json
  [ -f "$base" ] || { echo "oss: no base snapshot ($base)" >&2; return 1; }
  rebuilt="$(cat "$base")"
  n="$(jq '.mutations | length' "$sf")"
  i=0
  while [ "$i" -lt "$n" ]; do
    seq_json="$(jq -c ".mutations[$i]" "$sf")"
    op="$(printf '%s' "$seq_json" | jq -r '.op')"
    payload="$(printf '%s' "$seq_json" | jq -c '.payload')"
    rebuilt="$(printf '%s' "$rebuilt" \
      | jq --argjson m "$seq_json" '.mutations += [$m]' \
      | _oss_apply_op "$op" "$payload")" || return 4
    i=$((i+1))
  done
  live="$(jq -S . "$sf")"
  if [ "$(printf '%s' "$rebuilt" | jq -S .)" = "$live" ]; then
    echo "replay: clean ($n mutations)"
  else
    echo "replay: DRIFT detected - live state does not equal base+journal ($n mutations). Run 'oss doctor' and repair from journal." >&2
    return 5
  fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-state-replay.sh`
Expected: `pass=3 fail=0`
Also run: `bash ossify/tests/test-state-core.sh` — Expected: still `pass=11 fail=0` (no regression)

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/tests/test-state-replay.sh
git commit -m "feat(ossify): mutation replay + drift detection (Plan A task 4)"
```

---

### Task 5: Schema migration guard + `oss doctor`

**Files:**
- Modify: `ossify/lib/state.sh` (append)
- Create: `ossify/lib/doctor.sh`
- Test: `ossify/tests/test-doctor.sh`

**Interfaces:**
- Produces: `oss_state_check_version <state-file>` — rc 0 if `schema_version == 1`; rc 6 + "state schema vN requires a newer ossify" if newer; rc 6 if missing/invalid. Migration registry lives here: future v1→v2 migrations are added as `_oss_migrate_1_to_2` cases (policy per §9.2 — no silent upgrades; doctor names the needed migration). `oss_cmd_doctor [state-file]` — runs: version check, stale-lock check (lock dir older than 30 min → warn with removal hint), replay drift check, required-keys check; prints one line per check `ok|warn|fail: <name> - <detail>`; rc 0 only if no `fail`.

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-doctor.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
. "$HERE/../lib/doctor.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; S="$TMP/state.json"

oss_state_init "$S" doc-demo >/dev/null

t_capture "$OSS" doctor "$S"
t_assert_rc 0 "doctor green on fresh state"
t_assert_contains "$T_OUT" "ok: schema" "version check reported"
t_assert_contains "$T_OUT" "ok: replay" "drift check reported"

jq '.schema_version = 99' "$S" > "$S.x" && mv "$S.x" "$S"
t_capture "$OSS" doctor "$S"
t_assert_rc 1 "doctor fails on future schema"
t_assert_contains "$T_OUT" "requires a newer ossify" "upgrade message"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-doctor.sh`
Expected: FAIL (doctor.sh missing)

- [ ] **Step 3: Write the implementation**

Append to `ossify/lib/state.sh`:
```bash
oss_state_check_version() { # $1=state-file
  local v
  v="$(jq -r '.schema_version // empty' "$1" 2>/dev/null)"
  [ -n "$v" ] || { echo "state schema missing/invalid" >&2; return 6; }
  if [ "$v" -gt "$OSS_STATE_SCHEMA_VERSION" ] 2>/dev/null; then
    echo "state schema v$v requires a newer ossify (this build supports v$OSS_STATE_SCHEMA_VERSION)" >&2
    return 6
  fi
  # Migration registry: when v2 exists, dispatch _oss_migrate_1_to_2 here
  # (explicit, journaled, never silent - spec §9.2).
  return 0
}
```

`ossify/lib/doctor.sh`:
```bash
#!/usr/bin/env bash
# oss doctor - state health checks (spec §9.2 + §9.1 doctor entry).

oss_cmd_doctor() { # $1=state-file (optional; default .ossify/project-state.json)
  local sf="${1:-.ossify/project-state.json}" rc=0 out
  [ -f "$sf" ] || { echo "fail: state - not found at $sf"; return 1; }

  if out="$(oss_state_check_version "$sf" 2>&1)"; then
    echo "ok: schema - v$(jq -r '.schema_version' "$sf")"
  else
    echo "fail: schema - $out"; rc=1
  fi

  if [ -d "$sf.lock" ]; then
    if [ -n "$(find "$sf.lock" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
      echo "warn: lock - stale lock dir (>30min): rmdir '$sf.lock' if no ceremony is running"
    else
      echo "warn: lock - held (a ceremony may be mid-mutation)"
    fi
  else
    echo "ok: lock - free"
  fi

  if [ "$rc" -eq 0 ]; then
    if out="$(oss_state_replay "$sf" 2>&1)"; then
      echo "ok: replay - $out"
    else
      echo "fail: replay - $out"; rc=1
    fi
  fi

  local key
  for key in releases spines work_items demo_ledger bones mutations; do
    if ! jq -e --arg k "$key" 'has($k)' "$sf" >/dev/null 2>&1; then
      echo "fail: shape - missing key '$key'"; rc=1
    fi
  done
  [ "$rc" -eq 0 ] && echo "ok: shape - all required keys present"
  return "$rc"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-doctor.sh`
Expected: `pass=6 fail=0`
Also run: `ossify/bin/oss doctor /nonexistent` — Expected: `fail: state - not found...`, exit 1 (dispatcher path exercised)

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/doctor.sh ossify/tests/test-doctor.sh
git commit -m "feat(ossify): schema version guard + oss doctor (Plan A task 5)"
```

---

### Task 6: Entity ops — releases, spines, work items

**Files:**
- Modify: `ossify/lib/state.sh` (extend `_oss_apply_op`)
- Create: `ossify/lib/entities.sh`
- Test: `ossify/tests/test-entities.sh`

**Interfaces:**
- Produces: `oss_entity_add_release <state> <name> <goal>` → prints new id (via `oss_id_next_release`); `oss_entity_add_spine <state> <release-id> <name> <class:bone|flesh> <target_repo>` → prints id; rejects unknown release (rc 7), rejects class not in {bone,flesh} (rc 2); `oss_entity_add_work_item <state> <spine-id> <title>` → prints id, rejects unknown spine (rc 7); `oss_entity_set_spine_class <state> <spine-id> <class> <reason>` (records a class_overrides entry + updates spine — the critic-veto/user-override write path).
- Record shapes: release `{id,name,goal,status:"planned",created_at}`; spine `{id,release,name,class,target_repo,status:"planned",created_at}`; work item `{id,spine,title,status:"planned",created_at}`; class_override `{spine,from,to,reason,at}`.
- Consumes: `oss_id_*` (Task 2), `oss_state_mutate` (Task 3).

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-entities.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/entities.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" ent-demo >/dev/null

t_capture oss_entity_add_release "$S" "Skeleton" "core loop usable end-to-end"
t_assert_rc 0 "release added"; t_assert_eq "r0" "$T_OUT" "first release is r0"

t_capture oss_entity_add_spine "$S" r0 "walking skeleton" bone canonical
t_assert_rc 0 "spine added"; t_assert_eq "r0.s1" "$T_OUT" "spine id"
t_capture oss_entity_add_spine "$S" r9 "ghost" flesh canonical
t_assert_rc 7 "unknown release rejected"
t_capture oss_entity_add_spine "$S" r0 "bad" cartilage canonical
t_assert_rc 2 "invalid class rejected"

t_capture oss_entity_add_work_item "$S" r0.s1 "wire entry point"
t_assert_rc 0 "work item added"; t_assert_eq "r0.s1.w1" "$T_OUT" "wi id"

t_capture oss_entity_set_spine_class "$S" r0.s1 flesh "user override after critic veto discussion"
t_assert_rc 0 "class override applied"
t_capture oss_state_read "$S" '.spines[0].class';            t_assert_eq "flesh" "$T_OUT" "class updated"
t_capture oss_state_read "$S" '.class_overrides | length';   t_assert_eq "1" "$T_OUT" "override recorded"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-entities.sh`
Expected: FAIL (entities.sh missing)

- [ ] **Step 3: Write the implementation**

Extend `_oss_apply_op` in `ossify/lib/state.sh` — add these cases before `*)`:
```bash
    add_release)
      jq --argjson p "$payload" '.releases += [$p]' ;;
    add_spine)
      jq --argjson p "$payload" '.spines += [$p]' ;;
    add_work_item)
      jq --argjson p "$payload" '.work_items += [$p]' ;;
    set_spine_class)
      jq --argjson p "$payload" '
        (.spines[] | select(.id == $p.spine) | .class) = $p.to
        | .class_overrides += [{spine:$p.spine,from:$p.from,to:$p.to,reason:$p.reason,at:$p.at}]' ;;
```

`ossify/lib/entities.sh`:
```bash
#!/usr/bin/env bash
# Entity write paths: thin payload builders over oss_state_mutate.

oss_entity_add_release() { # $1=state $2=name $3=goal
  local sf="$1" id ts
  id="$(oss_id_next_release "$sf")"; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_release \
    "$(jq -n --arg id "$id" --arg n "$2" --arg g "$3" --arg ts "$ts" \
      '{id:$id,name:$n,goal:$g,status:"planned",created_at:$ts}')" || return $?
  echo "$id"
}

oss_entity_add_spine() { # $1=state $2=release-id $3=name $4=class $5=target_repo
  local sf="$1" rel="$2" class="$4" id ts
  case "$class" in bone|flesh) ;; *) echo "oss: class must be bone|flesh" >&2; return 2;; esac
  jq -e --arg r "$rel" '.releases[] | select(.id == $r)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown release '$rel'" >&2; return 7; }
  id="$(oss_id_next_spine "$sf" "$rel")"; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_spine \
    "$(jq -n --arg id "$id" --arg r "$rel" --arg n "$3" --arg c "$class" --arg t "$5" --arg ts "$ts" \
      '{id:$id,release:$r,name:$n,class:$c,target_repo:$t,status:"planned",created_at:$ts}')" || return $?
  echo "$id"
}

oss_entity_add_work_item() { # $1=state $2=spine-id $3=title
  local sf="$1" spine="$2" id ts
  jq -e --arg s "$spine" '.spines[] | select(.id == $s)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  id="$(oss_id_next_work_item "$sf" "$spine")"; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_work_item \
    "$(jq -n --arg id "$id" --arg s "$spine" --arg t "$3" --arg ts "$ts" \
      '{id:$id,spine:$s,title:$t,status:"planned",created_at:$ts}')" || return $?
  echo "$id"
}

oss_entity_set_spine_class() { # $1=state $2=spine-id $3=new-class $4=reason
  local sf="$1" spine="$2" to="$3" from ts
  case "$to" in bone|flesh) ;; *) echo "oss: class must be bone|flesh" >&2; return 2;; esac
  from="$(jq -r --arg s "$spine" '.spines[] | select(.id == $s) | .class // empty' "$sf")"
  [ -n "$from" ] || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  ts="$(_oss_now)"
  oss_state_mutate "$sf" set_spine_class \
    "$(jq -n --arg s "$spine" --arg f "$from" --arg t2 "$to" --arg r "$4" --arg ts "$ts" \
      '{spine:$s,from:$f,to:$t2,reason:$r,at:$ts}')"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-entities.sh`
Expected: `pass=11 fail=0`
Also run: `bash ossify/tests/test-state-replay.sh` — Expected: still green (new ops replay through the same `_oss_apply_op`)

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/entities.sh ossify/tests/test-entities.sh
git commit -m "feat(ossify): release/spine/work-item entity ops + class override path (Plan A task 6)"
```

---

### Task 7: Registry ops — bones, risk gates, fakes, feature map + touch check

**Files:**
- Modify: `ossify/lib/state.sh` (extend `_oss_apply_op`)
- Create: `ossify/lib/registries.sh`
- Test: `ossify/tests/test-registries.sh`

**Interfaces:**
- Produces: `oss_reg_add_bone <state> <adr-ref> <title> <touch-globs-csv> [revisit-trigger]`; `oss_reg_add_risk_gate <state> <name> <touch-globs-csv> <controls-csv>`; `oss_reg_add_fake <state> <boundary> <channel:real|fake|deferred> <reason> <replacement-trigger> <expiry-release>`; `oss_reg_add_feature <state> <name> <value-line> <class-guess> <source>`; `oss_reg_touch_check <state> <path>...` → prints `bone <adr-ref>` / `risk_gate <name>` per match (case-glob match of each path against each touch surface), rc 0 with matches, rc 1 clean. Touch surfaces stored as JSON arrays of glob strings.
- Record shapes: bone `{adr,title,touch:[...],revisit_trigger,at}`; risk_gate `{name,touch:[...],controls:[...],at}`; fake `{boundary,channel,reason,replacement_trigger,expiry_release,status:"active",at}`; feature `{name,value,class_guess,source,at}`.

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-registries.sh`:
```bash
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

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-registries.sh`
Expected: FAIL (registries.sh missing)

- [ ] **Step 3: Write the implementation**

Extend `_oss_apply_op` in `ossify/lib/state.sh` — add cases:
```bash
    add_bone)      jq --argjson p "$payload" '.bones += [$p]' ;;
    add_risk_gate) jq --argjson p "$payload" '.risk_gates += [$p]' ;;
    add_fake)      jq --argjson p "$payload" '.fakes += [$p]' ;;
    add_feature)   jq --argjson p "$payload" '.feature_map += [$p]' ;;
```

`ossify/lib/registries.sh`:
```bash
#!/usr/bin/env bash
# Bones / risk gates / fakes / feature map + touch-surface matching.

_oss_csv_to_json() { printf '%s' "$1" | jq -R 'split(",") | map(gsub("^ +| +$";"")) | map(select(length>0))'; }

oss_reg_add_bone() { # $1=state $2=adr-ref $3=title $4=touch-csv $5=revisit(optional)
  oss_state_mutate "$1" add_bone \
    "$(jq -n --arg adr "$2" --arg t "$3" --argjson touch "$(_oss_csv_to_json "$4")" \
        --arg rv "${5:-}" --arg ts "$(_oss_now)" \
      '{adr:$adr,title:$t,touch:$touch,revisit_trigger:(if $rv=="" then null else $rv end),at:$ts}')"
}

oss_reg_add_risk_gate() { # $1=state $2=name $3=touch-csv $4=controls-csv
  oss_state_mutate "$1" add_risk_gate \
    "$(jq -n --arg n "$2" --argjson touch "$(_oss_csv_to_json "$3")" \
        --argjson c "$(_oss_csv_to_json "$4")" --arg ts "$(_oss_now)" \
      '{name:$n,touch:$touch,controls:$c,at:$ts}')"
}

oss_reg_add_fake() { # $1=state $2=boundary $3=channel $4=reason $5=trigger $6=expiry-release
  case "$3" in real|fake|deferred) ;; *) echo "oss: channel must be real|fake|deferred" >&2; return 2;; esac
  oss_state_mutate "$1" add_fake \
    "$(jq -n --arg b "$2" --arg c "$3" --arg r "$4" --arg tr "$5" --arg ex "$6" --arg ts "$(_oss_now)" \
      '{boundary:$b,channel:$c,reason:$r,replacement_trigger:$tr,expiry_release:$ex,status:"active",at:$ts}')"
}

oss_reg_add_feature() { # $1=state $2=name $3=value $4=class-guess $5=source
  oss_state_mutate "$1" add_feature \
    "$(jq -n --arg n "$2" --arg v "$3" --arg cg "$4" --arg s "$5" --arg ts "$(_oss_now)" \
      '{name:$n,value:$v,class_guess:$cg,source:$s,at:$ts}')"
}

oss_reg_touch_check() { # $1=state $2..=paths ; rc 0 if any match, 1 if clean
  local sf="$1"; shift
  local hit=1 path glob line kind name
  while IFS=$'\t' read -r kind name glob; do
    [ -n "$glob" ] || continue
    for path in "$@"; do
      # shellcheck disable=SC2254
      case "$path" in $glob) echo "$kind $name"; hit=0;; esac
    done
  done < <(
    { jq -r '.bones[] | . as $b | .touch[] | ["bone", $b.adr, .] | @tsv' "$sf" 2>/dev/null || true; }
    { jq -r '.risk_gates[] | . as $g | .touch[] | ["risk_gate", $g.name, .] | @tsv' "$sf" 2>/dev/null || true; }
  ) 
  return "$hit"
}
```

Note on glob semantics: bash `case` treats `src/domain/**` as `src/domain/`+anything (`*` matches `/` in case-globs), which is exactly the intended prefix semantics here — document this in the function if extended. Dedupe of repeated matches is deliberately not done in v1 (callers act on any-match).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-registries.sh`
Expected: `pass=9 fail=0`
Also run: `bash ossify/tests/test-state-replay.sh` — still green.

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/registries.sh ossify/tests/test-registries.sh
git commit -m "feat(ossify): bones/risk-gates/fakes/feature-map registries + touch check (Plan A task 7)"
```

---

### Task 8: Demo ledger ops — add, supersede/retire, quarantine, patch records

**Files:**
- Modify: `ossify/lib/state.sh` (extend `_oss_apply_op`)
- Create: `ossify/lib/ledger.sh`
- Test: `ossify/tests/test-ledger.sh`

**Interfaces:**
- Produces: `oss_ledger_add_auto <state> <spine-id> <text> <command> <expected>` → prints `d<N>` (counter-minted); `expected` grammar: `exit:<n>` or `contains:<string>` (validated, rc 2 otherwise); `oss_ledger_add_user <state> <spine-id> <text> <outcome>` → prints id; **journey floor guard**: rejects (rc 2, message `inspector phrasing banned`) any user-line text starting with `inspect `, `view `, or `open ` (case-insensitive) — the mechanical half of the §5.3 floor; `oss_ledger_supersede <state> <line-id> <by-spine> <reason>` / `oss_ledger_retire <state> <line-id> <by-spine> <reason>` (status change, archived never deleted); `oss_ledger_quarantine <state> <line-id> <reason>`; `oss_ledger_active_auto <state>` → JSON array of active auto lines (runner input, Task 9); `oss_ledger_add_patch <state> <commit-ish> <one-liner>` (patch-lane record).
- Line shape: `{id,type:"auto"|"user",text,command?,expected?,outcome?,source_spine,status:"active"|"superseded"|"retired"|"quarantined",status_reason,status_by,at}`.

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-ledger.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/ledger.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" ledger-demo >/dev/null

t_capture oss_ledger_add_auto "$S" r0.s1 "backtest CLI smoke" "true" "exit:0"
t_assert_rc 0 "auto line added"; t_assert_eq "d1" "$T_OUT" "counter-minted id"
t_capture oss_ledger_add_auto "$S" r0.s1 "bad expected" "true" "somehow:fine"
t_assert_rc 2 "invalid expected grammar rejected"

t_capture oss_ledger_add_user "$S" r0.s1 "Type a strategy idea and run a backtest from the chat panel" "results table visible"
t_assert_rc 0 "user journey line added"; t_assert_eq "d2" "$T_OUT" "second id"
t_capture oss_ledger_add_user "$S" r0.s1 "Inspect the pulse.db schema" "schema visible"
t_assert_rc 2 "inspector phrasing banned"

t_capture oss_ledger_supersede "$S" d1 r1.s2 "flow redesigned"
t_assert_rc 0 "supersede ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'; t_assert_eq "superseded" "$T_OUT" "status archived"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "[]" "$(printf '%s' "$T_OUT" | jq -c .)" "superseded line not active"

t_capture oss_ledger_add_patch "$S" abc1234 "bump serde patch version"
t_assert_rc 0 "patch record added"
t_capture oss_state_read "$S" '.patch_records | length'; t_assert_eq "1" "$T_OUT" "patch recorded"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-ledger.sh`
Expected: FAIL (ledger.sh missing)

- [ ] **Step 3: Write the implementation**

Extend `_oss_apply_op` in `ossify/lib/state.sh` — add cases:
```bash
    add_demo_line)
      jq --argjson p "$payload" '.demo_ledger += [$p] | .counters.demo_line += 1' ;;
    set_demo_line_status)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.status = $p.status | .status_reason = $p.reason | .status_by = $p.by)' ;;
    add_patch_record)
      jq --argjson p "$payload" '.patch_records += [$p]' ;;
```

`ossify/lib/ledger.sh`:
```bash
#!/usr/bin/env bash
# Cumulative product demo ledger (spec §3, §6.1) + patch lane records.

_oss_ledger_next_id() { echo "d$(( $(jq -r '.counters.demo_line' "$1") + 1 ))"; }

oss_ledger_add_auto() { # $1=state $2=spine $3=text $4=command $5=expected
  case "$5" in exit:[0-9]*|contains:?*) ;; *)
    echo "oss: expected must be 'exit:<n>' or 'contains:<str>'" >&2; return 2;; esac
  local id; id="$(_oss_ledger_next_id "$1")"
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg id "$id" --arg s "$2" --arg t "$3" --arg c "$4" --arg e "$5" --arg ts "$(_oss_now)" \
      '{id:$id,type:"auto",text:$t,command:$c,expected:$e,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" || return $?
  echo "$id"
}

oss_ledger_add_user() { # $1=state $2=spine $3=text $4=outcome
  local lower
  lower="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in inspect\ *|view\ *|open\ *)
    echo "oss: inspector phrasing banned in user journey lines (spec §5.3 floor) - phrase as an action the user performs for value" >&2
    return 2;; esac
  local id; id="$(_oss_ledger_next_id "$1")"
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg id "$id" --arg s "$2" --arg t "$3" --arg o "$4" --arg ts "$(_oss_now)" \
      '{id:$id,type:"user",text:$t,outcome:$o,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" || return $?
  echo "$id"
}

_oss_ledger_set_status() { # $1=state $2=line-id $3=status $4=by $5=reason
  jq -e --arg id "$2" '.demo_ledger[] | select(.id == $id)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown demo line '$2'" >&2; return 7; }
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg st "$3" --arg by "$4" --arg r "$5" \
      '{id:$id,status:$st,by:$by,reason:$r}')"
}
oss_ledger_supersede()  { _oss_ledger_set_status "$1" "$2" superseded "$3" "$4"; }
oss_ledger_retire()     { _oss_ledger_set_status "$1" "$2" retired "$3" "$4"; }
oss_ledger_quarantine() { _oss_ledger_set_status "$1" "$2" quarantined "quarantine" "$3"; }

oss_ledger_active_auto() { jq '[.demo_ledger[] | select(.type == "auto" and .status == "active")]' "$1"; }

oss_ledger_add_patch() { # $1=state $2=commit $3=one-liner
  oss_state_mutate "$1" add_patch_record \
    "$(jq -n --arg c "$2" --arg t "$3" --arg ts "$(_oss_now)" '{commit:$c,text:$t,at:$ts}')"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-ledger.sh`
Expected: `pass=12 fail=0`
Also run: `bash ossify/tests/test-state-replay.sh` — still green.

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/ledger.sh ossify/tests/test-ledger.sh
git commit -m "feat(ossify): demo ledger ops - floor guard, supersede/retire/quarantine, patch lane records (Plan A task 8)"
```

---

### Task 9: Auto-demo runner with halt-on-first-fail + vacuous-green guard

**Files:**
- Create: `ossify/lib/demo.sh`
- Test: `ossify/tests/test-demo-runner.sh`

**Interfaces:**
- Produces: `oss_cmd_demo_run <state-file>` (dispatcher-exposed) / `oss_demo_run_auto <state-file>` — iterates `oss_ledger_active_auto` lines in id order; per line: `bash -c "$command"` (captured), evaluate `expected` (`exit:<n>` → rc equality; `contains:<s>` → substring); **halt on first fail** (prints `FAIL <id> - <text>` + captured output tail, rc 1); **vacuous-green guard**: if command matches a recognized test runner (`pytest|cargo test|npm test|go test|bash .*test`) AND output matches a zero-tests pattern (`collected 0 items|running 0 tests|0 passing|no tests to run`), the line FAILS as `vacuous-green` even on exit 0. All pass → `PASS <n> lines`, rc 0. Quarantined lines reported as `SKIP (quarantined)`.
- Consumes: `oss_ledger_active_auto` (Task 8).

- [ ] **Step 1: Write the failing test**

`ossify/tests/test-demo-runner.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/ledger.sh"; . "$HERE/../lib/demo.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" demo-run >/dev/null

oss_ledger_add_auto "$S" r0.s1 "always true" "true" "exit:0" >/dev/null
oss_ledger_add_auto "$S" r0.s1 "greets" "echo hello-world" "contains:hello" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "all green"; t_assert_contains "$T_OUT" "PASS 2" "pass count"

oss_ledger_add_auto "$S" r0.s1 "always false" "false" "exit:0" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "halt on first fail"; t_assert_contains "$T_OUT" "FAIL d3" "failing line named"

oss_ledger_quarantine "$S" d3 "flaky env, fix by r1 close" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "quarantined line skipped"; t_assert_contains "$T_OUT" "SKIP" "skip reported"

oss_ledger_add_auto "$S" r0.s1 "vacuous suite" "echo 'collected 0 items'; true" "exit:0" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "vacuous green caught"; t_assert_contains "$T_OUT" "vacuous-green" "guard named"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-demo-runner.sh`
Expected: FAIL (demo.sh missing)

- [ ] **Step 3: Write the implementation**

`ossify/lib/demo.sh`:
```bash
#!/usr/bin/env bash
# Cumulative auto-demo runner (spec §6.1 core row). Halt-on-first-fail.

_oss_demo_zero_tests() { # $1=output ; rc 0 if vacuous
  printf '%s' "$1" | { grep -Eq 'collected 0 items|running 0 tests|0 passing|no tests to run' || return 1; }
}
_oss_demo_is_runner() { # $1=command
  printf '%s' "$1" | { grep -Eq 'pytest|cargo test|npm test|go test|bash .*test' || return 1; }
}

oss_demo_run_auto() { # $1=state-file
  local sf="$1" n i line id text cmd expected out rc passed=0
  n="$(jq '[.demo_ledger[] | select(.type=="auto" and (.status=="active" or .status=="quarantined"))] | length' "$sf")"
  i=0
  while [ "$i" -lt "$n" ]; do
    line="$(jq -c "[.demo_ledger[] | select(.type==\"auto\" and (.status==\"active\" or .status==\"quarantined\"))][$i]" "$sf")"
    id="$(printf '%s' "$line" | jq -r '.id')"
    text="$(printf '%s' "$line" | jq -r '.text')"
    if [ "$(printf '%s' "$line" | jq -r '.status')" = "quarantined" ]; then
      echo "SKIP $id (quarantined) - $text"
      i=$((i+1)); continue
    fi
    cmd="$(printf '%s' "$line" | jq -r '.command')"
    expected="$(printf '%s' "$line" | jq -r '.expected')"
    set +e; out="$(bash -c "$cmd" 2>&1)"; rc=$?; set -e 2>/dev/null || true
    case "$expected" in
      exit:*)
        if [ "$rc" -ne "${expected#exit:}" ]; then
          echo "FAIL $id - $text (rc=$rc, wanted ${expected#exit:})"; printf '%s\n' "$out" | tail -5; return 1
        fi ;;
      contains:*)
        case "$out" in *"${expected#contains:}"*) ;; *)
          echo "FAIL $id - $text (output missing '${expected#contains:}')"; printf '%s\n' "$out" | tail -5; return 1;; esac ;;
    esac
    if _oss_demo_is_runner "$cmd" && _oss_demo_zero_tests "$out"; then
      echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
    fi
    passed=$((passed+1)); i=$((i+1))
  done
  echo "PASS $passed lines"
}

oss_cmd_demo_run() { oss_demo_run_auto "${1:-.ossify/project-state.json}"; }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-demo-runner.sh`
Expected: `pass=8 fail=0`
Also run: `ossify/bin/oss demo_run /nonexistent 2>&1; echo rc=$?` — Expected: jq error surfaced, nonzero rc (dispatcher path exercised under strict mode)

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/demo.sh ossify/tests/test-demo-runner.sh
git commit -m "feat(ossify): auto-demo runner - halt-on-first-fail, quarantine skip, vacuous-green guard (Plan A task 9)"
```

---

### Task 10: Integration verification — full suites + end-to-end fixture walk

**Files:**
- Create: `ossify/tests/test-integration.sh`
- Modify: none

**Interfaces:**
- Consumes: everything above, through the dispatcher and libs together.

- [ ] **Step 1: Write the integration test (end-to-end fixture project)**

`ossify/tests/test-integration.sh`:
```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/entities.sh"
. "$HERE/../lib/registries.sh"; . "$HERE/../lib/ledger.sh"; . "$HERE/../lib/demo.sh"; . "$HERE/../lib/doctor.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; S="$TMP/.ossify/project-state.json"

# Fixture: a skeleton-first project from init to a passing cumulative demo.
oss_state_init "$S" fixture >/dev/null
R="$(oss_entity_add_release "$S" "Skeleton" "core loop usable")"
SP="$(oss_entity_add_spine "$S" "$R" "walking skeleton" bone canonical)"
oss_entity_add_work_item "$S" "$SP" "wire the entry point" >/dev/null
oss_reg_add_bone "$S" ADR-0002 "domain boundary" "src/domain/**" "" >/dev/null
oss_reg_add_fake "$S" coach fake "shell for skeleton" "first refinement" r1 >/dev/null
oss_ledger_add_auto "$S" "$SP" "golden journey" "echo journey-ok" "contains:journey-ok" >/dev/null
oss_ledger_add_user "$S" "$SP" "Run a backtest from the chat panel" "results visible" >/dev/null

t_capture oss_demo_run_auto "$S";  t_assert_rc 0 "fixture demo green"
t_capture "$OSS" doctor "$S";      t_assert_rc 0 "doctor green on full fixture"
t_capture oss_state_replay "$S";   t_assert_rc 0 "full fixture replays clean"
t_capture oss_reg_touch_check "$S" src/domain/x.rs; t_assert_rc 0 "touch check hits bone"

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run the whole ossify suite**

Run: `bash ossify/tests/run-all.sh`
Expected: `ALL GREEN` (all 8 test files)

- [ ] **Step 3: Run the repo root suite (full-suite rule — never just the new suites)**

Run: `for t in tests/test-*.sh; do bash "$t" || echo "ROOT-FAIL: $t"; done`
Expected: no `ROOT-FAIL` lines. The dual-publish/version-parity tests must not pick up ossify (it is not in marketplace.json yet); if any root test globs plugin dirs and trips on ossify, fix the exclusion in THIS task and note it in the commit message.

- [ ] **Step 4: Commit**

```bash
git add ossify/tests/test-integration.sh
git commit -m "feat(ossify): end-to-end fixture integration test; Plan A complete (task 10)"
```

---

## Self-Review (performed at authoring)

1. **Spec coverage (Plan A scope = state engine + primitives):** §9.2 state-safety commitments → Tasks 3-5 (atomic ✓ lock ✓ journal+replay ✓ schema_version+migration-guard ✓ doctor drift ✓); OQ7 ID grammar → Task 2 (single owner, no VS- collision, parity via lib reuse); OQ3 field detail → Task 3 state shape; §6.1 demo core row primitives → Tasks 8-9 (floor guard, amendments, quarantine, halt-on-first-fail, zero-tests guard); §5.3 floor rules (mechanical half) → Task 8; §7 touch surfaces → Task 7; patch lane record → Task 8. Ceremonies, skills, boundary, evals: Plans B-D by design (series map).
2. **Placeholder scan:** no TBDs; every step carries runnable code/commands. One deliberate deferral is *named as such*: state-path resolution via manifest is Plan B scope (functions take explicit paths).
3. **Type consistency:** all state ops route through `_oss_apply_op` (mutate + replay share it — checked each task extends both paths by extending the one function); `oss_ledger_active_auto` consumed by Task 9 matches Task 8's definition; id functions consumed in Tasks 6-8 match Task 2 signatures; rc conventions: 1 generic, 2 usage, 3 lock, 4 apply-failure, 5 drift, 6 schema, 7 unknown-ref.
