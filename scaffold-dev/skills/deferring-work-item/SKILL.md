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

```bash
sd remote_check || exit 1   # surfaces the actionable error verbatim; no silent fallback
```

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

```bash
sd issue_list   # raw JSON: number,title,body,labels
```

Read the JSON and JUDGE whether any open issue already covers this deferral. If one
clearly does, surface it ("already tracked — see #N") and offer to skip filing +
just add/confirm the `[TD]` line. Do NOT string-match mechanically — reason about it.

## 4. File the issue

Write the composed body to a temp file, then:

```bash
sd issue_create "<title>" "<body-file>" --label tech-debt
```

Capture the `#N` from the echoed URL/number.

## 5. Append the lean index line

Append one line to the memory-bank `tech-debt.md` (resolve its path via the manifest's
memory-bank location; **append-or-create** — if the file is absent, create it with the
header from scaffold-onboard's template, then append):

```
- [TD] <short desc> → #<N>
```

No prose duplication of the issue body — the index is pointers only.

## 6. Confirm

Tell the user: filed issue #N (title) in <repo>, indexed in tech-debt.md. Done.

## Anti-patterns
- **Never** invoke this from the implementer-agent subagent (no gh access; orchestrator-only).
- **Never** duplicate the issue body into the memory bank — the index is one line.
- **Never** mechanically string-match for de-dup — judge it.
