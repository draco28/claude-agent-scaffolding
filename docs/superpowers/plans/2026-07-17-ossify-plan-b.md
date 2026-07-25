# ossify Plan B — Onboarding + Planning Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ossify's first three entry skills — `start` (spec-core onboarding), `plan-release` (release planning + fail-closed critic veto), `plan-spine` (spine decomposition + demo authoring) — on top of the Plan A state engine, plus the code substrate they shell out to (manifest/state-path resolution, ID-mint-inside-lock fix, dispatcher subcommands, release-planning ops) and the planning-judge eval fixtures.

**Architecture:** Skills are ceremony prose (SKILL.md ≤~500 lines + `references/*.md` progressive disclosure + thin `commands/<short>.md` wrappers) that shell out to the `oss` bash dispatcher for all state mutation. Mechanical facts stay in the tested dispatcher; judgment lives in the skill prose and is eval-gated. `_oss_apply_op` remains the single pure-jq transform shared by mutate + replay; every new op lands there and only there.

**Tech Stack:** bash (BSD/macOS-compatible), jq, git. Markdown skills. No new dependencies.

## Global Constraints

*(Plan A's block, carried verbatim, plus Plan B additions. Every task's requirements implicitly include this section.)*

- Specs of record: `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` (§9.2 state-safety commitments are BINDING; Plan B scope = §4–§5, §9.1) + `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` (§3). Doctrine: `docs/conventions/evolutionary-architecture-playbook.md`.
- Dispatcher runs `set -euo pipefail`; every lib function must survive strict mode — guard all no-match greps with `|| true`, guard bare `x="$(cmd)"` that can fail (esp. anything between lock-acquire and lock-release — an unguarded failure there leaks the lock permanently), and test through the dispatcher path, not only by sourcing.
- BSD/macOS portability: `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamps (no GNU flags); `mkdir`-based locks (atomic on all POSIX filesystems); no `readarray`, no `grep -P`. Test harness runs each file under `bash` (zsh errexit/NOMATCH differs).
- ID grammar (single owner, `lib/id.sh`): release `r<N>` (`^r[0-9]+$`), spine `r<N>.s<K>` (`^r[0-9]+\.s[0-9]+$`), work item `r<N>.s<K>.w<J>` (`^r[0-9]+\.s[0-9]+\.w[0-9]+$`); branch `spine/<spine-id>-<kebab-slug>`; release dir `docs/specs/<release-id>/`; demo-line ids `d<N>` from `.counters.demo_line`. No `VS-` shapes.
- `_oss_apply_op` ops MUST be pure deterministic jq transforms (both mutate and replay route through them). IDs/timestamps are baked into the payload BEFORE journaling so replay reproduces them verbatim; **Plan B's B1 mint change keeps the id in the journaled payload and does NOT re-derive ids inside `_oss_apply_op` — so the mint change leaves `_oss_apply_op` and the journal format unchanged. New ops (B3/B4: `set_composition`, `set_overlay`, `set_release_meta`, `add_veto_disposition`) are added ADDITIVELY as pure jq cases per gotcha #7 and covered by new replay tests (`test-concurrency.sh`, `test-release-planning.sh`).**
- rc taxonomy (do not introduce overlapping codes): 1 generic, 2 usage, 3 lock, 4 apply-failure, 5 drift, 6 schema, 7 unknown-ref.
- All state functions take the state-file path as their FIRST argument (no cwd guessing; test-friendly). Skills resolve the path via `oss`'s manifest wiring (Task B2). Canonical location: `<ai_workspace>/.ossify/project-state.json`.
- Skill conventions: gerund skill dirs (`starting-project`, `planning-release`, `planning-spine`); SKILL.md frontmatter = `name` + `description` only (description embeds trigger phrases + slash token + a negative-scope clause); depth → `references/*.md` pointed at by a "Full X in `references/<f>.md`" sentence; thin `commands/<short>.md` wrappers use the `ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '...'` env-var bridge (NEVER `$1`/`$2`) then `Skill(ossify:<gerund>)`; skills shell out via `oss <subcommand>` (bin auto-on-`$PATH`, bash-shebang self-locating). SKILL bodies ≤~500 lines; all ceremony depth in `references/` (zero listing cost).
- ossify is NOT registered in `.claude-plugin/marketplace.json` and gets NO `.codex-plugin` manifest in Plan B (ship gate is Plan D; avoids surfacing a half-built plugin and avoids tripping the repo-root parity suite, which reads only registered plugins + a hardcoded `V0_PLUGINS`).
- Critic-veto (§5.2.3) and bone-touch (§6.1) are implemented PLUGIN-SIDE by interpreting standard `architect-critic:critiquing-spec` findings — architect-critic gains NO new interface (§12).
- Work on branch `feat/ossify-core` (stacks on Plan A). Commit per task with `git add ossify/... docs/...` (explicit paths, NEVER `git add -A`; unrelated files live in the tree). The `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer is fine in this repo (no commit-msg hook). All tests green via `bash ossify/tests/run-all.sh` AND the repo-root suite before the final task completes.

## Series map (Plans C–D, sketched — detailed after their predecessor ships)

- **Plan C — execution + close:** work-item execution port (implementer contract unchanged), `close` router (work-item → spine bone/flesh checklists → release), ledger `user:` walkthrough + amendments + release close (pin/publish, docs-increment trigger table, fake-expiry enforcement as a blocking close finding, boundary-audit hook point), memory-bank harvest port, patch-lane mechanics, utility commands port (/handoff, /defer, /work-pr, /adr, /flip-adr, /amend-spec, /changelog, /runbook), pr_hierarchical port. Spec: ossify §6–§8.
- **Plan D — boundary + ship gate:** workspace-init additive extension (visibility fields, `private_core`, resolvers, `add-private-core`), multi-repo worktrees + cross-repo dependency overrides, boundary audit, consolidated eval suite (THE ship gate, spec §13.4), marketplace registration + `.codex-plugin` manifest + `V0_PLUGINS` entry, Forge3D greenfield pilot + pulse-trader adopt-forward. Spec: companion §4–§6; ossify §10, §13.4.

---

### Task 1 (B1): ID-mint-inside-lock (close the one real concurrency gap)

**Context:** Plan A's final review flagged that `oss_id_next_*` and `_oss_ledger_next_id` read the counter/arrays OUTSIDE the mutate lock, then the mutate acquires the lock — so two concurrent ceremonies can mint the same id (handoff §5). Fix: mint the id INSIDE the locked critical section by reusing the existing derivation helpers, and inject the minted id into the payload *before* journaling. `_oss_apply_op` and the journal format are unchanged (the payload still carries the id verbatim), so replay stays byte-identical — this is strictly safer than re-deriving ids inside `_oss_apply_op`.

**Files:**
- Modify: `ossify/lib/state.sh` (`oss_state_mutate`, `_oss_state_mutate_body`; add `_oss_mint_id`)
- Modify: `ossify/lib/entities.sh` (`oss_entity_add_release`, `oss_entity_add_spine`, `oss_entity_add_work_item` — drop pre-lock id read, pass a mint spec)
- Modify: `ossify/lib/ledger.sh` (`oss_ledger_add_auto`, `oss_ledger_add_user` — drop `_oss_ledger_next_id`, pass `demo` mint spec)
- Create: `ossify/tests/test-concurrency.sh` (this file carries the mint-path replay coverage — do NOT append it to `test-state-replay.sh`, whose body tampers the live state + deletes the base snapshot before its tail)

**Interfaces:**
- Produces: `oss_state_mutate <state-file> <op> <payload-json> [<mint-spec>]` — when `<mint-spec>` is non-empty, mints an id inside the lock, injects it into the payload as `.id`, and echoes the minted id on stdout (success only). Mint specs: `release`, `spine:<release-id>`, `work_item:<spine-id>`, `demo`.
- Produces: `_oss_mint_id <state-file> <mint-spec>` — prints the id, rc 4 on unknown spec.
- Consumes: existing `oss_id_next_release/oss_id_next_spine/oss_id_next_work_item` (from `lib/id.sh`) — now called INSIDE the lock. They remain pure read helpers, still usable by skills/tests for previews.
- Entity/ledger functions now build payloads WITHOUT `.id` and pass the mint spec; they return the minted id via `oss_state_mutate`'s stdout passthrough.

- [ ] **Step 1: Write the failing test** — `ossify/tests/test-concurrency.sh`

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-concurrency.sh`
Expected: FAIL — against current code `oss_state_mutate` ignores the 4th arg, so the first release is stored with `id:"r99"` and stdout is empty; `t_assert_eq "r0" "$T_OUT"` and the stored-id assertion both fail.

- [ ] **Step 3: Write the implementation**

In `ossify/lib/state.sh`, add `_oss_mint_id` (place it just above `oss_state_mutate`), and replace `oss_state_mutate` + `_oss_state_mutate_body` with the mint-aware versions:

```bash
# Mint a sequential id from the CURRENT (locked) state. Reuses the Plan A
# derivation helpers verbatim — the only change from Plan A is the call site:
# these now run INSIDE the mutate lock (state is stable), so two concurrent
# ceremonies cannot read the same max/counter and mint a duplicate id.
_oss_mint_id() { # $1=state-file $2=mint-spec (release | spine:<rel> | work_item:<spine> | demo)
  local sf="$1" spec="$2" kind parent
  kind="${spec%%:*}"; parent="${spec#*:}"; [ "$parent" = "$spec" ] && parent=""
  case "$kind" in
    release)   oss_id_next_release "$sf" ;;
    spine)     oss_id_next_spine "$sf" "$parent" ;;
    work_item) oss_id_next_work_item "$sf" "$parent" ;;
    demo)      echo "d$(( $(jq -r '.counters.demo_line' "$sf" 2>/dev/null || echo 0) + 1 ))" ;;
    *)         echo "oss: unknown mint spec '$spec'" >&2; return 4 ;;
  esac
}

oss_state_mutate() { # $1=state-file $2=op $3=payload-json [$4=mint-spec]
  local sf="$1" op="$2" payload="$3" mint="${4:-}" lock="$1.lock" rc=0
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating; retry or run 'oss doctor'" >&2
    return 3
  fi
  # Critical section runs as a body function invoked in `|| rc=$?` context:
  # errexit is SUSPENDED for the whole body, so no bare command-substitution
  # inside it can hard-exit and leak the lock. The body echoes the minted id
  # (if any) to stdout on success; that stdout flows through this function.
  _oss_state_mutate_body "$sf" "$op" "$payload" "$mint" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

# Critical-section body. rc 0 ok, 4 on any failure. NO lock logic here - the
# wrapper owns lock acquire/release. Minting happens here (inside the lock);
# the minted id is injected into the payload BEFORE journaling so the journal
# format and _oss_apply_op are unchanged (replay stays byte-identical).
_oss_state_mutate_body() { # $1=state-file $2=op $3=payload $4=mint-spec
  local sf="$1" op="$2" payload="$3" mint="${4:-}" tmp seq ts minted_id=""
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 4
  if [ -n "$mint" ]; then
    minted_id="$(_oss_mint_id "$sf" "$mint")" || { rm -f "$tmp"; return 4; }
    [ -n "$minted_id" ] || { rm -f "$tmp"; echo "oss: id minting produced empty id" >&2; return 4; }
    # Inject the minted id, overriding any caller-supplied id (a caller can
    # never win a race by pre-baking an id).
    payload="$(printf '%s' "$payload" | jq -c --arg id "$minted_id" '. + {id:$id}')" \
      || { rm -f "$tmp"; return 4; }
  fi
  seq="$(jq '.mutations | length' "$sf" 2>/dev/null)" || { rm -f "$tmp"; return 4; }
  ts="$(_oss_now)" || { rm -f "$tmp"; return 4; }
  # journal append + effect in ONE jq pipeline into ONE $tmp, committed by a
  # single mv - mutation and journal entry commit atomically.
  if ! jq --arg op "$op" --arg ts "$ts" --argjson seq "$seq" --argjson payload "$payload" \
      '.mutations += [{seq:$seq,op:$op,ts:$ts,payload:$payload}]' "$sf" \
      | _oss_apply_op "$op" "$payload" > "$tmp"; then
    rm -f "$tmp"; return 4
  fi
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "oss: mutation produced invalid state; aborted (original untouched)" >&2
    return 4
  fi
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 4; }
  # Report the minted id (success only). Explicit `return 0`: a bare
  # `[ -n "$minted_id" ] && printf ...` as the last line would make the
  # function return 1 for non-mint ops (empty minted_id) - a false failure.
  [ -n "$minted_id" ] && printf '%s\n' "$minted_id"
  return 0
}
```

In `ossify/lib/entities.sh`, change the three minting entity functions to build id-less payloads and pass a mint spec (leave `oss_entity_set_spine_class` unchanged — it is not a sequential-id minter):

```bash
oss_entity_add_release() { # $1=state $2=name $3=goal
  local sf="$1" ts; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_release \
    "$(jq -n --arg n "$2" --arg g "$3" --arg ts "$ts" \
      '{name:$n,goal:$g,status:"planned",created_at:$ts}')" \
    release
}

oss_entity_add_spine() { # $1=state $2=release-id $3=name $4=class $5=target_repo
  local sf="$1" rel="$2" class="$4" ts
  case "$class" in bone|flesh) ;; *) echo "oss: class must be bone|flesh" >&2; return 2;; esac
  jq -e --arg r "$rel" '.releases[] | select(.id == $r)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown release '$rel'" >&2; return 7; }
  ts="$(_oss_now)"
  oss_state_mutate "$sf" add_spine \
    "$(jq -n --arg r "$rel" --arg n "$3" --arg c "$class" --arg t "$5" --arg ts "$ts" \
      '{release:$r,name:$n,class:$c,target_repo:$t,status:"planned",created_at:$ts}')" \
    "spine:$rel"
}

oss_entity_add_work_item() { # $1=state $2=spine-id $3=title
  local sf="$1" spine="$2" ts
  jq -e --arg s "$spine" '.spines[] | select(.id == $s)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  ts="$(_oss_now)"
  oss_state_mutate "$sf" add_work_item \
    "$(jq -n --arg s "$spine" --arg t "$3" --arg ts "$ts" \
      '{spine:$s,title:$t,status:"planned",created_at:$ts}')" \
    "work_item:$spine"
}
```

In `ossify/lib/ledger.sh`, remove `_oss_ledger_next_id` and change the two adders to pass the `demo` mint spec (leave supersede/retire/quarantine/add_patch unchanged — no sequential id):

```bash
oss_ledger_add_auto() { # $1=state $2=spine $3=text $4=command $5=expected
  case "$5" in exit:[0-9]*|contains:?*) ;; *)
    echo "oss: expected must be 'exit:<n>' or 'contains:<str>'" >&2; return 2;; esac
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg s "$2" --arg t "$3" --arg c "$4" --arg e "$5" --arg ts "$(_oss_now)" \
      '{type:"auto",text:$t,command:$c,expected:$e,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" \
    demo
}

oss_ledger_add_user() { # $1=state $2=spine $3=text $4=outcome
  local lower
  lower="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"
  lower="${lower#"${lower%%[![:space:]]*}"}"   # trim leading whitespace so " Open ..." can't evade the ban
  case "$lower" in inspect\ *|view\ *|open\ *)
    echo "oss: inspector phrasing banned in user journey lines (spec §5.3 floor) - phrase as an action the user performs for value" >&2
    return 2;; esac
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg s "$2" --arg t "$3" --arg o "$4" --arg ts "$(_oss_now)" \
      '{type:"user",text:$t,outcome:$o,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" \
    demo
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-concurrency.sh`
Expected: `pass=N fail=0` (proves the server-side mint overrides a stale caller id, distinct r0/r1, demo-counter mint, AND replay-clean over the full mint path — this file is the mint-path replay guard).
Then regression-run the suites the mint change touches — all must be unchanged (the fix is happy-path-preserving; the EXISTING `test-state-replay.sh` uses only non-mint `set_posture`, so it stays green as-is):
Run: `bash ossify/tests/test-state-replay.sh && bash ossify/tests/test-entities.sh && bash ossify/tests/test-ledger.sh && bash ossify/tests/test-integration.sh`
Expected: all `pass=N fail=0`.

> **Do NOT append replay assertions to `test-state-replay.sh`.** Its body tampers the live state to force drift (never restored) and deletes the base snapshot before its tail, so any appended `replay-clean` (rc 0) assertion would instead return rc 5 / rc 1 and red the suite. Mint-path replay is covered in `test-concurrency.sh` (this task) and `test-release-planning.sh` (B4).

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/entities.sh ossify/lib/ledger.sh ossify/tests/test-concurrency.sh
git commit -m "feat(ossify): mint ids inside the mutate lock - close concurrency gap (Plan B task 1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2 (B2): Manifest / state-path resolution (Plan A's named deferral)

**Context:** Plan A left path resolution to Plan B ("Callers resolve the path … resolution lands in Plan B with manifest wiring"). Port scaffold-dev's manifest discovery + resolver (`scaffold-dev/lib/manifest.sh`, `scaffold-dev/lib/roadmap.sh::sd_roadmap_state_path`), targeting the ossify convention `<ai_workspace.root>/.ossify/project-state.json`. **Crucial:** the upstream resolvers pass an unknown `${x.root}` token through as a literal broken path (the companion §1 "silent-literal" trap); the only upstream guard is `sd_roadmap_state_path`'s `*'${'*` check — ossify's resolver MUST include that guard. Reads the EXISTING pairing manifest only; never writes it, and knows nothing of `${private_core.root}` (Plan D).

**Files:**
- Create: `ossify/lib/manifest.sh`
- Create: `ossify/tests/test-manifest.sh`

**Interfaces:**
- Produces: `oss_manifest_discover` (echoes abs path to `.workspace/pairing.json`, rc 1 if none); `oss_manifest_get <jq-expr>` (rc 1 if no manifest/null); `oss_manifest_require` (rc 0 if manifest on walk-up path, else 1 + refusal); `oss_manifest_state_path` (echoes `<ai_workspace.root>/.ossify/project-state.json`, honoring an optional `.well_known_paths.project_state`, refusing unresolved `${...}`); `_oss_resolve_state [explicit-path]` (precedence: explicit arg > `$OSS_STATE_FILE` > manifest-derived); `oss_cmd_state_path` (dispatcher subcommand).
- Consumes: none (uses `jq`, `$PWD`, `$HOME`, `$USER`).
- The refusal string constant `OSS_MANIFEST_REFUSAL` keeps the load-bearing `/init-workspace` + `/pair-workspace` tokens verbatim.

- [ ] **Step 1: Write the failing test** — `ossify/tests/test-manifest.sh`

```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/manifest.sh"
TMP="$(mktemp -d)"

# Fixture workspace with a pairing manifest at .workspace/pairing.json.
mkdir -p "$TMP/ws/.workspace"
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON

# Discovery + convention default (walk up from a nested dir).
mkdir -p "$TMP/ws/sub/deep"
( cd "$TMP/ws/sub/deep"
  t_capture oss_manifest_discover
  t_assert_rc 0 "manifest discovered from nested dir"
  t_assert_eq "$TMP/ws/.workspace/pairing.json" "$T_OUT" "discovered path"
  t_capture oss_manifest_state_path
  t_assert_rc 0 "state path resolved"
  t_assert_eq "$TMP/ws/.ossify/project-state.json" "$T_OUT" "convention default state path"
)

# Honor an explicit well_known_paths.project_state with a resolvable token.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"\${ai_workspace.root}/.ossify/ps.json"}}
JSON
( cd "$TMP/ws"
  t_capture oss_manifest_state_path
  t_assert_rc 0 "routed state path resolved"
  t_assert_eq "$TMP/ws/.ossify/ps.json" "$T_OUT" "routed path token resolved"
)

# The silent-literal trap: an UNKNOWN token must be refused, not passed through.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"\${private_core.root}/ps.json"}}
JSON
( cd "$TMP/ws"
  t_capture oss_manifest_state_path
  t_assert_rc 1 "unresolved token refused (not passed through as literal)"
  t_assert_contains "$T_OUT" "unresolved" "refusal names the unresolved path"
)

# No manifest anywhere → require refuses with both slash-command tokens.
( cd "$TMP"
  t_capture oss_manifest_require
  t_assert_rc 1 "require refuses when no manifest"
  t_assert_contains "$T_OUT" "/init-workspace" "refusal keeps /init-workspace token"
  t_assert_contains "$T_OUT" "/pair-workspace" "refusal keeps /pair-workspace token"
)

# _oss_resolve_state precedence: explicit > OSS_STATE_FILE.
t_capture _oss_resolve_state "/explicit/x.json"
t_assert_eq "/explicit/x.json" "$T_OUT" "explicit path wins"
( export OSS_STATE_FILE="/env/y.json"; t_capture _oss_resolve_state
  t_assert_eq "/env/y.json" "$T_OUT" "OSS_STATE_FILE used when no explicit path" )

rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-manifest.sh`
Expected: FAIL — `ossify/lib/manifest.sh` does not exist / functions undefined.

- [ ] **Step 3: Write the implementation** — `ossify/lib/manifest.sh`

```bash
#!/usr/bin/env bash
# Manifest / state-path resolution for ossify. Ports scaffold-dev's manifest
# discovery + resolver, and adds the unresolved-token guard the companion §1
# "silent-literal-path" trap requires. Reads the EXISTING workspace-init
# pairing manifest (<ai-root>/.workspace/pairing.json); never writes it.

OSS_MANIFEST_REFUSAL="ossify requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."

# Walk up from $PWD to find .workspace/pairing.json. Echoes the abs path; rc 1.
oss_manifest_discover() {
  local dir="$PWD"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/.workspace/pairing.json" ]; then
      echo "$dir/.workspace/pairing.json"; return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Read a jq expression from the discovered manifest. rc 1 if no manifest / null.
oss_manifest_get() { # $1=jq-expr
  local expr="$1" manifest out
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  out="$(jq -r "${expr} // empty" "$manifest" 2>/dev/null)"
  [ -n "$out" ] || return 1
  echo "$out"
}

# Refuse to proceed when no manifest is on the walk-up path (skills call early).
oss_manifest_require() {
  oss_manifest_discover >/dev/null 2>&1 && return 0
  echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1
}

# Resolve the two root tokens + ${HOME}/${USER} in a string. Unknown ${x} tokens
# are LEFT IN PLACE (matching the upstream resolvers) - the CALLER detects them.
_oss_manifest_resolve() { # $1=ai-root $2=string
  local ai_root="$1" result="$2" manifest="$1/.workspace/pairing.json" aw cn
  [ -f "$manifest" ] || { echo "oss: manifest not found at $manifest" >&2; return 1; }
  aw="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  cn="$(jq -r '.canonical.root // empty' "$manifest" 2>/dev/null)"
  [ -n "$aw" ] && result="${result//\$\{ai_workspace.root\}/$aw}"
  [ -n "$cn" ] && result="${result//\$\{canonical.root\}/$cn}"
  result="${result//\$\{HOME\}/$HOME}"
  result="${result//\$\{USER\}/${USER:-$(id -un 2>/dev/null)}}"
  echo "$result"
}

# Resolve the ossify state-file path. Honors an optional
# .well_known_paths.project_state key (Plan D may add it); else derives by
# convention <ai_workspace.root>/.ossify/project-state.json. Closes the
# silent-literal trap: refuses any path still holding an unresolved ${...}.
# Echoes the path (the file itself may not exist yet).
oss_manifest_state_path() {
  local manifest ai_root routed dest
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  [ -n "$ai_root" ] || { echo "oss: manifest missing ai_workspace.root" >&2; return 1; }
  ai_root="${ai_root//\$\{HOME\}/$HOME}"
  ai_root="${ai_root//\$\{USER\}/${USER:-$(id -un 2>/dev/null)}}"
  routed="$(jq -r '.well_known_paths.project_state // empty' "$manifest" 2>/dev/null)"
  if [ -n "$routed" ]; then
    dest="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/.ossify/project-state.json"
  fi
  case "$dest" in
    ''|*'${'*) echo "oss: unresolved state path: '${dest:-<empty>}' (from '${routed:-convention}')" >&2; return 1 ;;
  esac
  echo "$dest"
}

# Dispatcher glue: resolve the state path for a subcommand.
# Precedence: explicit $1 > $OSS_STATE_FILE (test/override) > manifest-derived.
_oss_resolve_state() { # [$1=explicit-path]
  if [ -n "${1:-}" ]; then echo "$1"; return 0; fi
  if [ -n "${OSS_STATE_FILE:-}" ]; then echo "$OSS_STATE_FILE"; return 0; fi
  oss_manifest_state_path
}

oss_cmd_state_path() { oss_manifest_state_path; }   # `oss state_path` for skills/debug
```

Also wire the resolved default into the two existing subcommands so they no longer hardcode a bare relative path. In `ossify/lib/doctor.sh`, change the first line of `oss_cmd_doctor`:

```bash
oss_cmd_doctor() { # $1=state-file (optional; resolves via manifest/OSS_STATE_FILE when omitted)
  local sf rc=0 out; sf="$(_oss_resolve_state "${1:-}")" || return $?
  [ -f "$sf" ] || { echo "fail: state - not found at $sf"; return 1; }
```

In `ossify/lib/demo.sh`, change the first line of `oss_cmd_demo_run` the same way:

```bash
oss_cmd_demo_run() { # $1=state-file (optional; resolves via manifest/OSS_STATE_FILE when omitted)
  local sf; sf="$(_oss_resolve_state "${1:-}")" || return $?
  oss_demo_run_auto "$sf"
}
```

(Leave the rest of both functions unchanged. `_oss_resolve_state` with an explicit `$1` returns it verbatim, so the existing doctor/demo tests that pass a path are unaffected.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-manifest.sh`
Expected: `pass=N fail=0`.
Regression (the doctor/demo default-path change must not break their suites — they pass explicit paths):
Run: `bash ossify/tests/test-doctor.sh && bash ossify/tests/test-demo-runner.sh`
Expected: both `pass=N fail=0`.

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/manifest.sh ossify/lib/doctor.sh ossify/lib/demo.sh ossify/tests/test-manifest.sh
git commit -m "feat(ossify): manifest / state-path resolution with unresolved-token guard (Plan B task 2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3 (B3): Dispatcher subcommand wrappers (+ composition/overlay ops)

**Context:** The three skills shell out via `oss <subcommand>`, but today only `doctor`/`demo_run` are dispatcher-reachable; the entity/registry/ledger ops are plain `oss_*` functions. Add thin `oss_cmd_*` wrappers that resolve the state path (via B2) then delegate to the tested libs — no judgment logic in bash. Also add two small pure ops to populate the reserved `project.composition_root` / `project.overlay_wiring` fields (DD-F: `start` sets posture + overlay; composition_root stays for Plan D unless trivially canonical).

**Files:**
- Modify: `ossify/lib/state.sh` (`_oss_apply_op` — add `set_composition`, `set_overlay` cases)
- Create: `ossify/lib/commands.sh` (all new `oss_cmd_*` wrappers; auto-sourced by `bin/oss`)
- Create: `ossify/tests/test-dispatcher-ops.sh`

**Interfaces:**
- Produces (ops): `set_composition` → `.project.composition_root = $p.composition_root`; `set_overlay` → `.project.overlay_wiring = $p.overlay_wiring`.
- Produces (subcommands, all resolve state via `_oss_resolve_state`): `oss_cmd_init <name>`, `oss_cmd_posture_set <posture>`, `oss_cmd_composition_set <root>`, `oss_cmd_overlay_set <wiring>`, `oss_cmd_release_add <name> <goal>`, `oss_cmd_spine_add <release> <name> <class> [target_repo]`, `oss_cmd_class_set <spine> <new-class> <reason>`, `oss_cmd_bone_add <adr> <title> <touch-csv> [revisit]`, `oss_cmd_risk_gate_add <name> <touch-csv> <controls-csv>`, `oss_cmd_fake_add <boundary> <channel> <reason> <trigger> <expiry>`, `oss_cmd_feature_add <name> <value> <class-guess> <source>`, `oss_cmd_touch_check <path>...`, `oss_cmd_ledger_add_auto <spine> <text> <command> <expected>`, `oss_cmd_ledger_add_user <spine> <text> <outcome>`, `oss_cmd_ledger_supersede <line> <by-spine> <reason>`, `oss_cmd_ledger_retire <line> <by-spine> <reason>`, `oss_cmd_ledger_quarantine <line> <reason>`, `oss_cmd_patch_add <commit> <text>`, `oss_cmd_get <jq-expr>`, `oss_cmd_feature_list`, `oss_cmd_spine_list`, `oss_cmd_ledger_active_auto`.
- Consumes: `_oss_resolve_state` (B2); all `oss_entity_*`/`oss_reg_*`/`oss_ledger_*`/`oss_state_*` libs (Plan A + B1).

- [ ] **Step 1: Write the failing test** — `ossify/tests/test-dispatcher-ops.sh`

```bash
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

t_capture oss_cmd_overlay_set '$PULSE_PROMPT_DIR'
t_assert_rc 0 "overlay set"
t_capture oss_cmd_get '.project.overlay_wiring'; t_assert_eq '$PULSE_PROMPT_DIR' "$T_OUT" "overlay stored"

t_capture oss_cmd_release_add "Skeleton" "core loop usable"
t_assert_eq "r0" "$T_OUT" "release via wrapper mints r0"
t_capture oss_cmd_spine_add r0 "walking skeleton" bone
t_assert_eq "r0.s1" "$T_OUT" "spine via wrapper (default target_repo)"

t_capture oss_cmd_bone_add "ADR-0002" "hexagonal core" "src/domain/**,src/port.rs" "revisit at MVP"
t_assert_rc 0 "bone added via wrapper"
t_capture oss_cmd_touch_check "src/domain/order.rs"
t_assert_rc 0 "touch check hits the bone glob"
t_assert_contains "$T_OUT" "bone ADR-0002" "touch check names the bone"

t_capture oss_cmd_ledger_add_auto r0.s1 "core loop runs" "bash -c 'exit 0'" "exit:0"
t_assert_eq "d1" "$T_OUT" "auto demo line via wrapper mints d1"

# replay stays clean through the wrapper-driven mutations + new ops.
t_capture oss_state_replay "$OSS_STATE_FILE"
t_assert_rc 0 "replay clean after wrapper ops incl. set_overlay"

unset OSS_STATE_FILE
rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-dispatcher-ops.sh`
Expected: FAIL — `ossify/lib/commands.sh` missing; `set_overlay` op unknown (rc 4).

- [ ] **Step 3: Write the implementation**

In `ossify/lib/state.sh`, add two cases to `_oss_apply_op` (place them right after the `set_posture` case):

```bash
    set_composition)
      jq --argjson p "$payload" '.project.composition_root = $p.composition_root' ;;
    set_overlay)
      jq --argjson p "$payload" '.project.overlay_wiring = $p.overlay_wiring' ;;
```

Create `ossify/lib/commands.sh`:

```bash
#!/usr/bin/env bash
# Dispatcher subcommands for the onboarding + planning skills. Thin wrappers:
# resolve the state path (explicit > OSS_STATE_FILE > manifest) then delegate to
# the tested lib functions. NO judgment logic here - that lives in the skills.

oss_cmd_init() { # $1=project-name
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_init "$sf" "$1"
}
oss_cmd_posture_set() { # $1=posture
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_mutate "$sf" set_posture "$(jq -n --arg p "$1" '{posture:$p}')"
}
oss_cmd_composition_set() { # $1=composition-root
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_mutate "$sf" set_composition "$(jq -n --arg c "$1" '{composition_root:$c}')"
}
oss_cmd_overlay_set() { # $1=overlay-wiring
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_mutate "$sf" set_overlay "$(jq -n --arg o "$1" '{overlay_wiring:$o}')"
}
oss_cmd_release_add() { # $1=name $2=goal
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_release "$sf" "$1" "$2"
}
oss_cmd_spine_add() { # $1=release $2=name $3=class [$4=target_repo]
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_spine "$sf" "$1" "$2" "$3" "${4:-canonical}"
}
oss_cmd_class_set() { # $1=spine $2=new-class $3=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_spine_class "$sf" "$1" "$2" "$3"
}
oss_cmd_bone_add() { # $1=adr $2=title $3=touch-csv [$4=revisit]
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_bone "$sf" "$1" "$2" "$3" "${4:-}"
}
oss_cmd_risk_gate_add() { # $1=name $2=touch-csv $3=controls-csv
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_risk_gate "$sf" "$1" "$2" "$3"
}
oss_cmd_fake_add() { # $1=boundary $2=channel $3=reason $4=trigger $5=expiry-release
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_fake "$sf" "$1" "$2" "$3" "$4" "$5"
}
oss_cmd_feature_add() { # $1=name $2=value $3=class-guess $4=source
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_feature "$sf" "$1" "$2" "$3" "$4"
}
oss_cmd_touch_check() { # $@=paths
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_touch_check "$sf" "$@"
}
oss_cmd_ledger_add_auto() { # $1=spine $2=text $3=command $4=expected
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_auto "$sf" "$1" "$2" "$3" "$4"
}
oss_cmd_ledger_add_user() { # $1=spine $2=text $3=outcome
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_user "$sf" "$1" "$2" "$3"
}
oss_cmd_ledger_supersede() { # $1=line $2=by-spine $3=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_supersede "$sf" "$1" "$2" "$3"
}
oss_cmd_ledger_retire() { # $1=line $2=by-spine $3=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_retire "$sf" "$1" "$2" "$3"
}
oss_cmd_ledger_quarantine() { # $1=line $2=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_quarantine "$sf" "$1" "$2"
}
oss_cmd_patch_add() { # $1=commit $2=text
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_patch "$sf" "$1" "$2"
}
oss_cmd_get() { # $1=jq-expr
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" "$1"
}
oss_cmd_feature_list()      { local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" '[.feature_map[]]'; }
oss_cmd_spine_list()        { local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" '[.spines[]]'; }
oss_cmd_ledger_active_auto(){ local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_active_auto "$sf"; }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-dispatcher-ops.sh && bash ossify/tests/test-state-replay.sh`
Expected: both `pass=N fail=0`.
Dispatcher-path smoke (strict-mode rule — exercise through `bin/oss`, not just sourced):
Run: `cd "$(mktemp -d)" && OSS_STATE_FILE="$PWD/s.json" "$OLDPWD"/ossify/bin/oss init smoke && OSS_STATE_FILE="$PWD/s.json" "$OLDPWD"/ossify/bin/oss release_add A B && OSS_STATE_FILE="$PWD/s.json" "$OLDPWD"/ossify/bin/oss get '.releases[0].id'; cd "$OLDPWD"`
Expected: prints `r0` (no strict-mode abort).

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/commands.sh ossify/tests/test-dispatcher-ops.sh
git commit -m "feat(ossify): oss_cmd_* dispatcher wrappers + composition/overlay ops (Plan B task 3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4 (B4): Release-planning state ops (release meta, veto dispositions, work-item target_repo)

**Context:** `plan-release` (B7) records exit-criteria journeys, the spine DAG, the ledger wall-clock budget, the next-release sketch, and mandatory real-use findings on a release; it also records each critic-veto disposition (auto-reclassify-to-bone / user-override / **escalate** — the fail-closed trail). `plan-spine` (B8) authors work items that each declare a `target_repo` (companion §8). Add the ops + wrappers. Schema stays v1; the one new top-level array (`veto_dispositions`) is seeded in `oss_state_init` and added to `oss_cmd_doctor`'s shape list; ops read tolerantly (`// []`).

**Files:**
- Modify: `ossify/lib/state.sh` (`_oss_apply_op` — add `set_release_meta`, `add_veto_disposition`; `oss_state_init` — seed `veto_dispositions:[]`)
- Modify: `ossify/lib/entities.sh` (`oss_entity_add_work_item` — add `target_repo`; new `oss_entity_set_release_meta`, `oss_entity_add_veto`)
- Modify: `ossify/lib/commands.sh` (wrappers: `oss_cmd_work_item_add`, `oss_cmd_release_set_meta`, `oss_cmd_veto_add`)
- Create: `ossify/tests/test-release-planning.sh` (carries the new-ops replay coverage — do NOT append to `test-state-replay.sh`)

> **`veto_dispositions` is seeded in `oss_state_init` but deliberately NOT added to `oss_cmd_doctor`'s required-key loop.** The `add_veto_disposition` op is already tolerant of a missing key (`.veto_dispositions += [$p]` on `null` yields `[$p]`); gating it in doctor would hard-fail a valid v1 state that predates this field (schema stays v1, no migration) — contradicting the "ops read tolerantly" rule and §9.2's no-silent-degradation discipline. Doctor keeps its 14 core-engine keys as the shape invariant; `veto_dispositions` is an additive planning array.

**Interfaces:**
- Produces (ops): `set_release_meta` → `(.releases[] | select(.id==$p.release)) |= (. + $p.patch)` (shallow-merges exit_criteria/spine_dag/ledger_budget/next_sketch/real_use_findings onto the release record); `add_veto_disposition` → `.veto_dispositions += [$p]` (payload `{spine,finding,disposition,reason,at}`, `disposition ∈ auto-bone|override|escalate`).
- Produces: `oss_entity_add_work_item <state> <spine> <title> <target_repo>` (now with target_repo, default `canonical`); `oss_entity_set_release_meta <state> <release> <patch-json>`; `oss_entity_add_veto <state> <spine> <finding> <disposition> <reason>` (validates disposition, rc 2).
- Produces (subcommands): `oss_cmd_work_item_add <spine> <title> [target_repo]`, `oss_cmd_release_set_meta <release> <patch-json>`, `oss_cmd_veto_add <spine> <finding> <disposition> <reason>`.
- Consumes: B1's mint mechanism (work-item mint spec `work_item:<spine>`), B3's wrapper file.

- [ ] **Step 1: Write the failing test** — `ossify/tests/test-release-planning.sh`

```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger doctor; do . "$HERE/../lib/$lib.sh"; done
TMP="$(mktemp -d)"; export OSS_STATE_FILE="$TMP/state.json"
oss_cmd_init "release-planning-demo" >/dev/null
oss_cmd_release_add "MVP" "usable end to end" >/dev/null
oss_cmd_spine_add r0 "trade entry" bone >/dev/null

# work item carries target_repo (default canonical + explicit override).
t_capture oss_cmd_work_item_add r0.s1 "wire the entry point"
t_assert_eq "r0.s1.w1" "$T_OUT" "work item minted"
t_capture oss_cmd_get '.work_items[0].target_repo'
t_assert_eq "canonical" "$T_OUT" "default target_repo is canonical"
t_capture oss_cmd_work_item_add r0.s1 "private adapter" private_core
t_capture oss_cmd_get '.work_items[1].target_repo'
t_assert_eq "private_core" "$T_OUT" "explicit target_repo stored"

# release meta: exit criteria + DAG + budget + next sketch + real-use findings.
t_capture oss_cmd_release_set_meta r0 \
  '{"exit_criteria":["at close, a user can place a paper trade"],"spine_dag":[["r0.s1",[]]],"ledger_budget":"90s","next_sketch":"r1: live execution","real_use_findings":["backtest UI was unreachable"]}'
t_assert_rc 0 "release meta set"
t_capture oss_cmd_get '.releases[0].exit_criteria[0]'
t_assert_eq "at close, a user can place a paper trade" "$T_OUT" "exit criteria stored"
t_capture oss_cmd_get '.releases[0].real_use_findings[0]'
t_assert_eq "backtest UI was unreachable" "$T_OUT" "real-use findings stored"

# veto disposition: escalate is recorded (fail-closed trail), disposition validated.
t_capture oss_cmd_veto_add r0.s1 "flesh claim touches src/port.rs" auto-bone "bone-touch check hit"
t_assert_rc 0 "auto-bone veto recorded"
t_capture oss_cmd_veto_add r0.s1 "critic finding ambiguous" escalate "ambiguous - fail-closed to escalate"
t_assert_rc 0 "escalate veto recorded"
t_capture oss_cmd_get '[.veto_dispositions[].disposition] | join(",")'
t_assert_eq "auto-bone,escalate" "$T_OUT" "both dispositions recorded in order"
t_capture oss_cmd_veto_add r0.s1 "bad" nonsense "x"
t_assert_rc 2 "invalid disposition rejected"

# doctor shape stays green (14 core keys present; veto_dispositions is additive/ungated); replay stays clean.
t_capture oss_cmd_doctor "$OSS_STATE_FILE"
t_assert_contains "$T_OUT" "ok: shape" "doctor shape green"
t_capture oss_state_replay "$OSS_STATE_FILE"
t_assert_rc 0 "replay clean after release-planning ops"

unset OSS_STATE_FILE
rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ossify/tests/test-release-planning.sh`
Expected: FAIL — `target_repo` absent on work items; `set_release_meta`/`add_veto_disposition` ops unknown; `oss_cmd_release_set_meta`/`oss_cmd_veto_add` undefined.

- [ ] **Step 3: Write the implementation**

In `ossify/lib/state.sh`, seed the new array in `oss_state_init`'s `jq -n` skeleton (add to the arrays line):

```bash
    feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
```

and add two cases to `_oss_apply_op` (after `add_patch_record`):

```bash
    set_release_meta)
      jq --argjson p "$payload" '(.releases[] | select(.id == $p.release)) |= (. + $p.patch)' ;;
    add_veto_disposition)
      jq --argjson p "$payload" '.veto_dispositions += [$p]' ;;
```

(Do NOT touch `oss_cmd_doctor`'s shape loop — see the Files note above: `veto_dispositions` is seeded but not gated.)

In `ossify/lib/entities.sh`, replace `oss_entity_add_work_item` (add target_repo) and append two new functions:

```bash
oss_entity_add_work_item() { # $1=state $2=spine-id $3=title $4=target_repo
  local sf="$1" spine="$2" ts
  jq -e --arg s "$spine" '.spines[] | select(.id == $s)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  ts="$(_oss_now)"
  oss_state_mutate "$sf" add_work_item \
    "$(jq -n --arg s "$spine" --arg t "$3" --arg r "${4:-canonical}" --arg ts "$ts" \
      '{spine:$s,title:$t,target_repo:$r,status:"planned",created_at:$ts}')" \
    "work_item:$spine"
}

oss_entity_set_release_meta() { # $1=state $2=release-id $3=patch-json
  local sf="$1" rel="$2" patch="$3"
  jq -e --arg r "$rel" '.releases[] | select(.id == $r)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown release '$rel'" >&2; return 7; }
  oss_state_mutate "$sf" set_release_meta \
    "$(jq -n --arg r "$rel" --argjson patch "$patch" '{release:$r,patch:$patch}')"
}

oss_entity_add_veto() { # $1=state $2=spine $3=finding $4=disposition $5=reason
  local sf="$1" spine="$2" disp="$4"
  case "$disp" in auto-bone|override|escalate) ;; *)
    echo "oss: disposition must be auto-bone|override|escalate" >&2; return 2;; esac
  oss_state_mutate "$sf" add_veto_disposition \
    "$(jq -n --arg s "$spine" --arg f "$3" --arg d "$disp" --arg r "$5" --arg ts "$(_oss_now)" \
      '{spine:$s,finding:$f,disposition:$d,reason:$r,at:$ts}')"
}
```

In `ossify/lib/commands.sh`, append the three wrappers:

```bash
oss_cmd_work_item_add() { # $1=spine $2=title [$3=target_repo]
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_work_item "$sf" "$1" "$2" "${3:-canonical}"
}
oss_cmd_release_set_meta() { # $1=release $2=patch-json
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_release_meta "$sf" "$1" "$2"
}
oss_cmd_veto_add() { # $1=spine $2=finding $3=disposition $4=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_veto "$sf" "$1" "$2" "$3" "$4"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ossify/tests/test-release-planning.sh` (its own tail asserts replay-clean over the new ops — the new-ops replay guard).
Then regression: `bash ossify/tests/test-state-replay.sh && bash ossify/tests/test-doctor.sh && bash ossify/tests/test-entities.sh`
Expected: all `pass=N fail=0`. (`test-state-replay.sh` is unmodified and stays green — the new init seeds `veto_dispositions` and its `set_posture` mutations are unaffected; `test-doctor.sh` inits fresh states that carry all 14 core keys; `test-entities.sh`: `oss_entity_add_work_item` now takes a 4th arg with a `canonical` default, so its existing 3-arg call still works.)

> Do NOT append to `test-state-replay.sh` (see B1's note — its tail is drift-tampered + base-deleted). The new ops' replay coverage lives in `test-release-planning.sh`.

- [ ] **Step 5: Commit**

```bash
git add ossify/lib/state.sh ossify/lib/entities.sh ossify/lib/commands.sh ossify/tests/test-release-planning.sh
git commit -m "feat(ossify): release-planning ops (meta, veto dispositions, work-item target_repo) (Plan B task 4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5 (B5): Planning-judge eval scaffold (fixtures + rubrics + runner + aggregate)

**Context:** ossify's judgment surfaces (critic-veto interpretation, bone-touch check, spine-class declaration, journey-line floor, posture derivation) are eval-gated before ship (spec §13.4). Plan B **authors the fixtures + a runnable LOCAL judge harness**, mirroring `architect-critic/tests/eval/` verbatim (session-driven LLM-judge, subscription-funded); Plan D consolidates them into THE ship gate + registers ossify. This task builds the harness + fixtures; each of B6/B7/B8 turns its surfaces GREEN. Fixtures encode the SPEC contract (not the skill impl) — proper TDD.

**Files (create):**
- `ossify/tests/eval/README.md`, `ossify/tests/eval/RUNBOOK.md`, `ossify/tests/eval/run-evals.sh`, `ossify/tests/eval/lib/aggregate-scores.sh`
- `ossify/tests/eval/rubrics/<surface>.md` × 5
- `ossify/tests/eval/fixtures/<surface>/NN-*.md`
- `ossify/tests/eval/results/<surface>/.gitkeep` × 5

The five surfaces: `posture-derivation`, `journey-line-floor`, `spine-class-declaration`, `bone-touch-check`, `critic-veto-interpretation`.

- [ ] **Step 1: Copy the skill-agnostic aggregate gate verbatim** — `ossify/tests/eval/lib/aggregate-scores.sh`

```bash
#!/usr/bin/env bash
# aggregate-scores.sh — read per-fixture JSON results and print pass/fail summary.
# Run AFTER the Claude-Code-session eval run has written results/*.json.

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${EVAL_DIR}/results"

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "No results dir at $RESULTS_DIR — run the eval harness first."
  exit 1
fi

total_pass=0
total_fail=0
total_files=0

for skill_dir in "$RESULTS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill="$(basename "$skill_dir")"
  skill_pass=0
  skill_fail=0

  for result in "$skill_dir"*.json; do
    [[ -e "$result" ]] || continue
    total_files=$((total_files + 1))
    pass=$(jq -r '.pass' "$result" 2>/dev/null || echo "false")
    if [[ "$pass" == "true" ]]; then
      skill_pass=$((skill_pass + 1))
      total_pass=$((total_pass + 1))
    else
      skill_fail=$((skill_fail + 1))
      total_fail=$((total_fail + 1))
      notes=$(jq -r '.notes // ""' "$result" 2>/dev/null)
      echo "  FAIL: ${skill}/$(basename "$result" .json) — ${notes}"
    fi
  done

  echo "${skill}: ${skill_pass} pass / ${skill_fail} fail"
done

echo ""
echo "=== TOTAL: ${total_pass}/${total_files} passed ==="
[[ $total_fail -eq 0 ]]
```

- [ ] **Step 2: Write the runner + docs**

`ossify/tests/eval/run-evals.sh`:

```bash
#!/usr/bin/env bash
# run-evals.sh — print the ossify planning-judge eval runbook prompt for
# Claude-Code-session execution. Does NOT call any LLM.
# Usage: bash run-evals.sh [surface | all]

set -euo pipefail
EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
target="${1:-all}"

cat <<EOF
=== ossify planning-judge eval harness ===

Session-driven eval (no API runner). Open this repo in Claude Code and paste:

---
Run the ossify planning-judge eval harness per ossify/tests/eval/RUNBOOK.md.
${target:+(target: $target)}
For each surface, iterate fixtures in tests/eval/fixtures/<surface>/, dispatch an
Agent to apply the owning skill's judgment to each fixture, then a judge Agent to
score against tests/eval/rubrics/<surface>.md. Write per-fixture JSON to
tests/eval/results/<surface>/<id>.json. When done, run
bash ossify/tests/eval/lib/aggregate-scores.sh and report the summary.
---

Then: bash $EVAL_DIR/lib/aggregate-scores.sh
EOF
```

`ossify/tests/eval/README.md`:

```markdown
# ossify planning-judge eval harness

LLM-as-judge harness for ossify's judgment surfaces (spec §13.4). Session-driven
(no API runner); subscription-funded via Agent dispatch. Plan B authors these
fixtures + the local gate; Plan D consolidates them into THE ship gate.

## Surfaces → owning skill

| Surface | Owning skill | The judgment |
|---|---|---|
| `posture-derivation` | `start` | derive posture + moat channel from facts + intent |
| `journey-line-floor` | `plan-spine` | verb+observable-outcome required; inspector phrasing banned; internal spine names its consumer |
| `spine-class-declaration` | `plan-release` | bone vs flesh vs internal-enabler vs reject-as-horizontal |
| `bone-touch-check` | `plan-release` | a plan touching a registered touch surface auto-reclassifies to bone |
| `critic-veto-interpretation` | `plan-release` | veto→auto-bone; user override recorded; ambiguous/contradictory/stale→ESCALATE (fail-closed) |

## Fixture format

`fixtures/<surface>/NN-description.md` with YAML frontmatter carrying the
surface's `expected_*` field(s) + a body (≤800 tokens) describing the scenario
the skill judges. Frontmatter fields are per-surface (see each rubric header).
`NN-` prefixes order glob expansion only. Each surface includes at least one
negative-control fixture (expected: the safe/clean answer).

## Rubric format

`rubrics/<surface>.md` lists exactly 5 criteria; the judge scores each 1-5;
**pass = ≥4 on every criterion**; the rubric's last line pins the JSON output
contract. `lib/aggregate-scores.sh` reads only `.pass`/`.notes`, so it is
surface-agnostic.

## Run

Session-driven — see `RUNBOOK.md`. Then `bash lib/aggregate-scores.sh`
(exit 0 = all pass, 1 = any fail — the local gate).

## Seed provenance (spec §13.4)

Fixtures seed from the evolutionary-architecture playbook's 10 acceptance
scenarios + the 3 named historical failure modes (a horizontal build dressed as
a spine; an inspector-phrased journey line; a flesh claim touching a bone) + the
3 recorded target postures (pulse-trader→fully-private, PulseDB→open-core,
PulseHive→fully-open). Plan D expands to full 10-scenario coverage.
```

`ossify/tests/eval/RUNBOOK.md`:

```markdown
# Eval Runbook (ossify planning judges)

Executed by Claude Code in an interactive session. No API runner.

## Procedure (Claude executes)

For each `surface` in `[posture-derivation, journey-line-floor, spine-class-declaration, bone-touch-check, critic-veto-interpretation]`:

  For each `fixture.md` in `tests/eval/fixtures/<surface>/`:

  1. **Apply the judgment.** Dispatch `Agent` (general-purpose): "Read the owning skill's SKILL.md + the relevant `references/*.md` for `<surface>` end-to-end. Apply ONLY that skill's documented decision procedure to this fixture scenario (paste body). Output the judgment the skill would produce (e.g. the derived posture+channel, the accept/reject verdict + reason, the declared class, or the veto disposition). Do not improvise beyond the skill body." Capture the output.

  2. **Score.** Dispatch a fresh judge `Agent`: "You are an LLM-as-judge. Score the SKILL OUTPUT against the RUBRIC. Return one JSON object `{\"scores\":{...},\"pass\":true|false,\"notes\":\"<one sentence>\"}`. Pass = all criteria ≥4. JSON only. RUBRIC: <paste rubrics/<surface>.md>  FIXTURE: <paste fixture>  SKILL OUTPUT: <paste>." Write the JSON to `tests/eval/results/<surface>/<fixture_id>.json`.

After all surfaces: run `bash ossify/tests/eval/lib/aggregate-scores.sh` and report the summary.

## Cost

~5 surfaces × ~4 fixtures × 2 dispatches ≈ 40 Agent dispatches per full run; 5-10 min. Re-run a single surface by deleting its `results/<surface>/` and re-running.
```

- [ ] **Step 3: Write the five rubrics**

`ossify/tests/eval/rubrics/posture-derivation.md` (frontmatter fields: `expected_posture`, `expected_channel`):

```markdown
# Rubric: posture-derivation

Score each criterion 1-5. Pass = all ≥4.

1. **Posture correct** — the derived posture equals `expected_posture`.
   - 5: exact match. 1: wrong posture.
2. **Intent over facts** — where observable facts and intent conflict (pulse-trader reads source-available by facts but intent is fully-private), the derivation follows the stated intent signal, not the facts alone.
   - 5: intent correctly overrides facts. 1: derived from facts, ignoring intent.
3. **Channel correct** — the moat channel equals `expected_channel`, one of the companion §3.2 channels (`data-overlay` | `private-package` | `repo-private`) or `none` (the sentinel for a fully-open posture with no moat channel).
   - 5: exact. 1: wrong channel.
4. **Undecided → private** — an undecided/ambiguous posture resolves to fully-private (fail-safe), never to a public posture.
   - 5: resolves private. 1: resolves public.
5. **Moat mapped to channel** — each named moat item is correctly mapped to its channel (e.g. pulse-trader's prompt corpus → data-overlay; PulseDB's decay intelligence → private-package); a fully-open project is correctly identified as having no moat channel.
   - 5: correct mapping. 1: wrong/absent mapping.

## Output format
Return one JSON object: `{"scores":{"posture_correct":N,"intent_over_facts":N,"channel_correct":N,"undecided_private":N,"moat_mapped":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
```

`ossify/tests/eval/rubrics/journey-line-floor.md` (fields: `expected_verdict` accept|reject, `expected_reason`):

```markdown
# Rubric: journey-line-floor

Score each 1-5. Pass = all ≥4. (A 6th criterion is included for the before/after-evidence floor — an ossify-specific constraint per the README's 6th-criterion allowance.)

1. **Verdict correct** — accept/reject matches `expected_verdict`.
2. **Inspector phrasing caught** — a `user:` line phrased as inspection ("inspect", "view", "open the record") is rejected as a journey line.
3. **Verb + observable outcome** — an accepted journey line is an action the user performs for value (verb + observable outcome), not artifact inspection.
4. **Internal-spine consumer rule** — an internal (`auto:`-only) spine is admitted only if it names a committed user-facing consuming spine scheduled in the current or next release (one-release-ahead cap); otherwise rejected.
5. **No false reject** — a legitimately value-phrased journey line is not rejected.
6. **Before/after evidence** — a deepening pass claiming a measured quality (performance/reliability/cost) is rejected unless it states before/after evidence in its demo contribution.

## Output format
`{"scores":{"verdict_correct":N,"inspector_caught":N,"verb_outcome":N,"consumer_rule":N,"no_false_reject":N,"before_after_evidence":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
```

`ossify/tests/eval/rubrics/spine-class-declaration.md` (field: `expected_class` bone|flesh|internal-enabler|reject):

```markdown
# Rubric: spine-class-declaration

Score each 1-5. Pass = all ≥4.

1. **Class correct** — declared class equals `expected_class`.
2. **Horizontal build caught** — a spine that only builds an architectural layer with no actor-to-outcome journey is NOT accepted as a user-facing spine (it is internal-enabler at best, or rejected).
3. **Flesh-touching-bone reclassified** — a flesh claim whose scope touches a bone reclassifies to bone.
4. **No over-ceremony** — a genuine flesh spine on existing bones is not inflated to bone.
5. **Rationale cites the rule** — the decision references the governing rule (journey requirement / bone-touch / enabler consumer).

## Output format
`{"scores":{"class_correct":N,"horizontal_caught":N,"flesh_bone_reclassified":N,"no_over_ceremony":N,"rationale_cited":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
```

`ossify/tests/eval/rubrics/bone-touch-check.md` (field: `expected_verdict` auto-bone|clean):

```markdown
# Rubric: bone-touch-check

Score each 1-5. Pass = all ≥4.

1. **Verdict correct** — auto-bone vs clean matches `expected_verdict`.
2. **Touch-surface match** — a plan path overlapping a registered bone touch glob is detected.
3. **Independent of the critic** — the bone-touch reclassification fires regardless of what the critic said (it is a separate judge).
4. **No false positive** — a plan touching no registered surface stays clean.
5. **Risk-gate parallel** — a plan touching a risk-gate surface escalates to the bone path plus that gate's control checklist.

## Output format
`{"scores":{"verdict_correct":N,"touch_match":N,"independent":N,"no_false_positive":N,"risk_gate":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
```

`ossify/tests/eval/rubrics/critic-veto-interpretation.md` (field: `expected_disposition` auto-bone|override|escalate):

```markdown
# Rubric: critic-veto-interpretation

Score each 1-5. Pass = all ≥4.

1. **Disposition correct** — the disposition equals `expected_disposition`.
2. **Veto → auto-bone** — a clear veto finding auto-reclassifies the spine to bone (spec-aligned safety default).
3. **Fail-closed on ambiguity** — an ambiguous, contradictory, or stale finding resolves to ESCALATE, never to pass.
4. **Override recorded with reason** — a user override of the auto-bone is recorded with a reason (not silently applied).
5. **Never silent-pass** — the interpretation never lets a veto-triggering finding through as a pass.

## Output format
`{"scores":{"disposition_correct":N,"veto_auto_bone":N,"fail_closed":N,"override_recorded":N,"never_silent_pass":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
```

- [ ] **Step 4: Write the fixtures** (create each file with exactly the frontmatter + body shown)

**`fixtures/posture-derivation/01-pulse-trader-intent-flip.md`**
```markdown
---
scenario_id: 01-pulse-trader-intent-flip
expected_posture: fully-private
expected_channel: data-overlay
---
Project: pulse-trader (Rust, strict hexagonal, 6 port traits + Clock, determinism fingerprint).
Observable facts: public/private sibling repos; `src/agent/config.rs` documents a `$PULSE_PROMPT_DIR` override ("the private-workspace override — forward-compat to the owner's runtime-private moat"); standing discipline "moat in DATA, not code"; today `src/agent/prompts/composer.md` (system prompt via include_str!) sits in public source.
Intent signal: the owner wants BOTH repos fully private; the prompt corpus is the moat, carried at runtime via the declared override seam. Revenue intent: none.
(Facts alone read `source-available`; the intent signal is what decides it.)
```

**`fixtures/posture-derivation/02-pulsedb-open-core.md`**
```markdown
---
scenario_id: 02-pulsedb-open-core
expected_posture: open-core
expected_channel: private-package
---
Project: PulseDB (Rust, ports-and-adapters, 6 port traits; carries a written PUBLIC_BOUNDARY.md).
Observable facts: decay/re-rank implementations are public but their spec (DECAY_SPEC.md) is private; a 76KB SPEC.md is untracked-but-present in the public working tree (gitignored).
Intent signal: the core DB is open; the intelligence (ranking/decay algorithms + spec) stays private. Revenue intent: license (AGPL + commercial dual-license).
```

**`fixtures/posture-derivation/03-pulsehive-fully-open.md`**
```markdown
---
scenario_id: 03-pulsehive-fully-open
expected_posture: fully-open
expected_channel: none
---
Project: PulseHive (Rust, port traits in pulsehive-core, providers injectable; carries a written PUBLIC_BOUNDARY.md).
Observable facts: orchestration prompts in public source; its own PRD/Backlog publicly tracked.
Intent signal: code fully open (no functionality moat); tighten DOC routing so only user-facing docs are public (PRD/Backlog/orchestration-planning docs → private AI workspace). Revenue intent: none.
```

**`fixtures/posture-derivation/04-undecided-defaults-private.md`** (negative control)
```markdown
---
scenario_id: 04-undecided-defaults-private
expected_posture: fully-private
expected_channel: repo-private
---
Project: a fresh greenfield tool. Observable facts: single repo, no boundary artifacts yet.
Intent signal: the owner has NOT decided a posture ("undecided / figure it out later").
(Per the default-private fail-safe: undecided always resolves to fully-private; private→public is one ceremony later, public→private is impossible.)
```

**`fixtures/journey-line-floor/01-inspector-phrasing.md`** (the named failure mode)
```markdown
---
scenario_id: 01-inspector-phrasing
expected_verdict: reject
expected_reason: inspector phrasing is banned for journey lines
---
A user-facing spine proposes its sole `user:` demo line as: "inspect the SQLite schema to confirm the trade table exists".
```

**`fixtures/journey-line-floor/02-valid-journey.md`** (positive control)
```markdown
---
scenario_id: 02-valid-journey
expected_verdict: accept
expected_reason: verb + observable value outcome
---
A user-facing spine proposes its `user:` line as: "place a paper trade from the order ticket and see it appear in the open-positions list".
```

**`fixtures/journey-line-floor/03-internal-spine-no-consumer.md`**
```markdown
---
scenario_id: 03-internal-spine-no-consumer
expected_verdict: reject
expected_reason: internal spine names no committed consuming user-facing spine
---
An internal spine contributes only `auto:` lines (a normalization layer) and claims product value on the grounds that "the UI will consume it someday". No consuming user-facing spine is named or scheduled.
```

**`fixtures/journey-line-floor/04-internal-spine-with-consumer.md`** (positive control)
```markdown
---
scenario_id: 04-internal-spine-with-consumer
expected_verdict: accept
expected_reason: internal spine names a committed consumer within one release
---
An internal spine contributes only `auto:` lines (a pricing cache) and names the committed user-facing spine "quote ticket" scheduled in the next release as its consumer.
```

**`fixtures/spine-class-declaration/01-horizontal-as-spine.md`** (the named failure mode)
```markdown
---
scenario_id: 01-horizontal-as-spine
expected_class: internal-enabler
---
A proposed "vertical slice" builds the entire persistence layer (schema + repository + migrations) with no actor-to-outcome journey — its demo is "the migration runs and the tables exist". It is declared as a user-facing flesh spine.
```

**`fixtures/spine-class-declaration/02-flesh-touching-bone.md`** (the named failure mode)
```markdown
---
scenario_id: 02-flesh-touching-bone
expected_class: bone
---
A spine declared `flesh` ("add a second order type") plans work whose files include `src/domain/port.rs` — a module listed in the hexagonal-core bone's touch surface.
```

**`fixtures/spine-class-declaration/03-legit-flesh.md`** (positive control)
```markdown
---
scenario_id: 03-legit-flesh
expected_class: flesh
---
A spine "add a CSV export button" works entirely on existing bones (uses the existing report port + UI shell), touches no registered touch surface, and delivers a user journey.
```

**`fixtures/spine-class-declaration/04-legit-bone.md`** (positive control)
```markdown
---
scenario_id: 04-legit-bone
expected_class: bone
---
A spine "introduce the event-sourcing persistence model" creates a new load-bearing, hard-to-reverse persistence architecture (a new bone) with an ADR and a declared touch surface.
```

**`fixtures/bone-touch-check/01-touches-bone.md`**
```markdown
---
scenario_id: 01-touches-bone
expected_verdict: auto-bone
---
Registered bone ADR-0002 "hexagonal core" has touch surface `src/domain/**, src/port.rs`. A spine's plan lists changed paths including `src/domain/order.rs`.
```

**`fixtures/bone-touch-check/02-clean.md`** (negative control)
```markdown
---
scenario_id: 02-clean
expected_verdict: clean
---
Registered bone ADR-0002 "hexagonal core" has touch surface `src/domain/**, src/port.rs`. A spine's plan lists changed paths only under `src/ui/` and `docs/`.
```

**`fixtures/bone-touch-check/03-risk-gate.md`**
```markdown
---
scenario_id: 03-risk-gate
expected_verdict: auto-bone
---
Registered risk gate "live-order-execution" has touch surface `src/exec/**` and a control checklist (paper env, human confirm, kill switch, audit trail). A spine's plan changes `src/exec/router.rs`. (Expected: escalates to the bone close path PLUS the gate's control checklist.)
```

**`fixtures/critic-veto-interpretation/01-clear-veto.md`**
```markdown
---
scenario_id: 01-clear-veto
expected_disposition: auto-bone
---
architect-critic returns a clear, specific finding on spine r0.s2: "this 'flesh' spine changes the public trade-event schema — a compatibility-breaking, hard-to-reverse change." The plugin interprets the veto.
```

**`fixtures/critic-veto-interpretation/02-ambiguous-escalates.md`**
```markdown
---
scenario_id: 02-ambiguous-escalates
expected_disposition: escalate
---
architect-critic returns a vague finding on spine r0.s3: "something about the boundary here feels off, not sure it matters." It is neither a clear pass nor a clear veto.
```

**`fixtures/critic-veto-interpretation/03-stale-escalates.md`**
```markdown
---
scenario_id: 03-stale-escalates
expected_disposition: escalate
---
architect-critic's finding on spine r0.s4 references a module (`src/legacy/adapter.rs`) that no longer exists in the current plan — the finding is stale relative to the spine's actual scope.
```

**`fixtures/critic-veto-interpretation/04-user-override.md`**
```markdown
---
scenario_id: 04-user-override
expected_disposition: override
---
The critic vetoed spine r0.s5 (auto-reclassified to bone), but the user reviews and explicitly overrides back to flesh, giving the reason "the touched file is a generated stub, not the real port." The plugin records the override.
```

**`fixtures/critic-veto-interpretation/05-contradictory-escalates.md`** (the third named fail-closed trigger)
```markdown
---
scenario_id: 05-contradictory-escalates
expected_disposition: escalate
---
architect-critic returns a self-contradictory pair of findings on spine r0.s6: one says "this spine safely reuses the existing event schema (no compatibility risk)", the other says "this spine changes the event schema shape and breaks consumers." The two cannot both be true.
```

**`fixtures/journey-line-floor/05-deepening-no-evidence.md`** (the before/after-evidence floor)
```markdown
---
scenario_id: 05-deepening-no-evidence
expected_verdict: reject
expected_reason: a measured-quality deepening pass states no before/after evidence
---
A deepening pass claims "make order matching 3× faster" and proposes to close green on the existing auto tests, with NO before/after measurement stated in its demo contribution.
```

Create `ossify/tests/eval/results/<surface>/.gitkeep` (empty) for each of the five surfaces so the results dirs exist for the aggregate gate.

- [ ] **Step 5: Verify the harness is wired (structural RED)**

Run: `bash ossify/tests/eval/run-evals.sh posture-derivation`
Expected: prints the paste-able runbook prompt (no error).
Run: `bash ossify/tests/eval/lib/aggregate-scores.sh`
Expected: with empty `results/`, prints `=== TOTAL: 0/0 passed ===` and exits 0. (Once B6-B8 land and a session run writes result JSONs, this becomes the real gate. Until the skills exist, the surfaces have no passing results — that is the standing RED B6-B8 turn GREEN.)

- [ ] **Step 6: Commit**

```bash
git add ossify/tests/eval
git commit -m "test(ossify): planning-judge eval scaffold - 5 surfaces, fixtures + rubrics + gate (Plan B task 5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6 (B6): `start` skill — spec-core onboarding + posture block

**Context:** `start` owns spec-core onboarding (L§4 station 2) + the part-two posture block (B§3). Its behavior is contracted by the B5 `posture-derivation` fixtures (binding spec). The SKILL body carries the operative steps + `oss` shell-outs; all depth lives in `references/`. Memory bank + CLAUDE.md are authored by ossify itself from an ossify-owned brief (confirmed decision — decoupled from scaffold-onboard).

**Files:**
- Modify: `ossify/lib/commands.sh` (add `oss_cmd_critic_detect` — the filesystem probe the critic moment uses) + `ossify/tests/test-dispatcher-ops.sh` (assert it echoes `v0.2` or `absent`)
- Create: `ossify/skills/start/SKILL.md`
- Create: `ossify/skills/start/references/{journey-map,skeleton-cut,bones-registry,risk-gates,smoke-test-pass,spike-contract,lean-spec-schema,onboarding-question-subset,posture-block,memory-bank-brief,critic-moment}.md`
- Create: `ossify/commands/start.md`

**Interfaces:**
- Produces: `oss_cmd_critic_detect` → echoes `v0.2` (rc 0) or `absent` (rc 1) via a filesystem probe for `architect-critic/*/skills/critiquing-spec/SKILL.md`.
- Consumes (shell-outs the skill makes): `oss init <name>`, `oss posture_set <posture>`, `oss overlay_set <wiring>`, `oss composition_set <root>` (only if trivially canonical), `oss bone_add <adr> <title> <touch-csv> [revisit]`, `oss risk_gate_add <name> <touch-csv> <controls-csv>`, `oss feature_add <name> <value> <class-guess> <source>`, `oss critic_detect`, `oss doctor`.

- [ ] **Step 1: Add the critic-detect probe (RED test first)** — append to `ossify/tests/test-dispatcher-ops.sh` before `t_summary`:

```bash
t_capture oss_cmd_critic_detect
case "$T_OUT" in v0.2|absent) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: critic_detect echoes v0.2|absent (got '$T_OUT')";; esac
```
Run `bash ossify/tests/test-dispatcher-ops.sh` → FAIL (`oss_cmd_critic_detect` undefined). Then add to `ossify/lib/commands.sh`:

```bash
# Filesystem probe for architect-critic v0.2 (binary v0.2-or-absent), mirroring
# scaffold-onboard's sf_compose_detect_architect_critic. Used by start's
# spec-core critic moment. No composition.json read.
oss_cmd_critic_detect() {
  local cache skill_md
  for cache in "${HOME}/.claude/plugins/cache" "${CLAUDE_PLUGINS_DIR:-}"; do
    { [ -z "$cache" ] || [ ! -d "$cache" ]; } && continue
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [ -f "$skill_md" ] && { echo "v0.2"; return 0; }
    done
  done
  echo "absent"; return 1
}
```
Run again → PASS.

- [ ] **Step 2: Author `ossify/skills/start/SKILL.md`** — frontmatter (verbatim) + body to this skeleton (body ≤~500 lines; depth → references):

Frontmatter:
```yaml
---
name: start
description: Drive spec-core onboarding for a new ossify project — author the Patton journey map, the skeleton-cut (Release 0), the bones registry (forced-enumeration ADRs with touch surfaces + revisit triggers), risk gates, a smoke-test pass over unverified tech claims, the privacy posture + moat channels + PUBLIC_BOUNDARY.md, and a spec-core architect-critic moment — producing a lean MASTER-SPEC, EXEC-SUMMARY, memory bank + CLAUDE.md, bones ADRs, and a seed feature map. Use this when the user wants to start a new project, onboard a project into ossify, run /start, or kick off a skeleton-first build. Refuses without a workspace-init pairing manifest. Do NOT use for release planning (use /plan-release), spine decomposition (use /plan-spine), or amending an existing spec.
---
```

Body sections (each references its depth file with a "Full X in `references/<f>.md`" pointer):
1. **Overview** — the five-station lifecycle, where `start` sits (spec-core onboarding), and that it produces pre-code decisions only.
2. **When to use** (+ a `Do NOT auto-invoke when:` list routing to `plan-release`/`plan-spine`/amend).
3. **Pre-flight** — the `oss` dispatcher shell-out contract paragraph (bin-on-`$PATH`, bash-shebang self-locating; retarget the scaffold-dev boilerplate to `oss`). Manifest probe + refuse (keep the load-bearing tokens):
   ```bash
   if ! oss state_path >/dev/null 2>&1; then
     printf '%s\n' "ossify requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
     exit 0
   fi
   oss init "<project-name>"
   ```
4. **Product vision → narrative** — captured as narrative only; zero execution semantics; nothing sequences by it. `Full framing in references/lean-spec-schema.md`.
5. **Journey map** — Patton actor-action / system-responsibility / observable-evidence, each step marked skeleton|next|later; NOT a build order. `Full grammar + worked example in references/journey-map.md`. Unmarked/later steps → seed feature map (`oss feature_add`).
6. **Skeleton-cut** — mark the thinnest coherent path across the journey map; its answer pre-seeds Release 0 (NOT the MVP). `Full derivation in references/skeleton-cut.md`.
7. **Bones registry** — the forced-enumeration checklist (every category answered or `not-applicable`): system shape & topology; module boundaries & dependency direction; data ownership & migration; public contracts & compatibility; trust boundaries & destructive ops; failure visibility; rollback/evolution; stack; cross-cutting (auth/tenancy). Each bone is an ADR from birth with a declared touch surface + optional revisit trigger → `oss bone_add`. `Full checklist in references/bones-registry.md`.
8. **Risk gates** — each with touch surface + a control checklist scaled to harm (money/destructive → paper env, human confirm, kill switch, audit trail, progressive exposure) → `oss risk_gate_add`. `Full rules in references/risk-gates.md`.
9. **Smoke-test pass** — every tech claim a bone rests on is verified by a 20-50-line throwaway smoke test or explicitly marked unverified in the bone's ADR. `Full protocol in references/smoke-test-pass.md`.
9a. **Feasibility spike (optional, explicit)** — when spec-core surfaces GENUINE architectural uncertainty (beyond a lightweight smoke test), offer a disposable feasibility spike with a hard contract: one hypothesis / one falsifier / a timebox / `code_fate: discard` (disposable-by-contract — the code is thrown away, only the decision is kept). This is §4 station 3 (routed under `start` per §9.1); distinct from the routine smoke-test pass. `Full contract in references/spike-contract.md`.
10. **Posture block** — posture (`fully-private|source-available|open-core|fully-open`, undecided→`fully-private`) → `oss posture_set`; moat inventory → channel (`data-overlay|private-package|repo-private`); record the data-overlay override seam → `oss overlay_set`; author `PUBLIC_BOUNDARY.md` (rules block + working-tree allowlist + prose never-here rules — **no moat item named**) + a private boundary inventory. When a `private-package` split is needed, emit a "provisioning deferred to Plan D" note (do NOT call `add-private-core`; do NOT edit the manifest). `Full rules + stack-packaging per-language in references/posture-block.md`.
11. **Spec-core critic moment** — see step-3 mechanics below; `Full mechanism in references/critic-moment.md`.
12. **Lean-bootstrap Release-0 minimums** — each artifact's Release-0 minimum (journey map: one core journey; bones: only what the skeleton touches; feature map: may be 3 lines; posture: may be "default-private, revisit at MVP"). `Full minima in references/lean-spec-schema.md`.
13. **Outputs** — lean MASTER-SPEC + EXEC-SUMMARY (routed AI workspace), memory bank + CLAUDE.md (authored from `references/memory-bank-brief.md`), bones ADRs, seed feature map, `PUBLIC_BOUNDARY.md` (each public repo root). `Full derivation brief in references/memory-bank-brief.md` and section schema in `references/lean-spec-schema.md`.
14. **Slash-command interaction** — `/start` exports `$ARGUMENTS`; parse in bash, never `$1`/`$2`.
15. **Anti-patterns** — enumerating exhaustive FR/NFR / PRD/SRS/BACKLOG / multi-year roadmap (retired); naming a moat item in `PUBLIC_BOUNDARY.md`; letting this body exceed 500 lines; calling `add-private-core` (Plan D); reintroducing a "tracer/prototype" track (the disposable spike + lean Release 0 cover both — playbook decision #11 rejected it).
16. **Notes on tool boundaries** — You (judgment) / `oss` (mechanical state) / the user (decisions).

The critic-moment mechanics (step 11 body, adapted from `onboarding-project` §5 — fires once, at spec-core close, before bones harden, `target=master-spec-full, depth=close`):
```
1. Announce: "Spec-core close — invoking architect-critic for a `close` audit on the lean MASTER-SPEC + bones registry + skeleton-cut before the bones harden. Type `skip` to bypass."
2. End the turn; wait. If the user types `skip` (case-insensitive), log and continue to step 12.
3. Probe: `oss critic_detect`. If `absent`, warn once ("architect-critic not installed — skipping spec-core audit. Install via /plugin install architect-critic (v0.2+).") and continue. Do not stall.
4. If `v0.2`: invoke `Skill(architect-critic:critiquing-spec, target=master-spec-full, depth=close, artifact_path="<lean MASTER-SPEC path>")`.
5. On control return, disposition-triage the challenges: auto-accept spec-aligned ones (fold into the spec + bones ADRs), escalate only load-bearing/vision-touching ones to the user. Advisory — never a gate.
```

- [ ] **Step 3: Author the ten `references/*.md`** — each a focused depth doc:
- `journey-map.md` — Patton grammar (actor action / system responsibility / observable evidence), the skeleton|next|later marking, a worked example, and "unmarked/later steps become candidate spines via `oss feature_add <name> <value> next|later journey-map`".
- `skeleton-cut.md` — how to mark the thinnest coherent path; that it defines Release 0 (not MVP); the terminology-collision note (renamed from legacy "MVP cut").
- `bones-registry.md` — the full 9-category forced-enumeration checklist with an example ADR-from-birth entry and the exact `oss bone_add <adr-ref> <title> <touch-csv> [revisit]` call; touch-surface glob semantics.
- `risk-gates.md` — the harm-scaled control checklists (money/destructive/identity/ordering) + `oss risk_gate_add <name> <touch-csv> <controls-csv>`.
- `smoke-test-pass.md` — the 20-50-line throwaway-worktree protocol; when to mark a claim unverified; distinct from the feasibility spike.
- `spike-contract.md` — the feasibility-spike contract (§4 station 3): one hypothesis / one falsifier / timebox / `code_fate: discard`, disposable-by-contract; when to offer a spike (genuine architectural uncertainty) vs a smoke test (lightweight claim check); the code is discarded, only the recorded decision survives.
- `lean-spec-schema.md` — the lean MASTER-SPEC sections {vision-narrative, journey-map, skeleton-cut, bones-registry index, risk-gates, posture+boundary, Release-0 minimums} + what is dropped (FR/NFR/PRD/SRS/BACKLOG/roadmap/PROJECT_PLAN, grown at release-close in Plan C) + the Release-0 minimum for each.
- `onboarding-question-subset.md` — which onboarding questions stay upfront (vision-narrative, domain-model/data-ownership, security/trust-boundary + destructive-ops, architecture/system-shape) vs move to release-time; a note that 2-3 genuinely contested cuts (e.g. how much security is Release-0-minimum) are escalated to the user at authoring time.
- `posture-block.md` — posture values + undecided→private fail-safe; moat inventory → channel mapping; the data-overlay override-seam recording (e.g. `$PULSE_PROMPT_DIR`) via `oss overlay_set`; the `PUBLIC_BOUNDARY.md` template (machine-checkable rules block + working-tree hygiene allowlist + prose never-here rules, no moat item named); stack-packaging patterns per language (Rust/Python/TypeScript); the placement rule ("AI workspace never holds product code; private code requires `private_core`"); the Plan-D deferral note for `add-private-core`.
- `memory-bank-brief.md` — ossify's own lean derivation brief for the memory bank + CLAUDE.md, re-anchored to the lean-spec sections (decoupled from scaffold-onboard); the files to author and what each contains at Release-0 minimum.
- `critic-moment.md` — the full detection/announce/skip/invoke/warn-skip mechanism (mirror `onboarding-project/references/critic-moments.md`), the `oss critic_detect` probe, the single `close` invocation, and the "advisory, never a gate + disposition-triage" contract.

- [ ] **Step 4: Author `ossify/commands/start.md`** (thin wrapper, `$ARGUMENTS` bridge → `Skill`):

```markdown
---
description: Drive spec-core onboarding for a new ossify project (journey map, skeleton-cut, bones, risk gates, posture, spec-core critic)
argument-hint: "[project-name]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `ossify:start` skill, which owns spec-core onboarding.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "start: ARGS=${ARGS:-<none>}"
'
```

Now invoke the skill in-conversation:

**`Skill(ossify:start)`** — pass the parsed project name. The skill body owns the
journey map → skeleton-cut → bones → risk gates → smoke-test → posture block →
spec-core critic moment flow and shells out to `oss` for all state.
```

- [ ] **Step 5: Turn the `posture-derivation` eval surface GREEN**

Run the surface per `ossify/tests/eval/RUNBOOK.md` (dispatch invoke+judge Agents over the 4 `posture-derivation` fixtures; write results). Then:
Run: `bash ossify/tests/eval/lib/aggregate-scores.sh`
Expected: `posture-derivation: 4 pass / 0 fail`. If a fixture fails, revise `references/posture-block.md` (the binding contract is the fixture's `expected_posture`/`expected_channel`), not the fixture.
Also run `bash ossify/tests/run-all.sh` → `ALL GREEN` (the critic-detect probe assertion passes).

- [ ] **Step 6: Commit**

```bash
git add ossify/lib/commands.sh ossify/tests/test-dispatcher-ops.sh ossify/skills/start ossify/commands/start.md
git commit -m "feat(ossify): start skill - spec-core onboarding + posture block + critic moment (Plan B task 6)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7 (B7): `plan-release` skill — release planning + fail-closed critic veto

**Context:** `plan-release` (L§5.2) grooms the feature map into a release, declares each spine's class, runs the fail-closed critic veto + independent bone-touch judge, emits RELEASE.md, and sketches the next release. Contracted by the B5 `critic-veto-interpretation`, `bone-touch-check`, and `spine-class-declaration` fixtures.

**Files:**
- Create: `ossify/skills/plan-release/SKILL.md` + `references/{feature-map-grooming,spine-sequencing-dag,class-declaration,critic-veto,bone-touch-judge,real-use-findings,release-md-emission,rolling-wave}.md`
- Create: `ossify/commands/plan-release.md`

**Interfaces:**
- Consumes (shell-outs): `oss feature_list`, `oss spine_add <release> <name> <class> [target_repo]`, `oss class_set <spine> <new-class> <reason>`, `oss veto_add <spine> <finding> <disposition> <reason>`, `oss release_add <name> <goal>`, `oss release_set_meta <release> <patch-json>`, `oss touch_check <path>...`, `oss critic_detect`, and `Skill(architect-critic:critiquing-spec)`.

- [ ] **Step 1: Author `ossify/skills/plan-release/SKILL.md`** — frontmatter + body:

Frontmatter:
```yaml
---
name: plan-release
description: Plan an ossify release — groom the feature map into a set of spines, phrase exit criteria as user journeys, sequence spines by inter-spine DAG, declare each spine's class (bone/flesh) under a fail-closed architect-critic veto (veto → auto-reclassify to bone; ambiguous/contradictory/stale findings → ESCALATE, never pass; user override recorded with a reason) plus an independent bone-touch judge, emit RELEASE.md, and sketch the next release. Use this when the user wants to plan a release, run /plan-release, groom the feature map, pick spines for the next release, or plan Release 0 (the skeleton). Requires a project onboarded via /start. Do NOT use for spec-core onboarding (use /start) or spine decomposition into work items (use /plan-spine).
---
```

Body sections (mirror `planning-project-roadmap` shape; `oss` shell-out contract paragraph in Pre-flight; body ≤~500 lines):
1. **Overview** — release planning fixes the "no usable software early" failure; where it sits (after `start`, before `plan-spine`).
2. **When to use** (+ `Do NOT auto-invoke when:` → `/start`, `/plan-spine`).
3. **Pre-flight** — `oss` shell-out contract; manifest + onboarded-project probe (state exists with bones); refuse otherwise.
4. **Inputs** — feature map (`oss feature_list`), bones registry (touch surfaces), previous retro (n/a for Release 0), and **mandatory real-use findings** since the last release → recorded via `oss release_set_meta`. `Full input contract in references/real-use-findings.md`.
5. **Select spines + exit criteria + ledger budget** — pick spines from the map; phrase exit criteria as user journeys ("at close, a user can …") → `oss spine_add` + `oss release_set_meta` (exit_criteria). **Set the release's ledger wall-clock budget here** (§6.1: the demo ledger has a wall-clock budget set at release planning — exceeding it forces a prune/parallelize/deepen decision at planning) → `oss release_set_meta <release> '{"ledger_budget":"<Ns>"}'`. Release 0: normal ceremony with the skeleton spine pre-seeded from `start`'s skeleton-cut (bone by definition).
6. **Sequence by DAG** — explicit inter-spine dependency DAG at spine granularity → `oss release_set_meta` (spine_dag). `Full method in references/spine-sequencing-dag.md`.
7. **Declare class + critic veto** — the fail-closed veto (see mechanics below). `Full input contract in references/critic-veto.md`; `bone-touch judge in references/bone-touch-judge.md`; `class rules in references/class-declaration.md`.
8. **Emit RELEASE.md** — create `docs/specs/release-N/`; emit RELEASE.md (goal, spine order + dependencies, classes, exit criteria). `Full template in references/release-md-emission.md`.
9. **Sketch the next release** — goal + candidate spines, no detail (rolling wave). `Full rule in references/rolling-wave.md`.
10. **Slash-command interaction** — `$ARGUMENTS` bridge; never `$1`/`$2`.
11. **Anti-patterns** — auto-passing an ambiguous critic finding (must ESCALATE); silently overriding a veto (must record a reason); detailing more than the next release; skipping the mandatory real-use-findings input.
12. **Notes on tool boundaries.**

The critic-veto + bone-touch mechanics (step 7 body — plugin-side interpretation, no architect-critic change):
```
a. Bone-touch judge (independent of the critic): for each spine plan, `oss touch_check <changed-paths...>`. Any hit → `oss class_set <spine> bone "bone-touch: <hit>"` + `oss veto_add <spine> "<hit>" auto-bone "touch-surface overlap"`. A risk-gate hit additionally attaches that gate's control checklist to the spine's close path.
b. Critic veto: submit RELEASE.md + bones registry (with touch surfaces) + each spine plan to `Skill(architect-critic:critiquing-spec, target=..., depth=...)` (probe via `oss critic_detect`; warn-and-skip if absent). Interpret findings:
   - Clear veto finding → `oss class_set <spine> bone "critic veto: <finding>"` + `oss veto_add <spine> "<finding>" auto-bone "<reason>"` (spec-aligned safety default).
   - Ambiguous / contradictory / stale finding → `oss veto_add <spine> "<finding>" escalate "ambiguous|contradictory|stale - fail-closed"` and surface to the user. NEVER auto-pass.
   - User explicitly overrides an auto-bone → `oss class_set <spine> flesh "<user reason>"` + `oss veto_add <spine> "<finding>" override "<user reason>"` (recorded, never silent).
```

- [ ] **Step 2: Author the eight `references/*.md`** — `feature-map-grooming.md` (turning journey/feature entries into candidate spines), `spine-sequencing-dag.md` (DAG method + the `spine_dag` shape `[[spine-id,[deps...]],...]`), `class-declaration.md` (bone = creates/modifies a bone → full ceremony; flesh = entirely on existing bones → core only; class is the only classification), `critic-veto.md` (the full fail-closed input contract + the three ESCALATE cases + override-recording, verbatim to the fixtures), `bone-touch-judge.md` (`oss touch_check` usage + risk-gate control-checklist attach), `real-use-findings.md` (the mandatory pilot-evidence input; the motivation loop; n/a for Release 0), `release-md-emission.md` (the RELEASE.md template + `docs/specs/release-N/` creation via `oss` id grammar), `rolling-wave.md` (current detailed + next sketched + feature map beyond).

- [ ] **Step 3: Author `ossify/commands/plan-release.md`** — thin wrapper (frontmatter description/argument-hint/allowed-tools + `ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '...'` echo + `Skill(ossify:plan-release)`), same shape as `start.md`.

- [ ] **Step 4: Turn the `critic-veto-interpretation`, `bone-touch-check`, `spine-class-declaration` surfaces GREEN**

Run those three surfaces per RUNBOOK; then `bash ossify/tests/eval/lib/aggregate-scores.sh` → each surface `N pass / 0 fail`. Revise the relevant `references/*.md` (not the fixtures) on any miss.

- [ ] **Step 5: Commit**

```bash
git add ossify/skills/plan-release ossify/commands/plan-release.md
git commit -m "feat(ossify): plan-release skill - release planning + fail-closed critic veto (Plan B task 7)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8 (B8): `plan-spine` skill — decomposition + demo authoring (re-anchor of planning-vertical-slice)

**Context:** `plan-spine` (L§5.3) re-anchors scaffold-dev's `planning-vertical-slice`: decompose into 1-5 work items (no 4-5 floor), DAG rounds, per-round spec authoring, grill-me for bone spines only, and — new here — demo authoring with the floor rules. Contracted by the B5 `journey-line-floor` fixtures. Reuse `scaffold-dev/skills/planning-vertical-slice/SKILL.md` as the structural exemplar.

**Files:**
- Create: `ossify/skills/plan-spine/SKILL.md` + `references/{decomposition,dag-rounds,spec-authoring,demo-authoring,demo-amendments,fake-ledger-discipline,citation-foldin,cross-repo}.md`
- Create: `ossify/commands/plan-spine.md`

**Interfaces:**
- Consumes (shell-outs): `oss work_item_add <spine> <title> [target_repo]`, `oss ledger_add_auto <spine> <text> <command> <expected>`, `oss ledger_add_user <spine> <text> <outcome>`, `oss ledger_supersede <line> <by-spine> <reason>`, `oss ledger_retire <line> <by-spine> <reason>`, `oss fake_add <boundary> <channel> <reason> <trigger> <expiry-release>`, `oss touch_check`, and `Skill(ai-mentor:grill-me)` (bone spines only).

- [ ] **Step 1: Author `ossify/skills/plan-spine/SKILL.md`** — frontmatter + body:

Frontmatter:
```yaml
---
name: plan-spine
description: Plan an ossify feature spine — decompose into 1-5 work items (no 4-5 floor), identify rounds via a DAG, author specs per round, offer grill-me for bone spines only, and author the cumulative-demo criteria under the journey-line floor (every spine ≥1 demo line; a user-facing spine ≥1 `user:` journey line phrased as verb + observable outcome, inspector phrasing banned; an internal spine names a consuming user-facing spine scheduled in the current or next release; a measured-quality pass states before/after evidence), with fake-ledger discipline and a mechanical citation fold-in. Work items carry a target_repo. Use this when the user wants to plan a spine, decompose a spine into work items, run /plan-spine, author demo criteria, or start building a spine. Requires a release planned via /plan-release. Do NOT use for release selection (use /plan-release) or spec-core onboarding (use /start).
---
```

Body sections (mirror `planning-vertical-slice` skeleton; `oss` shell-out contract in Pre-flight; body ≤~500 lines):
1. **Overview** — spine decomposition; the deliberate changes from `planning-vertical-slice` (1-5 items, per-round specs, grill for bone only, demo authoring moves here).
2. **When to use** (+ `Do NOT auto-invoke when:` → `/plan-release`, `/start`).
3. **Pre-flight** — `oss` shell-out contract; manifest + release-exists probe; refuse otherwise.
4. **Decomposition** — 1-5 work items (a thin spine of 1-3 is legitimate) → `oss work_item_add <spine> <title> [target_repo]`. `Full worked example in references/decomposition.md`.
5. **Round identification (DAG)** — rounds via dependency DAG; cross-repo ordering (round 1 public port, round 2 private adapter). `Full method in references/dag-rounds.md` and `references/cross-repo.md`.
6. **Spec authoring** — per-round where the DAG allows (the critic sees the full spine plan); citation fold-in as a mechanical step. `Full grammar in references/spec-authoring.md`; `citation rules in references/citation-foldin.md`.
7. **Grill-me gate** — offered for **bone spines only** (and on any fix-up replan); skipped for flesh → `Skill(ai-mentor:grill-me)`.
8. **Demo authoring** — the floor rules (see below) → `oss ledger_add_auto` / `oss ledger_add_user`; amendments → `oss ledger_supersede`/`retire`. `Full floor rules in references/demo-authoring.md`; `amendments in references/demo-amendments.md`.
9. **Fake-ledger discipline** — every introduced/retained fake records a fake-ledger entry (boundary, channel, reason, replacement trigger, expiry release) → `oss fake_add`; the banned-fakes list. `Full rules in references/fake-ledger-discipline.md`.
10. **Slash-command interaction** — `$ARGUMENTS` bridge; never `$1`/`$2`.
11. **Anti-patterns** — inspector-phrased journey lines; a `4-5`-item floor; grill on flesh; a measured-quality pass with no before/after evidence; an internal spine with no named consumer.
12. **Notes on tool boundaries.**

The demo-authoring floor rules (step 8 body — the binding contract for `journey-line-floor`):
```
- Every spine MUST contribute ≥1 demo line to the cumulative ledger.
- A user-facing spine MUST contribute ≥1 `user:` journey line = a verb + observable outcome (an action the user performs for value). Inspector phrasing ("inspect", "view", "open the record/file/schema") is banned — `oss ledger_add_user` mechanically rejects it (rc 2); phrase for value.
- An internal spine (rare; declared at release planning) may contribute `auto:` lines only, and is admitted ONLY if it names the committed user-facing spine that consumes it, scheduled in the current or next release (one-release-ahead cap); else it returns to the feature map. It cannot claim product value.
- A deepening pass claiming a measured quality (perf/reliability/cost) MUST state before/after evidence in its demo contribution.
- Every `auto:` line binds to a runnable command + declared expected (`exit:<n>` | `contains:<str>`) at authoring time → `oss ledger_add_auto` (a line that can't state its command doesn't enter the ledger).
```

- [ ] **Step 2: Author the eight `references/*.md`** — `decomposition.md` (1-5 item guidance + worked example; the anti-microscope floor no longer applies), `dag-rounds.md` (strict-layer DAG + round identification), `spec-authoring.md` (per-round authoring; the critic sees the full plan), `demo-authoring.md` (the full floor rules verbatim to the fixtures + the `oss ledger_add_*` calls), `demo-amendments.md` (supersede/retire with reason; retired lines archived not deleted), `fake-ledger-discipline.md` (the banned-fakes list + replacement trigger + expiry via `oss fake_add`; AI providers always behind a product-owned swappable interface), `citation-foldin.md` (the mechanical citation check; new target set = lean MASTER-SPEC sections + bones ADRs + prior releases' increments; mandatory re-verify after bone changes), `cross-repo.md` (each work item targets exactly one repo via `target_repo`; the DAG orders cross-repo deps; multi-repo worktree spin-up is Plan D).

- [ ] **Step 3: Author `ossify/commands/plan-spine.md`** — thin wrapper, same shape as `start.md`/`plan-release.md`, `Skill(ossify:plan-spine)`.

- [ ] **Step 4: Turn the `journey-line-floor` surface GREEN**

Run the surface per RUNBOOK; `bash ossify/tests/eval/lib/aggregate-scores.sh` → `journey-line-floor: 4 pass / 0 fail`. The mechanical inspector-phrasing floor already lives in `oss_ledger_add_user` (B1/Plan A) — the skill's `user:` guidance must not contradict it. Revise `references/demo-authoring.md` (not the fixtures) on any miss.

- [ ] **Step 5: Commit**

```bash
git add ossify/skills/plan-spine ossify/commands/plan-spine.md
git commit -m "feat(ossify): plan-spine skill - decomposition + demo authoring with journey-line floor (Plan B task 8)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9 (B9): Integration + skill-listing budget + parity verification

**Context:** Prove the onboarding→planning chain works end-to-end, that the every-call skill-listing budget stays ≈0.3-0.4% with the 3 new entry skills, and that the repo-root parity suite stays green (ossify absent from `marketplace.json`/`V0_PLUGINS`).

**Files:**
- Create: `ossify/tests/test-integration-planning.sh`

**Interfaces:** Consumes every new op/wrapper from B1-B4 — this test is the de-facto full-op replay guard for the planning ops (handoff §5).

- [ ] **Step 1: Write the end-to-end integration test** — `ossify/tests/test-integration-planning.sh`

```bash
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
TMP="$(mktemp -d)"; export OSS_STATE_FILE="$TMP/state.json"

# start-shaped writes
oss_cmd_init "e2e" >/dev/null
oss_cmd_posture_set "fully-private" >/dev/null
oss_cmd_overlay_set '$PULSE_PROMPT_DIR' >/dev/null
oss_cmd_bone_add "ADR-0002" "hexagonal core" "src/domain/**,src/port.rs" "revisit at MVP" >/dev/null
oss_cmd_risk_gate_add "live-exec" "src/exec/**" "paper-env,human-confirm,kill-switch,audit-trail" >/dev/null
oss_cmd_feature_add "paper trade" "place a paper trade" "flesh" "journey-map" >/dev/null

# plan-release-shaped writes
REL="$(oss_cmd_release_add "Skeleton" "core loop usable")"
t_assert_eq "r0" "$REL" "release r0"
SP="$(oss_cmd_spine_add r0 "trade entry" bone)"
t_assert_eq "r0.s1" "$SP" "spine r0.s1"
oss_cmd_release_set_meta r0 '{"exit_criteria":["at close a user can place a paper trade"],"spine_dag":[["r0.s1",[]]],"real_use_findings":["n/a for release 0"]}' >/dev/null
# bone-touch judge: a plan path hits the bone surface -> auto-bone veto recorded
t_capture oss_cmd_touch_check "src/domain/order.rs"
t_assert_rc 0 "touch check hits bone"
oss_cmd_veto_add r0.s1 "src/domain/order.rs" auto-bone "bone-touch" >/dev/null

# plan-spine-shaped writes
oss_cmd_work_item_add r0.s1 "wire the entry point" canonical >/dev/null
DA="$(oss_cmd_ledger_add_auto r0.s1 "core loop runs" "bash -c 'exit 0'" "exit:0")"
t_assert_eq "d1" "$DA" "auto demo line d1"
DU="$(oss_cmd_ledger_add_user r0.s1 "place a paper trade and see it in open positions" "position appears")"
t_assert_eq "d2" "$DU" "user journey line d2"
# inspector phrasing rejected at authoring time
t_capture oss_cmd_ledger_add_user r0.s1 "inspect the schema" "schema seen"
t_assert_rc 2 "inspector phrasing rejected"

# demo runner over the accumulated auto lines
t_capture oss_cmd_demo_run "$OSS_STATE_FILE"
t_assert_rc 0 "cumulative auto-demo passes"

# doctor green + replay clean over the whole chain
t_capture oss_cmd_doctor "$OSS_STATE_FILE"
t_assert_contains "$T_OUT" "ok: schema" "doctor schema ok"
t_assert_contains "$T_OUT" "ok: shape" "doctor shape ok"
t_assert_contains "$T_OUT" "ok: replay" "doctor replay ok"
t_capture oss_state_replay "$OSS_STATE_FILE"
t_assert_rc 0 "full-chain replay clean"

unset OSS_STATE_FILE
rm -rf "$TMP"
t_summary
```

- [ ] **Step 2: Run it (and add it to the suite implicitly)**

Run: `bash ossify/tests/test-integration-planning.sh`
Expected: `pass=N fail=0`. (`run-all.sh` globs `test-*.sh`, so it is picked up automatically.)

- [ ] **Step 3: Full ossify suite + repo-root parity**

Run: `bash ossify/tests/run-all.sh`
Expected: `ALL GREEN`.
Run: `for t in tests/test-*.sh; do bash "$t" >/dev/null 2>&1 || echo "ROOT-FAIL: $t"; done`
Expected: no `ROOT-FAIL` lines (ossify stays absent from `.claude-plugin/marketplace.json`; the parity suite reads only registered plugins + its hardcoded `V0_PLUGINS`).

- [ ] **Step 4: Skill-listing budget check (host `/doctor`)**

With the 3 new entry skills present (`start`, `plan-release`, `plan-spine`), confirm via the host `/doctor` command that the every-call skill-listing cost is ≈0.3-0.4% (spec §9.1, handoff §6). Confirm all ceremony depth lives in `references/` (zero listing cost) and each SKILL.md body is ≤~500 lines:
Run: `for f in ossify/skills/*/SKILL.md; do echo "$f: $(wc -l < "$f") lines"; done`
Expected: each ≤ ~500. (If any exceeds, move depth into `references/`.) Record the `/doctor` budget reading in the SDD ledger.

- [ ] **Step 5: Commit**

```bash
git add ossify/tests/test-integration-planning.sh
git commit -m "test(ossify): end-to-end onboarding->planning integration + full-op replay guard (Plan B task 9)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (performed at authoring)

**1. Spec coverage.**
- L§4 spec-core onboarding (journey map, skeleton-cut, bones, risk gates, smoke-test, **feasibility spike / §4 station 3**, lean-bootstrap, critic moment) → B6 (spike routed under `start` per §9.1 via `references/spike-contract.md`). B§3 posture block (posture, moat→channels, PUBLIC_BOUNDARY.md, placement rule) → B6. ✓
- L§5.2 release planning (feature groom, exit-criteria-as-journeys, DAG, class + fail-closed critic veto, RELEASE.md, rolling wave, real-use findings) → B7. ✓
- L§5.3 spine planning (1-5 work items, per-round specs, grill for bone only, demo floor rules, amendments, fake ledger, citation fold-in) + B§ `target_repo` → B8. ✓
- L§9.1 entry-skill tree ≤6 + references progressive disclosure + budget → B6-B8 structure + B9 budget check. ✓
- L§9.2 state safety (the ID-mint gap, handoff §5) → B1; manifest/state-path resolution (Plan A deferral) → B2. ✓
- L§13.4 eval fixtures for the planning judges (10 scenarios + 3 failure modes + 3 postures) → B5; skills turn surfaces green in B6-B8. ✓
- L§12 no new architect-critic interface (plugin-side veto/bone-touch interpretation) → B7 mechanics. ✓
- Deferred correctly to C/D (not in this plan): execution/close, fake-expiry enforcement, boundary audit, `add-private-core`, multi-repo worktrees, marketplace registration, consolidated ship gate. ✓ (Series map records them.)

**2. Placeholder scan.** No "TBD/TODO/implement later" in code steps; every bash/markdown step shows complete content or (for skill prose) a complete section-skeleton + exact `oss` calls + reference content specs + the binding eval fixtures. The critic-moment, frontmatter, floor rules, and command wrappers are verbatim. Skill prose is authored to the eval contract (the repo's established pattern — `planning-vertical-slice` is "contracted by its eval").

**3. Type/name consistency.**
- `oss_state_mutate` 4th arg = mint spec (`release`/`spine:<rel>`/`work_item:<spine>`/`demo`) — consistent across B1 (definition), B3/B4 (entity fns pass it). ✓
- `_oss_resolve_state` (B2) used by every `oss_cmd_*` wrapper (B3, B4, B6). ✓
- New ops `set_composition`/`set_overlay` (B3), `set_release_meta`/`add_veto_disposition` (B4) all added to `_oss_apply_op` additively and covered by replay assertions in `test-concurrency.sh` (B1) / `test-dispatcher-ops.sh` (B3) / `test-release-planning.sh` (B4) — NOT by appending to `test-state-replay.sh` (whose tail is drift-tampered + base-deleted). ✓
- `veto_dispositions[]` seeded in `oss_state_init` (B4); deliberately NOT gated in `oss_cmd_doctor`'s shape loop (additive/tolerant — a valid v1 state lacking it must not hard-fail doctor; the `add_veto_disposition` op tolerates its absence). ✓
- `target_repo` on work items: `oss_entity_add_work_item` (B4) ↔ `oss_cmd_work_item_add` (B4) ↔ integration test (B9). ✓
- Eval surfaces named identically across B5 (dirs/rubrics), B6/B7/B8 (which surface each turns green), B9. ✓
- rc taxonomy preserved (2 usage for bad class/disposition/expected; 7 unknown-ref; 3 lock; 4 apply; 5 drift; 6 schema). ✓

**Fixes applied at authoring:** work-item `target_repo` consolidated into B4 (single edit to `oss_entity_add_work_item` + its wrapper) rather than split across B1/B3, so no function is edited for the same field twice; `oss_cmd_critic_detect` folded into B6 (its first consumer) with its own RED assertion rather than orphaned in B3.

**Fixes applied from the 3-lens adversarial self-review (2026-07-17):**
- **[CRITICAL]** Dropped the B1 + B4 "append to `test-state-replay.sh`" steps — that file tampers the live state and deletes the base snapshot before its tail, so appended `replay-clean` (rc 0) assertions would return rc 5/rc 1 and red the suite (empirically confirmed by a reviewer running the change). Mint-path + new-op replay coverage already lives in `test-concurrency.sh` and `test-release-planning.sh`; added explicit "do NOT append" warnings.
- **[IMPORTANT]** Removed `veto_dispositions` from `oss_cmd_doctor`'s required-key loop (kept the seed in init) — gating it would hard-fail a valid v1 state that predates the field, contradicting the tolerant-ops rule + §9.2.
- **[IMPORTANT]** Added the feasibility-spike contract under `start` (`references/spike-contract.md` + a §9a body step) — §9.1 routes `start` → "spike contract"; it was missing.
- **[IMPORTANT]** Added an explicit ledger-wall-clock-budget authoring step to B7 §5 (§6.1 mandates it be set at release planning; B4's context claimed it but no step wrote it).
- **[MINOR]** Added `05-contradictory-escalates` (completes the fail-closed triad) + `05-deepening-no-evidence` fixtures and a 6th `before_after_evidence` journey-line-floor rubric criterion; fixed the internal-spine window to "current or next release (one-release-ahead cap)"; replaced the posture rubric's out-of-output criterion 5 with a moat→channel mapping criterion and documented `none` as the fully-open sentinel; scoped the Global-Constraints `_oss_apply_op`-unchanged sentence to the B1 mint change (new ops are additive).

