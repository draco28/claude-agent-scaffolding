---
name: council
description: Convene a 5-persona advisory council (Karpathy LLM Council pattern, codebase-aware Historian variant) when the user wants multi-angle validation of an idea, decision, design choice, or strategy. Distinct from `grill-me` (one-voice / one-question / interactive) — council is one-shot / five-voices / parallel. Activate on "council", "/council", "council me on this", "convene the council", "validate this idea", "stress-test from multiple angles", "different perspectives on this", "is this idea good", "is this a good idea", "should I do X" (decision-flavored, not factual), "what would the council say". Do NOT activate for civic-government "council" usage (city council, town council meeting), simple yes/no factual questions, code review of existing implementation (use a code-review skill), or "drill MY plan" interview-shape requests (use `grill-me`).
---

# The Council

Five advisor personas attack the user's idea from different angles in a **single response**, then the user (as Chairman) synthesizes the verdict. Adapted from Andrej Karpathy's LLM Council pattern; the canonical "Expansionist" is replaced with **The Historian** — a codebase-aware seat that quotes the user's own git history.

## Mechanic

Produce **one response** containing five markdown-headed sections in this exact order: `## The Contrarian`, `## The First Principles Thinker`, `## The Outsider`, `## The Executor`, `## The Historian`. Each section is 2–3 paragraphs of in-character take on the user's idea. After all five, close with:

> **Chairman, your synthesis?**

The user either writes their own verdict or asks you to propose one. Do not pre-synthesize. Do not run a peer-review round between personas (deferred to a future version).

Full persona briefs — voice, what they hunt, opening moves, verbal tics — live in `personas.md`. **Read it before authoring the five sections** so each voice stays sharp and distinguishable. One-line summaries here for orientation only:

- **The Contrarian** — hunts the fatal flaw. Leads with what kills the idea, not caveats.
- **The First Principles Thinker** — ignores the surface question; rebuilds from the actual problem.
- **The Outsider** — fresh eyes. Names what the user thinks is obvious but isn't.
- **The Executor** — "what do you do Monday morning?" Concrete path or it's vapor.
- **The Historian** — codebase-aware. Quotes the user's prior commits / files / patterns.

## Historian special behavior — codebase tool work

The Historian is the only persona that does tool work.

Before authoring the Historian's section, run — in this order:

1. `git log --all --oneline | head -50` — cheap survey of recent history.
2. `git log -S '<pattern relevant to the idea>' --all --oneline` — history of the specific pattern being proposed (e.g., `-S 'hook'` if the idea reintroduces a hook; `-S 'subagent'` if it's about agent dispatch). Try 2–3 pattern variants if the first returns nothing.
3. `Glob` for relevant file types (e.g., `**/*api*` for an API-design idea; `**/hooks/**` for a hook-flavored idea).
4. Optional: `git log --all --oneline --diff-filter=D -- <path>` if a prior deletion is suspected.

The Historian's section **must** quote at least one specific commit SHA, file path, or branch name when priors exist. Phrase like: *"Commit `1d3c9e0` removed the PreToolUse hook from this very plugin three weeks ago — re-adding one now contradicts that decision unless conditions have changed. What changed?"*

**Greenfield degradation** — if the surveys return nothing relevant (fresh repo, no prior pattern, no related files), the Historian must explicitly say *"no priors found in this codebase"* (or close), then pivot: *"what's making you reach for THIS pattern over standard alternatives like X, Y, Z?"* Never fabricate history.

## Composition

- **`grill-me`** — different shape (one question per turn, interactive). **Do not run in the same session as council** — they fight each other for the interaction shape. Pick one.
- **`eli10`** / **`fool`** — fine to invoke on any single persona's section that reads too dense. Council yields gracefully.

## When NOT to use

- "Drill MY plan" / "interrogate this" — use `grill-me`, different mechanic.
- Simple yes/no factual questions ("does Python have a switch statement?") — just answer.
- Code review of an existing implementation — use a code-review skill.
- Civic-government "council" (city council, meeting agenda) — not this skill.
