---
description: Create a git worktree on a new branch AND fork the current branch's scaffold state into it. Materializes CLAUDE.md inside the new worktree.
argument-hint: "<branch> [--path <p>]"
allowed-tools: Bash(bash:*)
---

Wraps \`git worktree add\` + state copy + CLAUDE.md generation. See SPEC \`§5.6\`.

> **Build status:** stub. Implementation lands in Phase G. The plugin
> registers this command on install but it is not yet functional.
