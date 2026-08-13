#!/usr/bin/env bash
# oss interop_check - can this workspace be driven by Claude Code AND by Codex,
# interchangeably, mid-project? (spec §9.1, the `doctor` entry's fourth surface;
# §8.1 absorbs scaffold-onboard's `checking-workspace-interoperability` here.)
#
# NOT a port. scaffold-onboard's check requires `.routing.roadmap`,
# `.routing.sprint_specs`, `.routing.implementation_handoffs` and
# `.workspace/locks` - and every one of those is an artifact this stack
# RETIRED. ROADMAP.md is replaced by the feature map plus RELEASE.md, sprint
# specs by spine specs, and ossify's lock is a `<state>.lock` dir beside the
# state file rather than a workspace-wide directory. Carrying that key set over
# would have `doctor` report a correctly-configured ossify project as broken for
# not having the previous stack's furniture. What is absorbed is the QUESTION,
# not the checklist.
#
# The ossify-native answer is the four things a Codex session needs in order to
# drive this project the same way a Claude session does:
#   1. the pairing manifest exists at all
#   2. both repo roots resolve to real directories (`_oss_repo_root` needs both)
#   3. the state file has a well-known path, so state resolution does not depend
#      on which directory the session happens to start in
#   4. AGENTS.md exists and routes to ossify, because AGENTS.md is the ONLY
#      file Codex reads for project instructions - a workspace whose AGENTS.md
#      never mentions ossify has a Codex session driving the project with none
#      of its ceremonies, which is the exact drift this check exists to catch
#
# CHECK ONLY. Repair is deliberately not here: spec §9.1 allocates `doctor` an
# "interop check", and the additive repair half was scaffold-onboard's own
# extension. Emitting a remedy the user runs is this surface's contract.
#
# Line grammar matches `oss doctor` exactly (`ok:`/`fail:` + a named check),
# because `doctor` is the only consumer and one read-out should not carry two
# vocabularies. rc 1 if any `fail:` printed, else 0.

oss_interop_check() { # echoes one line per check ; rc 1 if any fail: printed
  local rc=0 manifest key root sf ai_root agents

  if ! manifest="$(oss_manifest_discover 2>/dev/null)" || [ ! -f "$manifest" ]; then
    echo "fail: manifest - no workspace-init pairing manifest on the walk-up from \$PWD; run /init-workspace or /pair-workspace"
    # Every later check reads the manifest, so there is nothing further to say.
    # Returning here rather than emitting four derived failures keeps the
    # read-out pointing at the one thing that has to be fixed first.
    return 1
  fi
  # EXISTENCE IS NOT READABILITY. Every check below reads this file through
  # `jq`, so a manifest that exists but cannot be read produced `ok: manifest`
  # followed by three or four derived failures about roots and paths that were
  # never actually consulted - directing the operator to repair several settings
  # when only one thing was wrong. That is the same reasoning the missing-manifest
  # branch above already applies; a manifest that cannot be read earns it too.
  #
  # `type == "object"` rather than a bare parse check, because the finding named
  # a CLASS - "the manifest cannot be read" - and malformed JSON is one instance.
  # `[]`, `null`, `42` and `"a string"` all parse cleanly and then fail every
  # `jq -r '.ai_workspace.root'` downstream, reproducing the identical misleading
  # read-out. Guarding only the parse would fix the reported instance and leave
  # the class. (#157)
  if ! jq -e 'type == "object"' "$manifest" >/dev/null 2>&1; then
    echo "fail: manifest - $manifest is not a readable JSON object; every later check reads it through jq, so nothing else could be reported"
    return 1
  fi
  echo "ok: manifest - $manifest"

  # `_oss_repo_root` is the resolver every other ossify verb already goes
  # through: it substitutes `${...}` tokens and refuses a path that only LOOKS
  # absolute. Reading the raw jq value instead would pass a manifest that every
  # real call then fails on, which is the opposite of what this check is for.
  for key in canonical ai_workspace; do
    if ! root="$(_oss_repo_root "$key" 2>/dev/null)" || [ -z "$root" ]; then
      echo "fail: ${key} - .${key}.root is absent, holds an unresolved \${...} token, or is not absolute"
      rc=1; continue
    fi
    if [ ! -d "$root" ]; then
      echo "fail: ${key} - resolved root is not a directory: $root"; rc=1; continue
    fi
    echo "ok: ${key} - $root"
  done

  # The state path. `oss_manifest_state_path` honours
  # `.well_known_paths.project_state` when present and otherwise DERIVES
  # `<ai_workspace.root>/.ossify/project-state.json` - and both forms are
  # manifest-absolute, so an unrouted manifest resolves identically from any
  # directory and is NOT an interop risk. Do not report it as one; the earlier
  # draft of this check did, and it was a claim about behaviour the function
  # does not have.
  #
  # What IS a risk is a path that does not resolve to an absolute location. Two
  # shapes, both now refused by `_oss_manifest_wellknown_guard`:
  #   - an unresolved `${...}` token, which expands differently depending on
  #     which variables a given session's environment happens to carry;
  #   - a RELATIVE routed value, which resolves against whichever directory the
  #     session started in. That one used to print `ok:` here, because the
  #     resolver substituted tokens without ever joining a bare relative value
  #     onto the workspace root - so the check certified as interop-safe the
  #     exact configuration it exists to catch. (Codex P2, PR #149.)
  if sf="$(oss_manifest_state_path 2>/dev/null)" && [ -n "$sf" ]; then
    # The manifest path is not necessarily the EFFECTIVE one. `_oss_resolve_state`
    # gives an exported $OSS_STATE_FILE precedence over the manifest, and that
    # override is a supported, tested form - so a check that reads only the
    # manifest path certifies the workspace as switch-ready while every ceremony
    # in this session reads and MUTATES a different project's state. That is the
    # interop failure in its purest form, so it is checked here rather than
    # assumed away. (Codex P2, PR #149 round 2.)
    #
    # COMPARED CANONICALLY, NOT AS RAW STRINGS. `$OSS_STATE_FILE` is an operator-
    # typed value and `oss_manifest_state_path` is composed from the manifest, so
    # the same file routinely arrives spelled two ways - `$ws/./.ossify/…` against
    # `$ws/.ossify/…`. Compared verbatim, the supported override made a HEALTHY
    # workspace fail, reporting that this session drives another project when it
    # drives this one. (#150)
    #
    # The failure message still echoes the RAW spellings: the operator set that
    # string, and showing them a canonicalized form they never typed makes the
    # remedy harder to act on, not easier.
    local eff eff_canon sf_canon
    eff="$(_oss_resolve_state 2>/dev/null)" || eff=""
    eff_canon="$(_oss_canon_path "$eff")"
    sf_canon="$(_oss_canon_path "$sf")"
    if [ -n "$eff" ] && [ "$eff_canon" != "$sf_canon" ]; then
      echo "fail: state_path - \$OSS_STATE_FILE overrides the manifest ($eff, not $sf); this session's ceremonies would read another project's state"
      rc=1
    else
      echo "ok: state_path - $sf"
    fi
  else
    echo "fail: state_path - the state path does not resolve to an absolute location (an unresolved \${...} token, a relative routed value, or no ai_workspace.root)"
    rc=1
  fi

  ai_root="$(_oss_repo_root ai_workspace 2>/dev/null)" || ai_root=""
  if [ -z "$ai_root" ]; then
    echo "fail: agents_md - cannot look for AGENTS.md without a resolvable ai_workspace root"
    return 1
  fi
  agents="$ai_root/AGENTS.md"
  if [ ! -f "$agents" ]; then
    echo "fail: agents_md - no AGENTS.md at $agents; a Codex session gets no project instructions at all"
    rc=1
  elif ! _oss_interop_names_ossify "$agents"; then
    echo "fail: agents_md - $agents never mentions ossify; a Codex session would drive this project with none of its ceremonies"
    rc=1
  else
    echo "ok: agents_md - $agents routes to ossify"
  fi

  return "$rc"
}

# One awk pass with index(), NOT `grep -q`. Under `set -o pipefail` a
# `… | grep -q` FAILS on a true match, because grep exits as soon as it has its
# answer and the writer takes SIGPIPE - a shape this repo has already shipped
# and had to fix. awk reads the whole file and cannot short-circuit.
_oss_interop_names_ossify() { # $1=path ; rc 0 if the file names ossify
  awk 'index(tolower($0), "ossify") { found = 1 } END { exit(found ? 0 : 1) }' "$1"
}
