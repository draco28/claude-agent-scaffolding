#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."
t_capture jq -r '.name' "$ROOT/.claude-plugin/plugin.json";  t_assert_eq "board" "$T_OUT" "claude manifest name"
t_capture jq -r '.name' "$ROOT/.codex-plugin/plugin.json";   t_assert_eq "board" "$T_OUT" "codex manifest name"
CV="$(jq -r '.version' "$ROOT/.claude-plugin/plugin.json")"; XV="$(jq -r '.version' "$ROOT/.codex-plugin/plugin.json")"
t_assert_eq "$CV" "$XV" "manifest versions agree"
t_capture jq -r '.skills' "$ROOT/.codex-plugin/plugin.json"; t_assert_eq "./skills/" "$T_OUT" "codex manifest exposes skills"
t_capture jq -e 'has("hooks") | not' "$ROOT/.codex-plugin/plugin.json"; t_assert_rc 0 "codex manifest has no hooks key"
t_summary
