#!/usr/bin/env bash
# scaffold-onboard/lib/state.sh
# Onboarding state CRUD. State file lives at $(sf_data_dir)/onboarding-state.json.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

sf_state_path() {
  echo "$(sf_data_dir)/onboarding-state.json"
}

sf_state_init() {
  local path
  path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$path" <<JSON
{
  "status": "in_progress",
  "current_phase": 1,
  "current_question": null,
  "project_class": null,
  "created_at": "$now",
  "updated_at": "$now",
  "answers": {}
}
JSON
}
