# claude-agent-scaffolding

A Claude Code **plugin marketplace**. Everything here ships to users via `/plugin install`.
There is no application — the plugins *are* the product.

Shipped: `workspace-init`, `scaffold-onboard`, `scaffold-dev`, `scaffold`, `ai-mentor`,
`architect-critic`, `claude-security-audit`. In development: `ossify`.

This repo is the **public canonical half** of a dual-repo project. Design specs, session
handoffs, review records and process exhaust live in a private sibling workspace and must
never be added back here.

---

## The one rule that matters most

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

**Measured, not asserted.** On this repo, new library bash has been ~29% of changed volume
and ~57% of review findings — roughly 4x the defect density of prose. On PR #166 it was
100%: four review rounds, five defects, every one in path-string handling, net product value
a path normalizer. At the time of writing, **15 of 38 open issues are bugs in library code
that the skill-first direction marks for deletion.**

Before adding anything to a `lib/`, answer: *what breaks if a model does this by reading
files instead?* If the answer is "nothing", write the prose.

Compare the reference point: `superpowers` ships ~40 shell scripts and no runtime library.
Every one is build/release/test tooling — `bump-version.sh`, `lint-shell.sh`, `run-test.sh`.
None of it runs on a user's path, so none of it can produce a user-facing defect.

## Skill-first

Default to a skill (prose instructions the model follows). Reach for deterministic code only
when the table above says so. Prefer agent/LLM-judge review over brittle deterministic gates
for anything semantic; keep deterministic checks for mechanical facts only.

Over-specifying mechanical precision in prose is its own failure — it drives review churn
without buying correctness.

---

## Testing discipline

Tests here are load-bearing and green means nothing on its own. Before trusting a passing
test, mutation-test it, and hold all three conditions:

1. **The mutation is semantic** — a syntax-broken mutation produces misleading RED that reads
   as coverage.
2. **The mutation applied** — echo the changed line back. A no-op `sed` and a worthless test
   are indistinguishable from the pass count.
3. **The mutation EXECUTES on the tested path** — a function with early returns needs one
   mutation per branch. A mutation on a line the fixtures never reach proves nothing, and
   reads as "this test is vacuous" when the test is fine.

Other ways a green test lies: round-trip tautologies (the verifier re-derives its expected
value from what the code just wrote); fixtures coupled through shared state; a grep-based
check that passes on its own comment; a justifying comment treated as verified behaviour.

**A loosening needs an adjacent control.** When a change makes a check accept more, its
failure mode is that it stops detecting anything — so pin a case that must still fail, right
next to the case that must now pass.

## Shell gotchas that have cost real time here

- `bin/*` dispatchers run `set -euo pipefail`; tests source libs directly and do **not**.
  A lib change verified only by sourcing can still abort under the dispatcher — add a
  dispatcher-path test.
- Under `set -o pipefail`, `… | grep -q` **fails on a true match** (SIGPIPE). Use one `awk`
  pass with `index()`.
- The Bash tool runs zsh; `run-all.sh` forces bash. An unmatched glob aborts the whole
  command line under zsh, and `shopt` does not exist.
- BSD `date -v` must precede `-f`, or it is silently ignored.
- Never compute a test's expected date with the lib's own command — that is a tautology.
- `${CLAUDE_PLUGIN_ROOT}` is not exported into Bash-tool subprocesses.

---

## Git policy

- **Never squash.** Merge commits or rebase only. Enforced by ruleset `20492634`
  (`allowed_merge_methods = [merge, rebase]`), not just convention.
- **Never push to `main` directly.** Branch + PR always.
- **No `Co-Authored-By:` or `🤖 Generated with` trailers.** A `commit-msg` trace filter
  rejects them. A blocked commit means the message is wrong — never `--no-verify` past it.
- **Delete merged branches by CONTENT**, not by merge-base: squashed *and* rebased branches
  are never ancestors of `main`, so `merge-base --is-ancestor` reports them unmerged forever.
  Check `git diff origin/main origin/<branch>` is empty.
- `branches/main/protection` returns 404 — the gate is a *ruleset*, not branch protection.
- Take reviewer thread counts from **GraphQL** (`reviewThreads.totalCount`); REST undercounts.

## Reviewing and being reviewed

- A prescribed remedy — in an issue or a review comment — is a **hypothesis**, not an
  instruction. Before implementing it, check that its premise holds at *this* call site and
  that it covers the whole class the finding names. Both failure modes have shipped defects
  here.
- After the first review round, deep-scan and fix all similar issues in **one** pass. Never
  grind one-at-a-time.
- If a function draws a finding in more than one round, **restructure it** rather than
  patching again. Three findings on one function means the shape is wrong.
- Agree the review stopping rule *before* opening the PR, never mid-cycle.

---

## Commands

```bash
bash ossify/tests/run-all.sh                    # full ossify suite
bash ossify/tests/eval/lib/aggregate-scores.sh  # LLM-judge eval gate
bash ossify/tests/test-block-ledger.sh          # shipped bash-block ledger
bash tests/test-recommendation-policy-parity.sh # cross-plugin byte-parity
```

`docs/conventions/` holds the byte-parity source of truth that parity test checks against —
it is shipped convention, not process exhaust, which is why it is the only `docs/` content
tracked here.
