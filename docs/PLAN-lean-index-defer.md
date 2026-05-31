# Lean-index memory bank + /defer + blocker-recall — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an agent-driven "defer → lean-index → recall" loop to scaffold-dev (#33 A+B): non-blocking gaps become GitHub issues in the project repo + a one-line `[TD] …→#N` pointer in a dedicated memory-bank index, filed by the orchestrator agent (interactive `/defer` or a round-close sweep), with two-layer blocker-recall.

**Architecture:** Two thin mechanical `gh` primitives (`sd_issue_create`, `sd_issue_list`) join `lib/pr.sh`; ALL decisions (which deferrals merit issues, issue content, de-dup, recall matching) are made by the orchestrator agent — there is NO deterministic `report.md` parser. A new `/defer` command + `deferring-work-item` skill own the interactive path; `planning-vertical-slice` §8.7 owns the round-close sweep; `executing-work-item` §3.4 + `planning-vertical-slice` §8.4 own blocker-recall. scaffold-onboard seeds a `tech-debt.md` memory-bank template.

**Tech Stack:** Bash 3.2+, `jq`, `git`, `gh`; the `bin/sd` dispatcher (auto-sources `lib/*.sh`); `tests/test-*.sh` auto-discovery + the `gh` PATH-shim from #40; markdown skills/commands/templates; LLM-judge evals.

**Authoritative spec:** `docs/SPEC-lean-index-defer.md`. Read it before starting.

**Branch:** continue on `feat/pr-hierarchical-merge-mode` (verify: `git rev-parse --abbrev-ref HEAD`). This stacks on #40 + #44 for the combined v0.2 PR. All paths relative to repo root `/Volumes/master_ssd/projects/claude-agent-scaffolding`.

**Binding principle:** the agent decides; bash only does `gh`/file I/O. Do not introduce any deterministic parser of `report.md` deferral content.

---

## Task 1: Extend the `gh` shim + issue-list fixture

**Files:**
- Modify: `scaffold-dev/tests/fixtures/gh-shim/gh`
- Create: `scaffold-dev/tests/fixtures/issue-list.json`

- [ ] **Step 1: Add `issue create` / `issue list` cases to the shim**

In `scaffold-dev/tests/fixtures/gh-shim/gh`, add two cases to the `case "${1:-} ${2:-}" in` block (place them alongside the existing `pr create` / `pr view` cases, before the `*)` catch-all):

```bash
  "issue create") echo "${GH_SHIM_ISSUE_URL:-https://github.com/test/repo/issues/7}"; exit 0 ;;
  "issue list")
    if [[ -n "${GH_SHIM_ISSUE_LIST_JSON:-}" && -f "$GH_SHIM_ISSUE_LIST_JSON" ]]; then
      cat "$GH_SHIM_ISSUE_LIST_JSON"
    else
      echo '[]'
    fi
    exit 0 ;;
```

- [ ] **Step 2: Create the canned issue-list fixture**

`scaffold-dev/tests/fixtures/issue-list.json`:

```json
[
  {
    "number": 7,
    "title": "Tune retry backoff in the ingest client",
    "body": "Deferred from VS-1.1.1 — retry uses a fixed 1s sleep; should be exponential. Non-blocking.",
    "labels": [{"name": "tech-debt"}]
  }
]
```

- [ ] **Step 3: Verify the shim still works**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: PASS (the existing 26 assertions — the shim change is additive). Also sanity-check the new cases:
`GH_SHIM_LOG=/dev/stdout tests/fixtures/gh-shim/gh issue create --title x --body-file /dev/null` → prints `issue create …` to the log then the canned `issues/7` URL.

- [ ] **Step 4: Commit**

```bash
git add scaffold-dev/tests/fixtures/gh-shim/gh scaffold-dev/tests/fixtures/issue-list.json
git commit -m "test(scaffold-dev): extend gh-shim + issue-list fixture for #33"
```

---

### Task 2: `sd_issue_create`

**Files:**
- Modify: `scaffold-dev/lib/pr.sh` (append function)
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests (append to `test-pr.sh` + register)**

```bash
# 19. issue_create echoes the issue url and calls gh with the right args
test_issue_create() {
  echo "test_issue_create:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo "deferred: tune backoff" > "$body"
  local out; out="$(sd_issue_create "Tune retry backoff" "$body" --label tech-debt 2>/dev/null)"
  assert_contains "echoes issue url" "issues/7" "$out"
  assert_file_contains "$GH_SHIM_LOG" "issue create --title Tune retry backoff --body-file"
  assert_file_contains "$GH_SHIM_LOG" "--label tech-debt"
}
```

Register `test_issue_create` above `sd_test_summary`.

- [ ] **Step 2: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_issue_create` unbound.

- [ ] **Step 3: Append the implementation to `lib/pr.sh`**

```bash
# sd_issue_create <title> <body-file> [extra gh args...] — wraps gh issue create
# (run from canonical so gh resolves the repo from origin). Echoes gh's stdout
# (issue url/number). rc 1 if gh absent or the create fails.
sd_issue_create() {
  local title="$1" body_file="$2"; shift 2
  local canonical out
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_issue_create: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_issue_create: 'gh' not in PATH."
    return 1
  fi
  if ! out="$(cd "$canonical" && gh issue create --title "$title" --body-file "$body_file" "$@" 2>&1)"; then
    sd_log_error "sd_issue_create: gh issue create failed: $out"
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
git commit -m "feat(scaffold-dev): sd_issue_create (gh issue create wrapper) (#33)"
```

---

### Task 3: `sd_issue_list`

**Files:**
- Modify: `scaffold-dev/lib/pr.sh`
- Test: `scaffold-dev/tests/test-pr.sh`

- [ ] **Step 1: Write the failing tests (append + register)**

```bash
# 20. issue_list passes gh's JSON through (for agent recall/de-dup)
test_issue_list() {
  echo "test_issue_list:"
  _setup_pr_workspace
  export GH_SHIM_ISSUE_LIST_JSON="$HERE/fixtures/issue-list.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_issue_list 2>/dev/null)"
  assert_eq "first issue number" "7" "$(echo "$json" | jq -r '.[0].number')"
  assert_eq "first issue label" "tech-debt" "$(echo "$json" | jq -r '.[0].labels[0].name')"
}

# 21. issue_list returns empty array when no issues
test_issue_list_empty() {
  echo "test_issue_list_empty:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_issue_list 2>/dev/null)"
  assert_eq "empty list" "0" "$(echo "$json" | jq -r 'length')"
}
```

Register both. (Each test sets/relies on `GH_SHIM_ISSUE_LIST_JSON`; `_setup_pr_workspace` does not unset it, so `test_issue_list_empty` must run from a fresh setup — it does, and the shim defaults to `[]` when the var points nowhere. To be safe, the empty test does NOT set the var and `_setup_pr_workspace` runs first; add `unset GH_SHIM_ISSUE_LIST_JSON` to the `_setup_pr_workspace` reset line in Step 2 below.)

- [ ] **Step 2: Add `GH_SHIM_ISSUE_LIST_JSON` to the shim-env reset**

In `tests/test-pr.sh`, find the `_setup_pr_workspace` reset line (added in #40 Task 1):
```bash
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON
```
Change it to also unset the issue vars:
```bash
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON GH_SHIM_ISSUE_LIST_JSON GH_SHIM_ISSUE_URL
```

- [ ] **Step 3: Run to verify failure**

Run: `cd scaffold-dev && bash tests/test-pr.sh`
Expected: FAIL — `sd_issue_list` unbound.

- [ ] **Step 4: Append the implementation to `lib/pr.sh`**

```bash
# sd_issue_list [extra gh args...] — emit open issues as JSON for the agent to
# reason over (blocker-recall / de-dup). NO interpretation here. rc 1 if gh absent.
sd_issue_list() {
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_issue_list: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_issue_list: 'gh' not in PATH."
    return 1
  fi
  (cd "$canonical" && gh issue list --state open --json number,title,body,labels "$@")
}
```

- [ ] **Step 5: Run to verify pass + dispatcher exposes both**

Run: `cd scaffold-dev && bash tests/test-pr.sh` (expect PASS)
Run: `./bin/sd --list | grep -E 'issue_create|issue_list'` → expect both `issue_create` and `issue_list`.

- [ ] **Step 6: Commit**

```bash
git add scaffold-dev/lib/pr.sh scaffold-dev/tests/test-pr.sh
git commit -m "feat(scaffold-dev): sd_issue_list (gh issue list JSON passthrough) (#33)"
```

---

### Task 4: `tech-debt.md` memory-bank template (scaffold-onboard)

**Files:**
- Create: `scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl`
- Modify: `scaffold-onboard/templates/memory-bank/index.md.tmpl`
- Modify: `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md`

- [ ] **Step 1: Create the template**

`scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl`:

```markdown
# Tech debt — lean index

> Lean pointer index, NOT a prose store. Each line is ONE deferred item pointing
> at its GitHub issue; the depth lives in the issue, not here.
>
> Format: `- [TD] <short description> → #<issue-no>`
>
> Filed by scaffold-dev's `/defer` command or the round-close auto-file sweep
> (#33). Blocker-recall reads this file before treating a gap as a fresh defect.

<!-- [TD] entries below — one line each, newest at the bottom -->
```

- [ ] **Step 2: Add the file to the memory-bank index template**

Read `scaffold-onboard/templates/memory-bank/index.md.tmpl` first to match its row format. Append a row for `tech-debt.md` in the same style as the existing file rows (e.g. after the `08-governance.md` row). Use this description text:
`Lean tech-debt index — [TD] <desc> → #<issue> pointers to deferred GitHub issues (#33).`

- [ ] **Step 3: Wire the file into `scaffolding-memory-bank`**

Read `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` and find where it enumerates the memory-bank files it renders (the 00–08 + index + WORKFLOW set). Add `tech-debt.md` (rendered from `tech-debt.md.tmpl`) to that set, matching the existing rendering pattern. It is an **unnumbered** file (like `WORKFLOW.md`), seeded with only its header (no `[TD]` entries). Add a one-line note that scaffold-dev append-or-creates entries into it at defer/round-close time.

- [ ] **Step 4: Verify scaffold-onboard suite still green**

Run: `cd scaffold-onboard && bash run-tests.sh` (NOTE: scaffold-onboard suites are SLOW — 55–75s+ each; be patient, generous timeout, do not assume a hang). Expected: all green. If a test asserts an exact memory-bank file count/list, update that assertion to include `tech-debt.md` (it's a real expected change, not a workaround).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl scaffold-onboard/templates/memory-bank/index.md.tmpl scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md
git commit -m "feat(scaffold-onboard): seed tech-debt.md lean-index memory-bank template (#33)"
```

---

### Task 5: `/defer` command + `deferring-work-item` skill

**Files:**
- Create: `scaffold-dev/commands/defer.md`
- Create: `scaffold-dev/skills/deferring-work-item/SKILL.md`

- [ ] **Step 1: Create the command (mirrors the established `$ARGUMENTS` bridge)**

`scaffold-dev/commands/defer.md`:

````markdown
---
description: Defer a non-blocking gap — file a project-repo GitHub issue + add a lean [TD] index line. Usage: /defer <what to defer>
argument-hint: "<short description of the deferred item>"
allowed-tools: Bash(bash:*), Bash(sd:*), Read, Write, Edit, Glob, Grep
---

# /defer

Wraps the `deferring-work-item` skill — files a templated GitHub issue in the
project (canonical) repo and appends a `[TD] …→#N` line to the memory-bank
`tech-debt.md`. Bridge `$ARGUMENTS` into an env var the skill body reads (per
`feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "defer: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:deferring-work-item)`** — pass the deferral description
parsed from `$SCAFFOLD_DEV_ARGS`. The skill body owns the remote/gh pre-flight,
issue composition, de-dup, filing, and index append.
````

- [ ] **Step 2: Create the skill body**

`scaffold-dev/skills/deferring-work-item/SKILL.md`:

```markdown
---
name: deferring-work-item
description: File a non-blocking gap as a project-repo GitHub issue and record a lean [TD] index pointer. Use when the user says `/defer`, "defer this", "file this as tech debt", "track this for later", or when the orchestrator captures a deferral at round-close. Orchestrator-side only — never invoked from the implementer-agent subagent (it has no gh access).
---

# deferring-work-item

Turn a non-blocking gap into (1) a GitHub issue in the project (canonical) repo and
(2) a single `[TD] <desc> → #N` line in the memory-bank `tech-debt.md`. The DEPTH
lives in the issue; the memory bank stays a lean index. This skill is **agent-driven**:
YOU compose the issue and decide de-dup — there is no deterministic parser.

## 1. Pre-flight (refuse fast)

This skill files to GitHub via `gh`. Guard first:

\```bash
sd remote_check || exit 1   # surfaces the actionable error verbatim; no silent fallback
\```

`sd remote_check` verifies canonical has an `origin` remote AND `gh` is authenticated.
If it fails, surface the message and STOP — do not write anything.

## 2. Gather the deferral (judgment, not a rigid form)

From `$SCAFFOLD_DEV_ARGS` (or the conversation) you have a short description. Elaborate,
asking the user only for what's genuinely missing, into a coherent issue:

- **What** — the gap/debt in one line (the issue title).
- **Why deferred** — why it's non-blocking now.
- **Unblock condition** — what would make this worth doing.
- **Trace ids** — any FR/NFR/Backlog/spec refs the user mentions (optional).

Compose the body with judgment; do not demand every field if the user didn't give it.

## 3. De-dup (agent judgment)

Before filing, check for an existing open issue that already covers this:

\```bash
sd issue_list   # raw JSON: number,title,body,labels
\```

Read the JSON and JUDGE whether any open issue already covers this deferral. If one
clearly does, surface it ("already tracked — see #N") and offer to skip filing +
just add/confirm the `[TD]` line. Do NOT string-match mechanically — reason about it.

## 4. File the issue

Write the composed body to a temp file, then:

\```bash
sd issue_create "<title>" "<body-file>" --label tech-debt
\```

Capture the `#N` from the echoed URL/number.

## 5. Append the lean index line

Append one line to the memory-bank `tech-debt.md` (resolve its path via the manifest's
memory-bank location; **append-or-create** — if the file is absent, create it with the
header from scaffold-onboard's template, then append):

\```
- [TD] <short desc> → #<N>
\```

No prose duplication of the issue body — the index is pointers only.

## 6. Confirm

Tell the user: filed issue #N (title) in <repo>, indexed in tech-debt.md. Done.

## Anti-patterns
- **Never** invoke this from the implementer-agent subagent (no gh access; orchestrator-only).
- **Never** duplicate the issue body into the memory bank — the index is one line.
- **Never** mechanically string-match for de-dup — judge it.
```

(Note: the `\``` fences above are escaped in this plan; write them as normal triple-backtick fences in the actual file.)

- [ ] **Step 3: Verify frontmatter + dispatcher**

Run: `cd scaffold-dev && bash tests/test-render.sh` and `bash run-tests.sh` — expect green (a new skill/command shouldn't break suites). Confirm the skill's YAML frontmatter parses (the `test-codex-dual-publish.sh` frontmatter check from #35 covers this — run `cd /Volumes/master_ssd/projects/claude-agent-scaffolding && bash tests/test-codex-dual-publish.sh`, expect PASS).

- [ ] **Step 4: Commit**

```bash
git add scaffold-dev/commands/defer.md scaffold-dev/skills/deferring-work-item/
git commit -m "feat(scaffold-dev): /defer command + deferring-work-item skill (#33)"
```

---

### Task 6: Round-close auto-file + report Deferrals wiring

**Files:**
- Modify: `scaffold-dev/skills/planning-vertical-slice/SKILL.md` (§8.7 round-complete)
- Modify: `scaffold-dev/skills/executing-work-item/SKILL.md` (§6 Deferrals wording)

- [ ] **Step 1: Add the round-close auto-file step to `planning-vertical-slice` §8.7**

Read §8.7 ("Round-complete handoff") first. Insert a new step BEFORE the "Round K complete…" surface prompt, so the sequence becomes: update README → **auto-file deferrals** → surface round-complete. Add:

````markdown
**Deferral auto-file (agent-driven, #33).** Before surfacing round-complete, review each work item's `report.md` **"Deferrals"** section (you already read these reports during §8.4–8.5 — re-read the Deferrals section). This is judgment, not parsing:

1. For each deferral, DECIDE whether it warrants a tracked GitHub issue (skip trivia and anything already tracked — use `sd issue_list` and judge for de-dup).
2. Surface the proposed issues to the user as a single batch for a quick confirm (title + one-line why each). Never file silently.
3. For each confirmed item, file + index via the same logic as `/defer`: `Skill(scaffold-dev:deferring-work-item)` (or inline `sd issue_create` + append the `[TD] …→#N` line). 

If `sd remote_check` fails (no gh/remote), SKIP filing — note that the deferrals remain in the reports' Deferrals sections for later — and proceed to round-complete WITHOUT blocking. There is **no deterministic parser** of the Deferrals section; you read and judge.
````

- [ ] **Step 2: Update `executing-work-item` §6 Deferrals wording**

In `executing-work-item/SKILL.md` §6 (the "Deferrals" bullet in the 9-section list), append one sentence so it reads (keep the existing text, add the trailing sentence):

> 6. **Deferrals** — any nice-to-have gaps from §3.4 that did not block execution but represent open questions worth re-surfacing; any AC where you took a defensible default but the spec is silent. **The orchestrator reads this section at round-close (`planning-vertical-slice` §8.7) and decides which entries to file as project-repo GitHub issues (#33) — write each deferral as a clear one-line prose note (what + why non-blocking) so that decision is well-informed.**

- [ ] **Step 3: Verify**

Run: `cd scaffold-dev && bash run-tests.sh` (expect green — these are doc edits; no deterministic test should break).
Run: `command grep -q "Deferral auto-file" scaffold-dev/skills/planning-vertical-slice/SKILL.md && command grep -q "decides which entries to file" scaffold-dev/skills/executing-work-item/SKILL.md && echo WIRED` → expect `WIRED`.

- [ ] **Step 4: Commit**

```bash
git add scaffold-dev/skills/planning-vertical-slice/SKILL.md scaffold-dev/skills/executing-work-item/SKILL.md
git commit -m "feat(scaffold-dev): round-close deferral auto-file + report Deferrals wiring (#33)"
```

---

### Task 7: Blocker-recall (two layers)

**Files:**
- Modify: `scaffold-dev/skills/executing-work-item/SKILL.md` (§3.4 — layer 1)
- Modify: `scaffold-dev/skills/planning-vertical-slice/SKILL.md` (§8.4 — layer 2)

- [ ] **Step 1: Layer 1 — implementer reads the local index before declaring a gap (§3.4)**

In `executing-work-item/SKILL.md` §3.4 ("Scan for spec ambiguity"), add a paragraph at the END of the section (before §3.5):

````markdown
**Blocker-recall (local, #33).** Before building a gap entry for an ambiguity that reads like "X is missing / why wasn't this done?", READ the memory-bank `tech-debt.md` (lean `[TD] …→#N` index; resolve its path via the manifest memory-bank location). If you JUDGE that the gap is already a known/tracked deferral, surface it in your return as "known — see #N" rather than as a fresh unresolved gap. This reads the local file only (you have no `gh` access). It is advisory recall — a genuine new blocker is still a blocker; you are only avoiding re-deriving something already tracked.
````

- [ ] **Step 2: Layer 2 — orchestrator consults open issues on a gaps-mode return (§8.4)**

In `planning-vertical-slice/SKILL.md` §8.4 (process returns), find the `mode: gaps-surfaced` handling and add, before re-dispatch/escalation:

````markdown
**Blocker-recall (issues, #33).** On a `gaps-surfaced` return, before re-dispatching or escalating to the §12.2 menu, run `sd issue_list` and JUDGE whether an open issue already covers the surfaced gap. If one does, surface "known — see #N" and fold that into the clarification appended to the handoff (so the re-dispatched implementer proceeds informed) rather than treating the gap as novel. Judgment, not string-matching; skip silently if `sd remote_check` fails.
````

- [ ] **Step 3: Verify**

Run: `command grep -q "Blocker-recall (local" scaffold-dev/skills/executing-work-item/SKILL.md && command grep -q "Blocker-recall (issues" scaffold-dev/skills/planning-vertical-slice/SKILL.md && echo RECALL-WIRED` → expect `RECALL-WIRED`.
Run: `cd scaffold-dev && bash run-tests.sh` (expect green).

- [ ] **Step 4: Commit**

```bash
git add scaffold-dev/skills/executing-work-item/SKILL.md scaffold-dev/skills/planning-vertical-slice/SKILL.md
git commit -m "feat(scaffold-dev): two-layer blocker-recall (local index + open issues) (#33)"
```

---

### Task 8: Eval scenarios (agent decisions)

**Files:**
- Create: `scaffold-dev/evals/deferring-work-item.md`
- Modify: `scaffold-dev/evals/planning-vertical-slice.md`
- Modify: `scaffold-dev/evals/executing-work-item.md`

- [ ] **Step 1: New eval for `deferring-work-item`**

Create `scaffold-dev/evals/deferring-work-item.md`. READ an existing eval (e.g. `evals/closing-vertical-slice.md`) first to match the house format (Purpose / Harness / Scenarios with Setup/Trigger/Expected behavior/Assertion / Pass-fail criteria / Out-of-scope). Include two scenarios:

```markdown
### S1 — /defer files an issue + lean index line

**Setup:** dual-repo workspace; canonical has an `origin` remote; `gh` authenticated (harness may stub gh); `tech-debt.md` present (empty index). No open issue matches the deferral.

**Trigger:** `/defer retry backoff in the ingest client is a fixed 1s sleep; should be exponential`

**Expected behavior:** the skill runs `sd remote_check`, composes a coherent issue (title + why-deferred + unblock-condition), runs `sd issue_create`, captures #N, and appends exactly one `- [TD] … → #N` line to `tech-debt.md`. No prose body duplicated into the memory bank.

**Assertion (judge):** PASS iff the transcript shows remote_check before any file write, a single `sd issue_create` (not a raw `gh` call bypassing the helper), exactly one new `[TD] …→#N` line in `tech-debt.md`, and NO multi-line issue-body copy in the memory bank. FAIL if it files without remote_check, or duplicates the body into tech-debt.md.

### S2 — /defer de-dups against an existing open issue

**Setup:** identical, but `sd issue_list` returns an open issue (#7) that already covers the same retry-backoff debt (fixture `tests/fixtures/issue-list.json` shape).

**Trigger:** `/defer the ingest retry backoff is still fixed — should be exponential`

**Expected behavior:** the skill reads `sd issue_list`, JUDGES that #7 already covers this, surfaces "already tracked — see #7", and offers to skip filing rather than opening a duplicate.

**Assertion (judge):** PASS iff the transcript surfaces #7 as the existing match and does NOT call `sd issue_create` for a duplicate. FAIL if it files a second issue for the same debt.
```

Plus a short Purpose/Harness/Pass-fail/Out-of-scope wrapper matching the house style.

- [ ] **Step 2: Round-close scenario in `planning-vertical-slice.md`**

Append (numbering follows the file — it has S1–S5 after #40; add **S6**):

```markdown
### S6 — round-close auto-files a report Deferral

**Setup:** pr-mode-agnostic workspace; a round with 2 work items both verified+merged; one `report.md` has a "Deferrals" section noting a non-blocking gap; `gh` authenticated; no open issue covers it.

**Trigger:** the orchestrator reaches round-complete (§8.7).

**Expected behavior:** before surfacing "Round K complete", the orchestrator reads the reports' Deferrals, JUDGES that the gap merits an issue, surfaces it for a quick confirm, then files via `sd issue_create` + appends a `[TD] …→#N` line. No deterministic parser is used (the agent reads the prose).

**Assertion (judge):** PASS iff a deferral is surfaced for confirmation, filed via `sd issue_create` after confirm, and indexed with one `[TD]` line — AND the orchestrator did not silently file without surfacing. FAIL if it files silently, or if round-complete is surfaced without considering the Deferrals.
```

- [ ] **Step 3: Blocker-recall scenario in `executing-work-item.md`**

Append (the file has S1–S4; add **S5**):

```markdown
### S5 — blocker-recall surfaces a known [TD] instead of a fresh gap

**Invocation mode:** Mode B (subagent dispatch).

**Setup:** a work item whose spec has an ambiguity that matches an existing `tech-debt.md` line (`- [TD] ingest retry backoff is fixed → #7`).

**Trigger:** dispatch the implementer-agent on the work item.

**Expected behavior:** during §3.4, the implementer reads `tech-debt.md`, JUDGES the ambiguity is already tracked, and surfaces "known — see #7" in its return rather than presenting it as a fresh blocking gap. It uses NO `gh` (local file read only).

**Assertion (judge):** PASS iff the return references the existing #7 (or the `[TD]` line) for that ambiguity and does NOT treat it as a novel unresolved gap; AND no `gh` invocation appears in the implementer's tool-call log. FAIL if it re-derives the gap as new, or if it attempts a `gh` call.
```

- [ ] **Step 4: Verify scenarios landed**

Run: `command grep -q "S1 — /defer files an issue" scaffold-dev/evals/deferring-work-item.md && command grep -q "round-close auto-files a report Deferral" scaffold-dev/evals/planning-vertical-slice.md && command grep -q "blocker-recall surfaces a known" scaffold-dev/evals/executing-work-item.md && echo EVALS-ADDED` → expect `EVALS-ADDED`.
Also update the "GREEN when all N scenarios PASS" count lines in `planning-vertical-slice.md` (5→6) and `executing-work-item.md` (4→5) and ensure the new `deferring-work-item.md` has its own count line.

- [ ] **Step 5: Commit**

```bash
git add scaffold-dev/evals/deferring-work-item.md scaffold-dev/evals/planning-vertical-slice.md scaffold-dev/evals/executing-work-item.md
git commit -m "test(scaffold-dev): eval scenarios for /defer, round-close auto-file, blocker-recall (#33)"
```

---

### Task 9: scaffold-onboard 0.3.8 bump, README, full-suite gate

**Files:**
- Modify: `scaffold-onboard/.claude-plugin/plugin.json`
- Modify: `scaffold-onboard/.codex-plugin/plugin.json`
- Modify: `README.md`

- [ ] **Step 1: Run BOTH full suites**

Run: `cd /Volumes/master_ssd/projects/claude-agent-scaffolding/scaffold-dev && bash run-tests.sh` → all green (incl. extended `test-pr.sh`).
Run: `cd /Volumes/master_ssd/projects/claude-agent-scaffolding/scaffold-onboard && bash run-tests.sh` → all green (SLOW; be patient).
If anything fails, fix before proceeding; do not bump over a red suite.

- [ ] **Step 2: Bump scaffold-onboard 0.3.7 → 0.3.8 (both manifests)**

Edit `scaffold-onboard/.claude-plugin/plugin.json` line 3: `"version": "0.3.7"` → `"version": "0.3.8"`.
Edit `scaffold-onboard/.codex-plugin/plugin.json` line 3: `"version": "0.3.7"` → `"version": "0.3.8"`.
(0.3.7 was set by #44 earlier on this branch; this is the next patch.)

- [ ] **Step 3: Verify dual-publish parity**

Run: `cd /Volumes/master_ssd/projects/claude-agent-scaffolding && bash tests/test-codex-dual-publish.sh` → PASS, incl. `scaffold-onboard codex manifest version (0.3.8) matches claude manifest`.

- [ ] **Step 4: Update README**

Edit `README.md`:
- scaffold-onboard version-table row: `v0.3.7` → `v0.3.8`; append to its description: `Seeds a lean tech-debt.md index for scaffold-dev's /defer loop (#33).`
- scaffold-dev version-table row: keep `v0.2.0`, but update its skill/command counts if the row states them (it says "9 skills, 4 slash commands" — now 10 skills, 5 commands with `deferring-work-item` + `/defer`); append `Adds /defer + blocker-recall (#33).`
- Directory-tree comment: bump any scaffold-onboard version mention to v0.3.8.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/.claude-plugin/plugin.json scaffold-onboard/.codex-plugin/plugin.json README.md
git commit -m "release(scaffold-onboard): v0.3.8 — tech-debt.md template for #33; README counts"
```

- [ ] **Step 6: Tag note**

Do NOT tag. The combined PR (#40 + #44 + #33) merges first; then `scaffold-dev-v0.2.0` + `scaffold-onboard-v0.3.8` tags are applied on main per the release mechanics.

---

## Self-Review (completed during planning)

**1. Spec coverage:**
- SPEC §3 split (agent decides, bash = `gh`/IO) → Tasks 2/3 (mechanical primitives), 5/6/7 (all decisions in skill prose, explicit "no parser" / "judge" language).
- §4 `/defer` interactive → Task 5.
- §5 round-close auto-file + report Deferrals → Task 6.
- §6 `tech-debt.md` index (append-or-create + scaffold-onboard seed) → Task 4 (seed) + Task 5 §5 / Task 6 (append-or-create).
- §7 blocker-recall layers 1+2 → Task 7.
- §3 primitives `sd_issue_create`/`sd_issue_list` → Tasks 2/3; shim/fixtures → Task 1.
- §8 manifest routing/degradation → Task 5 §1 + Task 6 (skip-on-remote-fail).
- §9 testing (primitives via shim; decisions via evals) → Tasks 1–3 + Task 8.
- §10 rollout (scaffold-onboard 0.3.8) → Task 9.
- §2 scope guard C/D/E/F out → nothing implements them (correct).

**2. Placeholder scan:** none — every code/content step is complete. (The escaped fences in Task 5 Step 2 are intentional, with a note to write real backticks.)

**3. Type/name consistency:** `sd_issue_create`/`sd issue_create`, `sd_issue_list`/`sd issue_list`, `sd_remote_check`/`sd remote_check`, `tech-debt.md`, `[TD] <desc> → #N`, `deferring-work-item`, `/defer` used identically across primitives (Tasks 2/3), command/skill (Task 5), wiring (Tasks 6/7), and evals (Task 8). The `GH_SHIM_ISSUE_LIST_JSON`/`GH_SHIM_ISSUE_URL` env vars are defined in the shim (Task 1) and reset in `_setup_pr_workspace` (Task 3 Step 2) before use (Task 3 tests).
