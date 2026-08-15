# impl-check — the three-layer work-item gate

Depth for SKILL.md §4, step 2. This is the orchestrator-side gate over one work
item's output (spec §6, last bullet). It runs on the resolved `$spec`, `$report`
and `$wt` from `work-item-close.md` §1 — **never on a placeholder**.

Three layers, in order. **Halt on the first failure in any layer**, and a halt is
terminal: no later layer runs, no commit, no merge, no status write.

---

## 1. Why this one halts when the implementer's did not

The implementer runs every verification command **without** halting on the first
failure, deliberately (`work-item/SKILL.md` §6). This gate does the opposite, and
for the opposite reason:

| | Implementer | This gate |
|---|---|---|
| On first failure | keep going | **halt** |
| Why | nobody is listening; a partial picture forces a second dispatch that costs more than the failed commands did | there *is* a human to route to, and the recovery choice does not improve with more failures attached |

So the two are not inconsistent, and neither is a bug to be "aligned" with the
other. If you are tempted to make this one gather everything first: the first
failure is what the recovery menu acts on, and running the rest changes files,
burns time, and buries it.

---

## 2. Layer 1 — `auto:` ACs, halt-on-first-fail

```bash
oss verify_acs "$spec"    # TSV: label <tab> command <tab> expectation, in declared order
```

Then, per row, in the order it printed. The fields are tab-separated (commands
contain spaces), and the rows are consumed by **redirection, never by a pipe**:

```bash
rows="$(oss verify_acs "$spec")" \
  || { echo "[AC] cannot read the spec '$spec' - the gate would otherwise pass by reading nothing"; exit 2; }
[ -n "$rows" ] \
  || { echo "[AC] the spec '$spec' yields zero auto: ACs - verify the spec path and the AC grammar"; exit 2; }

rc=0
while IFS="$(printf '\t')" read -r label cmd exp; do
  [ -n "$label" ] || continue
  oss verify_step "$wt" "$cmd" "$exp" || rc=$?
  [ "$rc" -eq 0 ] || { echo "[AC] $label \`$cmd\` did not satisfy '$exp' (rc $rc)"; break; }
done <<EOF
$rows
EOF
[ "$rc" -eq 0 ] || exit "$rc"        # halt: no later layer runs
```

Three idioms here, all load-bearing and all silent when wrong.

**Parse the spec ONCE, up front, where the rc is checkable.** The rows used to be
fed straight in from a process substitution, whose rc the loop cannot see. A spec
that could not be read — a mis-derived path landing on the handoff or last
round's spec, or AC lines that drifted from the grammar — produced **zero rows**:
the loop body never ran, `rc` kept the `0` it was initialised with, and the gate
reported **green having read nothing**. A gate that passes when it is blind is
worse than no gate. Capture the rows first, fail closed on an unreadable spec,
and treat "zero auto ACs" as a defect to surface rather than a vacuous pass.

**`|| rc=$?`, never `if ! oss verify_step …; then rc=$?`.** After a negated test
`$?` is the *negation's* status — zero — so `rc` records a pass, the halt check
below never fires, and the loop runs every remaining AC before falling into layer
2. The `||` form captures the command's own rc, and as an OR-list it is
errexit-exempt.

**`oss verify_acs … | while …` is the other trap.** The last element of a pipeline runs
in a **subshell**: `rc` is set in a child and lost, `break` leaves only the
subshell, and the ceremony sails past the halt into layer 2 with a failing AC
behind it — at rc 0. Feeding the loop from the captured `$rows` by heredoc (as
above) keeps it in the current shell, which is what makes the halt reach the
caller. A `< <(…)` process substitution does that too and is fine where the
producer's rc does not matter — but here it does, which is why the parse moved
out of the redirection entirely.

Both nonzero codes halt, and they mean different things, so say which:

| rc | Meaning | Tag |
|---|---|---|
| 0 | the AC's command behaved as declared | — |
| 1 | the AC failed | `[AC]` |
| 2 | the expectation is malformed or unrecognized | `[AC]`, and name the criterion, not the code |

An rc 2 is a **criterion** defect: the expectation grammar is `exit <n>` or
`output contains <str>`, and anything else fails closed rather than passing
silently. That routes to the third recovery option (re-author the AC), never to
"re-dispatch the implementer" — the code is not what is wrong.

**`verify_step` already applies the zero-tests guard for you.** A command naming
a recognized test runner whose output shows a zero-tests result fails as *vacuous
green*. Do not re-implement it in the ceremony. Two scoping facts, because both
directions bite:

- It fires **only on an `exit 0` expectation.** A row legitimately expecting
  `exit 1` from a recognized runner is not vacuous, and is not flagged.
- It requires **both** halves — the command must name a recognized runner **and**
  the output must show zero tests. A non-runner that merely prints a zero-tests
  phrase is not vacuous.

`user:` rows are not parsed here at all. They are journey lines for the
cumulative demo, walked by a human at spine and release close.

---

## 3. Layer 2 — report cross-check

```bash
oss report_cross_check "$report" "$spec"    # 0 accounted-for | 1 missing | 2 report not found
```

Every `auto:` AC in the spec must appear in the report's AC table
(`work-item/references/report-contract.md` §2). **A missing `auto:` AC halts** —
an unreported AC is indistinguishable from an unimplemented one, and the whole
point of the report is that it is the evidence the gate reads.

The lib emits `oss: report does not account for: <AC>` and returns rc 1. The
`[report cross-check]` tag below is **the skill's surfacing convention layered on
top** — it appears in no lib and you should not grep for it.

An AC that was deferred, skipped under a recorded override, or only partially
satisfied still has to be **named** in the report with its severity. "Quietly
dropped" and "incomplete report" are the same observation from here.

---

## 4. Layer 3 — code patterns

Read the project's `03-code-patterns.md` and **judge** whether the staged diff
violates a documented pattern.

**This layer is agent judgment in this release, and that is a decision rather
than an omission.** The predecessor stack's mechanical evaluator is a phantom
entry point over three unimplemented rule families: it resolves to nothing, it
passes everything, and it reads as coverage. **A mechanical gate that silently
passes is worse than an honest judgment call** — the first is trusted, the second
is read.

**Settled, 2026-08-15: the evaluator is wontfix.** This paragraph used to end
*"a real evaluator arrives with rule authoring"*, then *"that remains a
separate v0.3 item"*. Neither is true any longer: no ossify evaluator will
ship, by decision rather than delay. An authored rule is documented, validated
at authoring (`doctor` §6), and read **here, by you**, on every work-item
close — this layer IS ossify's evaluation mechanism, and the planned Layer 4
agent pass (#139) is its deepening, not its replacement. Nothing in this stack
parses those blocks and runs them against a codebase, and nothing is waiting
to. (The legacy scaffold-dev stack still does, on spines it drives — its
`implementation-checking` applies the same shared artifact mechanically.)

So: read the file, read the diff, and say what you find. If the project has no
`03-code-patterns.md`, say that too — an absent rule file is a fact worth one
line, not a silent pass.

### Where the file is

The memory bank, in the **AI workspace** — not the canonical repo, and not
beside the code being reviewed. The bank is manifest-routed: resolve it exactly
as `references/harvest.md` §7 does (the pairing manifest's
`.well_known_paths.memory_bank`, token-expanded; a relative or unresolved route
is a STOP), never against `$PWD`. The file is `<bank>/03-code-patterns.md`.

`03-code-patterns.md` is one of the bank's live files, authored at onboarding
from bones category 8 (`start/references/memory-bank-brief.md` §1) and grown by
the harvest. Its `## Machine-checkable rules` section ships **seeded empty** —
an empty section is not the same as an absent file, and neither is a violation.

### What a finding looks like

Two parts, always, because a finding the author cannot act on is an opinion:

1. **The pattern, quoted** from `03-code-patterns.md` — its own words, not your
   paraphrase of them.
2. **The offending hunk**, by file and line, from the staged diff.

> `[rule] src/orders/api.rs:142` — `03-code-patterns.md`: *"adapters never
> import from `domain::internal`"*. This hunk adds
> `use crate::domain::internal::OrderState;` in an adapter.

**Calibrate against the pattern as written, not its spirit.** If the diff
violates what the rule *says*, it is a finding. If it violates something you
believe the rule *meant*, that is a gap in the rule — say so as an observation
and do not halt the gate on it. The rules are the project's, and rewriting them
by interpretation at a close gate is how a rule set stops meaning anything.

### What is not a finding

- **Style the file does not mention.** Naming, formatting, import order — if
  `03-code-patterns.md` is silent, so are you. This is not a code review; see
  `code-review.md` for the judgment layer that *is*.
- **Code the diff did not touch.** Pre-existing violations are a backlog item,
  not this work item's failure. Note them once, in passing.
- **A pattern you would have written differently.** Not yours to relitigate here.
- **An empty or absent `## Machine-checkable rules` section.** Expected on a
  young project. Say so in a line and move on.

---

## 5. Source-tagged errors

Every surfaced error starts with a **literal** tag naming which layer produced
it. The tag is how a reader knows whether to look at the code, the report, or the
criterion:

```text
[AC]                 AC-3 `<command>` expected `exit 0`, observed rc 1
[report cross-check] report does not account for: AC-2
[rule]               <file>:<line> - <the documented pattern it violates>
```

Do not invent a fourth tag, do not translate one into prose, and do not merge two
layers' findings under one tag. Three tags, spelled exactly as above.

---

## 6. The recovery menu

Surfaced on any halt, **never auto-selected**. Present all three with their real
consequences and stop:

1. **Re-dispatch the implementer with the failure.** The default when the code is
   wrong. The failure detail goes into the handoff as a clarification, because a
   fresh worker has no memory of the previous attempt. The execution lane's
   3-dispatch cap still applies.
2. **Accept with a recorded deferral.** The choice when the gap is real, bounded,
   and not worth another round now. It is *recorded*, not waved through — an
   accepted failure that leaves no trace is an unaccepted failure that nobody
   will find.
3. **Fix the criterion.** Only when the **criterion** is wrong — never when the
   code is wrong. Rewriting a criterion to match what was built is how a gate
   becomes decorative, and it is silent: every later run passes.

   **Which criterion depends on the layer that halted**, because the three layers
   are judged against three different documents:

   | Halting layer | The criterion is | Fixing it means |
   |---|---|---|
   | `[AC]` — Layer 1 | the AC in `spec.md` | re-author the AC: a malformed expectation, or a command that never tested what the AC describes |
   | `[report cross-check]` — Layer 2 | the report's AC table | the report under-accounts; the fix is in `report.md`, not the spec |
   | `[rule]` — Layer 3 | the pattern in `03-code-patterns.md` | amend the pattern in the memory bank — with the user, since it binds every future spine |

   A Layer 3 halt offered "re-author the AC" is being offered the wrong document:
   no AC is involved, and the honest options are amend the pattern, or fix the
   code. **A pattern amendment is never a quiet by-product of one work item's
   gate** — it changes the rule for everything after it.

The user picks. This is not a disposition row and the auto-apply policy does not
reach it (`work-item-close.md` §5).

---

## 7. Anti-patterns

- **Running a layer on a placeholder path.** `$spec`, `$report` and `$wt` were
  resolved for you; `<spec path>` is a filename.
- **Gathering all failures before halting.** §1.
- **Re-implementing the zero-tests guard**, or expecting it on a non-`exit 0`
  expectation (§2).
- **Grepping lib output for `[report cross-check]`** (§3).
- **Reading rc 2 as a code failure.** It is a criterion failure (§2).
- **Treating a missing `auto:` AC in the report as a reporting nit** (§3).
- **Auto-selecting a recovery option**, or presenting only one (§6).
- **Re-authoring an AC because the code failed it** (§6).
- **Running `user:` rows here** (§2).
