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
is read. A real evaluator arrives with rule authoring, when there are authored
rules for it to evaluate.

So: read the file, read the diff, and say what you find. If the project has no
`03-code-patterns.md`, say that too — an absent rule file is a fact worth one
line, not a silent pass.

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
3. **Re-author the AC.** Only when the **criterion** is wrong — a malformed
   expectation, a command that never tested what the AC describes. **Never when
   the code is wrong.** Rewriting a criterion to match what was built is how a
   gate becomes decorative, and it is silent: every later run passes.

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
