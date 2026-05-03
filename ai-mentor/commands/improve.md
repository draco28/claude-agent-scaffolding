---
description: Rewrite an unstructured natural-language draft into a clean coding-agent prompt — no external API call, uses your current Claude session. Pass-through marker for already-well-formed drafts. Always shows the rewrite for your confirmation before acting on it.
argument-hint: "<your natural-language prompt to improve>"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
DRAFT="${ARGUMENTS:-$*}"
if [[ -z "$DRAFT" ]]; then
  cat <<EOF
Usage: /improve <your natural-language prompt>

Example:
  /improve fix the auth bug, login fails sometimes

What it does: rewrites the draft into a structured coding-agent prompt
(specific files, expected behavior, constraints, definition of done).
The rewrite happens in the current session — no external API call. You
will see the rewrite and confirm before Claude acts on it.

Already-well-formed drafts pass through unchanged with a marker line.
EOF
  exit 1
fi
echo "── User'\''s draft ─────────────────────────────"
printf "%s\n" "$DRAFT"
echo "──────────────────────────────────────────────"
' "$ARGUMENTS"
```

The bash above just echoes the user's draft back. **You (Claude, the current session) do the rewrite work in this turn.** Take the user's draft (everything between `── User's draft ──` and the closing line in the bash output) and rewrite it using these rules:

## Rewrite rules

1. **Specific over vague.** Name actual files, functions, behaviors, error messages where the user mentioned them. Do *not* invent specifics the user didn't provide.
2. **Goal-driven.** State what success looks like in measurable / verifiable terms.
3. **Constraints.** Surface non-goals, performance/security constraints, time pressure, compatibility requirements when the draft mentions them.
4. **Definition of done.** What should be true when the agent finishes? (tests pass / file written / behavior verified / etc.)
5. **Context the agent needs.** Dependencies, related code, similar patterns the agent should consult.
6. **Resist inventing.** If the user said "fix the auth bug," don't invent a database schema or framework. Mark gaps as `TODO: ask user about X` instead.
7. **Preserve intent.** The user's exact words may carry meaning (specific phrasing, deliberate ambiguity). Keep their phrasing where it's already precise.

## Pass-through detection

If the draft is **already well-structured** — specific files, expected behavior, constraints, and definition of done already present — output it unchanged with a leading marker:

```
<!-- already well-formed; no changes -->
<original draft verbatim>
```

A draft is "well-formed" when it has at least three of: named files/paths, expected behavior or output, constraints (perf/security/compat/non-goals), definition of done. Vague drafts ("fix the bug", "make it better") fail this test and need rewriting.

## Output format

Show the user the result clearly. Use this exact shape so the format is recognizable across invocations:

```
── Improved prompt ──────────────────────────────

<the rewrite, or marker + original verbatim>

──────────────────────────────────────────────
```

Then ask one of these depending on the rewrite outcome:

- **Pass-through case** (marker present): "Your draft was already well-formed. Want me to proceed with it as-is?"
- **Substantive rewrite**: "Want me to proceed with this improved version, or edit it first?"
- **Rewrite added invented information** (file paths or constraints the user didn't mention — watch for this when filling in `TODO:` items): explicitly flag what was added: "I added X / Y which you didn't mention. Want to drop those, edit, or use the original draft instead?"

## After confirmation

When the user confirms ("yes", "go", "use it", "proceed"), treat the chosen prompt (improved, edited, or original) as the actual task and start working on it. Do **not** auto-execute the rewrite without confirmation — the whole point of `/improve` is letting the user see and approve the rewrite before you act.

## Cost note

This rewrite happens inline in the current session, so it costs whatever the active model charges for the rewrite tokens (~500–1500 tokens of context + ~200–600 tokens of output). No separate API call, no spawned subprocess, no `ANTHROPIC_API_KEY` required. The rewrite is essentially free if you're already in a paid session.
