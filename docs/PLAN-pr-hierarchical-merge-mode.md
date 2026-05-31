# PR-hierarchical merge mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in `merge_mode=pr_hierarchical` to scaffold-dev that routes slice and sprint integration through CI-and-review-gated GitHub PRs (work-item → slice → sprint → main), leaving the default `direct` behavior byte-for-byte unchanged.

**Architecture:** Thin deterministic git/`gh` primitives in a new `lib/pr.sh` (one mechanical op each, no semantic parsing) + agent-driven orchestration & merge-gate decisions documented in a shared `references/git-workflow.md` and wired into three lifecycle skills (`planning-vertical-slice`, `closing-vertical-slice`, `writing-sprint-retrospective`). Mode is read from the manifest's `during_dev.merge_mode`; everything new is gated on it.

**Tech Stack:** Bash 3.2+ (stock macOS), `jq`, `git`, `gh` (GitHub CLI); existing `bin/sd` dispatcher (auto-sources every `lib/*.sh`); bash test harness auto-discovering `tests/test-*.sh`; LLM-judge evals via Agent dispatch.

**Authoritative spec:** `docs/SPEC-pr-hierarchical-merge-mode.md`. Read it before starting.

**Repo note:** This is the plugin **source** repo (no `.workspace/pairing.json`). scaffold-dev's own slice/handoff skills don't apply here — implement with normal TDD + frequent commits on a feature branch. All paths below are relative to repo root `/Volumes/master_ssd/projects/claude-agent-scaffolding`.

**Before Task 1:** create the feature branch.

```bash
git checkout -b feat/pr-hierarchical-merge-mode main
```

---

### Task 1: Test harness — `gh` PATH-shim + canned PR-state fixtures

A fake `gh` lets us test the `gh`-wrapping primitives with no network. Canned JSON files model the PR states the agent-driven gate reasons over.

**Files:**
- Create: `scaffold-dev/tests/fixtures/gh-shim/gh`
- Create: `scaffold-dev/tests/fixtures/pr-view-clean.json`
- Create: `scaffold-dev/tests/fixtures/pr-view-with-review-comment.json`
- Create: `scaffold-dev/tests/test-pr.sh` (harness helper + smoke test only in this task)

- [ ] **Step 1: Write the fake `gh`**

`scaffold-dev/tests/fixtures/gh-shim/gh`:

```bash
#!/usr/bin/env bash
# Fake gh for scaffold-dev tests. Records args to $GH_SHIM_LOG; emits canned
# output controlled by env vars. NO network. Subcommand matched on "$1 $2".
[[ -n "${GH_SHIM_LOG:-}" ]] && printf '%s\n' "$*" >> "$GH_SHIM_LOG"
case "${1:-} ${2:-}" in
  "auth status") exit "${GH_SHIM_AUTH_RC:-0}" ;;
  "pr create")   echo "${GH_SHIM_PR_URL:-https://github.com/test/repo/pull/123}"; exit 0 ;;
  "pr view")
    if [[ -n "${GH_SHIM_PR_VIEW_JSON:-}" && -f "$GH_SHIM_PR_VIEW_JSON" ]]; then
      cat "$GH_SHIM_PR_VIEW_JSON"
    else
      echo '{}'
    fi
    exit 0 ;;
  "pr merge")    exit "${GH_SHIM_MERGE_RC:-0}" ;;
  *)             exit 0 ;;
esac
```

Then: `chmod +x scaffold-dev/tests/fixtures/gh-shim/gh`

- [ ] **Step 2: Write the canned PR-state fixtures**

`scaffold-dev/tests/fixtures/pr-view-clean.json`:

```json
{
  "mergeStateStatus": "CLEAN",
  "statusCheckRollup": [{"name": "ci", "conclusion": "SUCCESS"}],
  "reviews": [],
  "reviewThreads": [],
  "latestReviews": [],
  "comments": []
}
```

`scaffold-dev/tests/fixtures/pr-view-with-review-comment.json`:

```json
{
  "mergeStateStatus": "CLEAN",
  "statusCheckRollup": [{"name": "ci", "conclusion": "SUCCESS"}],
  "reviews": [{"author": {"login": "chatgpt-codex-connector"}, "state": "COMMENTED", "body": "Possible off-by-one in the retry loop."}],
  "reviewThreads": [{"isResolved": false, "comments": [{"body": "Possible off-by-one in the retry loop."}]}],
  "latestReviews": [{"author": {"login": "chatgpt-codex-connector"}, "state": "COMMENTED"}],
  "comments": []
}
```

- [ ] **Step 3: Write `test-pr.sh` harness helper + smoke test**

`scaffold-dev/tests/test-pr.sh`:

```bash
#!/usr/bin/env bash
# tests/test-pr.sh — lib/pr.sh primitives (pr_hierarchical merge mode, #40).
# Uses a local bare repo as origin + a gh PATH-shim (no network).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/worktree.sh"
source "$HERE/../lib/merge.sh"
source "$HERE/../lib/pr.sh"

# Build a dual-repo workspace + bare origin + gh shim on PATH.
_setup_pr_workspace() {
  setup_tmp_workspace "$@"
  BARE_ORIGIN="$TMP_DIR/origin.git"
  git init -q --bare "$BARE_ORIGIN"
  git -C "$TMP_CANONICAL" remote add origin "$BARE_ORIGIN"
  chmod +x "$HERE/fixtures/gh-shim/gh" 2>/dev/null || true
  export PATH="$HERE/fixtures/gh-shim:$PATH"
  export GH_SHIM_LOG="$TMP_DIR/gh-calls.log"
  : > "$GH_SHIM_LOG"
  # Reset shim env to defaults each setup.
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON
  export GH_SHIM_PR_URL="https://github.com/test/repo/pull/123"
}

# 0. smoke — shim is reachable and records calls
test_shim_smoke() {
  echo "test_shim_smoke:"
  _setup_pr_workspace
  local out; out="$(gh pr create --head x --base y --title t --body-file /dev/null)"
  assert_contains "shim echoes canned PR url" "pull/123" "$out"
  assert_file_contains "$GH_SHIM_LOG" "pr create"
}

test_shim_smoke

sd_test_summary
```

- [ ] **Step 4: Run it to verify the harness fails cleanly (pr.sh not yet present)**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `lib/pr.sh: No such file or directory` (the `source` line). This confirms the harness is wired; Task 2 creates `lib/pr.sh`.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/tests/fixtures scaffold-dev/tests/test-pr.sh
git commit -m "test(scaffold-dev): gh PATH-shim + PR-state fixtures + test-pr harness (#40)"
```

---

### Task 2: `lib/pr.sh` skeleton + `sd_merge_mode` + branch-name helpers

**Files:**
- Create: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh` (add tests)

- [ ] **Step 1: Write the failing tests**

Add to `test-pr.sh` (before the final `sd_test_summary`, and add the calls):

```bash
# 1. merge_mode defaults to "direct" when unset
test_merge_mode_default() {
  echo "test_merge_mode_default:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "default merge_mode" "direct" "$(sd_merge_mode)"
}

# 2. merge_mode reads pr_hierarchical from manifest
test_merge_mode_pr() {
  echo "test_merge_mode_pr:"
  _setup_pr_workspace
  # inject merge_mode into the manifest
  local tmp; tmp="$(mktemp)"
  jq '.during_dev.merge_mode = "pr_hierarchical"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  cd "$TMP_AI_WORKSPACE"
  assert_eq "reads pr_hierarchical" "pr_hierarchical" "$(sd_merge_mode)"
}

# 3. sprint branch name default template
test_sprint_branch_name() {
  echo "test_sprint_branch_name:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "sprint branch default" "sprint-1.1" "$(_sd_sprint_branch_name "1.1")"
}

# 4. slice branch name default template
test_slice_branch_name() {
  echo "test_slice_branch_name:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "slice branch default" "slice/VS-1.1.1" "$(_sd_slice_branch_name "VS-1.1.1")"
}
```

Register the calls (above `sd_test_summary`):

```bash
test_merge_mode_default
test_merge_mode_pr
test_sprint_branch_name
test_slice_branch_name
```

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `lib/pr.sh: No such file or directory`.

- [ ] **Step 3: Create `lib/pr.sh` with the config layer**

`scaffold-dev/lib/pr.sh`:

```bash
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
```

- [ ] **Step 4: Run to verify the 4 tests pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS (smoke + 4 config tests).

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): lib/pr.sh config layer — merge_mode + branch-name helpers (#40)"
```

---

### Task 3: `sd_branch_create_from` (idempotent)

**Files:**
- Modify: `scaffold-dev/lib/pr.sh` (append function)
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests**

Add to `test-pr.sh` + register:

```bash
# 5. create branch off base
test_branch_create() {
  echo "test_branch_create:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-1.1" 2>/dev/null
  assert_exit_code 0 git -C "$TMP_CANONICAL" rev-parse --verify --quiet "refs/heads/sprint-1.1"
}

# 6. idempotent — second create is a no-op rc 0
test_branch_create_idempotent() {
  echo "test_branch_create_idempotent:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-1.1" 2>/dev/null
  set +e; sd_branch_create_from "main" "sprint-1.1" 2>/dev/null; local rc=$?; :
  assert_eq "re-create rc=0" "0" "$rc"
}

# 7. missing base fails
test_branch_create_missing_base() {
  echo "test_branch_create_missing_base:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_branch_create_from "no-such-base" "x" 2>/dev/null; local rc=$?; :
  assert_ne "missing base rc!=0" "0" "$rc"
}
```

Register: `test_branch_create`, `test_branch_create_idempotent`, `test_branch_create_missing_base`.

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_branch_create_from: command not found` / unbound.

- [ ] **Step 3: Append the implementation to `lib/pr.sh`**

```bash
# sd_branch_create_from <base> <new> — create <new> off <base> in canonical.
# Idempotent: rc 0 if <new> already exists. rc 1 if <base> is missing.
sd_branch_create_from() {
  local base="$1" new="$2" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_branch_create_from: no canonical.root"; return 1; }
  if git -C "$canonical" rev-parse --verify --quiet "refs/heads/$new" >/dev/null; then
    return 0
  fi
  if ! git -C "$canonical" rev-parse --verify --quiet "refs/heads/$base" >/dev/null; then
    sd_log_error "sd_branch_create_from: base branch not found: $base"
    return 1
  fi
  if ! git -C "$canonical" branch "$new" "$base" >/dev/null 2>&1; then
    sd_log_error "sd_branch_create_from: failed to create $new off $base"
    return 1
  fi
  return 0
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS (all prior + 3 new).

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_branch_create_from (idempotent) (#40)"
```

---

### Task 4: `sd_branch_push`

**Files:**
- Modify: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests**

```bash
# 8. push lands the branch on the bare origin
test_branch_push() {
  echo "test_branch_push:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-1.1" 2>/dev/null
  sd_branch_push "sprint-1.1" 2>/dev/null
  assert_exit_code 0 git -C "$BARE_ORIGIN" rev-parse --verify --quiet "refs/heads/sprint-1.1"
}

# 9. push fails cleanly with no origin remote
test_branch_push_no_remote() {
  echo "test_branch_push_no_remote:"
  _setup_pr_workspace
  git -C "$TMP_CANONICAL" remote remove origin
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_branch_push "main" 2>/dev/null; local rc=$?; :
  assert_ne "no-remote push rc!=0" "0" "$rc"
}
```

Register both.

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_branch_push` unbound.

- [ ] **Step 3: Append the implementation**

```bash
# sd_branch_push <branch> — push <branch> to origin with upstream. rc 1 if no
# 'origin' remote configured on canonical.
sd_branch_push() {
  local branch="$1" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_branch_push: no canonical.root"; return 1; }
  if ! git -C "$canonical" remote get-url origin >/dev/null 2>&1; then
    sd_log_error "sd_branch_push: no 'origin' remote on canonical; pr_hierarchical mode requires a remote."
    return 1
  fi
  if ! git -C "$canonical" push -u origin "$branch" >/dev/null 2>&1; then
    sd_log_error "sd_branch_push: failed to push $branch to origin"
    return 1
  fi
  return 0
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_branch_push (#40)"
```

---

### Task 5: `sd_remote_check`

**Files:**
- Modify: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests**

```bash
# 10. remote_check passes with origin + authed gh shim
test_remote_check_ok() {
  echo "test_remote_check_ok:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_remote_check 2>/dev/null; local rc=$?; :
  assert_eq "remote_check ok rc=0" "0" "$rc"
}

# 11. remote_check fails with no origin
test_remote_check_no_remote() {
  echo "test_remote_check_no_remote:"
  _setup_pr_workspace
  git -C "$TMP_CANONICAL" remote remove origin
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_remote_check 2>/dev/null; local rc=$?; :
  assert_ne "no-remote rc!=0" "0" "$rc"
}

# 12. remote_check fails when gh auth fails
test_remote_check_auth_fail() {
  echo "test_remote_check_auth_fail:"
  _setup_pr_workspace
  export GH_SHIM_AUTH_RC=1
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_remote_check 2>/dev/null; local rc=$?; :
  unset GH_SHIM_AUTH_RC
  assert_ne "auth-fail rc!=0" "0" "$rc"
}
```

Register all three.

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_remote_check` unbound.

- [ ] **Step 3: Append the implementation**

```bash
# sd_remote_check — verify canonical has an 'origin' remote AND gh is present +
# authenticated. rc 0 on success; rc 1 + actionable message otherwise.
sd_remote_check() {
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_remote_check: no canonical.root"; return 1; }
  if ! git -C "$canonical" remote get-url origin >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: no 'origin' remote on canonical. Add one (git remote add origin <url>) — pr_hierarchical mode opens PRs against it."
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: 'gh' not in PATH. Install GitHub CLI — pr_hierarchical mode opens PRs via gh."
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: 'gh' is not authenticated. Run 'gh auth login' — pr_hierarchical mode needs it to open PRs."
    return 1
  fi
  return 0
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_remote_check degradation guard (#40)"
```

---

### Task 6: `sd_pr_open`

**Files:**
- Modify: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests**

```bash
# 13. pr_open echoes the PR url and calls gh with the right args
test_pr_open() {
  echo "test_pr_open:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo "body text" > "$body"
  local out; out="$(sd_pr_open "slice/VS-1.1.1" "sprint-1.1" "VS-1.1.1: title" "$body" 2>/dev/null)"
  assert_contains "echoes PR url" "pull/123" "$out"
  assert_file_contains "$GH_SHIM_LOG" "pr create --head slice/VS-1.1.1 --base sprint-1.1"
}
```

Register `test_pr_open`.

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_pr_open` unbound.

- [ ] **Step 3: Append the implementation**

```bash
# sd_pr_open <head> <base> <title> <body-file> — wraps gh pr create (run from
# canonical so gh resolves the repo from origin). Echoes gh's stdout (PR url or
# number). rc 1 if gh absent or the create fails.
sd_pr_open() {
  local head="$1" base="$2" title="$3" body_file="$4" canonical out
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_open: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_open: 'gh' not in PATH."
    return 1
  fi
  if ! out="$(cd "$canonical" && gh pr create --head "$head" --base "$base" --title "$title" --body-file "$body_file" 2>&1)"; then
    sd_log_error "sd_pr_open: gh pr create failed: $out"
    return 1
  fi
  echo "$out"
  return 0
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_pr_open (gh pr create wrapper) (#40)"
```

---

### Task 7: `sd_pr_state`

**Files:**
- Modify: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests**

```bash
# 14. pr_state passes through gh's JSON unchanged (clean state)
test_pr_state_clean() {
  echo "test_pr_state_clean:"
  _setup_pr_workspace
  export GH_SHIM_PR_VIEW_JSON="$HERE/fixtures/pr-view-clean.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_state 123 2>/dev/null)"
  assert_eq "mergeStateStatus passthrough" "CLEAN" "$(echo "$json" | jq -r '.mergeStateStatus')"
  assert_eq "no review comments" "0" "$(echo "$json" | jq -r '.reviewThreads | length')"
}

# 15. pr_state surfaces an unresolved review-comment state verbatim
test_pr_state_with_comment() {
  echo "test_pr_state_with_comment:"
  _setup_pr_workspace
  export GH_SHIM_PR_VIEW_JSON="$HERE/fixtures/pr-view-with-review-comment.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_state 123 2>/dev/null)"
  assert_eq "unresolved thread present" "false" "$(echo "$json" | jq -r '.reviewThreads[0].isResolved')"
}
```

Register both. (Each test sets `GH_SHIM_PR_VIEW_JSON`; `_setup_pr_workspace` unsets it, so ordering is safe.)

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_pr_state` unbound.

- [ ] **Step 3: Append the implementation**

```bash
# sd_pr_state <pr> — emit gh pr view JSON for the agent-driven gate to reason
# over. NO interpretation here. rc 1 if gh absent.
sd_pr_state() {
  local pr="$1" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_state: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_state: 'gh' not in PATH."
    return 1
  fi
  (cd "$canonical" && gh pr view "$pr" --json mergeStateStatus,statusCheckRollup,reviews,reviewThreads,latestReviews,comments)
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_pr_state (gh pr view JSON passthrough) (#40)"
```

---

### Task 8: `sd_pr_merge` + dispatcher `--list` verification

**Files:**
- Modify: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests**

```bash
# 16. pr_merge invokes gh pr merge with the pr number
test_pr_merge() {
  echo "test_pr_merge:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_pr_merge 123 2>/dev/null; local rc=$?; :
  assert_eq "merge rc=0" "0" "$rc"
  assert_file_contains "$GH_SHIM_LOG" "pr merge 123"
}

# 17. pr_merge --auto passes the flag through
test_pr_merge_auto() {
  echo "test_pr_merge_auto:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_pr_merge 123 --auto 2>/dev/null
  assert_file_contains "$GH_SHIM_LOG" "pr merge 123 --auto"
}

# 18. dispatcher exposes the new functions
test_dispatcher_lists_pr_fns() {
  echo "test_dispatcher_lists_pr_fns:"
  local listed; listed="$("$HERE/../bin/sd" --list)"
  assert_contains "lists branch_create_from" "branch_create_from" "$listed"
  assert_contains "lists pr_open" "pr_open" "$listed"
  assert_contains "lists pr_state" "pr_state" "$listed"
  assert_contains "lists merge_mode" "merge_mode" "$listed"
}
```

Register all three. (Note: `sd --list` filters to `sd_<suffix>` where suffix's first char is non-`_`; `sd_pr_open`→`pr_open`, `sd_merge_mode`→`merge_mode`. The `_sd_*` private helpers are correctly excluded.)

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_pr_merge` unbound (and `--list` missing `pr_merge`).

- [ ] **Step 3: Append the implementation**

```bash
# sd_pr_merge <pr> [extra gh args...] — wraps gh pr merge. Pass --auto to enable
# auto-merge once required checks pass.
sd_pr_merge() {
  local pr="$1"; shift
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_merge: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_merge: 'gh' not in PATH."
    return 1
  fi
  (cd "$canonical" && gh pr merge "$pr" "$@")
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS — full `test-pr.sh` green.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_pr_merge + dispatcher --list coverage (#40)"
```

---

### Task 9: `sd_merge_work_item` optional target-branch arg

Lets work-item merges target the slice branch under `pr_hierarchical`; omitted arg preserves today's `default_branch` behavior exactly.

**Files:**
- Modify: `scaffold-dev/lib/merge.sh:23-27`
- Test: `scaffold-dev/tests/test-merge.sh`

- [ ] **Step 1: Write the failing test (append to `test-merge.sh` + register)**

```bash
# 15. explicit target-branch arg merges into that branch, not main
test_merge_into_target_branch() {
  echo "test_merge_into_target_branch:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  # Create a slice integration branch off main on canonical.
  git -C "$TMP_CANONICAL" branch slice/VS-1.1.1 main
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1.1" "feat" "1.1" 2>/dev/null)"
  _make_commit "$wt" "feat.txt" "hello"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" "slice/VS-1.1.1" 2>/dev/null
  # File is on the slice branch...
  assert_eq "feat on slice branch" "hello" "$(git -C "$TMP_CANONICAL" show "slice/VS-1.1.1:feat.txt" 2>/dev/null)"
  # ...and NOT on main.
  set +e; git -C "$TMP_CANONICAL" show "main:feat.txt" >/dev/null 2>&1; local on_main=$?; :
  assert_ne "feat NOT on main" "0" "$on_main"
}
```

Register `test_merge_into_target_branch` in the call list and update the header comment count (`14 tests` → `15 tests`).

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-merge.sh`
Expected: FAIL — file lands on `main` (current behavior ignores a 3rd arg), so the slice-branch assertion fails.

- [ ] **Step 3: Modify `sd_merge_work_item`**

In `scaffold-dev/lib/merge.sh`, replace the signature/derivation block (lines ~23-27):

```bash
# sd_merge_work_item <wt-path> <branch> [<target-branch>]
# Commits any staged changes in the worktree, then merges <branch> into
# <target-branch> via --no-ff. When <target-branch> is omitted, derives
# .canonical.default_branch (today's behavior). Returns non-zero on conflict.
sd_merge_work_item() {
  local wt="$1" branch="$2" target="${3:-}"
  local canonical target_branch
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_merge_work_item: no canonical.root"; return 1; }
  if [[ -n "$target" ]]; then
    target_branch="$target"
  else
    target_branch="$(sd_manifest_get '.canonical.default_branch')" || target_branch="main"
  fi
```

Then update the rest of the function to use `$target_branch` everywhere it previously used `$default_branch` (the checkout block at lines ~50-57 and the merge at ~60). Specifically:
- `cur_branch` comparison: `if [[ "$cur_branch" != "$target_branch" ]]; then`
- checkout: `git -C "$canonical" checkout -q "$target_branch"` and its error message `canonical not on $target_branch (got $cur_branch)`.

No other lines change.

- [ ] **Step 4: Run to verify pass (new test + all existing merge tests)**

Run: `cd scaffold-dev && bash tests/test-merge.sh`
Expected: PASS — 15 tests, 0 failures (the 14 existing tests pass 2 args → `target` empty → `default_branch`, unchanged).

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/merge.sh scaffold-dev/tests/test-merge.sh
git commit -m "feat(scaffold-dev): sd_merge_work_item optional target-branch arg (#40)"
```

---

### Task 10: `sd_worktree_add` optional base-branch param

Lets work-item worktrees branch off the slice branch under `pr_hierarchical`; omitted arg preserves branching off `default_branch`.

**Files:**
- Modify: `scaffold-dev/lib/worktree.sh:52-78`
- Test: `scaffold-dev/tests/test-worktree.sh`

- [ ] **Step 1: Write the failing test (append to `test-worktree.sh` + register)**

```bash
# base-branch param: worktree branches off the given base, not main
test_worktree_add_base_branch() {
  echo "test_worktree_add_base_branch:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  # A slice branch with a commit main does NOT have.
  git -C "$TMP_CANONICAL" branch slice/VS-1.1.1 main
  git -C "$TMP_CANONICAL" checkout -q slice/VS-1.1.1
  echo "base-only" > "$TMP_CANONICAL/base.txt"
  git -C "$TMP_CANONICAL" add base.txt
  git -C "$TMP_CANONICAL" commit -q -m "base-only commit"
  git -C "$TMP_CANONICAL" checkout -q main
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1.1" "feat" "1.1" "slice/VS-1.1.1" 2>/dev/null)"
  # The worktree, based on the slice branch, sees base.txt.
  assert_file_exists "$wt/base.txt"
}
```

Register the call (and bump the file's header test-count comment if present).

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-worktree.sh`
Expected: FAIL — worktree branches off `main` (no 5th-arg handling), so `base.txt` is absent.

- [ ] **Step 3: Modify `sd_worktree_add`**

In `scaffold-dev/lib/worktree.sh`, update the signature + base derivation and the `git worktree add` base ref:

Change the doc comment + signature (lines ~47-53) to:

```bash
# sd_worktree_add <work-id> <slice-id> <kebab> [sprint-id] [base-branch]
# Creates a worktree under <canonical.root>/.worktrees and a fresh branch.
# Echoes the absolute worktree path on stdout. Branches from <base-branch> when
# given (the slice branch under pr_hierarchical), else canonical's default_branch.
sd_worktree_add() {
  local work_id="$1" slice_id="$2" kebab="$3" sprint_id="${4:-}" base_branch="${5:-}"
  local canonical default_branch raw_worktrees_dir worktrees_dir branch wt_path base_ref
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "no canonical.root"; return 1; }
  default_branch="$(sd_manifest_get '.canonical.default_branch')" || default_branch="main"
  if [[ -n "$base_branch" ]]; then base_ref="$base_branch"; else base_ref="$default_branch"; fi
```

Then change the worktree-add line (was line ~72) from `… "$wt_path" "$default_branch" …` to:

```bash
  if ! git -C "$canonical" worktree add -b "$branch" "$wt_path" "$base_ref" >/dev/null 2>&1; then
```

No other lines change.

- [ ] **Step 4: Run to verify pass (new test + all existing worktree tests)**

Run: `cd scaffold-dev && bash tests/test-worktree.sh`
Expected: PASS (existing tests pass 4 args → `base_branch` empty → `default_branch`, unchanged).

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/lib/worktree.sh scaffold-dev/tests/test-worktree.sh
git commit -m "feat(scaffold-dev): sd_worktree_add optional base-branch param (#40)"
```

---

### Task 11: `references/git-workflow.md` — the shared workflow doc

The single explicit write-up of the topology, modes, primitive contracts, the agent-driven pre-merge gate, and degradation. Lives under `planning-vertical-slice` (the orchestration entry skill) and is cited by the other two skills.

**Files:**
- Create: `scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md`

- [ ] **Step 1: Write the doc**

Create `scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md` with this content:

````markdown
# scaffold-dev git workflow (merge modes)

Shared reference for `planning-vertical-slice`, `closing-vertical-slice`, and
`writing-sprint-retrospective`. Defines how slice/sprint work reaches `main`.
Behavior is selected by `during_dev.merge_mode` (read via `sd merge_mode`).

## Modes

- **`direct`** (default / unset) — today's behavior, **byte-for-byte unchanged**.
  Work-item branches merge locally (`--no-ff`) into `.canonical.default_branch`.
  No remote, no `gh`, no PR. Nothing in this doc's `pr_hierarchical` sections runs.
- **`pr_hierarchical`** — a three-tier integration hierarchy with PR gates:

```
main  ───────────────────────────────●   PR: sprint-N → main   (protected; real CI + review gate)
  └─ sprint-N                  (off main; whole sprint)
       ├─ slice/VS-N.M.1       (off sprint-N)
       │    ├─ work-item branches → DIRECT local --no-ff merge → slice branch
       │    └─ then  PR: slice/VS-N.M.1 → sprint-N   (CI + review gate)
       └─ slice/VS-N.M.2       (off sprint-N, after slice-1's PR merges)
```

- work-item → slice: direct local merge (no PR; already gated by implementation-checking).
- slice → sprint-N: PR at slice close.
- sprint-N → main: PR at sprint close.

## Deterministic primitives (mechanical only — `lib/pr.sh`)

Invoke via the `sd` dispatcher. Each does ONE git/`gh` op; the agent reasons over output.

- `sd merge_mode` → `direct` | `pr_hierarchical`.
- `sd branch_create_from <base> <new>` → idempotent branch create in canonical.
- `sd branch_push <branch>` → push to origin; errors if no remote.
- `sd remote_check` → verify origin remote + authenticated `gh`.
- `sd pr_open <head> <base> <title> <body-file>` → `gh pr create`; echoes PR url.
- `sd pr_state <pr>` → raw `gh pr view --json …` (mergeStateStatus, statusCheckRollup,
  reviews, reviewThreads, latestReviews, comments). NO interpretation.
- `sd pr_merge <pr> [--auto]` → `gh pr merge`.

Branch names: `sd`-internal helpers `_sd_sprint_branch_name <sprint_id>` (default
`sprint-{sprint_id}`) and `_sd_slice_branch_name <vs_id>` (default `slice/{vs_id}`),
configurable via `during_dev.sprint_branch_naming` / `during_dev.slice_branch_naming`.

## Slice-ordering rule (pr_hierarchical)

A slice's PR into `sprint-N` is expected to merge **before** the next slice branches
off `sprint-N`. If a prior slice PR is still open when the next slice starts, SURFACE
it — *"VS-N.M.1's PR is still open; merge it before branching VS-N.M.2 off sprint-N,
or proceed knowing slice-2 won't include slice-1's commits"* — and wait for the user.
Never silently branch off a stale `sprint-N`.

## Agent-driven pre-merge gate (BINDING — judgment, not bash)

Before merging ANY PR (slice→sprint or sprint→main), the orchestrator:

1. Calls `sd pr_state <pr>` → full state (CI rollup **and** review threads/comments).
2. Reasons over the FULL state — **not just** `statusCheckRollup` / `mergeStateStatus`:
   - Review-app and human review **comments** are usually NOT modeled as required
     status checks, so `mergeStateStatus == CLEAN` can coexist with an unresolved
     review finding. Account for review comments from **any review source** (the
     Codex GitHub app today; generic so it survives any reviewer change).
   - If the latest commit postdates the newest bot review, a re-review is likely
     still incoming — note that.
3. SURFACES unresolved review comments + CI state to the user and ASKS.
   **Never auto-merge over un-addressed review findings without explicit user
   acknowledgment.**
4. On the user's decision: `sd pr_merge <pr> [--auto]`, leave open, or wait.
   The gate does NOT busy-wait / poll the conversation on CI.

This is non-enforced guidance to the agent — deterministic checks stay only for the
mechanical git/`gh` facts above.

## Degradation

`pr_hierarchical` but missing `gh` / not authenticated / no origin remote → the
orchestrator REFUSES at planning pre-flight (`sd remote_check`) with the actionable
message. No silent fallback to `direct`.
````

- [ ] **Step 2: Verify the doc has the load-bearing anchors**

Run:
```bash
grep -q "pr_hierarchical" scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md \
  && grep -q "Never auto-merge over un-addressed review findings" scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md \
  && grep -q "sd remote_check" scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md \
  && echo "ANCHORS-OK"
```
Expected: `ANCHORS-OK`.

- [ ] **Step 3: Commit**

```bash
git add scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md
git commit -m "docs(scaffold-dev): shared git-workflow reference for pr_hierarchical (#40)"
```

---

### Task 12: Wire `planning-vertical-slice` for `pr_hierarchical`

**Files:**
- Modify: `scaffold-dev/skills/planning-vertical-slice/SKILL.md` (§3.2 area, §8.1, §8.6)

- [ ] **Step 1: Add a merge-mode pre-flight subsection after §3.3**

Insert a new subsection (renumber nothing else; add as `### 3.3a Merge-mode pre-flight (pr_hierarchical)`) immediately after the §3.3 block:

````markdown
### 3.3a Merge-mode pre-flight (pr_hierarchical)

Read the mode early (it gates §8.1 + §8.6 + slice-close). See
`references/git-workflow.md` for the full topology and primitive contracts.

```bash
merge_mode="$(sd merge_mode)"   # "direct" (default) | "pr_hierarchical"
```

If `merge_mode == "direct"`: skip the rest of this subsection — behavior is
unchanged from v0.1.

If `merge_mode == "pr_hierarchical"`:

1. **Refuse fast if the remote/gh prerequisites are missing:**
   ```bash
   sd remote_check || exit 1   # surfaces the actionable error verbatim
   ```
   Do NOT silently fall back to `direct`.
2. **Ensure the sprint integration branch exists** (create off `default_branch`
   at the first slice of the sprint; reuse otherwise):
   ```bash
   sprint_branch="sprint-${sprint_id}"          # or per during_dev.sprint_branch_naming
   default_branch="$(sd manifest_get '.canonical.default_branch')" || default_branch="main"
   sd branch_create_from "$default_branch" "$sprint_branch"
   ```
3. **Slice-ordering check:** if a prior slice's PR into `$sprint_branch` is still
   open, surface it per `references/git-workflow.md` (slice-ordering rule) and wait
   for the user before continuing.
4. **Create the slice branch off the sprint branch:**
   ```bash
   slice_branch="slice/${vs_id}"                # or per during_dev.slice_branch_naming
   sd branch_create_from "$sprint_branch" "$slice_branch"
   ```
   Carry `$slice_branch` forward — §8.1 bases work-item worktrees on it and §8.6
   merges into it.
````

- [ ] **Step 2: Amend §8.1 (worktree base)**

In §8.1, after the existing `sd worktree_add …` example, add:

````markdown
Under `merge_mode=pr_hierarchical`, pass the slice branch as the base so the
worktree branches off the slice (not `default_branch`):

```bash
sd worktree_add "${work_id}" "${vs_id}" "${kebab}" "${sprint_id}" "${slice_branch}"
```
````

- [ ] **Step 3: Amend §8.6 (merge target)**

In §8.6 step 2, replace the merge instruction so it reads:

````markdown
2. Merge the work-item branch into the integration target via `sd_merge_work_item`.
   - `direct` mode: `sd merge_work_item "<worktree>" "<branch>"` (merges into
     `default_branch` — today's behavior).
   - `pr_hierarchical` mode: `sd merge_work_item "<worktree>" "<branch>" "${slice_branch}"`
     (merges locally into the slice branch; **no push, no PR at this level**).

   **HALT on conflict** per SPEC §11 — surface the failure-response menu ("Merge
   conflict" row): user resolves via `git merge --continue`, OR aborts via
   `git merge --abort` and replans integration.
````

- [ ] **Step 4: Verify the edits landed**

Run:
```bash
grep -q "Merge-mode pre-flight (pr_hierarchical)" scaffold-dev/skills/planning-vertical-slice/SKILL.md \
  && grep -q 'sd merge_work_item "<worktree>" "<branch>" "${slice_branch}"' scaffold-dev/skills/planning-vertical-slice/SKILL.md \
  && grep -q "sd remote_check" scaffold-dev/skills/planning-vertical-slice/SKILL.md \
  && echo "PLANNING-WIRED"
```
Expected: `PLANNING-WIRED`.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/skills/planning-vertical-slice/SKILL.md
git commit -m "feat(scaffold-dev): wire planning-vertical-slice for pr_hierarchical (#40)"
```

---

### Task 13: Wire `closing-vertical-slice` for `pr_hierarchical`

**Files:**
- Modify: `scaffold-dev/skills/closing-vertical-slice/SKILL.md` (§5 demo target, new post-cleanup PR section)

- [ ] **Step 1: Amend §5 (auto-demo runs on the slice branch under pr_hierarchical)**

In §5, after the binding `cd "$canonical"` note, add:

````markdown
Under `merge_mode=pr_hierarchical` (read via `sd merge_mode`), the slice's work
lives on the slice branch, not `default_branch`. Check it out before demos:

```bash
if [[ "$(sd merge_mode)" == "pr_hierarchical" ]]; then
  git -C "$canonical" checkout -q "slice/${vs_id}"   # or per during_dev.slice_branch_naming
fi
```
Restore is unnecessary — the slice branch is the integration target until its PR merges.
````

- [ ] **Step 2: Add a new section after §10 (cleanup) opening the slice→sprint PR**

Insert a new `## 10a. Open the slice→sprint PR (pr_hierarchical only)` after §10:

````markdown
## 10a. Open the slice→sprint PR (pr_hierarchical only)

Runs only when `sd merge_mode` == `pr_hierarchical`, AFTER §9 harvest + §10
worktree cleanup (work-item worktree/branch cleanup is decoupled from this PR —
the slice branch already holds every work-item commit; see
`references/git-workflow.md`).

1. **Push the slice branch:** `sd branch_push "slice/${vs_id}"`.
2. **Compose the PR body** to a temp file: the slice README (with the populated
   Demo-verification section) + the architect-critic close-depth summary (§7) +
   any linked tech-debt/issue references.
3. **Open the PR:**
   ```bash
   sd pr_open "slice/${vs_id}" "sprint-${sprint_id}" "VS-${vs_id}: <slice title>" "<body-file>"
   ```
4. **Run the agent-driven pre-merge gate** per `references/git-workflow.md`
   (`sd pr_state` → reason over CI **and** review comments → surface → ask).
   Merge via `sd pr_merge` only on explicit user acknowledgment, or leave the PR
   open for asynchronous CI/review. Do NOT busy-wait.

`direct` mode skips this section entirely — work items already merged into
`default_branch` at §8.6, exactly as in v0.1.
````

- [ ] **Step 3: Verify the edits landed**

Run:
```bash
grep -q "Open the slice→sprint PR (pr_hierarchical only)" scaffold-dev/skills/closing-vertical-slice/SKILL.md \
  && grep -q 'sd pr_open "slice/${vs_id}" "sprint-${sprint_id}"' scaffold-dev/skills/closing-vertical-slice/SKILL.md \
  && echo "CLOSING-WIRED"
```
Expected: `CLOSING-WIRED`.

- [ ] **Step 4: Commit**

```bash
git add scaffold-dev/skills/closing-vertical-slice/SKILL.md
git commit -m "feat(scaffold-dev): wire closing-vertical-slice slice→sprint PR (#40)"
```

---

### Task 14: Wire `writing-sprint-retrospective` for the sprint→main PR

**Files:**
- Modify: `scaffold-dev/skills/writing-sprint-retrospective/SKILL.md` (new final section)

- [ ] **Step 1: Add a new section opening the sprint→main PR**

Append a new section (after the retrospective is authored; place it as the final numbered section before any anti-patterns/slash-command section — read the file to find the right slot):

````markdown
## Open the sprint→main PR (pr_hierarchical only)

Runs only when `sd merge_mode` == `pr_hierarchical`, AFTER the sprint
retrospective is authored and all slice PRs into `sprint-${sprint_id}` have
merged. See `references/git-workflow.md` (cited by `planning-vertical-slice`) for
the topology and the binding pre-merge gate.

1. **Confirm slice PRs merged:** if any slice PR into `sprint-${sprint_id}` is
   still open, surface it and stop — the sprint isn't ready to integrate to `main`.
2. **Push the sprint branch:** `sd branch_push "sprint-${sprint_id}"`.
3. **Compose the PR body:** the sprint retrospective summary + the slice list +
   linked issues.
4. **Open the PR:**
   ```bash
   sd pr_open "sprint-${sprint_id}" "$(sd manifest_get '.canonical.default_branch' || echo main)" \
     "Sprint ${sprint_id}: <summary>" "<body-file>"
   ```
5. **Run the agent-driven pre-merge gate** per `references/git-workflow.md`
   (`sd pr_state` → reason over CI **and** review comments → surface → ask). This
   is the protected boundary — be especially explicit about unresolved review
   findings. Merge via `sd pr_merge` only on explicit user acknowledgment.

`direct` mode skips this section — there is no sprint branch and no PR.
````

- [ ] **Step 2: Verify the edit landed**

Run:
```bash
grep -q "Open the sprint→main PR (pr_hierarchical only)" scaffold-dev/skills/writing-sprint-retrospective/SKILL.md \
  && grep -q 'sd pr_open "sprint-${sprint_id}"' scaffold-dev/skills/writing-sprint-retrospective/SKILL.md \
  && echo "SPRINT-WIRED"
```
Expected: `SPRINT-WIRED`.

- [ ] **Step 3: Commit**

```bash
git add scaffold-dev/skills/writing-sprint-retrospective/SKILL.md
git commit -m "feat(scaffold-dev): wire writing-sprint-retrospective sprint→main PR (#40)"
```

---

### Task 15: Eval scenarios for the agent-driven gates

LLM-judge scenarios (per the repo's eval pattern — natural-language assertions, no bash truthy-tests) covering the `pr_hierarchical` paths. Read each target eval's existing "Harness" + scenario format first and match it.

**Files:**
- Modify: `scaffold-dev/evals/planning-vertical-slice.md`
- Modify: `scaffold-dev/evals/closing-vertical-slice.md`
- Modify: `scaffold-dev/evals/writing-sprint-retrospective.md`

- [ ] **Step 1: Add a planning scenario — pr_hierarchical pre-flight**

Append a scenario to `evals/planning-vertical-slice.md` matching its existing scenario shape:

```markdown
### Scenario: pr_hierarchical pre-flight creates the branch hierarchy

**Setup:** dual-repo workspace with `during_dev.merge_mode = "pr_hierarchical"`,
canonical has an `origin` remote, `gh` is authenticated (test harness may stub gh).
Roadmap declares VS-1.1.1 as the first slice of sprint 1.1.

**Trigger:** user invokes `/orchestrate VS-1.1.1`.

**Expected behavior:** the skill reads `sd merge_mode`, runs `sd remote_check`,
ensures `sprint-1.1` exists off main, creates `slice/VS-1.1.1` off `sprint-1.1`,
and bases work-item worktrees on `slice/VS-1.1.1`.

**Assertion (judge):** PASS iff the tool-call log shows (a) a merge-mode read,
(b) a `remote_check` / remote-prerequisite gate BEFORE any branch creation,
(c) `sprint-1.1` created off the default branch, (d) `slice/VS-1.1.1` created off
`sprint-1.1`, (e) worktree creation bases off `slice/VS-1.1.1`. FAIL if it merges
work items into `default_branch`, or proceeds without `remote_check` when the mode
is pr_hierarchical.
```

- [ ] **Step 2: Add a closing scenario — review comment blocks auto-merge**

Append to `evals/closing-vertical-slice.md`:

```markdown
### Scenario: pr_hierarchical slice close surfaces a review comment before merging

**Setup:** pr_hierarchical workspace mid-slice; demos pass; `sd pr_state` returns
`mergeStateStatus: CLEAN` AND an unresolved review thread from a review bot
(fixture `tests/fixtures/pr-view-with-review-comment.json` shape).

**Trigger:** user closes the slice (`close VS-1.1.1`).

**Expected behavior:** after harvest + worktree cleanup, the skill pushes the slice
branch, opens the slice→sprint PR, reads `sd pr_state`, and — because an unresolved
review comment exists despite green CI — SURFACES the comment and ASKS before
merging rather than auto-merging on the green check.

**Assertion (judge):** PASS iff the transcript shows the slice→sprint PR opened,
the unresolved review comment surfaced to the user, and NO `sd pr_merge` / `gh pr
merge` invocation before explicit user acknowledgment. FAIL if it merges on
`CLEAN` mergeStateStatus while the review thread is unresolved.
```

- [ ] **Step 3: Add a sprint scenario — sprint→main PR at sprint close**

Append to `evals/writing-sprint-retrospective.md`:

```markdown
### Scenario: pr_hierarchical sprint close opens the sprint→main PR

**Setup:** pr_hierarchical workspace; final slice of sprint 1.1 closed (its
slice→sprint PR merged); sprint retrospective just authored.

**Trigger:** user closes sprint (`close sprint 1.1`).

**Expected behavior:** the skill confirms slice PRs merged, pushes `sprint-1.1`,
opens a PR `sprint-1.1 → main`, then runs the pre-merge gate (reasons over CI +
review state, surfaces, asks).

**Assertion (judge):** PASS iff the transcript shows the sprint→main PR opened with
a body referencing the sprint retro, and the pre-merge gate run (state read +
surface + ask) before any merge. FAIL if it pushes directly to main or merges
without the gate.
```

- [ ] **Step 4: Verify the scenarios landed**

Run:
```bash
grep -q "pr_hierarchical pre-flight creates the branch hierarchy" scaffold-dev/evals/planning-vertical-slice.md \
  && grep -q "surfaces a review comment before merging" scaffold-dev/evals/closing-vertical-slice.md \
  && grep -q "opens the sprint→main PR" scaffold-dev/evals/writing-sprint-retrospective.md \
  && echo "EVALS-ADDED"
```
Expected: `EVALS-ADDED`.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/evals/planning-vertical-slice.md scaffold-dev/evals/closing-vertical-slice.md scaffold-dev/evals/writing-sprint-retrospective.md
git commit -m "test(scaffold-dev): eval scenarios for pr_hierarchical gates (#40)"
```

---

### Task 16: Full-suite green, version bump, README, tag prep

**Files:**
- Modify: `scaffold-dev/.claude-plugin/plugin.json`
- Modify: `scaffold-dev/.codex-plugin/plugin.json`
- Modify: `README.md` (line ~12 version table + line ~120 directory-tree comment)

- [ ] **Step 1: Run the FULL scaffold-dev suite**

Run: `cd scaffold-dev && bash run-tests.sh`
Expected: every `tests/test-*.sh` passes, 0 failures — including the existing suites (the `direct` path is unchanged) and the new `test-pr.sh`. If anything fails, fix before proceeding; do not bump versions over a red suite.

- [ ] **Step 2: Bump both plugin manifests to 0.2.0 (parity is enforced)**

Edit `scaffold-dev/.claude-plugin/plugin.json` line 3: `"version": "0.1.7"` → `"version": "0.2.0"`.
Edit `scaffold-dev/.codex-plugin/plugin.json` line 3: `"version": "0.1.7"` → `"version": "0.2.0"`.

- [ ] **Step 3: Verify the dual-publish parity guard passes**

Run: `bash tests/test-codex-dual-publish.sh`
Expected: PASS — `scaffold-dev codex manifest version (0.2.0) matches claude manifest`.

- [ ] **Step 4: Bump the README**

Edit `README.md`:
- Line ~12 (plugin version table): `| [`scaffold-dev`](./scaffold-dev/) | v0.1.7 |` → `v0.2.0`, and extend the description sentence with: ` Opt-in pr_hierarchical merge mode (work-item → slice → sprint → main) with agent-driven PR gates.`
- Line ~120 (directory-tree comment): `# scaffold-dev plugin (v0.1.7)` → `(v0.2.0)`.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/.claude-plugin/plugin.json scaffold-dev/.codex-plugin/plugin.json README.md
git commit -m "release(scaffold-dev): v0.2.0 — pr_hierarchical merge mode (#40)"
```

- [ ] **Step 6: Tag prep (DO NOT push/tag until the PR merges)**

The tag `scaffold-dev-v0.2.0` is created **after** this feature branch merges to main
(per the handoff's release mechanics). Note it for the merge step; do not tag the
feature branch.

---

## Self-Review (completed during planning)

**1. Spec coverage** — every SPEC section maps to a task:
- §3 topology + §3.1 ordering + §3.2 cleanup-decoupling → Tasks 11 (doc), 12 (planning ordering check), 13 (decoupled cleanup note).
- §4 config → Task 2 (`merge_mode` + naming helpers).
- §5 primitives → Tasks 2–8; §5.1 signature changes → Tasks 9–10.
- §6 skill changes → Tasks 12–14; §6.4 reference doc → Task 11.
- §7 pre-merge gate → Task 11 (doc) + exercised by Task 15 evals.
- §8 degradation/back-compat → Task 5 (`sd_remote_check`) + Tasks 9/10 (omitted-arg back-compat) + Task 12 (refuse-fast).
- §9 testing → Tasks 1–10 (unit) + Task 15 (evals) + Task 16 (full suite).
- §10 rollout → Task 16.

**2. Placeholder scan** — no TBD/TODO/"handle edge cases"; every code + content step is complete.

**3. Type/name consistency** — `sd_merge_mode`/`sd merge_mode`, `sd_branch_create_from`, `sd_branch_push`, `sd_remote_check`, `sd_pr_open`, `sd_pr_state`, `sd_pr_merge`, `slice/${vs_id}`, `sprint-${sprint_id}` used identically across the lib, tests, doc, and skill tasks. `sd_merge_work_item`'s 3rd arg and `sd_worktree_add`'s 5th arg are referenced consistently between definition (Tasks 9/10) and callers (Tasks 12/13).
