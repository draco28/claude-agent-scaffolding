#!/usr/bin/env bash
# `oss rules_validate` — the mcrule block SHAPE validator behind `doctor`'s
# rule-authoring surface. Shape only: nothing here evaluates a rule against a
# codebase, and nothing should until the evaluator lands.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/rules.sh"
OSS="$HERE/../lib/../bin/oss"

# --- the four types, each in its fully-worked form -------------------------
t_capture oss_rules_validate_block banned_imports 'in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3]'
t_assert_rc 0 "banned_imports with both optional fields is valid"

t_capture oss_rules_validate_block banned_imports 'forbid: [requests]'
t_assert_rc 0 "banned_imports with ONLY its required field is valid — optional means optional"

t_capture oss_rules_validate_block coverage_floor 'paths: [src/api/]
threshold: 80'
t_assert_rc 0 "coverage_floor with both required fields is valid"

t_capture oss_rules_validate_block style_invariants 'in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '"'"'\bprint\('"'"''
t_assert_rc 0 "style_invariants with a backslash-bearing regex is valid"

t_capture oss_rules_validate_block required_pattern 'in: src/api/handlers/*.py
require_pattern: '"'"'Args:\s+.*\s+Returns:'"'"'
where: function_def'
t_assert_rc 0 "required_pattern whose VALUE contains a colon is valid — the key is split on the FIRST colon"

# --- the field table is per-type, not global -------------------------------
# `coverage_floor` is the one type with NO optional fields (§8.3). If the table
# ever collapses to one shared allow-list, this is the assertion that catches
# it: `in:` is legal for three types and illegal for this one.
t_capture oss_rules_validate_block coverage_floor 'paths: [src/api/]
threshold: 80
in: src/**/*.py'
t_assert_rc 1 "coverage_floor rejects 'in' — it has no optional fields, unlike the other three"
t_assert_contains "$T_OUT" "unknown field 'in'" "the unknown field is named, not just counted"

t_capture oss_rules_validate_block banned_imports 'in: src/**/*.py'
t_assert_rc 1 "a block missing its required field is invalid"
t_assert_contains "$T_OUT" "requires field 'forbid'" "the MISSING field is named, so the author is sent to the one wrong line"

# --- the typo case, which is the whole reason this validator exists ---------
# `forbid_patern` would author a block that the evaluator later skips for having
# no required field: green at authoring time, silently unenforced forever after.
#
# A typo'd REQUIRED field trips the required check first, and that ordering is
# deliberate rather than incidental: "requires field 'forbid_pattern'" hands the
# author the CORRECT spelling, where "unknown field 'forbid_patern'" would only
# confirm what they already typed. Swap the two passes and this assertion goes
# red — which is the point of asserting the message and not just the rc.
t_capture oss_rules_validate_block style_invariants 'forbid_patern: x'
t_assert_rc 1 "a typo'd required field is rejected rather than authored"
t_assert_contains "$T_OUT" "requires field 'forbid_pattern'" "the typo's error names the CORRECT spelling, not the typed one"

# A typo'd OPTIONAL field has no required check to trip, so it must be caught by
# the unknown-field pass — the arm the case above deliberately does not reach.
t_capture oss_rules_validate_block style_invariants 'forbid_pattern: x
excl: tests/**'
t_assert_rc 1 "a typo'd optional field is rejected even though every required field is present"
t_assert_contains "$T_OUT" "unknown field 'excl'" "the typo is echoed back verbatim"

# --- shape failures are reported as shape failures -------------------------
t_capture oss_rules_validate_block banned_imports 'forbid: [requests]
this line is prose, not a key-value pair'
t_assert_rc 1 "a non key:value line is invalid"
t_assert_contains "$T_OUT" "malformed rule line" "prose is reported as MALFORMED, not as a missing field"

t_capture oss_rules_validate_block banned_imports 'two words: x'
t_assert_rc 1 "a key containing a space is invalid"
t_assert_contains "$T_OUT" "malformed rule key" "the key-charset failure has its own message"

# --- an EMPTY value is not a present field ---------------------------------
# Only the text before the colon used to be recorded, so `forbid:` registered
# the key and the required-field pass below saw it as satisfied — validating a
# rule that forbids nothing. An empty pattern is worse than useless: its match
# semantics under a future evaluator are whatever that evaluator happens to
# decide, which is a decision nobody made deliberately.
t_capture oss_rules_validate_block banned_imports 'forbid:'
t_assert_rc 1 "a required field with no value is invalid"
t_assert_contains "$T_OUT" "has no value" "the empty-value failure has its own message, not 'requires field'"
t_capture oss_rules_validate_block coverage_floor 'paths:
threshold: 80'
t_assert_rc 1 "a required field holding only whitespace is invalid"
t_capture oss_rules_validate_block style_invariants 'forbid_pattern: x
exclude:'
t_assert_rc 1 "an OPTIONAL field with no value is invalid too — an empty exclude excludes nothing"

t_capture oss_rules_validate_block no_such_type 'forbid: [x]'
t_assert_rc 1 "an unknown rule type is invalid"
t_assert_contains "$T_OUT" "banned_imports" "the error lists the known types rather than making the author look them up"

# --- blank and indented lines are tolerated --------------------------------
t_capture oss_rules_validate_block banned_imports 'forbid: [requests]

   where: any_function_marked_async'
t_assert_rc 0 "blank and leading-whitespace lines do not break the shape pass"

# --- values are opaque to the shape pass -----------------------------------
# Only the KEY is charset-checked. A value may hold `$`, backslashes, brackets,
# quotes and glob metacharacters — every one of which appears in real regex and
# path-pattern rules — and none of it may reach the `case` guards or the
# unquoted `for pk in $present` word-split.
#
# This deliberately does NOT claim to distinguish `<<<"$body"` from `<<EOF`.
# Measured: they behave identically here, because a heredoc expands its source
# text once and does not re-scan the substituted value. A test written to
# discriminate them cannot fail.
t_capture oss_rules_validate_block style_invariants 'in: src/**/[a-z]*.py
forbid_pattern: '"'"'\$\{HOME\}|\bprint\(.*\)'"'"''
t_assert_rc 0 "a value holding \$, braces, brackets, globs and backslashes validates — values are opaque to the shape pass"

# --- usage -----------------------------------------------------------------
t_capture oss_rules_validate_block
t_assert_rc 2 "no type is a usage error (rc 2), not an invalid block (rc 1)"
t_capture oss_rules_validate_block banned_imports
t_assert_rc 2 "no body is a usage error (rc 2)"

# --- the type list is data, not a second hand-maintained copy --------------
t_capture oss_rules_types
t_assert_rc 0 "rules_types runs"
t_assert_eq "4" "$(printf '%s\n' "$T_OUT" | wc -l | tr -d ' ')" "rules_types lists exactly the four v0.2 types"

# ---------------------------------------------------------------------------
# Dispatcher path. `bin/oss` runs `set -euo pipefail`; every assertion above
# only sourced the lib (no `set -e`), so the `for`-loop bodies and the
# `case`-based guards — the exact shapes that abort under errexit when written
# as bare `[ ... ] && x=1` — are structurally untested until here.
# ---------------------------------------------------------------------------
t_capture "$OSS" rules_validate banned_imports 'forbid: [requests]'
t_assert_rc 0 "dispatcher: a valid block is rc 0 under strict mode"
t_capture "$OSS" rules_validate coverage_floor 'threshold: 80'
t_assert_rc 1 "dispatcher: an invalid block is rc 1 under strict mode, not a strict-mode abort"
t_assert_contains "$T_OUT" "requires field 'paths'" "dispatcher: the lib's own message reaches the caller"
t_capture "$OSS" rules_validate banned_imports
t_assert_rc 2 "dispatcher: a missing argument is the arity guard's rc 2, not an unbound-variable crash"
t_capture "$OSS" rules_types
t_assert_contains "$T_OUT" "required_pattern" "dispatcher: rules_types reaches the caller"

t_summary
