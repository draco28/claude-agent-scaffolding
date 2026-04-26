#!/usr/bin/env bash
# scaffold/lib/changelog.sh — CHANGELOG.md mutation helpers.
#
# These functions live in their own file (rather than inline in the
# /changelog command) because awk programs use single quotes for body
# delimiters, which conflict with the `bash -c '...'` pattern used in
# slash-command bash blocks. Sourcing avoids the conflict.

# sf_changelog_ensure <path> <template-path>
# Make sure CHANGELOG.md exists with at least an [Unreleased] heading.
# If missing or has no [Unreleased], (re)seed from template (or fallback).
sf_changelog_ensure() {
  local file="$1" tmpl="$2"
  if [[ -r "$file" ]] && grep -q "^## \[Unreleased\]" "$file"; then
    return 0
  fi
  if [[ -r "$tmpl" ]]; then
    cp "$tmpl" "$file"
  else
    {
      echo "# Changelog"
      echo ""
      echo "## [Unreleased]"
      echo ""
    } > "$file"
  fi
}

# sf_changelog_append <file> <type> <summary>
# Append a `- summary` bullet under `### <type>` inside [Unreleased].
# Creates the subsection if missing. Inserts before the next `## [` heading
# if the subsection doesn't exist.
sf_changelog_append() {
  local file="$1" type="$2" summary="$3"
  local tmp; tmp="$(mktemp)"
  awk -v type="$type" -v summary="$summary" '
    BEGIN { state = "before"; inserted = 0 }
    /^## \[Unreleased\]/ {
      state = "in_unreleased"
      print
      next
    }
    state == "in_unreleased" && /^## \[/ {
      if (!inserted) {
        print "### " type
        print "- " summary
        print ""
        inserted = 1
      }
      state = "after"
      print
      next
    }
    state == "in_unreleased" && $0 == "### " type && !inserted {
      print
      print "- " summary
      inserted = 1
      next
    }
    { print }
    END {
      if (state == "in_unreleased" && !inserted) {
        print "### " type
        print "- " summary
      }
    }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# sf_changelog_bump <file> <version> <date>
# Replace `## [Unreleased]` with a fresh empty `## [Unreleased]` followed by
# `## [<version>] — <date>`. The prior Unreleased content falls under the new
# versioned heading naturally because we only modify the heading line.
sf_changelog_bump() {
  local file="$1" version="$2" date="$3"
  local tmp; tmp="$(mktemp)"
  awk -v version="$version" -v date="$date" '
    /^## \[Unreleased\]/ && !done {
      print "## [Unreleased]"
      print ""
      print "## [" version "] — " date
      done = 1
      next
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}
