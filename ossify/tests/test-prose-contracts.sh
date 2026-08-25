#!/usr/bin/env bash
# Cross-file prose contracts. Prose is an executable artifact here and it has no
# other CI: nothing else in this suite can see a drift between two documents.
#
# The one guarded here is the engine's own deadlock. The callee's pre-flight
# Gate 1 treats a handoff whose Constraints omit `git_policy: STAGE-not-commit`
# or the return JSON shape as MALFORMED, and malformed is itself a gap. So the
# orchestrator-side contract that says what to write into a handoff
# (handoff-contract.md) must agree, to the byte, with the callee-side contract
# that says what will be read back (returns.md) and with the binding body
# (SKILL.md). If they drift, every dispatch returns gaps-surfaced, no work ever
# starts, and there is no runtime signal at all - the failure is two documents
# disagreeing.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
WI="$HERE/../skills/work-item"

# The TEMPLATE line, not the worked example: both files also carry a filled-in
# example of each shape, and those legitimately differ. The templates are the
# ones still holding `<placeholder>` markers.
_shape() { # $1=file $2=mode
  { grep -F "\"mode\": \"$2\"" "$1" || true; } | { grep -F '<' || true; } | head -1
}

for mode in complete gaps-surfaced; do
  base="$(_shape "$WI/references/returns.md" "$mode")"
  # Non-emptiness FIRST. Two files that both fail to match would compare equal,
  # and the parity assertions below would pass while asserting nothing.
  if [ -n "$base" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: returns.md declares no '$mode' template - the parity checks below are vacuous"
  fi
  for f in "$WI/SKILL.md" "$WI/references/handoff-contract.md"; do
    t_assert_eq "$base" "$(_shape "$f" "$mode")" \
      "$(basename "$f") carries the '$mode' return shape byte-identically to returns.md"
  done
done

# The other half of Gate 1's Constraints requirement. handoff-contract.md must
# carry the literal the callee looks for - a paraphrase ("stage, do not commit")
# reads fine to a human and fails the gate.
for f in "$WI/SKILL.md" "$WI/references/pre-flight.md" "$WI/references/handoff-contract.md"; do
  if grep -Fq 'git_policy: STAGE-not-commit' "$f"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $(basename "$f") does not carry the literal 'git_policy: STAGE-not-commit'"
  fi
done

# ---------------------------------------------------------------------------
# Memory-bank harvest contracts. The harvest has no verb since the conversion
# (close/references/harvest.md §7 — "you are the writer"), which makes these
# prose-only contracts the harvest's only mechanical surface. They were held
# by the deleted test-harvest.sh section F; deleting the producer must not
# delete the guard on what it guarded.
# ---------------------------------------------------------------------------
CLOSE="$HERE/../skills/close"

# The §9 heading is matched by EXACT STRING at harvest time. If the contract
# that pins it and the ceremony that greps it ever disagree, every report reads
# as "no suggestions" and the harvest is silently empty at "wrote 0".
_H9='## 9. Suggestions for memory bank'
for f in "$WI/references/report-contract.md" "$CLOSE/references/harvest.md"; do
  if grep -Fq -- "$_H9" "$f"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $(basename "$f") does not carry the byte-exact heading '$_H9'"
  fi
done

# Step 9 of the spine-close checklist must still route to the ceremony's only
# copy — a step that names no reference is a caller that does not call.
if grep -Fq -- 'references/harvest.md' "$CLOSE/references/spine-close.md"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: spine-close.md step 9 does not route to 'references/harvest.md'"
fi

# The two-file allowlist the apply holds in prose must name the same two files
# the ceremony tells the reader to choose between.
for tok in '09-known-issues.md' '10-decisions-log.md'; do
  if grep -Fq -- "$tok" "$CLOSE/references/harvest.md"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: harvest.md does not name the allowlisted target '$tok'"
  fi
done


# --- The manifest refusal: one string, three hardcoded copies -----------------
# Skills may not `source` the libs, so a ceremony that must print the refusal
# verbatim has no choice but to carry the literal. That makes drift the default:
# #272/#310 changed the refusal to name the topology remedies and two ceremonies
# kept printing the pre-topology text, sending a topology-only project to
# /init-workspace. No runtime signal - the ceremony refuses correctly, with the
# wrong remedy. Discovered by grep rather than a fixed list, so a fourth copy is
# covered the moment it is written.
OSSLIB="$HERE/../lib"
OSSSK="$HERE/.."
_refusal_literal() { sed -n 's/^[^"]*"//; s/"$//p' "$1"; }

REF_LIB="$(sed -n 's/^OSS_MANIFEST_REFUSAL="\(.*\)"$/\1/p' "$OSSLIB/manifest.sh")"
if [ -n "$REF_LIB" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: cannot read OSS_MANIFEST_REFUSAL from lib/manifest.sh - the parity checks below are vacuous"
fi

# Every prose file printing the refusal's opening clause must print all of it.
REF_COPIES="$({ grep -rl 'ossify requires a topology declaration' "$OSSSK/skills" "$OSSSK/commands" || true; } | sort)"
REF_N="$(printf '%s\n' "$REF_COPIES" | { grep -c . || true; })"
if [ "$REF_N" -ge 3 ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: only $REF_N prose copy/copies of the manifest refusal found - expected the start, plan-release and plan-spine probes at minimum"
fi

# A pipe into `while` runs the loop in a SUBSHELL and every t_assert_eq inside
# it increments a counter that dies with it - the summary would report a clean
# run having asserted nothing. Read from a file instead.
REF_LIST="$(mktemp)"; printf '%s\n' "$REF_COPIES" > "$REF_LIST"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  got="$({ grep -F 'ossify requires a topology declaration' "$f" || true; } | head -1 | sed 's/^[^"]*"//; s/"$//')"
  t_assert_eq "$REF_LIB" "$got" \
    "$(basename "$(dirname "$f")")/$(basename "$f") prints OSS_MANIFEST_REFUSAL byte-identically"
done < "$REF_LIST"
rm -f "$REF_LIST"

# --- /start's topology probe must not halt ----------------------------------
# The block printed the refusal then `exit 0`, while the paragraph under it said
# to author a topology and carry on. A model following the block stopped; one
# following the prose proceeded - and the no-manifest project is exactly the
# case /start exists to serve, so the halt made the headline feature of
# #272/#310 unreachable through its own ceremony. Mechanical fact, mechanical
# check: the probe block carries no exit.
PROBE="$(awk '/^```bash$/{n++} n==1 && !/^```/{print} /^```$/{if(n==1) exit}' "$OSSSK/skills/start/SKILL.md")"
if printf '%s' "$PROBE" | grep -q 'oss state_path'; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: start/SKILL.md's first bash block is not the topology probe - the exit check below is vacuous"
fi
case "$PROBE" in
  *exit*) T_FAIL=$((T_FAIL+1)); echo "FAIL: start/SKILL.md's topology probe carries an 'exit' - a refused probe must author and proceed, not halt" ;;
  *)      T_PASS=$((T_PASS+1)) ;;
esac

t_summary
