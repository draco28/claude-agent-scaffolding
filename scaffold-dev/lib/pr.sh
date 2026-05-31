#!/usr/bin/env bash
# scaffold-dev/lib/pr.sh
# PR-hierarchical merge-mode primitives (issue #40). Thin, MECHANICAL wrappers
# over git + gh — ONE operation each, clean exit code / raw JSON out, NO semantic
# parsing. The agent-driven merge gate (references/git-workflow.md) reasons over
# the output. Only invoked when during_dev.merge_mode == "pr_hierarchical"; the
# default "direct" path never sources behavior from here.
#
# Bash 3.2+ compatible. Safe to double-source.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# sd_merge_mode — echo during_dev.merge_mode, defaulting to "direct".
sd_merge_mode() {
  local m
  m="$(sd_manifest_get '.during_dev.merge_mode')" || m="direct"
  [[ -z "$m" ]] && m="direct"
  echo "$m"
}

# _sd_sprint_branch_name <sprint_id> — substitute {sprint_id} in the template
# (during_dev.sprint_branch_naming; default "sprint-{sprint_id}").
_sd_sprint_branch_name() {
  local sprint_id="$1" tpl
  tpl="$(sd_manifest_get '.during_dev.sprint_branch_naming')" || tpl="sprint-{sprint_id}"
  echo "${tpl//\{sprint_id\}/$sprint_id}"
}

# _sd_slice_branch_name <vs_id> — substitute {vs_id} in the template
# (during_dev.slice_branch_naming; default "slice/{vs_id}").
_sd_slice_branch_name() {
  local vs_id="$1" tpl
  tpl="$(sd_manifest_get '.during_dev.slice_branch_naming')" || tpl="slice/{vs_id}"
  echo "${tpl//\{vs_id\}/$vs_id}"
}
