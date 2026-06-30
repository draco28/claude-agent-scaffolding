---
description: Drive an arbitrary PR through the full review-fix-merge loop — fetch findings, disposition each, drive fixes, re-review, defer leftovers, merge on ack. Usage: /work-pr <PR number or URL> [--repo-root DIR]
argument-hint: "<PR number or URL> [--repo-root DIR]"
allowed-tools: Bash(bash:*), Bash(sd:*), Bash(git:*), Bash(gh:*), Read, Write, Edit, Glob, Grep
---

# /work-pr

Wraps the `working-pull-request` skill — drives a single, arbitrary pull request to
mergeable: fetch every reviewer finding, disposition each, drive the fixes, re-review on
the new head, defer the non-blocking leftovers, and merge only on explicit ack.
Slice-decoupled and manifest-free; the invoking agent (Claude Code or Codex) runs the
whole loop itself. Bridge `$ARGUMENTS` into an env var the skill body reads (per
`feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "work-pr: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:working-pull-request)`** — pass the PR ref + optional
`--repo-root` parsed from `$SCAFFOLD_DEV_ARGS`. The skill body owns the manifest-free
preflight, the fetch, the disposition + fix loop (per `git-workflow.md` §7), the
deferral of leftovers, and the merge ask.
