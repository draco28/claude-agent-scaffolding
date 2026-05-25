# Chain model vs. rejoin — what "handoff" actually means

A reference explainer for users (and skill bodies) on what the handoff escape valve is — and what it is NOT. Builds on SPEC §6b.4.

## The wrong mental model: "rejoin"

A natural assumption when reading the term "handoff" is: the source session pauses, the fork session runs the detour, then control "returns" to the source session — which picks up where it left off.

This is WRONG for scaffold-dev's handoff model. There is no literal rejoin.

Claude Code sessions are not designed to be paused and resumed across detours that themselves span multiple turns or hours. Even if a session could technically be left open in a terminal indefinitely, its context window has drifted away from the slice work by the time the detour completes. The "rejoin" would be returning to a session that's no longer authoritative about the slice's state — it's reading stale memory.

## The right mental model: chain

A handoff is a **markdown file** that another session reads. The original session is dead (or, equivalently, has paused indefinitely and won't be the one to resume). A NEW session reads the handoff and continues the work. The chain is:

```
Session A (source)
  writes  forward-handoff.md
  terminates

Session B (fork session — does the detour)
  reads   forward-handoff.md
  does the detour work
  writes  return-handoff.md
  terminates

Session C (new main thread)
  reads   forward-handoff.md AND return-handoff.md
  resumes the slice work
```

A, B, C are three DIFFERENT Claude sessions. The "thread" of work — the slice's progress — is mediated by files, not by session state. The files are the durable substrate; sessions are transient executors.

## Why this matters

Several skill-body behaviors flow from the chain model:

1. **The source session writes the handoff BEFORE terminating.** It can't write the handoff later. The skill body must complete the doc in-session, then surface to user: "handoff written; this session can terminate."

2. **The fork session must be a FRESH Claude session, not a subagent.** Per SPEC §6b.7 subagent boundary rule, subagents handle planned in-slice work. Handoff detours go OUT of the slice and need full toolset (including `git commit`, which subagents don't have). User opens a new terminal/session manually.

3. **The new main session is also FRESH.** When the user picks up the slice work again post-detour, they open another new session — not the original source session. The original is gone or stale; the new session bootstraps from the two handoff docs.

4. **No session-state IPC.** The skill body does NOT try to pause/resume Claude sessions, communicate via inbox/outbox files between LIVE sessions, or any session-to-session mechanism. Files only. Files at rest, read by whoever opens the next session.

## Comparison: handoff vs. subagent

| Aspect | Subagent (implementer-agent) | Handoff |
|---|---|---|
| Lifecycle | Spawned by parent within same orchestrator session; returns to parent | Independent session; reads files on disk; no parent |
| Communication | Task tool prompt + structured return value | Markdown files at `.workspace/handoffs/` |
| Tool boundary | Limited (no commit, no Task) | Full Claude Code session (everything) |
| Scope | Planned work-item inside slice | Anything OUT of planned slice work |
| Concurrency model | Parent waits for child return (within session) | Chain — strictly sequential across sessions |
| Cleanup | Subagent dies on return | Handoff file persists until sprint-close cleanup |

The boundary rule (SPEC §6b.7): subagent = planned work-item inside slice; handoff = anything taking you out of planned slice work. Subagents never invoke `handing-off-session`. Orchestrator may invoke either.

## What "rejoin" would have required (and why we rejected it)

A literal rejoin would need:
- Claude Code session pause/resume primitive (does not exist).
- OR: an explicit session-state save/load (would be enormous tokens to serialize all context).
- OR: a "supervisor" outside Claude Code coordinating sessions (out of scope; this is a plugin, not a meta-orchestrator).

The chain model needs:
- A directory where files can be written and read (`.workspace/handoffs/`).
- A skill body that writes handoffs and reads them in fresh sessions.
- User discipline to open new sessions at the right moments.

The chain model is strictly weaker than rejoin (it requires more user discipline; it cannot preserve every detail) but it's strictly cheaper (no special primitives) and strictly more robust (file at rest survives any session crash).

## How sessions "find" each other

Sessions don't find each other directly — they find the **files**. Discovery:

1. The skill body emits filenames the user can `ls` in their terminal.
2. The naming pattern (`<scope>-<purpose>-<short-id>.md`) makes related handoffs co-locate alphabetically.
3. The return uses the SAME short-id as its forward, so `ls .workspace/handoffs/vs-3.2-bugfix-auth-*` returns the pair.
4. The user, when opening a new session, prompts: "read [path-to-handoff]" — explicitly naming the file.

There is no automated session discovery. Users specify which handoff to consume.

## Implications for the user

- You will have many `.workspace/handoffs/*.md` files mid-sprint. That's normal.
- Closing a slice or sprint cleans most up (per SPEC §6b.6); only the carry-forward survives.
- If you ever wonder "what was I doing?" — read the most recent handoff. It's the most recent codified state outside memory bank.
- The handoffs dir is gitignored — these files don't sync. Per-machine. That's intentional (they capture session-specific context that loses meaning on another machine).

## Implications for the skill body

- Never claim "I will resume your work" or "control will return to your original session." Wrong model.
- Always write the handoff completely before signalling done. The source session cannot revise the handoff after termination.
- For forward handoffs that expect a return: section 10 must template the return handoff so the fork session has a clear shape to fill.
- For return handoffs: section 8 ("next intended action") must point at the slice resumption — naming the trigger phrase or skill the new main session should invoke first.

## When the chain breaks

Three failure modes, all user-discipline issues in v0.1:

1. **Source writes forward but no one reads it.** Handoff file exists; no fork session opens. Detected: user notices the orphan in `.workspace/handoffs/`. Resolution: open a session, read, execute.

2. **Fork session does the work but forgets the return.** Detour landed, but no return doc. Detected: new main session reads only the forward, has to infer state from canonical git log. Resolution: best-effort; can re-author the return retroactively if the fork session is still alive.

3. **New main session ignores the return.** Forward + return both exist, but the new main session only reads the forward — proceeds with stale state. Detected: confusion in the new session ("why does main have these commits I don't recognize?"). Resolution: read the return and reconcile.

v0.2 may add detection (orphan-forward warnings, missing-return warnings). v0.1 is user-discipline.
