# HANDOFF — Shell portability v0.x.1 (zsh compatibility + plugin runtime workaround)

**Date:** 2026-05-26
**Author session:** First real-test of the claude-agent-scaffolding plugin lineup
**Target session:** Implementation session — patch all affected plugins, version-bump, push, release
**Estimated effort:** 1-2 days (5 plugins, parallelizable per-plugin)
**Priority:** P0 — blocks the in-progress first real-project test; every macOS user (default `$SHELL=zsh`) is affected on first install

---

## TL;DR for the implementing session

1. Read this entire doc before touching code. Then read the friction log at `~/.claude/projects/-Volumes-master-ssd-projects-claude-agent-scaffolding/memory/project_friction_log_first_realtest.md` for the live evidence trail.
2. Decision is locked: **Option C — bash via wrapper script per plugin** (see §3). Do not re-litigate; the alternatives (zsh primary, auto-detect everywhere) are written up in the friction log with the reasoning.
3. Five plugins need the dispatcher refactor (workspace-init, scaffold-onboard, scaffold-dev, architect-critic, claude-security-audit). ai-mentor has no lib code and is exempt.
4. Three extra bugs ride along with scaffold-onboard's patch (Issue #1 skill-name discoverability, Issue #3 env-var fallback, Issue #4 state schema lacks `project_root`). Don't ship the scaffold-onboard patch without these.
5. Ship as v0.x.1 patch releases per the [[plugin-version-bump-required]] memory: bump `plugin.json` `version` AND add an entry to `marketplace.json` — `/plugin update` is version-keyed, not commit-keyed.
6. After all five plugins are pushed, ping the user (Praveen) so he can restart his real-test from `/init-workspace`.

---

## 1. Context — what's broken and why

### The trigger
Praveen started the first end-to-end real-test of the plugin lineup on 2026-05-26. Workflow: `/init-workspace` → `/onboard` → `/plan-roadmap` → `/scaffold-project` → `/orchestrate VS-1.1` etc. The first step (`/init-workspace`) blew up during template-path resolution. Rollback per SPEC §13.3 worked correctly (yay), then `/onboard` also blew up during state-source loading.

### Root cause #1: BASH_SOURCE leak
Lib files use `${BASH_SOURCE[0]}` for self-locating templates, helpers, and sibling libs. `BASH_SOURCE` is bash-only. Claude Code's Bash tool on macOS runs **zsh** regardless of what shell launched `claude` (verified: `ps -p $$ -o comm = /bin/zsh`, `ZSH_VERSION=5.9`, `BASH_VERSION=<unset>` in a Bash tool subprocess). Skill bodies tell Claude to `source` the libs, which inherits the calling shell — so the sourced lib runs under zsh and `BASH_SOURCE` evaluates empty.

**Concrete failure evidence:**
```
state.sh:6: BASH_SOURCE[0]: parameter not set
state.sh:source:6: no such file or directory: /_helpers.sh
sf_state_path: command not found
sf_data_dir: command not found
```

### Root cause #2: BASH_REMATCH silent corruption
**This is worse than #1 because it doesn't crash.** scaffold-onboard has 11 `${BASH_REMATCH[…]}` sites in spec parsers / rule validators. Under zsh, `[[ $x =~ pattern ]]; foo="${BASH_REMATCH[1]}"` returns empty silently — the match succeeded but the capture is empty. Parser appears to work, downstream consumers get garbage. This is the kind of bug that lands in production unnoticed.

### Root cause #3: Plugin runtime env vars not exported (upstream)
Already-filed Claude Code issue [#48230](https://github.com/anthropics/claude-code/issues/48230). `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` are documented in plugin.json / hooks.json contexts but **not exported to the Bash tool's subprocess env**. scaffold-onboard's `_helpers.sh:19-26` falls through to a literal `~/.scaffold-onboard-test-data/` path labeled "test fallback" — but it's currently the active path in production because the env vars are never exported. Result: state writes to a "test" dir and a 14-day-old stranger state file from a totally different project caused a false "resume" mode at session start.

### Full bash-ism audit (all plugins, 2026-05-26)

| Plugin | Libs | BASH_SOURCE | BASH_REMATCH | assoc | mapfile | Notes |
|---|---|---|---|---|---|---|
| claude-security-audit | 33 | **55** | 1 | 0 | 0 | Most volume |
| workspace-init | 7 | 13 | 2 | 0 | 0 | Bootstrapping the test |
| scaffold-onboard | 11 | 11 | **11** | 4 | 1 | Worst silent-corruption surface |
| scaffold-dev | 11 | 12 | 2 | 0 | 0 | Same family as scaffold-onboard |
| architect-critic | 8 | 12 | 0 | 4 | 0 | Called peer-to-peer from onboard/dev |
| ai-mentor | 0 | 0 | 0 | 0 | 0 | EXEMPT (no lib code, purely conversational) |
| **Total** | **70** | **103** | **16** | **8** | **1** | |

---

## 2. Known upstream issues (don't duplicate filing)

- [anthropics/claude-code#48230](https://github.com/anthropics/claude-code/issues/48230) — "Feature request: expose CLAUDE_PLUGIN_ROOT as shell env var in Bash tool context." This is exactly our Bug #3. **Add a +1 comment with our specific scaffold-onboard fallback evidence**, don't open a duplicate.
- [anthropics/claude-code#9354](https://github.com/anthropics/claude-code/issues/9354) — "[BUG] Fix ${CLAUDE_PLUGIN_ROOT} in command…" — adjacent issue.
- Best-practice references for shell self-location portability:
  - [chrissicool/zsh-bash](https://github.com/chrissicool/zsh-bash) — zsh plugin that re-implements `source` to be bash-compatible (informative, not a dependency we want)
  - [artudi54/script-sourcing](https://github.com/artudi54/script-sourcing) — cross-shell source utilities (same — informative)
  - Standard portable idiom (do NOT use; we're going with Option C wrapper):
    ```bash
    if [ -n "${BASH_VERSION:-}" ]; then
      DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [ -n "${ZSH_VERSION:-}" ]; then
      DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    fi
    ```

---

## 3. Decision — Option C (bash via wrapper script) — LOCKED

**The architecture:** Each affected plugin gets a `bin/<prefix>` dispatcher script:

```
workspace-init/bin/wi
scaffold-onboard/bin/sf
scaffold-dev/bin/sd
architect-critic/bin/ac
claude-security-audit/bin/csa   (or similar — pick the shortest unambiguous prefix)
```

Each dispatcher:
1. Has `#!/usr/bin/env bash` shebang — **the kernel respects this on direct execution regardless of caller shell**.
2. Sources its plugin's libs (which then run under bash, so `BASH_SOURCE` + `BASH_REMATCH` + `declare -A` all work).
3. Dispatches to lib functions based on argv. Example: `bin/sf state mode` calls `sf_state_mode`, `bin/sf state init "$@"` calls `sf_state_init "$@"`.
4. Returns the function's exit code + stdout/stderr verbatim.

**Skill bodies change from:**
```bash
source "${SF_LIB_DIR}/_helpers.sh"
source "${SF_LIB_DIR}/state.sh"
sf_state_mode
```

**to:**
```bash
"${SF_PLUGIN_ROOT}/bin/sf" state mode
# Or equivalently, since the wrapper has its own bash shebang:
bash "${SF_PLUGIN_ROOT}/bin/sf" state mode
```

**Why this is the right answer (versus the alternatives, settled):**

| Option | Verdict | Why not |
|---|---|---|
| A — zsh primary | ❌ | Loses CI/container portability (Alpine, RHEL-minimal, Docker bases default to bash/sh); fewer zsh shell-scripting patterns to copy; bash is what most plugin contributors know |
| B — Auto-detect everywhere | ❌ | 103+16+8+1 = 128 sites to audit and shim individually; ongoing portability burden; BASH_REMATCH rewrites are non-trivial (regex idioms differ); test surface explodes |
| **C — Bash via wrapper** | ✅ | **One-line invocation contract; shebang guarantees bash via kernel on direct execution; libs stay simple; bonus = clean CLI surface for terminal testing of lib functions** |

Option C is exactly how mature CLI tools (git, kubectl, terraform) handle this: stable CLI boundary, language-locked internals.

### Dispatcher template (use this for every plugin)

```bash
#!/usr/bin/env bash
# bin/<prefix> — dispatcher entry point for <plugin-name>
# Invoked from skill bodies; guarantees bash runtime via shebang regardless of caller shell.

set -euo pipefail

# Self-locate (BASH_SOURCE works here because the shebang forced bash)
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$BIN_DIR/.." && pwd)"
LIB_DIR="$PLUGIN_ROOT/lib"

# Source all libs (order matters — _helpers.sh first if other libs depend on it)
source "$LIB_DIR/_helpers.sh"
for f in "$LIB_DIR"/*.sh; do
  [ "$(basename "$f")" = "_helpers.sh" ] && continue
  source "$f"
done

# Dispatch
if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <namespace> <function> [args...]" >&2
  echo "Example: $(basename "$0") state mode" >&2
  exit 2
fi

namespace="$1"; shift
case "$namespace" in
  state)    fn="sf_state_$1"; shift; "$fn" "$@" ;;
  rules)    fn="sf_rules_$1"; shift; "$fn" "$@" ;;
  spec)     fn="sf_spec_$1"; shift; "$fn" "$@" ;;
  # ... add cases per plugin's lib namespaces
  *)        echo "Unknown namespace: $namespace" >&2; exit 2 ;;
esac
```

Adjust the case statement per plugin. Add `--help` support if time permits.

---

## 4. Plan — phased work (parallelizable per-plugin)

### Phase 0 — Setup (15 min)
- Create a feature branch: `git checkout -b shell-portability-v0x1`
- Sanity-check baseline: from a fresh zsh terminal, run each plugin's existing test suite. Note: many tests probably pass today because tests run `bash test.sh` directly (kernel respects shebang for executable invocation), so the bug only surfaces from skill-body `source` calls. **Don't be falsely reassured by green test runs.**

### Phase 1 — Dispatcher template + design lock (30 min)
- Finalize the dispatcher template in `/tmp/wrapper-template.sh` (start from §3 above).
- Decide naming: `bin/wi`, `bin/sf`, `bin/sd`, `bin/ac`, `bin/csa` (or longer). Short = better DX.
- Decide error contract: what does the dispatcher do when a lib function fails? (Recommend: propagate exit code, stderr passthrough, no wrapping.)
- Decide help/discoverability: `bin/sf --list` should print available namespaces + functions. Nice-to-have, not blocker.

### Phase 2 — Per-plugin refactor (parallel across plugins; ~1-2 hr each)

**For each of the 5 affected plugins, do:**

1. **Create `bin/<prefix>`** from the dispatcher template. Adjust the `case` statement to cover all this plugin's lib namespaces. `chmod +x bin/<prefix>`.
2. **Refactor every SKILL.md body** to invoke `"${PLUGIN_ROOT}/bin/<prefix>" <namespace> <fn> <args>` instead of `source && fn`. Audit with: `grep -rn "source.*lib/" <plugin>/skills/` — every match needs review.
3. **Refactor any commands/*.md** that source libs directly. Same pattern.
4. **Refactor hooks-handlers/*.sh** if they source libs across plugin boundaries. (scaffold-onboard has session-start.sh — check.)
5. **Smoke test from fresh zsh:**
   ```bash
   # In a fresh terminal:
   ./<plugin>/bin/<prefix> <namespace> <known-fn> <test-args>
   # Expected: works, returns 0 (or expected exit code)
   ```
6. **Run existing test suite** — should still pass since tests already invoke `bash test.sh` directly.
7. **Update CHANGELOG.md** with the portability fix entry under the new version heading.

**Per-plugin extra work (do NOT skip):**

- **scaffold-onboard** also needs:
  - **Issue #1 (skill-name discoverability):** Add alias map in plugin.json or surface the qualified skill name `scaffold-onboard:onboarding-project` verbatim in `commands/onboard.md` body so the slash-command handler points Claude at the right `Skill(...)` invocation. Repeat for `/plan-roadmap` → `planning-project-roadmap`, `/scaffold-project` → `scaffolding-memory-bank`, `/scaffold-docs` → `scaffolding-governance-docs`.
  - **Issue #3 (env var fallback):** Change `sf_data_dir` in `lib/_helpers.sh`. When `CLAUDE_PLUGIN_DATA` is unset, compute the canonical path `$HOME/.claude/plugins/data/<slug>/` instead of the literal `~/.scaffold-onboard-test-data/` test fallback. The slug should match what Claude Code's plugin runtime would compute (look at the existing dir `/Users/draco/.claude/plugins/data/scaffold-onboard-claude-agent-scaffolding/` — slug is `<plugin>-<repo>`).
  - **Issue #4 (state schema project_root):** Add `project_root` field to `onboarding-state.json` schema. Capture from `pwd` (or workspace-init manifest's canonical path) at `sf_state_init`. In `sf_state_mode`, if stored `project_root != current pwd`, treat as new project — or prompt: *"State from `<other path>` found. Resume that, or start fresh here?"*. Add a migration step for existing state files (set `project_root` to "unknown" on first read, force user to confirm).
- **scaffold-dev** also needs:
  - Same `Skill(...)` qualified-name surfacing for `/orchestrate` → `planning-vertical-slice`, `/work-item` → `executing-work-item`, `/impl-check` → `implementation-checking`, `/handoff` → `handing-off-session`.
  - Check whether `sd_data_dir` has the same "test fallback" antipattern as `sf_data_dir`. If yes, fix the same way.
- **architect-critic** also needs:
  - Same `Skill(...)` qualified-name surfacing for `/critique` → `critiquing-spec`, `/principles-list` → `listing-principles`, `/critique-list` → `reviewing-critique-history`, `/promote-principle` → `promoting-principle`.
- **claude-security-audit** has the most BASH_SOURCE volume but only 1 BASH_REMATCH. Should be the most mechanical refactor.
- **workspace-init** is the smallest. Save it for last as a confidence-builder, or do it first to validate the dispatcher pattern. Either is fine.

### Phase 3 — Cross-plugin smoke test (30 min)
From a fresh terminal (zsh, not bash), invoke each plugin's primary entry point and confirm zero BASH_SOURCE/BASH_REMATCH errors:

```bash
cd /tmp/shell-portability-smoketest && rm -rf testproject && mkdir testproject && cd testproject
# (Then in a new claude session in that dir, run through:)
/init-workspace
/onboard               # walk through 1-2 phases, confirm state writes to canonical path
/plan-roadmap          # author one phase + sprint + slice, confirm critic invocation works
/scaffold-project
/scaffold-docs
/orchestrate VS-1.1    # confirm dispatcher pattern works for the most complex skill
```

Capture the entire transcript; this is the regression test for the next release cycle.

### Phase 4 — Release (1 hr)
Per the [[plugin-version-bump-required]] memory — `/plugin update` is version-keyed, not commit-keyed. Bump versions:

| Plugin | From | To |
|---|---|---|
| workspace-init | 0.1.0 | **0.1.1** |
| scaffold-onboard | 0.2.0 | **0.2.1** |
| scaffold-dev | 0.1.1 | **0.1.2** |
| architect-critic | 0.2.0 | **0.2.1** |
| claude-security-audit | (check current) | bump patch version |

For each plugin:
1. Update `<plugin>/.claude-plugin/plugin.json` `"version"` field.
2. Update `<plugin>/CHANGELOG.md` with the new version section.
3. Update `<repo-root>/marketplace.json` entry for that plugin to the new version.

Then a single commit per plugin OR one bundled "shell-portability v0.x.1 release" commit (per [[dual-repo-commit-cadence]] — the AI workspace bundles per milestone, and this is a multi-plugin milestone).

```bash
git add -A
git commit -m "shell-portability v0.x.1: bash-via-wrapper for 5 plugins + scaffold-onboard Issues #1/#3/#4

Adds bin/<prefix> dispatcher scripts to workspace-init, scaffold-onboard,
scaffold-dev, architect-critic, claude-security-audit. Refactors skill bodies
to invoke dispatchers instead of bare 'source && fn'. Fixes zsh-related
BASH_SOURCE crashes and BASH_REMATCH silent-corruption surface across all
affected plugins. Adds Skill(...) qualified-name surfacing in slash-command
bodies. scaffold-onboard adds project_root to state schema (cross-project
contamination fix) and canonical fallback for CLAUDE_PLUGIN_DATA when host
runtime doesn't export it (workaround for upstream claude-code#48230).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push origin shell-portability-v0x1
# Open PR; merge to main; users get the update via /plugin update.
```

---

## 5. Acceptance criteria

### Per-plugin (must pass before that plugin is marked done)
- [ ] `bin/<prefix>` dispatcher exists, executable, has bash shebang
- [ ] All `source "$LIB_DIR/…"` sites in `skills/*/SKILL.md` and `commands/*.md` replaced with dispatcher calls
- [ ] Existing test suite passes from a fresh zsh terminal
- [ ] Smoke test: `./bin/<prefix> <namespace> <fn> <args>` runs cleanly from a fresh zsh terminal (no BASH_SOURCE errors)
- [ ] `plugin.json` version bumped; `CHANGELOG.md` entry added
- [ ] `marketplace.json` entry updated to new version

### scaffold-onboard extras
- [ ] `sf_data_dir` computes canonical `$HOME/.claude/plugins/data/scaffold-onboard-claude-agent-scaffolding/` when env vars unset (NOT the test fallback)
- [ ] `onboarding-state.json` schema includes `project_root` field
- [ ] `sf_state_mode` detects project mismatch and prompts/treats-as-new appropriately
- [ ] `commands/onboard.md` body surfaces `Skill(scaffold-onboard:onboarding-project)` verbatim
- [ ] Same Skill(...) surfacing for plan-roadmap, scaffold-project, scaffold-docs commands

### scaffold-dev extras
- [ ] Same Skill(...) surfacing for orchestrate, work-item, impl-check, handoff commands
- [ ] `sd_data_dir` (if exists) audited for the test-fallback antipattern

### architect-critic extras
- [ ] Same Skill(...) surfacing for critique, principles-list, critique-list, promote-principle commands

### Cross-plugin
- [ ] End-to-end smoke test (Phase 3) completes without ANY shell-portability errors
- [ ] No regression in existing test suites across the 5 plugins

### Release
- [ ] All 5 plugins on new version in plugin.json + marketplace.json
- [ ] CHANGELOG.md per plugin updated
- [ ] PR merged to main
- [ ] Praveen confirms `/plugin update` pulls the new versions

---

## 6. Out of scope (defer to a different patch cycle)

- ai-mentor v2.0 (no lib code, not affected)
- Bigger redesign of state storage (per-workspace `<workspace>/.scaffold-onboard/state.json` instead of user-global) — sketched in friction log Issue #4 as an alternative; defer to v0.2.x
- Generic "tracker adapter" interface for Linear/Jira/Pulse Project integration — separate brainstorm
- Pulse Diagram integration — parked separately, see [[pulse-diagram-integration-parked]]

---

## 7. Restart-the-real-test playbook (for Praveen, post-release)

Once the patches ship and you've run `/plugin update`:

1. **Yes, restart from `/init-workspace`** — not from `/onboard`. Reasons:
   - The whole test purpose is to validate the pipeline END-TO-END including the patched init-workspace
   - Picking up mid-flow leaves workspace-init untested in its patched version
   - Your in-progress test project hasn't actually started any product work yet — nothing to lose

2. **Clean up the stale state** before restarting:
   ```bash
   # The stale "test-data" dir that caused Issue #4 contamination:
   rm -rf ~/.scaffold-onboard-test-data/
   # The partial workspace from the failed init attempt (if exists):
   ls -la /Volumes/master_ssd/projects/  # identify the partial dirs
   rm -rf /Volumes/master_ssd/projects/<your-project-name>{,-workspace}
   ```

3. **Verify the patched versions are live:**
   ```bash
   for p in workspace-init scaffold-onboard scaffold-dev architect-critic claude-security-audit; do
     echo "$p: $(grep '"version"' ~/.claude/plugins/cache/*/$p/.claude-plugin/plugin.json 2>/dev/null | head -1)"
   done
   # Expect: 0.1.1 / 0.2.1 / 0.1.2 / 0.2.1 / etc
   ```

4. **Start fresh:**
   ```bash
   cd /Volumes/master_ssd/projects   # parent folder
   claude                            # start session
   # In the session:
   /init-workspace
   # Walk through, then exit, cd into <name>-workspace, start a new session, /onboard
   ```

5. **As you go, keep flagging friction.** The first real-test surfaced 4 issues in 2 commands. There will be more.

---

## 8. Pointers

- **Friction log (live):** `~/.claude/projects/-Volumes-master-ssd-projects-claude-agent-scaffolding/memory/project_friction_log_first_realtest.md` — the running tally of issues; this handoff is the v0.x.1 patch derived from Issues #1-#4
- **Memory: version bump requirement:** `~/.claude/projects/.../memory/feedback_plugin_version_bump_required.md`
- **Memory: dual-repo commit cadence:** `~/.claude/projects/.../memory/project_dual_repo_commit_cadence.md`
- **Memory: skill naming convention:** `~/.claude/projects/.../memory/feedback_skill_naming_gerund_convention.md` — relevant to the Skill(...) qualified-name fix
- **Existing handoff docs for pattern reference:** `docs/HANDOFF-architect-critic-build.md`, `docs/HANDOFF-claude-security-audit-impl.md`
- **Upstream:** [claude-code#48230](https://github.com/anthropics/claude-code/issues/48230)

---

## 9. Sign-off

When done, leave a return-handoff doc at `docs/HANDOFF-shell-portability-v0x1-RETURN.md` with:
- Per-plugin: shipped? version? CHANGELOG link?
- Any deviations from this plan and why
- Any new friction discovered during the patch (add to the friction log)
- Smoke-test transcript (Phase 3)

Then ping Praveen with "v0.x.1 portability patches live — safe to restart the real-test."
