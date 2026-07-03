#!/usr/bin/env bash
# tests/test-redact.sh — unit tests for lib/redact.sh (sd_redact_candidates).
# The candidate-surfacer is the MECHANICAL half of the #38 redaction pass: it
# flags candidates by pattern; the agent judges each in context. So these tests
# assert recall on known secret shapes + that benign prose is not over-flagged —
# NOT redact/keep decisions (those are the agent's, exercised in the eval).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/redact.sh"

# helper: run candidates over a heredoc string via stdin
_cand() { printf '%s' "$1" | sd_redact_candidates -; }

# --- recall: each known secret shape is surfaced with the right category ---

test_flags_github_token() {
  echo "test_flags_github_token:"
  local out; out="$(_cand 'token here: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ab done')"
  assert_contains "github-token surfaced" "github-token" "$out"
}

test_flags_github_fine_grained_pat() {
  echo "test_flags_github_fine_grained_pat:"
  local out; out="$(_cand 'token here: github_pat_11ABCDEFG0abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcd')"
  assert_contains "github fine-grained PAT surfaced" "github-token" "$out"
}

test_flags_openai_key() {
  echo "test_flags_openai_key:"
  local out; out="$(_cand 'export KEY=sk-abcdef0123456789ABCDEFghij')"
  assert_contains "openai-key surfaced" "openai-key" "$out"
}

test_flags_aws_key() {
  echo "test_flags_aws_key:"
  local out; out="$(_cand 'aws id AKIAIOSFODNN7EXAMPLE trailing')"
  assert_contains "aws-access-key surfaced" "aws-access-key" "$out"
}

test_flags_aws_sts_key() {
  echo "test_flags_aws_sts_key:"
  local out; out="$(_cand 'aws sts id ASIAIOSFODNN7EXAMPLE trailing')"
  assert_contains "aws STS access key surfaced" "aws-access-key" "$out"
}

test_flags_slack_token() {
  echo "test_flags_slack_token:"
  local out; out="$(_cand 'slack xoxb-1234567890-abcdefghij')"
  assert_contains "slack-token surfaced" "slack-token" "$out"
}

test_flags_pem_key() {
  echo "test_flags_pem_key:"
  local out; out="$(_cand '-----BEGIN RSA PRIVATE KEY-----')"
  assert_contains "pem-private-key surfaced" "pem-private-key" "$out"
}

test_flags_url_credentials() {
  echo "test_flags_url_credentials:"
  local out; out="$(_cand 'clone https://user:s3cr3tpw@github.com/org/repo.git')"
  assert_contains "url-credentials surfaced" "url-credentials" "$out"
}

test_flags_email() {
  echo "test_flags_email:"
  # Emails are surfaced as candidates; the AGENT decides (an author's own email
  # in header metadata is a benign keep — that judgment is not this fn's job).
  local out; out="$(_cand 'ping me at alice.smith@example.com anytime')"
  assert_contains "email surfaced" "email" "$out"
}

test_flags_labeled_secret() {
  echo "test_flags_labeled_secret:"
  local out; out="$(_cand 'password: hunter2horse')"
  assert_contains "labeled-secret surfaced" "labeled-secret" "$out"
}

# --- precision: benign prose is not over-flagged ---

test_benign_prose_clean() {
  echo "test_benign_prose_clean:"
  # "token"/"secret" appear as plain words with NO :/= assignment; no secret
  # shapes present. Expect zero candidates.
  local out; out="$(_cand 'The auth token is fine and the secret sauce still works. Dispatch the agent.')"
  assert_eq "no candidates for benign prose" "" "$out"
}

test_labeled_secret_needs_assignment() {
  echo "test_labeled_secret_needs_assignment:"
  # keyword present but no assignment operator → must NOT match labeled-secret
  local out; out="$(_cand 'the bearer of this message should read the spec')"
  assert_not_contains_str "labeled-secret" "$out"
}

# --- format + IO contract ---

test_output_is_tab_tripled() {
  echo "test_output_is_tab_tripled:"
  local out; out="$(_cand 'k: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ab')"
  # first field numeric line-no, then TAB category TAB match
  if printf '%s\n' "$out" | grep -qE '^[0-9]+	github-token	'; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') lineno<TAB>category<TAB>match"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') bad format: $out"
  fi
}

test_clean_input_empty() {
  echo "test_clean_input_empty:"
  local out; out="$(_cand 'just a normal handoff sentence with nothing sensitive')"
  assert_eq "clean input yields empty" "" "$out"
}

test_file_arg_mode() {
  echo "test_file_arg_mode:"
  local f; f="$(mktemp -t sd-redact.XXXXXX)"
  printf 'line one\nAKIAIOSFODNN7EXAMPLE\nline three\n' > "$f"
  local out; out="$(sd_redact_candidates "$f")"
  rm -f "$f"
  # AKIA... is on line 2
  if printf '%s\n' "$out" | grep -qE '^2	aws-access-key	'; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') file mode reports correct line-no"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') got: $out"
  fi
}

test_unreadable_file_errors() {
  echo "test_unreadable_file_errors:"
  set +e
  sd_redact_candidates "/no/such/path/redact-xyz" >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "missing file rc=1" "1" "$rc"
}

# REGRESSION (real dispatch path): bin/sd runs `set -euo pipefail`. An early
# empty category (grep exit 1) must NOT abort the scan and drop later categories.
# Input has ONLY an email (category 7) — categories 1-6 are all empty.
test_strict_mode_does_not_drop_later_categories() {
  echo "test_strict_mode_does_not_drop_later_categories:"
  local out
  out="$(bash -c '
    set -euo pipefail
    source "'"$HERE"'/../lib/_helpers.sh"
    source "'"$HERE"'/../lib/redact.sh"
    printf "author reachable at alice@example.com only\n" | sd_redact_candidates -
  ' 2>/dev/null)"
  assert_contains "email survives strict-mode + empty earlier categories" "email" "$out"
}

test_same_line_candidates_are_preserved() {
  echo "test_same_line_candidates_are_preserved:"
  local out
  out="$(_cand 'contact alice@example.com password: hunter2horse')"
  assert_contains "same-line email surfaced" $'1\temail\talice@example.com' "$out"
  assert_contains "same-line labeled secret surfaced" $'1\tlabeled-secret\tpassword: hunter2horse' "$out"
}

# small local assert used above (not in _helpers)
assert_not_contains_str() {
  local needle="$1" haystack="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') unexpectedly contains: $needle"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') does not contain: $needle"
  fi
}

test_flags_github_token
test_flags_github_fine_grained_pat
test_flags_openai_key
test_flags_aws_key
test_flags_aws_sts_key
test_flags_slack_token
test_flags_pem_key
test_flags_url_credentials
test_flags_email
test_flags_labeled_secret
test_benign_prose_clean
test_labeled_secret_needs_assignment
test_output_is_tab_tripled
test_clean_input_empty
test_file_arg_mode
test_unreadable_file_errors
test_strict_mode_does_not_drop_later_categories
test_same_line_candidates_are_preserved

sd_test_summary
