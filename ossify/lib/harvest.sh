#!/usr/bin/env bash
# Memory-bank harvest (spec §6.1's core row, §8's memory-bank contract). Two
# functions, both driven from spine close step 9 as `oss harvest_dir` and
# `oss harvest_apply`; the ceremony itself is skills/close/references/harvest.md.
#
# D8 — the idempotency check is REBUILT here, not ported. scaffold-dev's
# `sd_harvest_apply` skips on `grep -Fq "$text" "$file"` (harvest.sh:171), and
# that check is wrong in BOTH directions:
#   - text carrying a BLANK LINE makes `grep -F` read the empty line as one
#     alternative, which matches any non-empty file, so every item "already
#     exists" and the whole payload skips at rc 0 — issue #115's real mechanism;
#   - multi-line text whose ANY line already exists skips, and text that is a
#     substring of existing content skips;
#   - with no `--` terminator, text starting `-` is read as OPTIONS. BSD grep
#     then does one of three things depending on the letters that follow: rc 2
#     "invalid option" (the `if` is false and the item appends every time,
#     defeating idempotency the other way), rc 0 through an option string that
#     happens to match (a silent false skip), or — for an all-flag-letters
#     string like `-alpha` — it consumes every character as a flag, finds no
#     pattern operand and BLOCKS READING STDIN. `tests/run-all.sh` redirects no
#     stdin and sets no timeout, so that last one hangs a suite rather than
#     failing it.
# The replacement matches a CONTENT HASH carried in the provenance trailer,
# anchored on the trailer's closing ` -->`, with `-F` so the hash is literal and
# `--` so no argument can be read as an option, scoped to the target file. A
# hash has no blank line and no leading dash, and once anchored no substring
# ambiguity — the whole defect class is designed out rather than patched.
#
# rc contract:
#   oss_harvest_memory_bank_dir   0  echoed the resolved directory
#                                 1  no manifest / no ai_workspace.root / the
#                                    resolved path still holds a ${...} token
#   oss_harvest_apply             0  at least one entry written, OR the payload
#                                    was empty
#                                 1  the payload was non-empty and nothing was
#                                    written (every item a duplicate, or the
#                                    memory-bank directory did not resolve)
#                                 2  the payload was REJECTED — bad shape, a
#                                    source outside report|handoff, or a target
#                                    outside the allowlist. Rejection is
#                                    whole-payload and precedes every write.
# Both rc 0 and rc 1 echo `harvest: wrote <N>, skipped <M>` on stdout.
#
# Repo rc taxonomy: 1 generic, 2 usage, 3 lock, 4 apply-failure, 5 drift,
# 6 schema, 7 unknown-ref, 8 git/worktree. The harvest writes to the MEMORY
# BANK and never to project state, so it journals no op and can never return
# 4, 5 or 6.

# The only two harvestable files. Everything else in the bank is derived from
# the lean spec (start/references/memory-bank-brief.md §1) and must not be
# hand-appended; an enforceable pattern is a rule-authoring referral, not a raw
# append. Deliberately a hardcoded allowlist rather than the complement of a
# derived-files list: a file added to the bank later must not become harvestable
# by default.
_OSS_HARVEST_TARGETS="09-known-issues.md 10-decisions-log.md"

# Resolve the memory-bank directory. Honors `.well_known_paths.memory_bank`,
# else derives by convention <ai_workspace.root>/.claude/memory-bank. Echoes the
# path (which need not exist yet).
#
# This mirrors `oss_manifest_state_path` (manifest.sh:66-84) step for step, and
# the reason is the P0 the naive form reintroduces: `oss_manifest_get` is a bare
# `jq -r` with NO token expansion, and workspace-init writes this key in TOKEN
# form on every project it emits (workspace-init/lib/manifest.sh:328 →
# "${ai_workspace.root}/.claude/memory-bank"). Reading it raw yields the literal
# string, `mkdir -p` then creates a directory literally named
# `${ai_workspace.root}` under $PWD, and the harvest reports `wrote N` at rc 0
# while the real memory bank is never touched — the same "rc 0 and nothing where
# you are looking" signature this whole task exists to remove.
#
# Takes NO state argument: the manifest is found by walking up from $PWD, never
# from the state file, and nothing here reads state. Its sibling is
# `_oss_repo_root`, which takes a repo key, not a state path.
oss_harvest_memory_bank_dir() {
  local manifest ai_root routed dir
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)" || true
  [ -n "$ai_root" ] || { echo "oss: manifest missing ai_workspace.root" >&2; return 1; }
  # Guard ${HOME:-} (Codex C8): bin/oss runs `set -euo pipefail`, so a bare
  # `$HOME` aborts this command with "HOME: unbound variable" when OpenCode
  # launches without HOME set (e.g. `env -u HOME oss harvest_dir`). Leaving the
  # literal ${HOME} token in place when unset matches the resolver contract and
  # is caught by the unresolved-${...} case below.
  [ -n "${HOME:-}" ] && ai_root="${ai_root//\$\{HOME\}/$HOME}"
  ai_root="${ai_root//\$\{USER\}/$(_oss_current_user)}"
  routed="$(jq -r '.well_known_paths.memory_bank // empty' "$manifest" 2>/dev/null)" || true
  if [ -n "$routed" ]; then
    dir="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dir="$ai_root/.claude/memory-bank"
  fi
  case "$dir" in
    ''|*'${'*) echo "oss: unresolved memory-bank path: '${dir:-<empty>}' (from '${routed:-convention}')" >&2; return 1 ;;
  esac
  echo "$dir"
}

# Create a live memory-bank file that does not exist yet, with the structure a
# later reader expects rather than a bare header. Never truncates an existing
# file (the `if` returns first).
_oss_harvest_seed() { # $1=abs-file $2=basename
  if [ -f "$1" ]; then return 0; fi
  local title section
  case "$2" in
    09-known-issues.md)  title="Known issues";  section="## Caveats and gotchas" ;;
    10-decisions-log.md) title="Decisions log"; section="## Decisions" ;;
    *) echo "oss: harvest will not seed '$2'" >&2; return 1 ;;
  esac
  mkdir -p "$(dirname "$1")" || return 1
  {
    printf '# %s\n\n' "$title"
    printf '> Live file — grown by the harvest at every spine close, never\n'
    printf '> regenerated from the spec.\n\n'
    printf '%s\n' "$section"
  } > "$1"
}

# oss_harvest_apply <state> <payload-json>
#
# `<state>` is accepted for dispatcher symmetry — every `oss_cmd_*` resolves a
# state path first — and is deliberately NOT read: the harvest writes to the
# memory bank, never to state, and Task 12 adds no state op. Do not "fix" this
# by reaching into state; tests/test-harvest.sh asserts the state file is never
# even created.
#
# Payload: a JSON array of
#   {"source":"report|handoff","source_id":"…","target_file":"…","text":"…"}
oss_harvest_apply() { # $1=state-file (unread) $2=payload-json
  local payload="${2:-}" n mb today fatal=""
  if [ -z "$payload" ]; then
    echo "oss: harvest_apply usage: oss harvest_apply '<payload-json-array>'" >&2
    return 2
  fi
  if ! printf '%s' "$payload" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "oss: harvest rejected - payload must be a JSON array" >&2
    return 2
  fi
  n="$(printf '%s' "$payload" | jq 'length' 2>/dev/null)" || n=""
  case "$n" in
    ''|*[!0-9]*) echo "oss: harvest rejected - cannot read the payload length" >&2; return 2 ;;
  esac
  if [ "$n" -eq 0 ]; then echo "harvest: wrote 0, skipped 0"; return 0; fi

  # Pass 1 - validate the WHOLE payload. A bad item must not leave earlier valid
  # items applied, and must not seed an empty live file either: nothing below
  # this loop touches the filesystem until every item has passed.
  #
  # `< <(...)`, never `| while`: a piped loop runs in a SUBSHELL, so `return`
  # exits the subshell and execution falls through, and the counters in pass 2
  # would silently reset to zero.
  local i=0 item ty target src sid text
  while IFS= read -r item; do
    ty="$(printf '%s' "$item" | jq -r 'type' 2>/dev/null)" || ty=""
    if [ "$ty" != "object" ]; then
      echo "oss: harvest rejected - item $i is not a JSON object" >&2; return 2
    fi
    target="$(printf '%s' "$item" | jq -r '.target_file // ""' 2>/dev/null)" || target=""
    src="$(printf '%s' "$item" | jq -r '.source // ""' 2>/dev/null)" || src=""
    sid="$(printf '%s' "$item" | jq -r '.source_id // ""' 2>/dev/null)" || sid=""
    text="$(printf '%s' "$item" | jq -r 'if (.text|type) == "string" then .text else "" end' 2>/dev/null)" || text=""
    case " $_OSS_HARVEST_TARGETS " in
      *" $target "*) ;;
      *) echo "oss: harvest rejected - item $i targets '$target'; the harvest may only append to $_OSS_HARVEST_TARGETS (everything else in the bank is derived from the spec, and an enforceable pattern is a rule-authoring referral, not an append)" >&2
         return 2 ;;
    esac
    if [ "$src" != "report" ] && [ "$src" != "handoff" ]; then
      echo "oss: harvest rejected - item $i source is '$src'; must be exactly 'report' or 'handoff'" >&2; return 2
    fi
    if [ -z "$sid" ]; then
      echo "oss: harvest rejected - item $i has no .source_id (the provenance trailer cannot be written)" >&2; return 2
    fi
    if [ -z "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then
      echo "oss: harvest rejected - item $i has no non-empty .text" >&2; return 2
    fi
    i=$((i+1))
  done < <(printf '%s' "$payload" | jq -c '.[]')

  mb="$(oss_harvest_memory_bank_dir)" || { echo "harvest: wrote 0, skipped 0"; return 1; }
  mkdir -p "$mb" || { echo "oss: harvest cannot create $mb" >&2; echo "harvest: wrote 0, skipped 0"; return 1; }
  today="$(date -u +%Y-%m-%d)" || today="unknown"

  # Pass 2 - append. Same `< <(...)` form, and for the same reason: $w and $s
  # are read after the loop.
  local w=0 s=0 h file
  while IFS= read -r item; do
    target="$(printf '%s' "$item" | jq -r '.target_file')" || target=""
    src="$(printf '%s' "$item" | jq -r '.source')" || src=""
    sid="$(printf '%s' "$item" | jq -r '.source_id')" || sid=""
    text="$(printf '%s' "$item" | jq -r '.text')" || text=""
    h="$(printf '%s' "$text" | cksum | awk '{print $1}')" || h=""
    if [ -z "$h" ]; then fatal="cannot hash the entry from $sid"; break; fi
    file="$mb/$target"
    if ! _oss_harvest_seed "$file" "$target"; then fatal="cannot seed $file"; break; fi
    # ANCHORED on the trailer's closing delimiter. `cksum` emits variable-width
    # decimals, so an unanchored `h:123` lookup is satisfied by a stored
    # `h:1234` and the new entry is silently skipped - the same "skips when it
    # should write" outcome as the grep -F bug, through a narrower door.
    if grep -Fq -- "h:${h} -->" "$file" 2>/dev/null; then
      s=$((s+1))
      continue
    fi
    {
      printf '\n'
      printf '%s\n' "$text"
      printf '<!-- ossify harvest: %s, %s; source: %s; h:%s -->\n' "$sid" "$today" "$src" "$h"
    } >> "$file" || { fatal="cannot append to $file"; break; }
    w=$((w+1))
  done < <(printf '%s' "$payload" | jq -c '.[]')

  echo "harvest: wrote $w, skipped $s"
  if [ -n "$fatal" ]; then echo "oss: harvest halted - $fatal" >&2; return 1; fi
  if [ "$w" -gt 0 ]; then return 0; fi
  return 1
}
