#!/usr/bin/env bash
# lib/demo-criteria.sh — auto:/user: demo criteria grammar parser + idempotent writer.
#
# Per SPEC §9 (scaffold-onboard v0.2):
#   sf_demo_parse_line  — validate one line; emit JSON {prefix, body, expected}.
#   sf_demo_parse_slice — read ROADMAP.md; emit JSON array for one named slice.
#   sf_demo_append      — idempotent append to a target (markdown OR state JSON).
#
# Grammar (SPEC §9.1):
#   - [ ] auto: <bash command> → expected: <exit code 0 | pattern in output>
#   - [ ] user: <action description> → expected: <observable outcome>
#
# Arrow delimiter is U+2192 (→) — the ASCII digraph "->" is a grammar violation
# and is rejected with a specific error class (see §11 of the SKILL body).
#
# Idempotence (SPEC §9.2): pre-write equality check on the literal line / string
# (trailing whitespace normalized). No reordering of existing entries.
#
# Bash 3.2-compatible (macOS-portable): no `declare -A`, no GNU-only awk; jq for
# JSON; BSD awk acceptable.

# Source logging helpers — same probe pattern as routing.sh.
_sf_demo_source_helpers() {
  local helpers
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh" ]]; then
    helpers="${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
  else
    helpers="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
  fi
  # shellcheck disable=SC1090
  [[ -f "$helpers" ]] && source "$helpers"
}
_sf_demo_source_helpers

# U+2192 ARROW. Defined once so callers can share the byte sequence.
SF_DEMO_ARROW="→"

# ----------------------------------------------------------------------------
# _sf_demo_strip_checkbox <text> → echoes text with leading "- [ ] " (or
# "- [x] ") stripped if present. No-op otherwise. Also trims trailing whitespace.
# ----------------------------------------------------------------------------
_sf_demo_strip_checkbox() {
  local s="$1"
  # Strip the bullet/checkbox prefix if present (allow either [ ] or [x]/[X]).
  if [[ "$s" =~ ^-\ \[[\ xX]\]\ (.*)$ ]]; then
    s="${BASH_REMATCH[1]}"
  fi
  # Trim trailing whitespace.
  s="${s%"${s##*[![:space:]]}"}"
  echo "$s"
}

# ----------------------------------------------------------------------------
# sf_demo_parse_line <line_text>
# ----------------------------------------------------------------------------
# Validates a single demo-criterion line and emits JSON on stdout:
#   {"prefix": "auto"|"user", "body": "<text>", "expected": "<text>"}
#
# Accepts both forms:
#   - With leading "- [ ] " checkbox (markdown bullet form)
#   - Without leading prefix (state-mode string form)
#
# Grammar checks (returns exit 1 + stderr message on any failure):
#   1. After stripping the optional bullet prefix, line begins with "auto: " or "user: ".
#   2. Body (between prefix and first U+2192) is non-empty.
#   3. ASCII "->" is NOT used as the delimiter (specific error class).
#   4. The U+2192 arrow is present.
#   5. After the arrow, the tail begins with "expected:".
#   6. The expected tail is non-empty.
sf_demo_parse_line() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    sf_log_error "sf_demo_parse_line: empty input"
    return 1
  fi

  # Strip optional bullet prefix + trim trailing whitespace.
  local line
  line="$(_sf_demo_strip_checkbox "$raw")"

  # Identify the prefix (auto: or user:).
  local prefix
  if [[ "$line" == auto:\ * ]]; then
    prefix="auto"
  elif [[ "$line" == user:\ * ]]; then
    prefix="user"
  else
    sf_log_error "sf_demo_parse_line: line must start with 'auto: ' or 'user: ' (got: ${line:0:40}...)"
    return 1
  fi

  # Strip the "auto: " or "user: " prefix to get the rest.
  local rest="${line#${prefix}: }"

  # Split on the FIRST U+2192 arrow. Use parameter expansion to avoid awk
  # quoting headaches with the literal arrow byte sequence.
  if [[ "$rest" != *"${SF_DEMO_ARROW}"* ]]; then
    # Detect ASCII -> as a specific error class.
    if [[ "$rest" == *"->"* ]]; then
      sf_log_error "sf_demo_parse_line: found ASCII '->'; the grammar requires the U+2192 arrow character '→' (SPEC §9.1)"
    else
      sf_log_error "sf_demo_parse_line: missing '→' delimiter (SPEC §9.1)"
    fi
    return 1
  fi

  local body="${rest%%${SF_DEMO_ARROW}*}"
  local tail="${rest#*${SF_DEMO_ARROW}}"

  # Trim surrounding whitespace from body + tail.
  body="${body%"${body##*[![:space:]]}"}"   # trim trailing
  body="${body#"${body%%[![:space:]]*}"}"   # trim leading
  tail="${tail#"${tail%%[![:space:]]*}"}"

  if [[ -z "$body" ]]; then
    sf_log_error "sf_demo_parse_line: empty body before '→'"
    return 1
  fi

  # Tail must begin with "expected:".
  if [[ "$tail" != expected:* ]]; then
    sf_log_error "sf_demo_parse_line: missing 'expected:' clause after '→' (SPEC §9.1)"
    return 1
  fi
  local expected="${tail#expected:}"
  expected="${expected#"${expected%%[![:space:]]*}"}"   # trim leading whitespace
  expected="${expected%"${expected##*[![:space:]]}"}"   # trim trailing

  if [[ -z "$expected" ]]; then
    sf_log_error "sf_demo_parse_line: empty 'expected:' clause"
    return 1
  fi

  # Emit JSON. jq -n with --arg handles arbitrary content safely (quotes, arrows, etc.).
  jq -n --arg prefix "$prefix" --arg body "$body" --arg expected "$expected" \
    '{prefix: $prefix, body: $body, expected: $expected}'
}

# ----------------------------------------------------------------------------
# sf_demo_parse_slice <roadmap_md> <slice_id>
# ----------------------------------------------------------------------------
# Reads ROADMAP.md, finds the "#### <slice_id>:" or "#### <slice_id> " H4
# heading, walks forward to the "##### Demo criteria" subsection, and parses
# every "- [ ] ..." bullet line beneath it (until the next H4/H3/H2/H1 heading).
#
# Emits a JSON array of {prefix, body, expected} objects on stdout.
# Returns exit 0 with "[]" if the slice is not found OR has no criteria.
# Returns exit 1 if the file is missing.
sf_demo_parse_slice() {
  local roadmap="${1:-}"
  local slice_id="${2:-}"

  if [[ -z "$roadmap" || -z "$slice_id" ]]; then
    sf_log_error "sf_demo_parse_slice: usage: sf_demo_parse_slice <roadmap_md> <slice_id>"
    return 1
  fi
  if [[ ! -f "$roadmap" ]]; then
    sf_log_error "sf_demo_parse_slice: file not found: $roadmap"
    return 1
  fi

  # Extract bullet lines under the slice's "##### Demo criteria" subsection,
  # one per line, using awk to walk state through headings.
  local bullets
  bullets="$(awk -v sid="$slice_id" '
    function is_h(line, n) {
      # n = level (1..6); checks "^#{n} " prefix.
      return match(line, "^#" "+ ") && length(substr(line, 1, RLENGTH-1)) == n
    }
    BEGIN { in_slice = 0; in_demo = 0 }
    {
      line = $0
      # Detect H4 slice heading "#### <slice_id>:" or "#### <slice_id> "
      if (line ~ /^#### /) {
        # Reset both state flags whenever we cross any H4.
        in_demo = 0
        # Match the slice id at the start of the heading body.
        heading_body = substr(line, 6)
        if (heading_body == sid || \
            index(heading_body, sid ":") == 1 || \
            index(heading_body, sid " ") == 1) {
          in_slice = 1
        } else {
          in_slice = 0
        }
        next
      }
      # Any higher-level heading (### / ## / #) ends the slice.
      if (line ~ /^### / || line ~ /^## / || line ~ /^# /) {
        in_slice = 0
        in_demo = 0
        next
      }
      # H5 within slice — toggle in_demo only for "Demo criteria".
      if (in_slice && line ~ /^##### /) {
        sub(/^##### +/, "", line)
        # Trim trailing whitespace.
        sub(/[ \t]+$/, "", line)
        if (line == "Demo criteria") {
          in_demo = 1
        } else {
          in_demo = 0
        }
        next
      }
      # Capture bullet lines while in the demo subsection.
      if (in_slice && in_demo && $0 ~ /^- \[[ xX]\] /) {
        print $0
      }
    }
  ' "$roadmap")"

  # Build a JSON array by parsing each bullet line.
  # We accumulate parsed JSON objects into a jq slurp.
  if [[ -z "$bullets" ]]; then
    echo "[]"
    return 0
  fi

  # Parse each bullet via sf_demo_parse_line; collect into an array via jq -s.
  # We must tolerate lines that fail to parse (skip with a warning).
  local tmp
  tmp="$(mktemp -t sf-demo-slice.XXXXXX)"
  while IFS= read -r b; do
    [[ -z "$b" ]] && continue
    if obj="$(sf_demo_parse_line "$b" 2>/dev/null)"; then
      printf '%s\n' "$obj" >> "$tmp"
    else
      sf_log_warn "sf_demo_parse_slice: skipping malformed line in $slice_id: $b"
    fi
  done <<< "$bullets"

  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    echo "[]"
    return 0
  fi
  jq -s '.' "$tmp"
  rm -f "$tmp"
}

# ----------------------------------------------------------------------------
# sf_demo_append <target_path> <slice_id> <criterion_line>
# ----------------------------------------------------------------------------
# Append a criterion idempotently to either a markdown file or a state JSON.
# Mode is chosen by file extension:
#   *.md   → markdown mode: insert under "##### Demo criteria" of the slice.
#   *.json → state mode: append to vertical_slices[].demo_criteria[] entry
#            (matched by id == slice_id).
#
# Idempotence: byte-identical string equality (trailing whitespace trimmed
# from the incoming line before comparison + write).
#
# Returns 0 on success (append OR no-op). Returns 1 on usage error / missing
# target / unparseable slice (e.g., state-mode and the slice isn't in vertical_slices[]).
sf_demo_append() {
  local target="${1:-}"
  local slice_id="${2:-}"
  local line="${3:-}"

  if [[ -z "$target" || -z "$slice_id" || -z "$line" ]]; then
    sf_log_error "sf_demo_append: usage: sf_demo_append <target_path> <slice_id> <criterion_line>"
    return 1
  fi
  if [[ ! -f "$target" ]]; then
    sf_log_error "sf_demo_append: target not found: $target"
    return 1
  fi

  # Trim trailing whitespace from incoming line (idempotence normalization).
  line="${line%"${line##*[![:space:]]}"}"

  case "$target" in
    *.json) _sf_demo_append_state    "$target" "$slice_id" "$line" ;;
    *.md)   _sf_demo_append_markdown "$target" "$slice_id" "$line" ;;
    *)
      sf_log_error "sf_demo_append: target extension must be .md or .json (got: $target)"
      return 1
      ;;
  esac
}

# ----- State-mode append -----------------------------------------------------
# Writes to vertical_slices[<idx where id==slice_id>].demo_criteria[].
# Idempotent on byte-identical string match across the existing array.
# Entries are stored WITHOUT a leading "- [ ] " checkbox (per SPEC §9.2 /
# SKILL.md §5.1) — we strip it if the caller supplied the bullet form.
_sf_demo_append_state() {
  local target="$1" slice_id="$2" line="$3"

  # Normalize: strip bullet prefix if present (state strings are bare).
  line="$(_sf_demo_strip_checkbox "$line")"

  # Confirm slice exists in vertical_slices[].
  local exists
  exists="$(jq --arg sid "$slice_id" \
    '[.vertical_slices[]? | select(.id == $sid)] | length' "$target" 2>/dev/null)"
  if [[ "$exists" != "1" ]]; then
    sf_log_error "_sf_demo_append_state: slice id '$slice_id' not found (or duplicated) in $target"
    return 1
  fi

  # Idempotent append via jq: if-not-already-present, push onto demo_criteria[].
  local tmp
  tmp="$(mktemp -t sf-demo-state.XXXXXX)"
  jq --arg sid "$slice_id" --arg crit "$line" '
    .vertical_slices |= map(
      if .id == $sid then
        .demo_criteria = (
          (.demo_criteria // []) as $cur
          | if ($cur | index($crit)) then $cur else ($cur + [$crit]) end
        )
      else . end
    )
  ' "$target" > "$tmp" || { rm -f "$tmp"; sf_log_error "_sf_demo_append_state: jq write failed"; return 1; }

  mv "$tmp" "$target"
  return 0
}

# ----- Markdown-mode append --------------------------------------------------
# Find the slice block, find (or create) "##### Demo criteria", and append
# the line at the end of the subsection (before the next H5/H4/H3/H2/H1).
# Idempotent on byte-identical bullet-line equality.
_sf_demo_append_markdown() {
  local target="$1" slice_id="$2" line="$3"

  # Ensure caller supplied the bullet form. If they passed the bare body, prepend.
  case "$line" in
    "- ["*) : ;;   # already has bullet
    *)     line="- [ ] $line" ;;
  esac

  # Pass 1: idempotence check — is the line already in the slice's demo block?
  # We re-use the slice parser walk but compare against raw bullet text.
  local existing
  existing="$(awk -v sid="$slice_id" '
    BEGIN { in_slice = 0; in_demo = 0 }
    {
      if ($0 ~ /^#### /) {
        in_demo = 0
        heading_body = substr($0, 6)
        if (heading_body == sid || \
            index(heading_body, sid ":") == 1 || \
            index(heading_body, sid " ") == 1) {
          in_slice = 1
        } else { in_slice = 0 }
        next
      }
      if ($0 ~ /^### / || $0 ~ /^## / || $0 ~ /^# /) {
        in_slice = 0; in_demo = 0; next
      }
      if (in_slice && $0 ~ /^##### /) {
        title = $0; sub(/^##### +/, "", title); sub(/[ \t]+$/, "", title)
        if (title == "Demo criteria") in_demo = 1; else in_demo = 0
        next
      }
      if (in_slice && in_demo && $0 ~ /^- \[[ xX]\] /) {
        # Normalize trailing whitespace for comparison.
        l = $0; sub(/[ \t]+$/, "", l)
        print l
      }
    }
  ' "$target")"

  if [[ -n "$existing" ]]; then
    # Compare against each existing line for byte equality.
    while IFS= read -r e; do
      if [[ "$e" == "$line" ]]; then
        # Already present — no-op.
        return 0
      fi
    done <<< "$existing"
  fi

  # Pass 2: locate insertion point + write atomically.
  # Strategy: stream the file through awk, maintain (in_slice, in_demo, demo_seen);
  # when we encounter the boundary that ends the demo subsection (next H5/H4/H3/H2/H1
  # while in_demo), emit our new line *before* that boundary.
  # If the slice exists but lacks a "##### Demo criteria" subsection, insert one
  # at end-of-slice (before the next H4/H3/H2/H1) with the new line.
  # If the slice doesn't exist at all → error.
  local tmp
  tmp="$(mktemp -t sf-demo-md.XXXXXX)"

  awk -v sid="$slice_id" -v newline="$line" '
    function flush_buffer() {
      for (i = 1; i <= buflen; i++) print buf[i]
      buflen = 0
    }
    # Emit the new bullet at the trailing edge of the buffered demo lines:
    # insert it AFTER the last non-blank line and BEFORE any trailing blank lines.
    function flush_with_insert(   i, last_nonblank) {
      last_nonblank = 0
      for (i = 1; i <= buflen; i++) {
        if (buf[i] !~ /^[ \t]*$/) last_nonblank = i
      }
      for (i = 1; i <= last_nonblank; i++) print buf[i]
      print newline
      for (i = last_nonblank + 1; i <= buflen; i++) print buf[i]
      buflen = 0
    }
    BEGIN {
      in_slice = 0; in_demo = 0; slice_found = 0; demo_found_in_slice = 0
      buflen = 0; appended = 0
    }
    {
      line = $0

      # H4 boundary.
      if (line ~ /^#### /) {
        # If we were inside the target slice and never emitted the new line
        # AND there was a demo subsection, append before leaving (after buffered lines).
        if (in_slice && in_demo && !appended) {
          flush_with_insert()
          appended = 1
          in_demo = 0
        }
        # If we were inside the target slice but never saw "##### Demo criteria",
        # create one now (before the next H4 starts).
        if (in_slice && !demo_found_in_slice && !appended) {
          flush_buffer()
          print "##### Demo criteria"
          print ""
          print newline
          print ""
          appended = 1
        }
        # Flush any unflushed buffer (non-target-slice case).
        if (buflen > 0) flush_buffer()

        heading_body = substr(line, 6)
        if (heading_body == sid || \
            index(heading_body, sid ":") == 1 || \
            index(heading_body, sid " ") == 1) {
          in_slice = 1; slice_found = 1; demo_found_in_slice = 0
        } else {
          in_slice = 0
        }
        in_demo = 0
        print line
        next
      }

      # Higher-level heading boundaries (### / ## / #).
      if (line ~ /^### / || line ~ /^## / || line ~ /^# /) {
        if (in_slice && in_demo && !appended) {
          flush_with_insert()
          appended = 1
          in_demo = 0
        }
        if (in_slice && !demo_found_in_slice && !appended) {
          flush_buffer()
          print "##### Demo criteria"
          print ""
          print newline
          print ""
          appended = 1
        }
        if (buflen > 0) flush_buffer()
        in_slice = 0; in_demo = 0
        print line
        next
      }

      # H5 inside target slice — open/close Demo criteria capture.
      if (in_slice && line ~ /^##### /) {
        # If we were in demo subsection and entering a different H5, flush + close demo.
        if (in_demo && !appended) {
          flush_with_insert()
          appended = 1
        }
        if (buflen > 0) flush_buffer()
        title = line; sub(/^##### +/, "", title); sub(/[ \t]+$/, "", title)
        if (title == "Demo criteria") {
          in_demo = 1; demo_found_in_slice = 1
        } else {
          in_demo = 0
        }
        print line
        next
      }

      # While in target slice + demo subsection, buffer lines so we can emit
      # the new bullet at the trailing edge (before next H5/H4 etc.).
      if (in_slice && in_demo) {
        buflen++
        buf[buflen] = line
        next
      }

      # Default: pass through.
      print line
    }
    END {
      # If file ended while still inside slice + demo without appending.
      if (in_slice && in_demo && !appended) {
        flush_buffer()
        print newline
        appended = 1
      }
      # If file ended while inside slice but never saw demo subsection.
      if (in_slice && !demo_found_in_slice && !appended) {
        flush_buffer()
        print ""
        print "##### Demo criteria"
        print ""
        print newline
        appended = 1
      }
      # Flush any leftover buffer (defensive).
      if (buflen > 0) flush_buffer()
      # Signal slice-not-found via exit status (via final print marker on stderr).
      if (!slice_found) {
        print "SLICE_NOT_FOUND" > "/dev/stderr"
        exit 2
      }
      if (!appended) {
        print "NOT_APPENDED" > "/dev/stderr"
        exit 3
      }
    }
  ' "$target" > "$tmp"
  local rc=$?

  if [[ $rc -eq 2 ]]; then
    rm -f "$tmp"
    sf_log_error "_sf_demo_append_markdown: slice '$slice_id' not found in $target"
    return 1
  fi
  if [[ $rc -ne 0 ]]; then
    rm -f "$tmp"
    sf_log_error "_sf_demo_append_markdown: append failed (awk rc=$rc) for $target"
    return 1
  fi

  mv "$tmp" "$target"
  return 0
}
