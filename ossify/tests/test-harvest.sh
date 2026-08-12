#!/usr/bin/env bash
# Task 12 (C1-12) — lib/harvest.sh: the memory-bank harvest.
#
# SCOPE, stated plainly so nobody infers coverage that does not exist.
#
# COVERED here: the two mechanical facts the harvest owns — where the memory
# bank IS (manifest-routed, token-resolved, unresolved-token-refused) and
# whether an entry is already there (an anchored content-hash match, not a
# `grep -F` over the text). Every fixture below is one member of the defect
# class D8 says to rebuild rather than port, plus the payload rejection and the
# count/rc contract. Driven both sourced and through `bin/oss` (which runs
# `set -euo pipefail`, so a strict-mode-only fault is visible).
#
# NOT COVERED, and not coverable by a bash test: **the ceremony itself** —
# enumerating the spine's work items, reading `## 9. Suggestions for memory
# bank`, categorising, tagging `[report]`/`[handoff]`, and the accept/edit/
# reject turn. That is prose (`close/references/harvest.md`) with no executable
# surface; a script that authored its own payload and then harvested it would be
# testing a fixture, not the ceremony. The cross-file prose contracts that DO
# have a mechanical surface — the §9 heading and spine-close step 9's wiring —
# are checked in section E.
#
# FIXTURE SAFETY: `oss_manifest_discover` walks up from $PWD, so every call here
# is made from inside $TMP/ws after a `cd`, and section A asserts the resolved
# directory is under $TMP. Without that, a suite run from inside a real paired
# workspace would append these fixtures into the developer's own memory bank.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in manifest harvest; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
SKILLS="$HERE/../skills"
TMP="$(mktemp -d)"

mkdir -p "$TMP/ws/.workspace" "$TMP/canon"

# $1 is the well_known_paths object. The heredoc is unquoted so "$1" expands,
# but its VALUE is not re-scanned — a `${ai_workspace.root}` inside it reaches
# the file literally, which is the whole point of fixtures (f) and (g).
_manifest() {
  cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":$1}
JSON
}

# Count occurrences of a ONE-LINE literal in a file. `grep -Fc` returns 1 on no
# match while still printing 0, so the `|| true` keeps the count and drops the rc.
_count() { grep -Fc -- "$1" "$2" 2>/dev/null || true; }

_ok()   { T_PASS=$((T_PASS+1)); }
_bad()  { T_FAIL=$((T_FAIL+1)); echo "FAIL: $1"; }

# ---------------------------------------------------------------------------
# A. Where the memory bank IS. The P0 this task exists to close: the routed key
#    is token-bearing on every manifest workspace-init emits, and a raw read
#    resolves to a directory literally named ${ai_workspace.root}.
# ---------------------------------------------------------------------------
_manifest '{}'
cd "$TMP/ws"

t_capture oss_harvest_memory_bank_dir
t_assert_rc 0 "convention default resolves"
t_assert_eq "$TMP/ws/.claude/memory-bank" "$T_OUT" "convention default is <ai_workspace.root>/.claude/memory-bank"

# (f) THE TOKEN FORM — the shape workspace-init actually writes. A literal-path
# fixture passes with a token-blind implementation and proves nothing.
_manifest '{"memory_bank":"${ai_workspace.root}/.claude/memory-bank"}'
t_capture oss_harvest_memory_bank_dir
t_assert_rc 0 "(f) a token-form memory_bank resolves"
t_assert_eq "$TMP/ws/.claude/memory-bank" "$T_OUT" "(f) the \${ai_workspace.root} token is EXPANDED, not echoed literally"
case "$T_OUT" in
  *'${'*) _bad "(f) the resolved path still carries a \${...} token: $T_OUT" ;;
  *)      _ok ;;
esac
case "$T_OUT" in
  "$TMP"/*) _ok ;;
  *)        _bad "(f) the resolved dir escaped the fixture tmpdir ($T_OUT) — an ambient manifest was read" ;;
esac

# (5) PRECEDENCE: the manifest key beats the convention path. Same manifest,
# a routed value that is NOT the convention path — the answer must follow it.
_manifest '{"memory_bank":"${ai_workspace.root}/mb-routed"}'
t_capture oss_harvest_memory_bank_dir
t_assert_rc 0 "the routed key resolves"
t_assert_eq "$TMP/ws/mb-routed" "$T_OUT" "the manifest key WINS over the <ai_root>/.claude/memory-bank convention"

# (g) an UNRESOLVABLE token is refused, never passed through as a literal.
_manifest '{"memory_bank":"${private_core.root}/mb"}'
t_capture oss_harvest_memory_bank_dir
t_assert_rc 1 "(g) an unresolvable token is refused"
t_assert_contains "$T_OUT" "unresolved" "(g) the refusal names the unresolved path"

# (g2) a RELATIVE route is refused too, and this is the sharper of the two: the
# token guard above always caught `${...}`, but a bare relative value came back
# from `_oss_manifest_resolve` unchanged and passed. Every consumer then composed
# `<relative>/03-code-patterns.md` against its own $PWD — so `doctor`'s rule
# authoring, which promises a manifest-routed AI-workspace path, could write into
# the canonical repo or wherever the caller happened to be standing. A WRITE path
# resolving against cwd is the worst of the three well-known paths to leave
# unguarded. (Codex P2, PR #149 round 2.)
_manifest '{"memory_bank":"mb-relative"}'
t_capture oss_harvest_memory_bank_dir
t_assert_rc 1 "(g2) a RELATIVE memory_bank route is refused, not resolved against the cwd"
t_assert_contains "$T_OUT" "not absolute" "(g2) the refusal names absoluteness, not tokens"

# No manifest anywhere on the walk-up path.
cd "$TMP"
t_capture oss_harvest_memory_bank_dir
t_assert_rc 1 "no manifest on the walk-up path -> rc 1"
t_assert_contains "$T_OUT" "/init-workspace" "the refusal keeps the slash-command tokens"
cd "$TMP/ws"

# ---------------------------------------------------------------------------
# B. The payload gate. Rejection is whole-payload and happens BEFORE any
#    filesystem mutation — the valid item in a rejected payload leaves no trace,
#    and the memory-bank directory is not even created.
# ---------------------------------------------------------------------------
_manifest '{"memory_bank":"${ai_workspace.root}/.claude/memory-bank"}'
MB="$TMP/ws/.claude/memory-bank"
# The state path is passed for dispatcher symmetry and is deliberately NOT read:
# the harvest writes to the memory bank, never to state, so it journals no op.
# Asserted below by the file never coming into existence.
SF="$TMP/ws/.ossify/project-state.json"

t_capture oss_harvest_apply "$SF" '[]'
t_assert_rc 0 "an empty payload is rc 0"
t_assert_eq "harvest: wrote 0, skipped 0" "$T_OUT" "an empty payload reports wrote 0, skipped 0"
if [ -e "$MB" ]; then _bad "an empty payload created the memory-bank directory"; else _ok; fi

REJECT="$(jq -c -n '[{source:"report",source_id:"r1.s2.w1",target_file:"09-known-issues.md",text:"a perfectly valid first item"},
                     {source:"report",source_id:"r1.s2.w2",target_file:"02-system-patterns.md",text:"a spec-derived target"}]')"
t_capture oss_harvest_apply "$SF" "$REJECT"
t_assert_rc 2 "a target outside the two-file allowlist rejects the WHOLE payload"
t_assert_contains "$T_OUT" "02-system-patterns.md" "the rejection names the offending target"
if [ -e "$MB/09-known-issues.md" ]; then
  _bad "the rejection happened AFTER writing the valid item — it must precede every filesystem write"
else _ok; fi
if [ -e "$MB" ]; then _bad "the rejection created the memory-bank directory"; else _ok; fi

t_capture oss_harvest_apply "$SF" "$(jq -c -n '[{source:"retro",source_id:"x",target_file:"09-known-issues.md",text:"t"}]')"
t_assert_rc 2 "a source outside report|handoff is rejected"
t_assert_contains "$T_OUT" "retro" "the rejection names the offending source"

t_capture oss_harvest_apply "$SF" '{"source":"report"}'
t_assert_rc 2 "a payload that is not a JSON array is rejected"
t_assert_contains "$T_OUT" "array" "...and says so"

t_capture oss_harvest_apply "$SF" "$(jq -c -n '[{source:"report",source_id:"x",target_file:"09-known-issues.md"}]')"
t_assert_rc 2 "an item with no .text is rejected"

t_capture oss_harvest_apply "$SF" 'not json at all'
t_assert_rc 2 "an unparseable payload is rejected"

# ---------------------------------------------------------------------------
# C. The defect class. Every text below skips at rc 0 under the ported
#    `grep -Fq "$text"` check (or, for the dash one, appends twice) — that is
#    issue #115's real mechanism and its inverse.
# ---------------------------------------------------------------------------
# (a) a BLANK LINE inside the text: `grep -F` reads the empty line as one
#     alternative, which matches any non-empty file, so the item "already
#     exists" and the whole payload skips at rc 0.
TEXT_A=$'The exporter drops the trailing newline.\n\nWorkaround for FIXTURE-A: append it in the caller.'
# host for the (c) substring fixture below.
TEXT_HOST='FIXTURE-C-HOST: the ledger writer holds the lock for the whole run.'
# (d) text starting with `-`: with no `--` terminator BSD grep reads it as
#     OPTIONS and exits rc 2 "invalid option", so the `if` is false and the
#     append fires whether or not the entry is already there.
TEXT_D='- FIXTURE-D: watch out for the race in worker.py'
TEXT_DEC='FIXTURE-DEC: chose cksum over sha256 for the harvest trailer.'

PAY_1="$(jq -c -n --arg a "$TEXT_A" --arg h "$TEXT_HOST" --arg d "$TEXT_D" --arg x "$TEXT_DEC" '
  [ {source:"report",  source_id:"r1.s2.w1", target_file:"09-known-issues.md",  text:$a},
    {source:"report",  source_id:"r1.s2.w2", target_file:"09-known-issues.md",  text:$h},
    {source:"handoff", source_id:"r1.s2.w3", target_file:"09-known-issues.md",  text:$d},
    {source:"report",  source_id:"r1.s2.w1", target_file:"10-decisions-log.md", text:$x} ]')"

t_capture oss_harvest_apply "$SF" "$PAY_1"
t_assert_rc 0 "first apply of a 4-item payload is rc 0"
t_assert_eq "harvest: wrote 4, skipped 0" "$T_OUT" "(a)+(d) every item is written on a FIRST apply — the blank-line text is not skipped"
KI="$MB/09-known-issues.md"; DL="$MB/10-decisions-log.md"
if [ -f "$KI" ] && [ -f "$DL" ]; then _ok; else _bad "the harvest did not create both target files under $MB"; fi
t_assert_eq "1" "$(_count 'The exporter drops the trailing newline.' "$KI")" "(a) the blank-line entry landed exactly once"
t_assert_eq "1" "$(_count "$TEXT_D" "$KI")" "(d) the leading-dash entry landed exactly once"
t_assert_eq "1" "$(_count "$TEXT_DEC" "$DL")" "the decisions item landed in 10-decisions-log.md"
t_assert_eq "0" "$(_count "$TEXT_DEC" "$KI")" "...and NOT in 09-known-issues.md"

# (e) the SAME payload applied twice. This is the apply on which (d)
#     discriminates: on a first apply both a correct and a broken check append,
#     because the entry genuinely is not there yet.
t_capture oss_harvest_apply "$SF" "$PAY_1"
t_assert_rc 1 "(e) an all-duplicate payload is rc 1 — non-empty and nothing written"
t_assert_eq "harvest: wrote 0, skipped 4" "$T_OUT" "(e) ...reported honestly as wrote 0, skipped 4"
t_assert_eq "1" "$(_count 'The exporter drops the trailing newline.' "$KI")" "(a) still exactly once after a second apply"
t_assert_eq "1" "$(_count "$TEXT_D" "$KI")" "(d) still exactly once after a second apply — the dash text is not re-appended"
t_assert_eq "1" "$(_count "$TEXT_DEC" "$DL")" "the decisions entry is still exactly once"

# (b) MULTI-LINE text whose FIRST line is already in the file (it is TEXT_A's
#     last line). The entry as a whole is new and must be written.
TEXT_B=$'Workaround for FIXTURE-A: append it in the caller.\nFIXTURE-B: the same fix applies to the CSV writer.'
# Precondition, asserted rather than assumed: this fixture only exercises
# "one line already present" if that line really is present. It is TEXT_A's last
# line, and TEXT_A is written by the (a) fixture above — so a regression that
# skips (a) would otherwise quietly turn this case into a plain new-entry test.
t_assert_eq "1" "$(_count 'Workaround for FIXTURE-A: append it in the caller.' "$KI")" "(b) precondition: the line this entry shares with (a) IS already in the file"
t_capture oss_harvest_apply "$SF" "$(jq -c -n --arg b "$TEXT_B" '[{source:"report",source_id:"r1.s2.w4",target_file:"09-known-issues.md",text:$b}]')"
t_assert_rc 0 "(b) a multi-line entry whose one line already exists is still written"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "(b) ...and counted as a write"
t_assert_eq "1" "$(_count 'FIXTURE-B: the same fix applies to the CSV writer.' "$KI")" "(b) the new entry is in the file"

# (c) text that is a strict SUBSTRING of existing content.
TEXT_C='the ledger writer holds the lock'
t_assert_eq "1" "$(_count "$TEXT_C" "$KI")" "(c) precondition: the substring occurs once (inside the host entry) before this apply"
t_capture oss_harvest_apply "$SF" "$(jq -c -n --arg c "$TEXT_C" '[{source:"report",source_id:"r1.s2.w5",target_file:"09-known-issues.md",text:$c}]')"
t_assert_rc 0 "(c) a substring of existing content is still a new entry"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "(c) ...and counted as a write"
t_assert_eq "2" "$(_count "$TEXT_C" "$KI")" "(c) the substring now occurs twice — host entry plus the new one"

# ---------------------------------------------------------------------------
# D. The hash lookup is ANCHORED on the trailer's closing delimiter. `cksum`
#    emits variable-width decimals, so an unanchored `h:123` lookup is satisfied
#    by a stored `h:1234` and the new entry is silently skipped — the same
#    "skips when it should write" outcome as the bug the hash replaces.
#
#    These two texts are a REAL cksum prefix collision, found by search:
#      h(TEXT_LONG)  = 1001618902
#      h(TEXT_SHORT) =  100161890   <- a proper decimal prefix of the above
# ---------------------------------------------------------------------------
TEXT_COLL_LONG='Prefix-collision probe 614644 for the harvest hash anchor.'
TEXT_COLL_SHORT='Prefix-collision probe 338442 for the harvest hash anchor.'
H_LONG="$(printf '%s' "$TEXT_COLL_LONG" | cksum | awk '{print $1}')"
H_SHORT="$(printf '%s' "$TEXT_COLL_SHORT" | cksum | awk '{print $1}')"
# Precondition, asserted so the fixture cannot rot into a vacuous pass.
if [ "$H_LONG" != "$H_SHORT" ]; then _ok; else _bad "the collision fixture's two hashes are equal — it cannot discriminate"; fi
case "$H_LONG" in
  "$H_SHORT"?*) _ok ;;
  *) _bad "the collision fixture no longer collides: h=$H_SHORT is not a proper prefix of h=$H_LONG" ;;
esac

t_capture oss_harvest_apply "$SF" "$(jq -c -n --arg t "$TEXT_COLL_LONG" '[{source:"report",source_id:"r1.s2.w6",target_file:"09-known-issues.md",text:$t}]')"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "the longer-hash entry is written first"
t_capture oss_harvest_apply "$SF" "$(jq -c -n --arg t "$TEXT_COLL_SHORT" '[{source:"report",source_id:"r1.s2.w7",target_file:"09-known-issues.md",text:$t}]')"
t_assert_rc 0 "a hash that is a PREFIX of a stored hash is still a new entry"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "...and is written, not skipped"
t_assert_eq "1" "$(_count "$TEXT_COLL_SHORT" "$KI")" "the prefix-hash entry is in the file exactly once"
t_assert_eq "1" "$(_count "$TEXT_COLL_LONG" "$KI")" "and the entry it collided with is untouched"

# The skip test is scoped to the TARGET FILE: the same text harvested to both
# live files must land in both — a hash in 09 cannot suppress a write to 10.
TEXT_BOTH='FIXTURE-SCOPE: the same sentence is both a caveat and a decision.'
t_capture oss_harvest_apply "$SF" "$(jq -c -n --arg t "$TEXT_BOTH" '[{source:"report",source_id:"r1.s2.w8",target_file:"09-known-issues.md",text:$t}]')"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "the shared text lands in 09-known-issues.md"
t_capture oss_harvest_apply "$SF" "$(jq -c -n --arg t "$TEXT_BOTH" '[{source:"report",source_id:"r1.s2.w8",target_file:"10-decisions-log.md",text:$t}]')"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "...and ALSO in 10-decisions-log.md — the skip test is per-file"
t_assert_eq "1" "$(_count "$TEXT_BOTH" "$KI")" "present in 09"
t_assert_eq "1" "$(_count "$TEXT_BOTH" "$DL")" "present in 10"

# The provenance trailer carries the source id, the source kind and the hash.
if grep -Fq -- "source: handoff; h:" "$KI"; then _ok; else _bad "no handoff-sourced provenance trailer in $KI"; fi
if grep -Fq -- "ossify harvest: r1.s2.w1" "$KI"; then _ok; else _bad "the trailer does not carry the source id"; fi

# The harvest journals NO op: after nine applies the state file still does not
# exist. Task 12 adds no state operation, and a reviewer must not add one.
if [ -e "$SF" ]; then _bad "the harvest touched the state file — it writes to the memory bank, not to state"; else _ok; fi

# An unresolvable memory-bank path must NOT degrade into a write somewhere else:
# rc 1, and no directory literally named ${...} anywhere under the workspace.
_manifest '{"memory_bank":"${private_core.root}/mb"}'
t_capture oss_harvest_apply "$SF" "$(jq -c -n '[{source:"report",source_id:"r1.s2.w9",target_file:"09-known-issues.md",text:"must not land anywhere"}]')"
t_assert_rc 1 "an unresolvable memory-bank path is rc 1, not a write into a literal token directory"
t_assert_contains "$T_OUT" "wrote 0" "...and reports that nothing was written"
LITERAL="$(find "$TMP/ws" -maxdepth 2 -name '$*' 2>/dev/null || true)"
t_assert_eq "" "$LITERAL" "no directory literally named \${...} was created"
_manifest '{"memory_bank":"${ai_workspace.root}/.claude/memory-bank"}'

# ---------------------------------------------------------------------------
# E. Through the real dispatcher, which runs `set -euo pipefail`. A sourced-only
#    test cannot see a strict-mode fault (repo lesson: the no-match grep and the
#    counting loop are both strict-mode hazards here).
# ---------------------------------------------------------------------------
t_capture bash "$OSS" harvest_dir
t_assert_rc 0 "dispatcher: harvest_dir works under strict mode"
t_assert_eq "$MB" "$T_OUT" "dispatcher: harvest_dir echoes the resolved memory-bank dir"

t_capture bash "$OSS" harvest_apply "$PAY_1"
t_assert_rc 1 "dispatcher: an all-duplicate payload survives strict mode and returns rc 1"
t_assert_eq "harvest: wrote 0, skipped 4" "$T_OUT" "dispatcher: the counts come back through bin/oss"

t_capture bash "$OSS" harvest_apply "$(jq -c -n '[{source:"handoff",source_id:"work-r1.s2.w9/handoff.md",target_file:"10-decisions-log.md",text:"FIXTURE-DISPATCH: a brand-new decision."}]')"
t_assert_rc 0 "dispatcher: a fresh entry writes under strict mode"
t_assert_eq "harvest: wrote 1, skipped 0" "$T_OUT" "dispatcher: the write is counted"

t_capture bash "$OSS" harvest_apply
t_assert_rc 2 "dispatcher: a missing payload argument is a usage error (rc 2), not an unbound-variable abort"
t_assert_contains "$T_OUT" "usage" "...and says usage"

# The rejection path runs `return 2` from inside a `while … done < <(…)` loop.
# That returns from the FUNCTION only because the loop body is in the current
# shell; a piped loop would return from a subshell and fall through. Sourced
# tests cannot see the difference under strict mode — this one can.
t_capture bash "$OSS" harvest_apply "$REJECT"
t_assert_rc 2 "dispatcher: a rejected payload returns rc 2 through bin/oss under strict mode"
t_assert_contains "$T_OUT" "02-system-patterns.md" "dispatcher: the rejection names the offending target"

t_capture bash "$OSS" harvest_apply '[]'
t_assert_rc 0 "dispatcher: an empty payload is rc 0"

# ---------------------------------------------------------------------------
# F. Cross-file prose contracts. Prose is the executable artifact here and has
#    no other CI: nothing else in this suite can see these drifts.
# ---------------------------------------------------------------------------
# The §9 heading is matched by EXACT STRING at harvest time. If the contract
# that pins it and the ceremony that greps it ever disagree, every report reads
# as "no suggestions" and the harvest is silently empty at rc 0.
_H9='## 9. Suggestions for memory bank'
for f in "$SKILLS/work-item/references/report-contract.md" "$SKILLS/close/references/harvest.md"; do
  if grep -Fq "$_H9" "$f"; then _ok; else _bad "$(basename "$f") does not carry the byte-exact heading '$_H9'"; fi
done

# Step 9 of the spine-close checklist is the harvest's ONLY caller. Until this
# task it named no verb, no payload and no reference — a one-line row that
# called nothing.
for tok in 'oss harvest_dir' 'oss harvest_apply' 'references/harvest.md'; do
  if grep -Fq -- "$tok" "$SKILLS/close/references/spine-close.md"; then
    _ok
  else
    _bad "spine-close.md step 9 does not name '$tok' — the caller does not call"
  fi
done

# The two-file allowlist is enforced in the lib (section B) and must be the same
# two files the ceremony tells the reader to choose between.
for tok in '09-known-issues.md' '10-decisions-log.md'; do
  if grep -Fq -- "$tok" "$SKILLS/close/references/harvest.md"; then
    _ok
  else
    _bad "harvest.md does not name the allowlisted target '$tok'"
  fi
done

cd "$HERE"
rm -rf "$TMP"
t_summary
