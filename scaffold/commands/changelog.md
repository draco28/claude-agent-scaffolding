---
description: Append an entry to CHANGELOG.md (Keep-a-Changelog). With <Type> <summary> args, adds a bullet under the matching ### subsection in [Unreleased]. With `bump <version>`, rotates [Unreleased] to a new versioned heading. Creates CHANGELOG.md from template if missing.
argument-hint: "<Added|Changed|Fixed|Removed|Security> <summary> | bump <version>"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/changelog.sh"

ARGS="${ARGUMENTS:-$*}"
read -r FIRST REST <<< "$ARGS"

REPO_ROOT="$(sf_repo_root)"
cd "$REPO_ROOT" || exit 1
CHANGELOG="CHANGELOG.md"
TMPL="${CLAUDE_PLUGIN_ROOT}/templates/changelog.md.tmpl"

case "$FIRST" in
  "")
    echo "Usage:"
    echo "  /changelog <Added|Changed|Fixed|Removed|Security> <summary>"
    echo "  /changelog bump <version>"
    exit 1
    ;;
  bump)
    VERSION="$REST"
    if [[ -z "$VERSION" ]]; then
      echo "Usage: /changelog bump <version>"
      echo "Example: /changelog bump 1.0.0"
      exit 1
    fi
    sf_changelog_ensure "$CHANGELOG" "$TMPL"
    DATE="$(date -u +%Y-%m-%d)"
    sf_changelog_bump "$CHANGELOG" "$VERSION" "$DATE"
    echo "Bumped: [Unreleased] → [${VERSION}] — ${DATE}"
    echo "  CHANGELOG.md updated"
    ;;
  Added|Changed|Fixed|Removed|Security)
    SUMMARY="$REST"
    if [[ -z "$SUMMARY" ]]; then
      echo "Usage: /changelog ${FIRST} <summary>"
      exit 1
    fi
    sf_changelog_ensure "$CHANGELOG" "$TMPL"
    sf_changelog_append "$CHANGELOG" "$FIRST" "$SUMMARY"
    echo "Added entry under [Unreleased] / ### ${FIRST}:"
    echo "  - ${SUMMARY}"
    ;;
  *)
    echo "Unknown type: ${FIRST}"
    echo "Valid: Added | Changed | Fixed | Removed | Security | bump"
    exit 1
    ;;
esac
' "$ARGUMENTS"
```

If the user invokes `/changelog` with no arguments, ask them which type of change (Added/Changed/Fixed/Removed/Security) and a one-line summary, then run `/changelog <type> <summary>`. For a `bump`, ask for the version (or detect from `package.json` / `pyproject.toml` if you want to be helpful) and run `/changelog bump <version>`.

After a bump, suggest committing the changelog with a `chore: release vX.Y.Z` message and tagging the release if the project uses git tags.
