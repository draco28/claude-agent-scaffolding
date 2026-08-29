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

Probe, in this order, and use the first one available:

1. **`ossify:challenge`** — if the ossify plugin is installed. Its interview mode is the
   normal case here.
2. **`ai-mentor:grill-me`** — if ai-mentor is installed and ossify is not.
3. **The protocol below** — always available, in-plugin, no dependency.

These are **soft** dependencies. Nothing about the correctness of this skill changes when
neither plugin is installed; the third option is a complete griller, not a degraded one. Do
not tell the user to install anything.

**Cadence differs between resolvers, and that is fine.** `ossify:challenge` and
`ai-mentor:grill-me` ask one question at a time. The protocol below asks a whole round at a
time. What must not differ is the agenda: whichever resolver fires, all five items above get
settled before you stop.

## The in-plugin protocol

Interview the user until you reach a shared understanding. Map the work as a **design tree**:
every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are
already settled — the questions you can ask *now* without guessing at answers you have not
heard yet. Ask the whole frontier in one round: number each question and give your
recommended answer. Then wait.

Format a round like this:

```
❓ **Q1** — **<question title>**: <question body, possibly several paragraphs, possibly with options>

➡️ <your recommended answer>

---

❓ **Q2** — **<question title>**: <question body>

➡️ <your recommended answer>
```

Each round of answers reshapes the tree: settled decisions push the frontier outward and
unblock questions that depended on them. Recompute the frontier and ask the next round. **A
question whose answer depends on another question still open in this round belongs to a later
round**, not this one.

**Finding facts is your job, never the user's.** When a frontier question needs a fact from
the environment — the filesystem, the test suite, the call sites — dispatch a sub-agent and
find it. Do not ask the user for anything you could look up. Do not block on it either: a
running exploration is an unsettled prerequisite, so only the questions downstream of it
wait. Ask the rest of the frontier now.

**The decisions are the user's.** Put each one to them and wait.

The session is done when the frontier is empty — every branch of the tree visited, nothing
left silently assumed. **Do not act on it until the user confirms you have reached a shared
understanding.**
