---
description: Show the current slice's phase, acceptance-criteria checklist, last test result, and next-step suggestion.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/slice.sh"

if ! sf_is_managed; then
  echo "scaffold: this branch is not initialized. Run /scaffold-init first."
  exit 0
fi

ID="$(sf_current_slice)"
if [[ -z "$ID" ]]; then
  echo "scaffold: no current slice on this branch."
  echo "  Start one: /slice-new <name>"
  echo "  See all:   /slice-list"
  exit 0
fi

STATE="$(sf_read_state)"
SLICE="$(echo "$STATE" | jq -r ".slices[\"$ID\"]")"

PHASE="$(echo "$SLICE" | jq -r .phase)"
SPEC_PATH="$(echo "$SLICE" | jq -r .spec_path)"
TEST_CMD="$(echo "$SLICE" | jq -r ".test_command // \"(none)\"")"
AC_COUNT="$(echo "$SLICE" | jq -r ".acceptance_criteria | length")"
AC_PASSING="$(echo "$SLICE" | jq -r "[.acceptance_criteria[] | select(.status == \"passing\")] | length")"
LAST_TEST="$(echo "$SLICE" | jq -r ".last_test_result.exit_code // \"never run\"")"

echo "Slice: $ID"
echo "  phase:        $PHASE"
echo "  spec:         $SPEC_PATH"
echo "  test_command: $TEST_CMD"
echo "  ACs:          $AC_PASSING / $AC_COUNT passing"
echo "  last verify:  $LAST_TEST"
echo ""
if [[ "$AC_COUNT" -gt 0 ]]; then
  echo "Acceptance criteria (from spec file):"
  echo "$SLICE" | jq -r ".acceptance_criteria[] | \"  [\(if .status == \"passing\" then \"✓\" elif .status == \"failing\" then \"✗\" else \" \" end)] \(.id): \(.text)\""
fi
echo ""
case "$PHASE" in
  spec)      echo "Next: add ACs to ${SPEC_PATH}, then /slice-contract" ;;
  contract)  echo "Next: scaffold failing tests for each AC, then /slice-scaffold" ;;
  scaffold)  echo "Next: write skeletons; tests should still fail. Then /slice-implement" ;;
  implement) echo "Next: add logic; run /slice-verify when ready" ;;
  verify)    echo "Next: tests are failing — fix and re-run /slice-verify" ;;
  complete)  echo "Slice complete. Run /slice-new <name> to start the next one." ;;
esac
'
```

After printing, briefly summarize what the user should do next based on the phase. If phase is `verify` and tests are failing, offer to look at the spec + test files to diagnose.
