#!/usr/bin/env bash
# resolve.sh — where things are. Walk-up for the workspace, the binding file,
# the state digest, and the machine-local sync record. Nothing here touches Huly.
_board_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

board_resolve_workspace() { # $1=dir ; echoes workspace root ; rc 3 if none
  local d; d="$(cd "$1" 2>/dev/null && pwd)" || return 3
  while :; do
    [ -f "$d/.ossify/project-state.json" ] && { echo "$d"; return 0; }
    [ "$d" = "/" ] && return 3
    d="$(dirname "$d")"
  done
}
board_binding_read()  { [ -f "$1/.board/config.json" ] || return 4; jq -er '.project' "$1/.board/config.json"; }
board_binding_write() { # $1=ws $2=identifier
  mkdir -p "$1/.board"; _board_gitignore "$1"
  local tmp; tmp="$(mktemp "$1/.board/config.json.tmp.XXXXXX")"
  jq -n --arg p "$2" '{project:$p, channel:false}' > "$tmp" && mv "$tmp" "$1/.board/config.json"
}
board_state_digest() { # $1=ws
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1/.ossify/project-state.json" | cut -d' ' -f1
  else shasum -a 256 "$1/.ossify/project-state.json" | cut -d' ' -f1; fi
}
_board_gitignore() { [ -f "$1/.board/.gitignore" ] || printf 'sync.json\nsync.log\n' > "$1/.board/.gitignore"; }
board_sync_read()  { # $1=ws $2=jq-expr ; prints null when the file is missing or corrupt
  [ -f "$1/.board/sync.json" ] || { echo null; return 0; }
  jq -r "$2" "$1/.board/sync.json" 2>/dev/null || echo null
}
board_sync_write() { # $1=ws $2=json
  mkdir -p "$1/.board"; _board_gitignore "$1"
  local tmp; tmp="$(mktemp "$1/.board/sync.json.tmp.XXXXXX")"
  printf '%s\n' "$2" | jq . > "$tmp" && mv "$tmp" "$1/.board/sync.json"
}
board_log() { mkdir -p "$1/.board"; _board_gitignore "$1"; printf '%s %s\n' "$(_board_now)" "$2" >> "$1/.board/sync.log"; }
