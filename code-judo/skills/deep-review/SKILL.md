---
name: deep-review
description: An unusually strict maintainability review of a branch or diff — abstraction quality, giant files, spaghetti growth, boundary leaks — pushed toward ambitious restructurings that delete complexity rather than rearrange it. Human-invoked only. Use for a deep code quality audit, a strict or harsh maintainability review, a code-judo pass over a branch, or "review this diff for structure, not bugs".
disable-model-invocation: true
---

# Deep review

An unusually strict review of implementation quality, maintainability, abstraction quality,
and codebase health. Not a correctness review and not a security review — those are different
skills with different questions.

Above all, be **ambitious** about structure. Do not stop at local cleanup. Actively hunt for
**code judo** moves: restructurings that preserve behaviour while making the implementation
dramatically simpler, smaller, more direct, and more elegant.

## The baseline

Everything below is applied on top of this:

> Perform a deep code quality audit of the current branch's changes.
> Rethink how to structure and implement the changes to meaningfully improve code quality
> without impacting behaviour.
> Work to improve abstractions and modularity, reduce spaghetti, improve succinctness and
> legibility.
> Be ambitious: if there is a clear path to improving the implementation that involves
> restructuring some of the codebase, go for it.
> Be extremely thorough and rigorous. Measure twice, cut once.

## 1. Scope the review before judging anything

Gather two things, and do not start reviewing until you have both:

- **The diff.** `git diff <base>...HEAD`, where `<base>` defaults to `main` unless the user
  named one.
- **The full contents of every changed file.** A diff shows what moved, not what it landed
  in. A hunk that looks fine in isolation is often the sixth special case bolted onto a
  function you cannot see.

Then:

- Apply the rubric **only to what the diff and the file contents show.** Do not report
  problems in code this change does not touch.
- **Trace cross-file impact** wherever the change touches a module boundary. A change that
  looks local is not local if three other modules reach through the seam it just moved.

Gathering these in parallel is fine and usually faster. What is not fine is reviewing the
diff alone.

## 2. Apply the rubric

Read `references/rubric.md` and apply it in full: the eight standards, the review questions
to ask of every meaningful change, what to escalate, the remedies to prefer, and the tone to
write in.

## 3. Write the report

Prioritise findings in this order:

1. Structural code-quality regressions
2. Missed opportunities for dramatic simplification — code-judo restructuring
3. Spaghetti and branching-complexity increases
4. Boundary, abstraction, and type-contract problems that make the code harder to reason about
5. File-size and decomposition concerns
6. Modularity and abstraction issues
7. Legibility and maintainability concerns

**Do not flood the review with low-value nits when there are larger structural issues.**
Prefer a smaller number of high-conviction comments over a long list of cosmetic notes.

## 4. Disposition, once

Read `references/disposition.md`. It carries the approval bar, the presumptive blockers, and
the stopping rule.

The stopping rule is the part that differs from every review skill this one descends from,
and it is not optional: **one report, one disposition pass, no loop.** This skill does not
re-review its own fixes. A second review is a new decision, made by a human.
