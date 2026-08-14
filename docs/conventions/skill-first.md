# Skill-first — the one rule that matters most

> **Single source of truth.** This file is authored once at the marketplace root
> (`docs/conventions/skill-first.md`) and imported by every `CLAUDE.md` that needs it,
> including the paired private AI workspace's. Edit here.
>
> **One copy is sanctioned: the headline sentence, inline above each import.** `@` expansion
> is a Claude Code feature, not a property of a file — Codex, `cat`, the GitHub web view, and
> any session whose external import was silently declined all receive a bare path and no rule.
> Those headlines exist for those readers. **Do not delete them, and do not extend them past
> the one sentence.** Where a headline and this file disagree, this file wins.
>
> Nothing else restates the rule. A restatement is the failure mode this file exists to
> prevent — the last one replaced a decidable test with a judgment call.

## What we are building, and why it constrains how

These plugins are built for our own daily workflow across many projects, and the design
lineage is `superpowers` and mattpocock's skills. That lineage is the rule, not a credit:
both ship capability as **prose skills a model follows**, not as runtime code the model
calls. Plugins here are developed **skill-first, not deterministic-code-first**.

## Scope: this governs code that runs on a user's path

Build, release and test tooling is **out of scope entirely**. Deterministic code for
maintaining the plugins themselves — version bumps, linting, test runners, parity checks —
is unconstrained by this rule, because it never executes on a consumer's machine and so
cannot produce a user-facing defect.

`superpowers` is the reference point: ~40 shell scripts and **no runtime library**. Every
one is build/release/test tooling — `bump-version.sh`, `lint-shell.sh`, `run-test.sh`.

Everything below is about the other kind of code: what ships and runs for a user.

## The rule

**Code that MUTATES DURABLE STATE may be deterministic. Code that READS AND REPORTS must be prose.**

The consumer of these plugins is a frontier model. It does not need a runtime library to
tell it what a path is or whether a file looks wrong — it can read the file. Every line of
shell we ship to do that work is a line the model would have done better, and a line that
can carry a bug.

| Deterministic is justified | Prose is correct |
|---|---|
| journal mutation, replay, locking | diagnostics ("read this, say what's wrong") |
| exact identity — digests, hashes | verification ("run this, did it pass") |
| real side effects — git, worktrees | extraction ("read these docs, pull out the lessons") |
| monotonic ID minting | validation of prose the agent itself authored |
| safety rails the agent must not argue past | anything heuristic or judgment-laden |

**The test, and it is deliberately decidable.** Before adding anything to a `lib/`, answer:
*what breaks if a model does this by reading files instead?* If the answer is "nothing",
write the prose.

It is decidable on purpose. A criterion like "only where deterministic code is really
crucial" is the sentence a session writes to justify the library it already wanted; mutation
is a property you can check.

## Measured, not asserted

On this repo, new library bash has been ~29% of changed volume and ~57% of review findings —
roughly 4x the defect density of prose. On PR #166 it was 100%: four review rounds, five
defects, every one in path-string handling, net product value a path normalizer. At the time
of writing, **6 of 41 open issues are bugs in library code the skill-first direction marks
for deletion** — 8 at the ceiling, and only if converting *both* `interop` and `doctor` also
orphans the shared path helper they call.

An earlier draft of this line claimed 15 of 38. That number came from a keyword grep over
issue **titles**, and a per-issue read retired it: it swept in prose bugs, other plugins'
bugs, and bugs in `manifest.sh` and `commands.sh` — 586 LOC the deterministic/prose sort
never classified in either direction. The direction still rests on the defect-density
measurement above; it does not rest on issue count.

## In practice

Default to a skill (prose instructions the model follows). Reach for deterministic code only
when the table above says so. Prefer agent/LLM-judge review over brittle deterministic gates
for anything semantic; keep deterministic checks for mechanical facts only.

Over-specifying mechanical precision in prose is its own failure — it drives review churn
without buying correctness.
