# Disposition

What the bar is, what presumptively fails it, and when to stop.

## The bar

**Do not treat a change as acceptable merely because the behaviour seems correct.** The bar
is:

- no clear structural regression
- no obvious missed opportunity to make the implementation dramatically simpler, where such a
  path is visible
- no unjustified file-size explosion
- no obvious spaghetti-growth from special-case branching
- no obviously hacky or magical abstraction that makes the code harder to reason about
- no unnecessary wrapper, cast, or optionality churn obscuring the real design
- no clear architecture-boundary leak, and no avoidable duplication of a canonical helper
- no missed opportunity for an obvious decomposition that would materially improve
  maintainability

## Presumptive blockers

Treat each of these as a blocker unless the author justifies it clearly:

- the change preserves a lot of incidental complexity when there is a plausible code-judo
  move that would delete it
- the change pushes a file from below 1000 lines to above 1000 lines
- the change adds ad-hoc branching that makes an existing flow more tangled
- the change solves a local problem by scattering feature checks across shared code
- the change adds an unnecessary abstraction, wrapper, or cast-heavy contract that makes the
  design more indirect
- the change duplicates an existing helper, or puts logic in the wrong layer when there is a
  clear canonical home

Where the bar is not met, leave explicit, actionable feedback and push for a cleaner
decomposition. Vague disapproval is not a finding.

## The verdict is advisory

State it as *"the bar is not met, because …"*, naming the clauses above that it fails.

**This is not a merge gate.** This skill does not approve or block anything; it says what it
found and why the bar is or is not met. Whether that stops a merge is a human decision made
elsewhere, by someone who can weigh delivery pressure, blast radius, and everything else this
review deliberately does not look at.

## Sort every finding, once

Sort by **failure direction**, not by severity feel:

| The finding says | Disposition |
|---|---|
| the code **admits what it cannot handle** — a case it silently mishandles, an invariant it breaks, an incoherence this change introduced | **fix** |
| the code **refuses valid input**, or the finding is taste — a defensible structure you would have written differently | **the author's call**; record it, do not press it |
| polish — naming, formatting, a nit with no structural consequence | **defer**; log it if it is worth logging, drop it otherwise |

The sort is categorical on purpose. "How bad does this feel" produces a different answer on a
different day, and a review whose severity drifts is a review nobody can act on consistently.

## Stop

**One report. One disposition pass. No loop.**

This skill does not re-review its own fixes. It does not open a round two. It does not check
whether the author addressed the findings.

The reason is structural, not stylistic. A review that grades its own remedies always finds
something — every fix is new code, and new code has findings — so a self-reviewing loop has no
natural end and its later rounds measure the review, not the change. Rounds two and beyond
are where a review stops being about the diff and starts being about itself.

A second review of this branch is a **new human decision**. If the user wants one, they
invoke this skill again, on the new head, and get one report and one disposition pass again.
