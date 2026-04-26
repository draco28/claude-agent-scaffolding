#!/usr/bin/env bash
#
# scaffold/tests/test-governance.sh — regression suite for the governance
# commands /adr-new, /changelog, /runbook-new.
#
# Runs each command's bash payload (extracted from its .md file) against a
# tempdir git repo with isolated CLAUDE_PLUGIN_DATA. Asserts the output files
# and state mutations match expectations.
#
# Isolation: tempdir + trap cleanup. Doesn't touch the user's real plugin data.
#
# Usage: bash scaffold/tests/test-governance.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMPDIR_TESTS="$(mktemp -d -t scaffold-gov-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Make a test repo, init scaffold state, cd in.
make_repo() {
  local d="$TMPDIR_TESTS/$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email t@t && git config user.name t \
    && touch .keep && git add .keep && git commit -q -m init )
  echo "$d"
}

# Extract the bash block from a command .md and run it with given ARGUMENTS.
run_cmd() {
  local cmd="$1" args="$2"
  local script="$TMPDIR_TESTS/_cmd.sh"
  awk '/^```bash$/,/^```$/' "$PLUGIN_ROOT/commands/${cmd}.md" | sed '/^```/d' > "$script"
  ARGUMENTS="$args" bash "$script"
}

# Source state lib so tests can poke at state.json directly.
# shellcheck source=../lib/state.sh
source "$PLUGIN_ROOT/lib/state.sh"

# ── /adr-new ────────────────────────────────────────────────────────────────
echo ""
echo "── /adr-new ──"

REPO="$(make_repo adr-test)"
cd "$REPO"
sf_init_state >/dev/null

# A1 — first ADR creates 0001-*.md and increments counter
out="$(run_cmd adr-new 'Choose Postgres over MySQL' 2>&1)"
[[ -r "docs/adr/0001-choose-postgres-over-mysql.md" ]] \
  && pass "A1 first ADR creates 0001-<slug>.md" \
  || fail "A1 ADR file" "files: $(ls docs/adr 2>/dev/null)"

[[ "$(sf_state_get adr_counter)" == "1" ]] \
  && pass "A2 adr_counter = 1 after first ADR" \
  || fail "A2 adr_counter" "got $(sf_state_get adr_counter)"

# A3 — file content has substituted title and date
grep -q "Choose Postgres over MySQL" "docs/adr/0001-choose-postgres-over-mysql.md" \
  && pass "A3 ADR title substituted" \
  || fail "A3 ADR title"

# A4 — second ADR increments to 0002
run_cmd adr-new 'Use JWT for sessions' >/dev/null 2>&1
[[ -r "docs/adr/0002-use-jwt-for-sessions.md" ]] \
  && pass "A4 second ADR → 0002" \
  || fail "A4 second ADR" "files: $(ls docs/adr)"

[[ "$(sf_state_get adr_counter)" == "2" ]] \
  && pass "A5 adr_counter = 2" \
  || fail "A5 adr_counter 2"

# A6 — no args → usage error
out="$(run_cmd adr-new '' 2>&1)"
echo "$out" | grep -q "Usage:" \
  && pass "A6 no args → usage message" \
  || fail "A6 usage" "got: $out"

# A7 — counter not incremented on usage error
[[ "$(sf_state_get adr_counter)" == "2" ]] \
  && pass "A7 counter unchanged on usage error" \
  || fail "A7 counter unchanged"

# ── /changelog ──────────────────────────────────────────────────────────────
echo ""
echo "── /changelog ──"

REPO2="$(make_repo cl-test)"
cd "$REPO2"
sf_init_state >/dev/null

# C1 — first invocation creates CHANGELOG from template
run_cmd changelog 'Added Initial release' >/dev/null 2>&1
[[ -r "CHANGELOG.md" ]] && pass "C1 CHANGELOG.md created" || fail "C1 CHANGELOG.md"

# C2 — has [Unreleased] section
grep -q "^## \[Unreleased\]" CHANGELOG.md \
  && pass "C2 has [Unreleased] heading" \
  || fail "C2 [Unreleased] heading"

# C3 — bullet appended under Added
grep -q "^- Initial release" CHANGELOG.md \
  && pass "C3 bullet appended under Added" \
  || fail "C3 Added bullet" "$(cat CHANGELOG.md)"

# C4 — second Added bullet
run_cmd changelog 'Added Another feature' >/dev/null 2>&1
count="$(grep -c "^- " CHANGELOG.md | head -1)"
[[ "$count" -ge 2 ]] && pass "C4 second Added bullet appended" || fail "C4 second bullet" "count=$count"

# C5 — Fixed under different subsection
run_cmd changelog 'Fixed Login bug' >/dev/null 2>&1
grep -q "^- Login bug" CHANGELOG.md \
  && pass "C5 Fixed bullet" \
  || fail "C5 Fixed bullet"

# C6 — bump rotates Unreleased → versioned
run_cmd changelog 'bump 1.0.0' >/dev/null 2>&1
grep -qE "^## \[1\.0\.0\] — [0-9]{4}-[0-9]{2}-[0-9]{2}" CHANGELOG.md \
  && pass "C6 bump creates [1.0.0] heading" \
  || fail "C6 [1.0.0] heading" "$(grep -E '^## \[' CHANGELOG.md)"

# C7 — Unreleased heading still present after bump (empty)
grep -q "^## \[Unreleased\]" CHANGELOG.md \
  && pass "C7 [Unreleased] preserved after bump" \
  || fail "C7 [Unreleased] preserved"

# C8 — Initial release bullet now under [1.0.0], not [Unreleased]
# Verify by checking line numbers: Unreleased line < 1.0.0 line < Initial release line
unrel_line="$(grep -n "^## \[Unreleased\]" CHANGELOG.md | head -1 | cut -d: -f1)"
ver_line="$(grep -n "^## \[1\.0\.0\]" CHANGELOG.md | head -1 | cut -d: -f1)"
bullet_line="$(grep -n "^- Initial release" CHANGELOG.md | head -1 | cut -d: -f1)"
[[ -n "$unrel_line" && -n "$ver_line" && -n "$bullet_line" \
   && "$unrel_line" -lt "$ver_line" && "$ver_line" -lt "$bullet_line" ]] \
  && pass "C8 bump moves prior Unreleased content under versioned heading" \
  || fail "C8 bump rotates content" "unrel=$unrel_line ver=$ver_line bullet=$bullet_line"

# C9 — adding to Unreleased after bump goes under fresh Unreleased, not 1.0.0.
# Re-grep ver_line AFTER insert (line numbers shift when content is inserted).
run_cmd changelog 'Added Post-release feature' >/dev/null 2>&1
post_line="$(grep -n "^- Post-release feature" CHANGELOG.md | head -1 | cut -d: -f1)"
ver_line_new="$(grep -n "^## \[1\.0\.0\]" CHANGELOG.md | head -1 | cut -d: -f1)"
[[ -n "$post_line" && -n "$ver_line_new" && "$post_line" -lt "$ver_line_new" ]] \
  && pass "C9 post-bump bullet lands above [1.0.0]" \
  || fail "C9 post-bump placement" "post_line=$post_line ver_line_new=$ver_line_new"

# C10 — invalid type rejected
out="$(run_cmd changelog 'Bogus oh no' 2>&1)"
echo "$out" | grep -q "Unknown type" \
  && pass "C10 invalid type rejected" \
  || fail "C10 invalid type" "got: $out"

# C11 — no args → usage
out="$(run_cmd changelog '' 2>&1)"
echo "$out" | grep -q "Usage:" \
  && pass "C11 no args → usage" \
  || fail "C11 usage"

# ── /runbook-new ────────────────────────────────────────────────────────────
echo ""
echo "── /runbook-new ──"

REPO3="$(make_repo rb-test)"
cd "$REPO3"
sf_init_state >/dev/null

# R1 — creates docs/runbooks/<slug>.md
run_cmd runbook-new 'High Latency Writes' >/dev/null 2>&1
[[ -r "docs/runbooks/high-latency-writes.md" ]] \
  && pass "R1 runbook file created at slugged path" \
  || fail "R1 runbook file" "files: $(ls docs/runbooks 2>/dev/null)"

# R2 — content has failure mode name substituted
grep -q "High Latency Writes" "docs/runbooks/high-latency-writes.md" \
  && pass "R2 failure mode name substituted" \
  || fail "R2 substitution"

# R3 — refuses to overwrite existing runbook
out="$(run_cmd runbook-new 'High Latency Writes' 2>&1)"
echo "$out" | grep -q "already exists" \
  && pass "R3 refuses to overwrite existing runbook" \
  || fail "R3 refuse overwrite" "got: $out"

# R4 — different name → different file
run_cmd runbook-new 'OOM kills' >/dev/null 2>&1
[[ -r "docs/runbooks/oom-kills.md" ]] && pass "R4 second runbook → separate file" || fail "R4 second runbook"

# R5 — no args → usage
out="$(run_cmd runbook-new '' 2>&1)"
echo "$out" | grep -q "Usage:" \
  && pass "R5 no args → usage" \
  || fail "R5 usage"

# Summary
TOTAL=$((PASS+FAIL))
echo ""
echo "─────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll %d tests passed.\033[0m\n' "$TOTAL"
  exit 0
else
  printf '\033[31m%d/%d tests failed.\033[0m\n' "$FAIL" "$TOTAL"
  for t in "${FAILED_TESTS[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
