---
description: Strict maintainability review of a branch or diff — abstraction quality, giant files, spaghetti growth, boundary leaks — pushed toward restructurings that delete complexity rather than rearrange it. One report, one disposition pass, no loop.
argument-hint: "[base-ref]"
allowed-tools: Bash(bash:*), Bash(git:*), Read, Glob, Grep, Task
disable-model-invocation: true
---

Parse the argument from `$ARGUMENTS` via the env-var bridge below — no positional `$1` /
`$2` / `$N`, which this harness substitutes at render time.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  BASE="${ARGS_FROM_CLAUDE:-}"
  if [ -z "$BASE" ]; then
    # No argument: resolve the repository default. Never assume "main" - on a
    # master/trunk repo that ref does not exist and the diff fails outright.
    # NOT the upstream of HEAD: that is usually this branch own remote ref, and
    # diffing a branch against itself yields an empty review that looks clean.
    BASE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
    for candidate in origin/main origin/master origin/trunk main master trunk; do
      [ -n "$BASE" ] && break
      git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1 && BASE="$candidate"
    done
  fi
  echo "deep-review: base=${BASE:-<unresolved>}"
'
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/deep-review/SKILL.md` end to end and follow it**, using
the base ref parsed above. If the bridge printed `<unresolved>`, say so and ask for an
explicit base rather than guessing one — a review scoped against the wrong ref reports on
commits the author never wrote.
`references/rubric.md` carries the standards, questions, flags, and remedies;
`references/disposition.md` carries the approval bar and the stopping rule.

This is a **quality** review, not a correctness or security review. It produces one report
and one disposition pass, and never re-reviews its own fixes.
