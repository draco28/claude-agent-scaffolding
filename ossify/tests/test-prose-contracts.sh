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

t_summary
