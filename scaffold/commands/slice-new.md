---
description: Start a new slice. Creates docs/slices/slice-NN-<name>.md from the slice-spec template, sets phase=spec, makes it the current slice. Refuses if another slice is in progress unless --force.
argument-hint: "<name> [--force]"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/slice.sh"

ARGS="${ARGUMENTS:-$*}"
NAME=""
FORCE=""
for tok in $ARGS; do
  case "$tok" in
    --force) FORCE="--force" ;;
    *) [[ -z "$NAME" ]] && NAME="$tok" ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: /slice-new <name> [--force]"
  echo "Example: /slice-new auth-rewrite"
  exit 1
fi

if ! sf_is_managed; then
  echo "scaffold: this branch is not initialized. Run /scaffold-init first."
  exit 1
fi

ID="$(sf_slice_create "$NAME" "$FORCE")"
RC=$?
if [[ $RC -ne 0 ]]; then exit $RC; fi

REPO_ROOT="$(sf_repo_root)"
SPEC_PATH="$(sf_slice_get_field "$ID" spec_path)"
echo "Created slice: $ID"
echo "  spec file:    ${SPEC_PATH}"
echo "  phase:        spec"
echo "  current:      yes (this is now the active slice)"
echo ""
echo "Next: capture acceptance criteria in the spec file, then /slice-contract."
' "$ARGUMENTS"
```

After running, open the newly-created spec file with the Read tool and walk the user through filling in the user story (persona / capability / outcome) and 2-5 acceptance criteria as numbered checklist items (`- [ ] **AC-1:** measurable behavior`). The spec file already has placeholders from the template — the user iterates on them. AC capture is a Curve-2/decide moment if architecture is unclear; otherwise it's Curve-1. Once ACs are concrete and measurable, advise `/slice-contract` to enter the contract phase.
