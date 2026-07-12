#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSS="$HERE/../bin/oss"

t_capture "$OSS" help
t_assert_rc 0 "oss help exits 0"
t_assert_contains "$T_OUT" "ossify" "help names the plugin"

t_capture "$OSS" definitely-not-a-command
t_assert_rc 2 "unknown subcommand exits 2"

t_summary
