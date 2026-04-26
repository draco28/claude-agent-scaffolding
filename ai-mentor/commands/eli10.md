---
description: Explain Like I'm 10. Re-invocable — each call simplifies further (ELI10 → ELI5 → ELI3).
argument-hint: "[topic — optional; defaults to most recent topic]"
allowed-tools: []
---

The user invoked `/eli10` with arguments: `$ARGUMENTS`

Re-explain the most recent topic (or the topic in `$ARGUMENTS` if provided) at a 10-year-old's level. Rules:

- No jargon. If a domain word is unavoidable, explain it using a concrete analogy first.
- Use a story or physical-world analogy when helpful (e.g., "a database index is like the index at the back of a book").
- Keep it short. A 10-year-old loses interest fast.
- End with: "Want me to make it simpler?" — this signals to the user that they can re-invoke `/eli10` for further simplification.

If the user invokes `/eli10` again on the same topic, simplify further (toward ELI5: shorter sentences, fewer concepts, more concrete). A third invocation goes toward ELI3: one core idea, one analogy, two sentences max.

If no topic is established in the conversation and `$ARGUMENTS` is empty, ask the user what they want explained.
