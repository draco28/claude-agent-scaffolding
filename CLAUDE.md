# claude-agent-scaffolding

A **plugin marketplace** published to three surfaces: Claude Code (`/plugin install`, from
`.claude-plugin/marketplace.json`), Codex (`.agents/plugins/marketplace.json`, the v0
dual-publish contract), and an OpenCode adapter bundle (`.opencode/`). There is no
application — the plugins *are* the product.

**A change to a plugin manifest or to packaging has to be carried to every surface that
plugin ships on**, and CI enforces it rather than advising it: `tests/test-codex-dual-publish.sh`
checks version and frontmatter parity across the two marketplaces, and the OpenCode adapter
has both a unit suite and a live-loader integration test. `scaffold` is deliberately absent
from the Codex v0 set — check the deferred list before assuming a plugin ships everywhere.

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
- Under `set -o pipefail`, `… | grep -q` can fail **on a true match** — `grep -q` exits at the
  first match and the producer takes SIGPIPE if it writes again. It fires intermittently,
  which is worse than deterministic. Replace it with a single `awk` pass.
  **When you do, preserve the predicate:** `index()` is a literal substring test, so it is not
  equivalent to `grep -E`, `-w`, or `-x`. Pick the awk form that matches the original and
  prove it on an input that separates them — the two predicates agreeing on your first fixture
  is not evidence.
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
- **No `Co-Authored-By:` or `🤖 Generated with` trailers.** This is a **policy you must
  follow, not a guarantee the repo enforces.** A `commit-msg` trace filter blocks them, but
  git hooks live in `.git/hooks/` and are **not tracked** — a fresh clone, a CI checkout, or
  any machine that never ran workspace-init has no filter at all. Do not rely on being
  stopped. If a commit *is* blocked, the message is wrong — never `--no-verify` past it.
- **Determining whether a branch is merged: ask the PR, not the trees.** Squashed *and*
  rebased branches are never ancestors of `main`, so `merge-base --is-ancestor` reports them
  unmerged forever. `git diff origin/main origin/<branch>` fails the other way: it compares
  two endpoint trees, so any unrelated commit on `main` makes the diff nonempty for a branch
  that is fully merged. Ask GitHub about the one branch you care about:
  `gh pr list --state merged --head <branch> --json number,mergedAt`. **Do not enumerate and
  grep** — `gh pr list` defaults to `--limit 30`, and this repo passed 56 merged PRs on
  2026-08-14, so an unqualified listing silently omits the oldest and strands their branches.
  `git cherry` is **not** a fallback here: against a squash merge it compares each topic
  commit's patch-id against individual upstream commits, so every commit on a squashed branch
  reports `+` — fully merged, reported unmerged.
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
bash ossify/tests/test-block-ledger.sh          # shipped bash-block ledger
bash tests/test-recommendation-policy-parity.sh # cross-plugin byte-parity
```

**The eval gate is NOT one command, and running the aggregator alone is a false green.**

```bash
bash ossify/tests/eval/lib/aggregate-scores.sh  # reads results/*.json — evaluates NOTHING
```

That script only summarises per-fixture JSON that a **prior Claude-Code session** wrote; its
own header says "Run AFTER the eval run has written `results/*.json`." Run it after changing a
skill or rubric and it re-reads the *committed* results and reports green, having evaluated
none of the change. The evaluation itself is the session-driven pass in
`ossify/tests/eval/RUNBOOK.md` (dispatch an agent per fixture, then a judge against
`rubrics/<surface>.md`, writing `results/<surface>/<id>.json`) — `run-evals.sh` prints that
instruction rather than performing it. Treat a green aggregate as valid only when the results
files were regenerated after the change under test.

`docs/conventions/` holds the byte-parity source of truth that parity test checks against —
it is shipped convention, not process exhaust, which is why it is the only `docs/` content
tracked here.
