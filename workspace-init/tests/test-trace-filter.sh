#!/usr/bin/env bash
# tests/test-trace-filter.sh — commit-msg hook regex + manifest behavior.
# Covers SPEC §7.3: anchored patterns, fail-open on missing manifest,
# empty-array short-circuit, multi-pattern detection.

source "$(dirname "$0")/_helpers.sh"
source "$WI_LIB_DIR/_helpers.sh"
source "$WI_LIB_DIR/manifest.sh"
source "$WI_LIB_DIR/trace-filter.sh"

# ---------------------------------------------------------------------------
# Shared fixture setup
# ---------------------------------------------------------------------------

# Create a tempdir with foo-ai/.workspace/pairing.json + foo/ canonical dir.
# Returns (echoes) the tempdir path.
_make_fixture() {
  local d; d="$(wi_tmpdir)"
  local ai="$d/foo-ai"; local cn="$d/foo"
  mkdir -p "$ai/.workspace" "$cn"
  wi_manifest_write "$ai" "$cn" personal >/dev/null 2>&1
  echo "$d"
}

# Render the hook from the fixture's ai workspace into a tempfile + chmod +x.
# Echoes the hook path.
_render_hook() {
  local d="$1"
  local ai="$d/foo-ai"
  local hook="$d/hook.sh"
  wi_trace_filter_render "$ai" > "$hook"
  chmod +x "$hook"
  echo "$hook"
}

_write_msg() {
  local d="$1"
  local content="$2"
  local msg="$d/msg"
  printf '%s' "$content" > "$msg"
  echo "$msg"
}

# Run hook against a commit message; returns the exit code via echo; stderr captured to $d/stderr.
_run_hook() {
  local hook="$1"; local msg="$2"; local d="$3"
  "$hook" "$msg" 2>"$d/stderr"
  echo $?
}

# ---------------------------------------------------------------------------
# Positive (must block) — 6 tests
# ---------------------------------------------------------------------------

test_P1_co_authored_by_claude_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: something\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "Co-Authored-By: Claude trailer must block"
}

test_P2_co_authored_by_human_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: something\n\nCo-Authored-By: Human Dev <h@example.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "Co-Authored-By trailer with human email must also block (broader catch)"
}

test_P3_robot_marker_at_line_start_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'🤖 Generated with [Claude Code]\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "🤖 Generated marker at line start must block"
}

test_P4_anthropic_noreply_substring_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: something\n\nSome text with <noreply@anthropic.com> in it\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "<noreply@anthropic.com> in angle-brackets must block"
}

test_P5_openai_noreply_substring_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: something\n\nTest with <noreply@openai.com> mid-line\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "<noreply@openai.com> must block"
}

test_P6_multi_pattern_blocks_on_first_match() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: something\n\n🤖 Generated with [Claude Code]\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "multi-pattern message blocks (exit 1)"
}

# ---------------------------------------------------------------------------
# Negative (must allow) — 6 tests
# ---------------------------------------------------------------------------

test_N1_plain_message_allows() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: bug\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "plain message exits 0"
}

test_N2_co_authored_mid_line_allows() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'docs: noting that Co-Authored-By trailers exist mid-line\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "Co-Authored-By not at line-start must allow (anchor)"
}

test_N3_robot_marker_mid_line_allows() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'chore: 🤖 Generated with marker stays mid-line\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "🤖 marker not at line-start must allow"
}

test_N4_docs_describing_pattern_allows() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'docs: document that hook blocks 🤖 Generated with marker\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "meta-commit about the pattern must allow (line doesn't START with marker)"
}

test_N5_bare_email_without_brackets_allows() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: bare noreply@anthropic.com without brackets in body\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "bare email without angle-brackets must allow (anchored within brackets)"
}

test_N6_empty_body_allows() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" "")"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "empty message body must allow"
}

# ---------------------------------------------------------------------------
# Edge cases — 8 tests
# ---------------------------------------------------------------------------

test_E1_manifest_missing_fails_open_with_warning() {
  local d; d="$(wi_tmpdir)"
  local ai="$d/foo-ai"
  mkdir -p "$ai"
  # No manifest written. Render the hook directly (template loader doesn't need manifest).
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: anything\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "missing manifest must fail-open (exit 0)" || return 1
  if ! grep -q "workspace-init manifest not found" "$d/stderr"; then
    echo "    expected stderr to contain 'workspace-init manifest not found'"
    echo "    got: $(cat "$d/stderr")"
    return 1
  fi
  return 0
}

test_E2_enforce_false_allows_everything() {
  local d; d="$(_make_fixture)"
  # Flip enforce to false
  local manifest="$d/foo-ai/.workspace/pairing.json"
  local tmp; tmp="$(mktemp)"
  jq '.git_policy.trace_filter.enforce = false' "$manifest" > "$tmp" && mv "$tmp" "$manifest"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "enforce:false must allow everything"
}

test_E3_empty_patterns_array_allows() {
  local d; d="$(_make_fixture)"
  local manifest="$d/foo-ai/.workspace/pairing.json"
  local tmp; tmp="$(mktemp)"
  jq '.git_policy.trace_filter.blocked_patterns = []' "$manifest" > "$tmp" && mv "$tmp" "$manifest"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "empty patterns array must allow everything"
}

test_E4_malformed_json_manifest_allows() {
  local d; d="$(_make_fixture)"
  # Corrupt the manifest into invalid JSON
  echo "{ this is not valid json" > "$d/foo-ai/.workspace/pairing.json"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "0" "$rc" "malformed JSON manifest must allow (jq fails silently, enforce defaults false)"
}

test_E5_trailer_at_line_start_in_multiline_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'feat: add thing\n\nThis is a longer message\nwith multiple lines.\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nSigned-off-by: User\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "trailer at line-start in multi-line body must block"
}

test_E6_pattern_at_line_start_with_trailing_whitespace_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  local msg; msg="$(_write_msg "$d" $'fix: x\n\nCo-Authored-By:   \n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "Co-Authored-By: with trailing whitespace still blocks (anchor ignores tail)"
}

test_E7_unicode_robot_at_line_start_blocks() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  # Explicitly UTF-8 encoded 🤖 (F0 9F A4 96)
  local msg; msg="$(_write_msg "$d" $'\xf0\x9f\xa4\x96 Generated with [Claude Code]\n')"
  local rc; rc="$(_run_hook "$hook" "$msg" "$d")"
  assert_eq "1" "$rc" "UTF-8 🤖 marker at line start must block"
}

test_E8_render_substitutes_token() {
  local d; d="$(_make_fixture)"
  local hook; hook="$(_render_hook "$d")"
  if grep -q '__AI_WORKSPACE_PATH__' "$hook"; then
    echo "    placeholder __AI_WORKSPACE_PATH__ still present in rendered hook"
    return 1
  fi
  if ! grep -qF "$d/foo-ai" "$hook"; then
    echo "    expected baked path $d/foo-ai not found in rendered hook"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

# Positive
wi_test_run test_P1_co_authored_by_claude_blocks
wi_test_run test_P2_co_authored_by_human_blocks
wi_test_run test_P3_robot_marker_at_line_start_blocks
wi_test_run test_P4_anthropic_noreply_substring_blocks
wi_test_run test_P5_openai_noreply_substring_blocks
wi_test_run test_P6_multi_pattern_blocks_on_first_match

# Negative
wi_test_run test_N1_plain_message_allows
wi_test_run test_N2_co_authored_mid_line_allows
wi_test_run test_N3_robot_marker_mid_line_allows
wi_test_run test_N4_docs_describing_pattern_allows
wi_test_run test_N5_bare_email_without_brackets_allows
wi_test_run test_N6_empty_body_allows

# Edge
wi_test_run test_E1_manifest_missing_fails_open_with_warning
wi_test_run test_E2_enforce_false_allows_everything
wi_test_run test_E3_empty_patterns_array_allows
wi_test_run test_E4_malformed_json_manifest_allows
wi_test_run test_E5_trailer_at_line_start_in_multiline_blocks
wi_test_run test_E6_pattern_at_line_start_with_trailing_whitespace_blocks
wi_test_run test_E7_unicode_robot_at_line_start_blocks
wi_test_run test_E8_render_substitutes_token

wi_test_summary
