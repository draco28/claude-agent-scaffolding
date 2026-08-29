# Grilling the picked candidate

Once the user picks a candidate, walk the decision tree with them. The **agenda** is fixed;
the **griller** is resolved at invocation time.

## The agenda

Whoever runs the grill, these are what the conversation has to settle before the candidate is
ready to build:

1. **Constraints** — what any new interface would have to satisfy.
2. **Dependencies** — what the module depends on, and which category each falls into
   (`code-judo:codebase-design` → `references/deepening.md`).
3. **The shape of the deepened module** — its interface: entry points, parameters,
   invariants, error modes.
4. **What sits behind the seam** — what the implementation absorbs, and what stays outside.
5. **What tests survive** — which existing tests are made redundant by tests at the new
   interface, and which have to be written.

Hand this agenda to the griller. Do not restate it as questions yourself if you are
delegating — that produces two interviews.

## Resolution order

Take the first of these that works:

1. **`ossify:challenge`** — the normal case, in interview mode.
2. **`ai-mentor:grill-me`**.
3. **The protocol below** — in-plugin, no dependency, always available.

**How to probe: just call it.** Invoke the Skill tool with the name. Do not try to detect
installation by looking for plugin directories on disk — the install path differs by host and
by install mode, so a wrong guess reports "not installed" for a plugin that is right there and
silently downgrades a user who has the better griller.

**Fall through only when the skill is genuinely absent.** "No such skill" is the answer that
means move on. A registry error, a plugin that failed to load, a permission refusal — none of
those mean the skill is not installed, and swallowing them as absence hides a real fault while
looking like a clean fallback. Surface anything that is not a plain not-found, say what
happened, and then continue with the in-plugin protocol so the user is not blocked.

These are **soft** dependencies. Nothing about the correctness of this skill changes when
neither plugin is installed; the third option is a complete griller, not a degraded one. Do
not tell the user to install anything.

**Cadence differs between resolvers, and that is fine.** `ossify:challenge` and
`ai-mentor:grill-me` ask one question at a time. The protocol below asks a whole round at a
time. What must not differ is the agenda: whichever resolver fires, all five items above get
settled before you stop.

## The in-plugin protocol

Compact by design. This is the fallback that ships with the plugin so the skill never depends
on another being installed — not a second general-purpose interviewer. Two of those already
exist in this marketplace, and a third written out at length would drift from both.

**Batch by dependency, not by topic.** Ask everything the agenda's current answers already
let you ask, in one go. Hold back anything whose sensible phrasing depends on an answer you
have not received — asking it now means guessing at that answer inside the question, and the
user ends up correcting your premise instead of deciding anything.

**Number the questions and answer each one yourself first.** A recommendation is what makes a
question cheap to answer: the user is confirming or overriding a position, not composing one
from nothing. Say which way you lean and why, in a sentence.

**Then stop and wait.** One batch, then silence until they reply. Answers reshape what is
askable, so recompute the next batch from the agenda rather than working down a list you
wrote earlier.

**Look things up yourself.** Anything the repository, the tests, or the tools can tell you is
yours to find — dispatch a sub-agent and keep going. Only decisions go to the user, and a
lookup in flight blocks only the questions downstream of it, not the whole batch.

**Done is when the agenda is settled**, not when you run out of questions. All five items —
constraints, dependencies, module shape, what sits behind the seam, surviving tests — have
answers the user has actually given. Then say what you understood, and wait for them to
confirm it before anything gets built.
