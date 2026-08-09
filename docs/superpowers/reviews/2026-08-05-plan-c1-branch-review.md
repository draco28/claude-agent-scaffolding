# Plan C1 whole-branch review — feat/ossify-core @ 70b0463

6 dimension-scoped reviewers reading HEAD state, each finding adversarially verified.
**24 confirmed of 28 raw** (4 refuted). 1 critical / 7 major / 14 minor / 2 nit.

The critical was independently reproduced by the controller before being recorded.

## [CRITICAL] `oss state_restore` silently wipes the entire project state to the empty init skeleton — rc 0, success message, doctor green afterwards — when `.mutations` is unreadable as a count

**File:** `ossify/lib/state.sh:372`

**Failure scenario:** State: a `project-state.json` holding a real project (releases, spines, bones, demo ledger) whose `.mutations` array is absent, or a 0-byte state file. `oss doctor` prints `fail: replay - replay: drift detected …` and a remedy line naming `oss state_restore`; skills/close/SKILL.md:112-115 tells the agent that exact remedy at close pre-flight. Running it returns **rc 0** with `restore: rebuilt from base + 0 journaled mutations`, and overwrites the live state with the pristine `base.json` — every release, spine, work item, bone, demo line, fake, class override and the journal itself are destroyed, with no pre-restore backup. `oss doctor` then reports all four checks green (`ok: replay - replay: clean (0 mutations)`), so nothing downstream can detect the loss. Root cause: line 372 `n="$(jq '.mutations | length' "$sf" 2>/dev/null)" || return 4` — jq exits **0** and yields `0` for a missing key (`null|length`) and yields *empty output* for a 0-byte file; neither is validated, so the rebuild loop at 374 is skipped entirely (in the empty case bash even prints `[: : integer expression expected` and reads the erroring test as false) and the body commits `$rebuilt`, which is nothing but `cat "$base"`. The only post-write guard (385) checks `.schema_version`, which the pristine base trivially satisfies. The success line at 362 compounds it: it re-derives the count by re-reading the file restore just wrote, so the message can never contradict the write (the tautology pattern this repo has already been bitten by). No test in ossify/tests covers this: `grep -rn 'del(.mutations)\|0-byte\|truncat\|integer expression' tests/*.sh` → NONE.

**Evidence:**

```
$ oss init p; oss posture_set private; R=$(oss release_add skeleton goal); S=$(oss spine_add $R s1 bone); oss bone_add ADR-1 b src/a
$ jq 'del(.mutations)' s.json > x && mv x s.json
$ oss doctor
ok: schema - v3
ok: lock - free
fail: replay - replay: drift detected - live state does not equal base+journal (0 mutations).
  Nothing is lost: the base snapshot (…/s.json.base.json) and the append-only journal inside …/s.json are both intact, so the correct state is still derivable from them.
  Recover with 'oss state_restore', …
fail: shape - missing key 'mutations'
rc=1
$ oss state_restore          # the remedy doctor and close/SKILL.md:114 both name
restore: rebuilt from base + 0 journaled mutations
rc=0
$ oss doctor
ok: schema - v3
ok: lock - free
ok: replay - replay: clean (0 mutations)
ok: shape - all required keys present
rc=0
$ jq -c '{posture:.project.posture,releases:[.releases[].id],spines:[.spines[].id],bones:[.bones[].adr]}' s.json
{"posture":null,"releases":[],"spines":[],"bones":[]}

# 0-byte variant, same file, restored from a full 5-op state:
$ : > s.json; oss state_restore
…/ossify/lib/state.sh: line 374: [: : integer expression expected
restore: rebuilt from base + 0 journaled mutations
rc=0

# contrast: a TRUNCATED (unparseable) file is handled correctly —
$ head -c 200 good.json > s.json; oss state_restore; echo rc=$?
rc=4   # original untouched
```

**Fix:** Validate the journal before entering the rebuild loop, in BOTH `_oss_state_restore_body` (372) and `oss_state_replay` (316): require `jq -e '.mutations | type == "array"' "$sf"` and require `n` to match `''|*[!0-9]*` → refuse rc 4 (same digits-only idiom already used at state.sh:417 for schema_version, and for the identical reason documented there — an erroring numeric test reads as 'condition not met'). Additionally: (a) have `_oss_state_restore_body` count what it actually replayed into a local and print that, instead of line 362 re-reading the file it just wrote; (b) copy `$sf` to `$sf.pre-restore` before the `mv` at 388 so a wrong restore is recoverable; (c) add a test with a `del(.mutations)` fixture asserting rc != 0 AND that a concrete pre-corruption value (e.g. `.releases[0].id == "r0"`) still exists in the file afterwards.

## [MAJOR] Spec §6.1 requires a patch-lane record to be `doctor`-visible; patch-lane.md asserts it twice, and `oss doctor` never reports one

**File:** `ossify/lib/doctor.sh:60`

**Failure scenario:** A user routes an out-of-spine change through the patch lane and records it with `oss patch_add <sha> "<why it took no spine>"`, as patch-lane.md §5 instructs. They then run `oss doctor` to audit accumulated out-of-spine drift, because patch-lane.md:113 tells them the record is "self-declared and `doctor`-visible" and :109-111 tells them "`doctor` cannot count what was never written" (implying it counts what was). Doctor prints nothing about it — not a warn line, not a count. The unvalidated-change window that spec §6.1 made observable on purpose is invisible in the only tool that reports state health, and the operator reads a clean doctor as "no out-of-spine drift".

**Evidence:**

```
Spec line (docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md §6.1): "may commit directly, with a one-line record appended to project-state.json (self-declared, `doctor`-visible)". Reproduced against the real libs:

  $ bash t2.sh
  --- patch_records:
  [{"commit":"abc1234","text":"comment typo in export path - no bone, no gate, no line observes it","at":"2026-08-05T17:49:07Z"}]
  --- doctor output:
  ok: schema - v3
  ok: lock - free
  ok: replay - replay: clean (1 mutations)
  ok: shape - all required keys present
  doctor rc=0

(t2.sh sources ossify/lib/*.sh, runs oss_state_init then oss_ledger_add_patch, then oss_cmd_doctor.) And the omission is structural, not a fixture artifact:

  $ grep -n "patch" ossify/lib/doctor.sh
  53:  for key in schema_version project counters releases spines work_items demo_ledger bones risk_gates fakes feature_map patch_records class_overrides veto_dispositions close_records mutations; do

The only occurrence of `patch` in doctor.sh is the shape-key presence loop. doctor.sh:60 introduces the visibility block as "§6.1 operator visibility: the three things that rot silently" and ships exactly three warn lines — pending amendments (:63), quarantines (:65), outstanding fakes (:67). §6.1 names a fourth.
```

**Fix:** Add a fourth line to the §6.1 visibility block in oss_cmd_doctor, in the same non-rc-setting `warn:` shape as its siblings — e.g. `pat="$(jq -r '.patch_records | length' "$sf" 2>/dev/null || echo 0)"; [ "$pat" -gt 0 ] 2>/dev/null && echo "warn: patches - $pat out-of-spine patch record(s) since the last spine close"` — and cover it in tests/test-doctor.sh alongside the existing warn fixtures. If it is instead meant to wait for C2, say so at patch-lane.md:113 rather than asserting doctor visibility that does not exist.

## [MAJOR] The companion-spec release-close boundary audit is absent from the shipped release close and absent from its "deliberately not shipped" table, while `start` tells the user it executes

**File:** `ossify/skills/close/references/release-close.md:21`

**Failure scenario:** A user onboards an `open-core` or `fully-open` project through `start`, which has them author PUBLIC_BOUNDARY.md with a `## Machine-checkable rules` block of `never-tracked:` patterns (secrets, keys, private specs). posture-block.md:186 annotates that block "Executed against tracked files by the release-close boundary audit" and :208 states "The machine-checkable block is what the release-close audit executes — deterministically, from a clean checkout or CI". The user then runs `/close r1`. The shipped release close runs seven steps, none of which reads PUBLIC_BOUNDARY.md, scans tracked or untracked files, or mentions the audit — and its explicit not-shipped table names only docs increment, handoff cleanup and the PR gate. The release closes green and the user believes a secrets/boundary check ran. This is the one deferral whose silent version produces a false safety assurance rather than a missing convenience.

**Evidence:**

```
Companion spec §6 is titled "Boundary audit (new release-close step, ossify §6.2)" and specifies "Runs at every release close ... confirmed findings block the release close". The audit does not exist anywhere in the shipped plugin:

  $ grep -rn "PUBLIC_BOUNDARY\|never-tracked\|gitleaks" ossify/skills/close/ ossify/lib/ | wc -l
         0

  $ grep -rn "boundary audit\|release-close audit" ossify/skills/ ossify/lib/
  ossify/skills/start/references/posture-block.md:45:> full-history secrets scan, a full boundary audit, and a semantic moat scan).
  ossify/skills/start/references/posture-block.md:186:<!-- Executed against tracked files by the release-close boundary audit. -->
  ossify/skills/start/references/posture-block.md:208:The machine-checkable block is what the release-close audit executes —

The only claim of the feature is in `start`; the only place a reader would look for its absence — release-close.md:21-32's status table, and the repo-dimension paragraph at :34-39 which names exactly two unbuilt companion items ("a pin/publish step ... and one PR per touched repo. Neither is built") — omits it. posture-block.md defers two other Plan-D items by name (§9 "Provisioning is deferred to Plan D", §10 composition root) but not this one, so the reader has no basis to infer it.
```

**Fix:** Add a row to release-close.md:21-32's table — "Boundary audit (companion §6) | **not shipped.** Plan D owns it; PUBLIC_BOUNDARY.md's machine-checkable block is authored but nothing executes it in this release" — and change posture-block.md:186 and :208 from present-tense assertion to the deferred form used by that file's own §9 (e.g. "will be executed by the release-close boundary audit (Plan D); nothing executes it in this release").

## [MAJOR] `oss migrate` has zero prose consumers, and close's pre-flight names a remedy (`oss state_restore`) that cannot fix the failure it is offered for

**File:** `ossify/skills/close/SKILL.md:114`

**Failure scenario:** A project whose project-state.json predates this build (schema v1 or v2) runs `/close r1.s2`. Pre-flight step 2 runs `oss doctor`, which reports `fail: schema` and rc 1. The skill body tells the agent the remedy is `oss state_restore`. Running it prints `restore: state is already clean - nothing to do` at rc 0 and leaves schema_version untouched, so `oss doctor` fails identically on the retry and the close is wedged. The verb that actually fixes it — `oss migrate` — is named in ZERO skill prose across all 5 SKILL.md and all 43 references/*.md (only in lib stderr and the plan doc), making it the third zero-consumer dispatcher verb after the two already recorded.

**Evidence:**

```
$ grep -rn 'migrat' ossify/skills/ ossify/commands/ ossify/README.md | grep -c 'oss migrate'
0
# fixture: state forced to v2 (live + base), then:
$ oss doctor
fail: schema - state schema v2 predates this build (v3) - run 'oss migrate' to upgrade it
ok: lock - free
skip: replay - skipped (schema check failed)
ok: shape - all required keys present
doctor rc=1
$ oss state_restore
restore: state is already clean - nothing to do
restore rc=0
$ jq -r .schema_version project-state.json
2
$ oss migrate
migrated v2 -> v3
```

**Fix:** Split the remedy in close/SKILL.md §3 step 2 by doctor line: `fail: replay` -> `oss state_restore`; `fail: schema` -> `oss migrate` (and echo doctor's own line rather than substituting a fixed remedy). That also gives `oss migrate` its first prose consumer.

## [MAJOR] `_oss_worktree_ignore` silently skips any repo whose `.git` is a file, so a `--separate-git-dir` canonical is left permanently dirty with `?? .worktrees/`

**File:** `ossify/lib/worktree.sh:71`

**Failure scenario:** Canonical was created with `git init --separate-git-dir` (or is a submodule). `.git` is a file, so `_oss_worktree_ignore` returns 0 without writing `.worktrees/` anywhere — the comment's premise ("it is itself a worktree ... inherits the parent's excludes") is false for a separate git dir, which has its own non-inherited info/exclude. After the first `oss worktree_add`, `git -C "$canonical" status --porcelain` prints `?? .worktrees/` forever. The next spine's round-1 gate (round-orchestration.md:54, `[ -z "$(git -C "$canonical" status --porcelain)" ] || { echo "canonical is dirty - halt"; exit 1; }`) then halts every subsequent spine on a dirty tree ossify itself created — exactly the outcome the function's own header comment says it exists to prevent.

**Evidence:**

```
$ git init -q -b main --separate-git-dir="$SB/gitdir/canon.git" "$SB/canon"   # .git is a FILE
$ oss worktree_add canonical r0.s1.w1 slug spine/r0.s1-s
.../canon/.worktrees/r0.s1.w1
$ git -C "$SB/canon" status --porcelain
?? .worktrees/
$ cat "$SB/gitdir/canon.git/info/exclude"
# git ls-files --others --exclude-from=.git/info/exclude
...   # no .worktrees/ line was ever written
```

**Fix:** Resolve the real common dir instead of testing for a `.git` directory: `cd="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"` and append to `$cd/info/exclude`. Keep it best-effort/non-fatal. (workspace-init already took this lesson on issue #85 for the commit-msg hook path.)

## [MAJOR] The round-orchestration execution lane has no invoking entry point — nothing routes an agent into it

**File:** `ossify/skills/work-item/references/round-orchestration.md:12`

**Failure scenario:** After `/plan-spine r1.s2` finishes, the user says "run the rounds" / "execute the spine" / "dispatch the work items". No skill description matches: `work-item`'s description is 'Execute one ossify work item end to end from its handoff doc', `close`'s is the close ceremony, `plan-spine`'s explicitly says it does not execute. There is no `commands/*.md` for the lane and README names none. So the agent loads work-item/SKILL.md, whose §2 says "Do NOT auto-invoke when: No handoff path was given. Ask once" and whose §2 also states "Mode B has no description-match" — and asks for a handoff path that nobody has authored. The whole Plan C1 orchestration contract (spine-branch cut-AND-checkout, worktree spawn, `oss work_item_exec`, Task dispatch, the 3-iteration cap, the round barrier) is reachable only if the agent happens to read a mid-body parenthetical at work-item/SKILL.md:26-34 or plan-spine/SKILL.md:38. If §2's `checkout -b` never runs, every later `/close r1.s2.w1` halts at "canonical is on 'main', not 'spine/...'" with no ceremony able to say why.

**Evidence:**

```
$ grep -rn "round-orchestration\|execution lane\|orchestrator" ossify/commands/ ossify/README.md ossify/agents/
ossify/agents/implementer-agent.md:38:the orchestrator replan.
ossify/agents/implementer-agent.md:42:command from running — the guarantee is your discipline plus the orchestrator's
# i.e. no command, no README line, no agent registration routes into the lane.
$ grep -n "references/" ossify/skills/work-item/SKILL.md
27:  (`references/round-orchestration.md`) — the execution-side caller that walks a
107:...handoff-contract.md 145:...pre-flight.md 203,224:...tdd-loop.md 256:...report-contract.md 313:...returns.md
# every other reference gets a "Read it when..." directive; round-orchestration.md gets only a descriptive mention in the Mode-B paragraph.
$ grep -n "orchestrat\|rounds" ossify/skills/work-item/SKILL.md | sed -n '1,3p'
26:- **Mode B — subagent system prompt.** ossify's **round-orchestration lane**
```

**Fix:** Give the lane a real trigger: either add an orchestrator mode to work-item/SKILL.md §2 ("If you were asked to drive a spine's rounds rather than one item, read `references/round-orchestration.md` in full and follow it") plus matching phrases in the skill description, or add a `/run-spine <spine-id>` command in ossify/commands/. Today plan-spine ends and nothing picks the baton up.

## [MAJOR] retrospective.md claims the memory-bank harvest sweeps retrospective files; it does not, and a candidate harvested from one is rejected whole-payload at rc 2

**File:** `ossify/skills/close/references/retrospective.md:9`

**Failure scenario:** An agent at spine close step 9 reads retrospective.md (step 8's contract) and takes line 9 at face value: "the memory-bank harvest (step 9) sweeps these files". It therefore enumerates candidates from the spine's `retrospective.md` alongside report.md/handoff.md — e.g. a durable lesson out of the bone set's `## 8. What we learned about the work`. That candidate has no `[report]`/`[handoff]` origin, so the payload item it produces carries a `source` outside the two-value enum. `oss harvest_apply` validates the WHOLE payload before touching the filesystem and returns rc 2 on the first bad item, so the entire accepted set — including every legitimate report-origin entry — is rejected and nothing is written. In the other direction, a reader who trusts line 9 also believes the retro's pinned headings are load-bearing for a machine that never reads them.

**Evidence:**

```
$ grep -n 'memory-bank harvest (step 9) sweeps' ossify/skills/close/references/retrospective.md
9:contract uses, and for the same reason: the memory-bank harvest (step 9) sweeps
(line 10 continues: "these files, and a heading invented per spine makes the retro series unreadable as a series.")

But harvest.md declares itself the only copy and names only two inputs:
$ sed -n '3,5p;18,19p' ossify/skills/close/references/harvest.md
Depth for `spine-close.md` §9 and SKILL.md §5. This is the **only copy** of the
harvest ceremony: ...
Step 8 authors the retrospective. **Step 9 is this.** ...
$ sed -n '10,10p' ossify/skills/close/references/harvest.md
artifacts nobody re-reads (`report.md`, `handoff.md`) ...

$ grep -rn 'retrospective' ossify/skills/close/references/harvest.md ossify/skills/close/references/spine-close.md | grep -i harvest
(spine-close.md:316 lists the harvest inputs as report.md + handoff.md only; no file in the tree other than retrospective.md:9 says the harvest reads a retro)

And the lib rejects it:
$ grep -n 'must be exactly' ossify/lib/harvest.sh
      echo "oss: harvest rejected - item $i source is '$src'; must be exactly 'report' or 'handoff'" >&2; return 2
```

**Fix:** Rewrite retrospective.md:7-11 so the pinned-headings rationale stands on its real ground — the release-close retro aggregation (release-close.md §6 reads these sections by name) and human re-readability as a series — and delete the harvest claim. The harvest reads `report.md`'s `## 9. Suggestions for memory bank` and each per-work-item `handoff.md`'s `## Clarifications`, and nothing else.

## [MAJOR] pre-flight Gate 2's malformed-AC detector names three causes that all produce NON-empty output, so the gate cannot fire for any of them

**File:** `ossify/skills/work-item/references/pre-flight.md:52`

**Failure scenario:** A spec ships an AC with the backticks omitted: `- [ ] AC-2 auto: pytest tests/two → expected: exit 0`. Gate 2 runs `oss verify_acs` and gets a row back, so pre-flight passes and the run proceeds — but the row's COMMAND field is the whole tail of the line (`pytest tests/two → expected: exit 0`), not the command the spec meant. The RED gate then `bash -c`s that string, it fails (as any garbage does), redgate reports rc 0 = RED = "proceed", and the worker spends the whole TDD loop trying to satisfy an AC whose command can never pass. It surfaces two ceremonies later as `[AC] AC-2 ... did not satisfy 'exit 0'` at the close gate, where recovery option 1 ("re-dispatch the implementer — the default when the code is wrong") points at code that was never the problem. The ASCII `->` and missing-`expected:` variants land the malformed text in the EXPECTATION field instead, producing an `oss: unrecognized expectation` rc 2 at the close gate rather than a gaps-mode return at pre-flight. In all three cases the gate that exists to catch this before any work starts is structurally unable to.

**Evidence:**

```
$ cat > /tmp/acs/spec.md <<'EOF'
- [ ] AC-1 auto: `pytest tests/` → expected: exit 0
- [ ] AC-2 auto: pytest tests/two → expected: exit 0
- [ ] AC-3 auto: `pytest tests/three` -> expected: exit 0
- [ ] AC-4 auto: `pytest tests/four` → exit 0
EOF
$ ./bin/oss verify_acs /tmp/acs/spec.md | sed 's/\t/ <TAB> /g'
AC-1 <TAB> pytest tests/ <TAB> exit 0
AC-2 <TAB>  pytest tests/two → expected: exit 0 <TAB> exit 0
AC-3 <TAB> pytest tests/three <TAB> `pytest tests/three` -> expected: exit 0
AC-4 <TAB> pytest tests/four <TAB> `pytest tests/four` → exit 0

All four malformations produce output. The prose:
$ sed -n '52,54p' ossify/skills/work-item/references/pre-flight.md
If the spec visibly has AC lines and this prints nothing, the AC grammar is
malformed (a missing backtick pair around the command, an ASCII `->` where the
grammar wants the arrow, a missing `expected:`). That is a gap.

What DOES produce empty output is a different class entirely — a missing/wrong checkbox or a missing `auto:`:
$ printf -- '- AC-1 auto: `pytest a` → expected: exit 0\n* [ ] AC-2 auto: `pytest b` → expected: exit 0\n- [ ] AC-3: `pytest c` → expected: exit 0\n' > /tmp/acs/spec2.md
$ ./bin/oss verify_acs /tmp/acs/spec2.md; echo "rc=$?"
rc=0     # no rows at all

Root cause is the unanchored fallthrough in the extractor:
$ grep -n 'sed -E .s/\^\[\^' ossify/lib/verify.sh
      cmd="$(printf '%s' "$rest" | sed -E 's/^[^`]*`([^`]*)`.*/\1/')"   # no match -> passes $rest through unchanged
```

**Fix:** Two changes. (a) Correct pre-flight.md:52-54: the empty-output case is caused by a malformed CHECKBOX or a missing `auto:` marker; list those instead. (b) Add the real detector for the three named causes as a Gate 2 shape check on the returned rows — a command field containing `→`/`->`/`expected:`, or an expectation field that is not `exit <n>` / `output contains <str>`, is a malformed AC and a blocking gap. (`oss verify_step` already fails closed on the latter at rc 2, so the ceremony can lean on that grammar rather than re-implementing it.)

## [MAJOR] report_cross_check returns rc 0 (CLEAN) when the spec cannot be read or yields no auto: rows — the process-substitution rc is discarded and the accumulator stays at its clean initial value

**File:** `ossify/lib/verify.sh:136`

**Failure scenario:** impl-check Layer 2 runs `oss report_cross_check "$report" "$spec"`. If `$spec` does not exist (mis-derived path, spec not authored yet) or exists but contains no line matching verify.sh:12's checkbox+`AC-<n>`+`auto:` shape (grammar drift: `->` instead of the U+2192 arrow, a missing checkbox, a wrapped line), `oss_verify_parse_acs` emits zero TSV rows. Because it is invoked as `done < <(oss_verify_parse_acs "$2")`, its rc 2 is discarded and the while loop never iterates, so `missing` stays `""` and line 137's `[ -z "$missing" ]` succeeds -> return 0. The gate reports 'every auto: AC is accounted for' about a report it never cross-checked. This is the one selector in the tree that folds could-not-check into clean; its siblings (registries.sh:54/56/115, ledger.sh:147) all go to lengths to return rc 2 = INCONCLUSIVE precisely so this cannot happen.

**Evidence:**

```
$ printf 'AC-1 auto: `false` -> expected: exit 0\n' > drifted-spec.md; printf 'nothing here\n' > rpt.md
$ bash ossify/bin/oss verify_acs drifted-spec.md; echo "verify_acs rc=$?"
verify_acs rc=0                      # zero rows, silent
$ bash ossify/bin/oss report_cross_check rpt.md drifted-spec.md; echo "rc=$?"
rc=0                                 # CLEAN, against a report naming no AC at all
$ bash ossify/bin/oss report_cross_check rpt.md /no/such/spec.md; echo "rc=$?"
oss: spec not found: /no/such/spec.md
rc=0                                 # stderr leaks out of the process substitution; the rc does not

Control (the gate does work on well-formed input):
$ bash ossify/bin/oss report_cross_check empty-report.md spec.md; echo "rc=$?"
oss: report does not account for: AC-1 AC-2 AC-3
rc=1

Documented contract that does not hold — skills/close/references/impl-check.md:95:
  oss report_cross_check "$report" "$spec"    # 0 accounted-for | 1 missing | 2 report not found
(no code is documented for an unreadable spec, and the function's own header at verify.sh:120-121 says "Every `auto:` AC in the spec must be accounted for in the report")

No test covers it: tests/test-verify.sh:75-100 and tests/test-close.sh:225-235 exercise only well-formed specs. `bash test-verify.sh` -> pass=33 fail=0, `bash test-close.sh` -> pass=158 fail=0.
```

**Fix:** Mirror the report guard onto the spec, and distinguish could-not-check from clean the way the sibling selectors do. Add `[ -f "$2" ] || { echo "oss: spec not found: $2" >&2; return 2; }` at verify.sh:124, and materialise the rows before the loop so a zero-row spec is rc 2 rather than rc 0: `rows="$(oss_verify_parse_acs "$2")" || return 2; [ -n "$rows" ] || { echo "oss: spec '$2' declares no parseable auto: AC — the cross-check is INCONCLUSIVE, not clean" >&2; return 2; }` then `done <<< "$rows"`. Update impl-check.md:95's rc comment to spell the new code, and add the rc-2 arm to §3.

## [MAJOR] impl-check Layer 1 (the shipped halt loop) reports green and prints nothing when the spec yields zero auto: rows — `rc` is initialised to 0 and the loop never runs

**File:** `ossify/skills/close/references/impl-check.md:45`

**Failure scenario:** The orchestrator-side per-work-item gate runs the block at impl-check.md:39-47. `rc=0` is set before the loop, and the loop is fed by `done < <(oss verify_acs "$spec")`, whose rc is discarded. If `$spec` is mis-pathed, or exists but its AC lines drifted from verify.sh:12's grammar, verify_acs emits zero rows, the loop body never executes, `rc` stays 0, and line 46's `[ "$rc" -eq 0 ] || exit "$rc"` passes. Layer 2 then also passes (see the sibling finding), so the ceremony's own contract — "Halt on the first failure in any layer" (impl-check.md:7-8) — is satisfied vacuously with ZERO acceptance criteria executed. In the grammar-drift case the block emits no stdout and no stderr at all, which is exactly the failure mode impl-check.md:118-124 argues against in prose ("A mechanical gate that silently passes is worse than an honest judgment call"). Live trigger: any work item whose spec's AC section was authored slightly off-grammar — and plan-spine/references/spec-authoring.md:37 names "Machine-checkable `auto:` lines" without ever showing the concrete `- [ ] AC-N auto: \`cmd\` -> expected: <exit n|output contains s>` template, so drift has no upstream template to anchor on. The only guard anywhere is work-item/references/pre-flight.md:50-57, which is an agent-judgment check run by a different actor (the implementer) and covers only the visible-AC-lines case.

**Evidence:**

```
Extracted the shipped block verbatim and ran it under real strict mode with an `oss` PATH shim, exactly as tests/test-close.sh:195-196 does:

$ awk '/^```bash$/{inb=1;buf="";next} /^```$/{if(inb && buf ~ /while IFS=/){printf "%s", buf; exit} inb=0; next} inb{buf=buf $0 "\n"}' ossify/skills/close/references/impl-check.md > layer1.sh

(a) missing spec:
$ env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; wt='$PWD/wt'; spec='$PWD/does-not-exist.md'; . layer1.sh; echo LAYER1_RESULT_rc=\$?"
oss: spec not found: /.../does-not-exist.md
LAYER1_RESULT_rc=0
outer rc=0

(b) spec present, ACs written without the checkbox (grammar drift) — COMPLETELY SILENT:
$ printf 'AC-1 auto: `false` -> expected: exit 0\nAC-2 auto: `false` -> expected: exit 0\n' > nocheckbox.md
$ env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; wt='$PWD/wt'; spec='$PWD/nocheckbox.md'; . layer1.sh; echo LAYER1_RESULT_rc=\$?"
LAYER1_RESULT_rc=0
outer rc=0

control (well-formed spec, failing AC — the gate does work):
$ printf -- '- [ ] AC-1 auto: `false` \xe2\x86\x92 expected: exit 0\n' > good.md
$ env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; wt='$PWD/wt'; spec='$PWD/good.md'; . layer1.sh"
oss: rc=1, wanted 0
[AC] AC-1 `false` did not satisfy 'exit 0' (rc 1)
outer rc=1

work-item-close.md:107's `[ -f "$spec" ] || { echo "close: no spec.md ..."; exit 1; }` covers case (a) on the close path only; nothing anywhere covers case (b).
```

**Fix:** Make the empty row-set an explicit halt in the shipped block rather than a fall-through. Replace `done < <(oss verify_acs "$spec")` with a materialised capture and a count guard: `acs="$(oss verify_acs "$spec")"` / `[ -n "$acs" ] || { echo "[AC] $spec declares no parseable auto: AC — the gate cannot verify anything; re-author the criteria (impl-check.md §6 option 3)"; exit 2; }` / `while IFS="$(printf '\t')" read -r label cmd exp; do ... done <<< "$acs"`. Add the zero-rows case to impl-check.md §7 Anti-patterns, and add a test-close.sh assertion driving the extracted block against a zero-row spec expecting nonzero (the extraction guard at test-close.sh:200-205 already exists to keep it honest).

## [MAJOR] The work-item close merge block's wrong-branch guard has zero executable coverage — deleting it leaves all 24 test files green

**File:** `ossify/skills/close/references/work-item-close.md:170`

**Failure scenario:** An edit (or an agent following a paraphrase) drops or breaks lines 170-173 of work-item-close.md. Canonical is parked on the base branch rather than the spine branch — the exact state test-worktree.sh's negative control reproduces. `git -C "$canonical" merge --no-ff "$wi_branch"` then lands the work item on the BASE branch at rc 0, `merge-base --is-ancestor "$wi_sha" HEAD` is satisfied (HEAD is the base branch), `oss work_item_status "$wi" complete` is written, spine close reads `complete` as 'this item's work is on the spine branch', and the cumulative demo measures a tree assembled by accident. The prose itself says this failure 'succeeds silently at rc 0' — and no test observes the guard. Its exact twin in spine-close.md:84-85 IS covered.

**Evidence:**

```
Verified against HEAD 70b0463. Current content confirmed with a fresh grep:
  $ grep -n 'head_branch|spine_branch=' ossify/skills/close/references/work-item-close.md
  170:spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"
  171:head_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"
  172:[ "$head_branch" = "$spine_branch" ] \
  173:  || { echo "close: canonical is on '$head_branch', not '$spine_branch' - halt"; exit 1; }

MUTATION (in a scratch copy; the repo was never edited — `git status --porcelain ossify/` is empty). Deleted lines 170-174 outright; echoed the region back to confirm the mutation applied:
  wi_branch="$(oss get ...)"
  [ -n "$wi_branch" ] && [ "$wi_branch" != "null" ] || { ... }
  # The spine branch: in the round flow it is already in scope; standalone,
  # recompose it from the slug step 1 recovered.
  git -C "$wt" commit -m "<message>"        <-- guard gone

Full suite on the mutant (all 24 files), byte-identical pass counts to baseline, zero failures:
  test-close.sh: pass=158 fail=0        test-worktree.sh: pass=53 fail=0
  test-integration-close.sh: pass=84 fail=0   test-skill-bash-blocks.sh: pass=33 fail=0
  test-prose-contracts.sh: pass=9 fail=0  ... (every file fail=0)

Control, proving the harness CAN see this shape when it executes the block: the same neutering applied to spine-close.md:84-85 gives test-close.sh pass=152 fail=6, including `FAIL: wrong-branch halt - the spine reached master anyway`.

Root cause: test-close.sh extracts and executes blocks from spine-close.md, release-close.md, impl-check.md and patch-lane.md (`
```

**Fix:** Extract work-item-close.md §4's block with the same `_extract_block` helper already in test-close.sh and run it under `set -euo pipefail` against the section-C fixture, mirroring E2: park canonical on `$BASE_BRANCH`, assert rc 1, assert the message names both branches, and assert `merge-base --is-ancestor "$WI_SHA" "$SPINE_BRANCH"` is still false. If it is genuinely not to be executed this release, say so explicitly in test-close.sh's NOT-COVERED header alongside the router and the gate ordering.

## [MAJOR] The spine-branch cut in round-orchestration.md can be reverted to `git branch` (the documented regression) with no RED anywhere

**File:** `ossify/skills/work-item/references/round-orchestration.md:57`

**Failure scenario:** Line 57 is changed from `git -C "$canonical" checkout -q -b "$spine_branch"` to `git -C "$canonical" branch "$spine_branch"`. The ref is created but canonical stays on its previous branch. Every downstream step is then rc 0: each work item is spawned off the right base, each work-item merge lands on the base branch instead of the spine, spine close's merge is 'Already up to date', and the cumulative demo measures a tree the spine never reached. This is the failure round-orchestration.md itself calls out twice (its `**checkout -b, not branch**` note and its gotcha list line 238 'the whole failure chain is rc 0'), and it is the same class as the three P0s this series shipped.

**Evidence:**

```
Current content confirmed at HEAD:
  $ grep -n 'checkout -q -b' ossify/skills/work-item/references/round-orchestration.md
  57:git -C "$canonical" checkout -q -b "$spine_branch"

MUTATION in a scratch copy, echoed back to confirm it applied:
  $ sed -n '57p' round-orchestration.md
  git -C "$canonical" branch "$spine_branch"

Full suite on the mutant — every file green, counts identical to baseline:
  test-close.sh: pass=158 fail=0            test-worktree.sh: pass=53 fail=0
  test-integration-close.sh: pass=84 fail=0 test-spine-planning.sh: pass=86 fail=0
  ... 24/24 fail=0

test-worktree.sh:150-247 DOES test this lifecycle and even ships the negative control for it — but it re-types the git commands itself (`git -C "$TMP/canon" checkout -q -b "$SPINE_BRANCH"`, tests/test-worktree.sh:165) rather than sourcing the shipped block, so the assertion's subject is the test's own fixture, not the artifact that ships. The only test that reads round-orchestration.md is test-close.sh:134, which greps it for the docs-path shape string.
```

**Fix:** Extract round-orchestration.md §2's block the way test-close.sh extracts spine-close.md's, run it under strict mode against test-worktree.sh's canonical fixture, and assert `git -C "$canon" rev-parse --abbrev-ref HEAD` equals the spine branch afterwards — the one observable that `git branch` cannot satisfy.

## [MINOR] An interrupted mutation leaks the mkdir lock permanently; the remedy the error message names cannot clear it, and no unlock verb exists

**File:** `ossify/lib/state.sh:256`

**Failure scenario:** There is no `trap` anywhere in ossify (`grep -rn 'trap ' lib/ bin/ tests/harness.sh` finds only a prose comment in manifest.sh:4). If an `oss` mutation is interrupted between `mkdir "$lock"` (256) and `rmdir "$lock"` (265) — ESC on an agent-driven ceremony, a killed session, a crash — `$sf.lock` survives forever. Every subsequent mutation returns rc 3 with the message `… retry or run 'oss doctor'`, but `oss doctor` (doctor.sh:22-30) prints only `warn: lock - held (a ceremony may be mid-mutation)` and offers no remedy until the dir is >30 minutes old, and there is no `oss` subcommand that clears a lock (`oss help | grep -ci lock` → 0). So the remedy the failure message names is inert for the first 30 minutes — the same defect class the team explicitly fixed for the replay drift message (tests/test-state-replay.sh:20-31: "A remediation string naming a command that cannot repair is worse than naming none"). Compounding it, skills/close/SKILL.md:115-116 tells the agent that a held lock is a `warn:` line and "not a blocker here" — so a close ceremony proceeds past a leaked lock and then fails rc 3 on every mutating step.

**Evidence:**

```
$ bash slow.sh s.json &          # _oss_now shadowed to sleep 30, real `set -euo pipefail`
$ sleep 2; [ -d s.json.lock ] && echo 'lock acquired (expected)'
lock acquired (expected)
$ kill -INT $P; sleep 1; kill -9 $P
$ [ -d s.json.lock ] && echo LOCK-LEAKED
LOCK-LEAKED
$ oss posture_set fully-private
oss: state locked (…/s.json.lock exists) - another ceremony is mutating; retry or run 'oss doctor'
rc=3
$ oss doctor | sed -n 1,3p
ok: schema - v3
warn: lock - held (a ceremony may be mid-mutation)
ok: replay - replay: clean (1 mutations)
$ oss help 2>&1 | grep -ci 'unlock\|lock'
0
```

**Fix:** Either (a) add `trap 'rmdir "$lock" 2>/dev/null || true' EXIT INT TERM` around the critical section in `oss_state_mutate`/`oss_state_restore` (set inside a subshell so it does not clobber a caller's trap), or (b) ship an explicit `oss state_unlock` verb and name *it* — not `oss doctor` — in the rc-3 message, and have doctor print the concrete `rmdir` remedy for a held lock at any age rather than only past 30 minutes.

## [MINOR] plan-spine's cross-repo lane documents two verifications the shipped impl-check and spine close do not perform, and never says cross-repo execution is unbuilt

**File:** `ossify/skills/plan-spine/references/cross-repo.md:66`

**Failure scenario:** A planner following plan-spine/SKILL.md:148-151 ("pass the private-side repo (e.g. `private_core`) for an item that lands there") and cross-repo.md records `oss work_item_add "$spine" "adapter" private_core`, plans rounds per cross-repo.md §2, and is told at :66-67 that "Implementation-check and spine close verify its [the dependency override's] absence from staged and tracked content". Neither ceremony does: grep for `override` across skills/close/ and skills/work-item/ returns only unrelated hits (recovery overrides, disposition `override`). At dispatch the round then halts at rc 2 out of `_oss_repo_root` because no manifest configures private_core — an honest halt, but one the planning skill gave no warning about. The wasted work is a whole spine decomposition; the false contract is two verification steps a reader believes are guarding them.

**Evidence:**

```
  $ grep -n "Implementation-check and spine close verify" ossify/skills/plan-spine/references/cross-repo.md
  66:- **It is never committed.** Implementation-check and spine close verify its

  $ grep -rni "override" ossify/skills/close/ ossify/skills/work-item/
  (10 hits, all recovery-menu overrides / veto disposition `override` / skip-escape overrides — none is a staged-or-tracked check for a dependency override)

The honest statement exists, but only in the execution skill loaded after planning: round-orchestration.md:121-124 — "Only `canonical` resolves today; an item declaring another repo halts at rc 2 out of the manifest lookup ... cross-repo execution is a later release". cross-repo.md says only "Spinning the multi-repo worktrees up is the execution engine's job, not this skill's" (:74-75), which reads as a division of labour, not as an unbuilt feature. Confirmed the halt is real: worktree.sh:17-22 resolves `.private_core.root` from the manifest and returns 2 ("repo 'private_core' is not configured in the pairing manifest") rather than falling back.
```

**Fix:** Add one line at the top of cross-repo.md mirroring round-orchestration.md:121-124 — cross-repo execution is a later release, an item declaring a non-canonical repo halts at rc 2 today — and either mark §3's two verification sentences as the future contract or drop them until the checks exist.

## [MINOR] `start` names the `doctor` entry skill as a live peer that owns state inspection and spec validation; it does not exist and its deferral is unstated

**File:** `ossify/skills/start/SKILL.md:494`

**Failure scenario:** A user finishing spec-core reads start/SKILL.md §'s tool-boundaries block and is told "the `doctor` entry skill owns state inspection and spec validation (distinct from the `oss doctor` subcommand above, which is its mechanical half)". They ask for spec validation or a lean-spec check and there is nothing to invoke — no skill directory, no command, no reference. Nothing in the sentence marks it as forthcoming, and every other skill it names in the same list (`plan-release`, `plan-spine`) does ship, so the reader has no signal that this one is different.

**Evidence:**

```
  $ sed -n '493,496p' ossify/skills/start/SKILL.md
  - **Peer entry skills:** `plan-release` owns Release 0, spine classes, and the
    critic veto; `plan-spine` owns decomposition and demo lines; the `doctor`
    entry skill owns state inspection and spec validation (distinct from the
    `oss doctor` subcommand above, which is its mechanical half).

  $ ls ossify/skills/
  close  plan-release  plan-spine  start  work-item

No routing target exists either — grep for '/doctor', 'Skill(ossify:doctor' and 'ossify:doctor' across skills/, commands/ and agents/ returns zero hits, so nothing actively dispatches to the missing skill. The plan places it in C2 ("Plan C2 — ... The `doctor` entry skill ... the §9.1 routing target"), but the shipped prose never says so.
```

**Fix:** Change the clause to the deferred form used elsewhere in this tree, e.g. "the `doctor` entry skill (spec §9.1) will own state inspection and spec validation — **not shipped in this release**; `oss doctor` is its mechanical half and is the only surface today".

## [MINOR] retrospective.md justifies its pinned headings by claiming the memory-bank harvest sweeps retrospectives; harvest.md enumerates only report.md and handoff.md and forbids touching the retro

**File:** `ossify/skills/close/references/retrospective.md:9`

**Failure scenario:** An agent running spine close reads retrospective.md before authoring step 8 and learns that step 9's harvest sweeps retrospective files. At step 9 it enumerates candidate lines out of the retro it just wrote and presents them — but harvest.md §6 requires every candidate's first line to start with the literal `[report]` or `[handoff]` (there is no `[retro]` tag), harvest.md §2 enumerates only `<spine_dir_abs>/work-<wi-id>/report.md` and `handoff.md`, and harvest.md §9 explicitly forbids writing back into the retro. The two references disagree about the harvest's input set, and the one a reader hits first is the wrong one.

**Evidence:**

```
  $ grep -n "harvest" ossify/skills/close/references/retrospective.md
  9:contract uses, and for the same reason: the memory-bank harvest (step 9) sweeps

(context, retrospective.md:7-11: "Headings exactly as written ... and for the same reason: the memory-bank harvest (step 9) sweeps these files, and a heading invented per spine makes the retro series unreadable as a series.")

harvest.md contradicts it in three places: :9-11 "it moves a handful of durable lines out of artifacts nobody re-reads (`report.md`, `handoff.md`)"; :71-73 the two composed input paths are `<spine_dir_abs>/work-<wi-id>/report.md` and `.../handoff.md`; :219-221 "The retro is authored at **step 8** and is a completed artifact ... editing a document the ceremony already finished". The only tags the payload accepts are `report` and `handoff` (harvest.md:172-173, and rc 2 rejects the whole payload on any other source).
```

**Fix:** Rewrite retrospective.md:7-11's justification to the true one — the pinned headings make the retro series readable across spines and feed the release retro's roll-up (release-close.md §6) — and drop the harvest claim, or narrow it to "the harvest sweeps each work item's report.md and handoff.md, not this file".

## [MINOR] `oss_worktree_dir` was built in Plan C1 and has zero callers anywhere — not in the dispatcher, not in another lib, not in any test

**File:** `ossify/lib/worktree.sh:26`

**Failure scenario:** Dead code shipped at close. There is no `oss_cmd_worktree_dir`, so prose cannot reach it (bin/oss dispatches only `oss_cmd_*`), and no lib calls it — `oss_worktree_add`, `oss_worktree_resolve`, `oss_worktree_list` and `oss_worktree_remove` each recompose `$root/.worktrees` inline instead. It therefore also carries no test, so a future divergence between it and the four inline compositions has no signal.

**Evidence:**

```
$ grep -rn '\boss_worktree_dir\b' ossify/lib ossify/bin ossify/tests ossify/skills
ossify/lib/worktree.sh:26:oss_worktree_dir() { # $1=repo-key
$ grep -c 'oss_cmd_worktree_dir' ossify/lib/commands.sh
0
$ git log --oneline main..HEAD -- ossify/lib/worktree.sh | tail -1
d4b4438 feat(ossify): repo-parameterized worktree layer
```

**Fix:** Either delete it, or make the four inline `$root/.worktrees` compositions call it so the path shape has one owner.

## [MINOR] round-orchestration.md's `target_repo` contract is false for `ai_workspace`: the documented rc-2 halt does not fire and a worktree is created inside the AI workspace

**File:** `ossify/skills/work-item/references/round-orchestration.md:121`

**Failure scenario:** A work item is created as `oss work_item_add r1.s2 "docs item" ai_workspace`. §3 promises "Only `canonical` resolves today; an item declaring another repo halts at rc 2 out of the manifest lookup". It does not: `_oss_repo_root` accepts `canonical|ai_workspace|private_core` (worktree.sh:14) and every workspace-init manifest configures `.ai_workspace.root`, so `oss worktree_add ai_workspace ...` returns rc 0 and creates `<ai-workspace>/.worktrees/<wi>` with a `work/<wi>-<slug>` branch in the AI workspace repo. The failure moves downstream to work-item-close §4, whose merge runs `git -C "$(oss repo_root canonical)" merge "$wi_branch"` against a branch that exists only in the other repo. `private_core` does halt as documented; `ai_workspace` does not.

**Evidence:**

```
$ oss work_item_add r0.s1 "docs" ai_workspace
r0.s1.w1
$ oss get '.work_items[0].target_repo'
ai_workspace
$ oss worktree_add ai_workspace r0.s1.w1 slug main; echo rc=$?
/…/seam4/ai/.worktrees/r0.s1.w1
rc=0
$ oss repo_root private_core; echo rc=$?
oss: repo 'private_core' is not configured in the pairing manifest
rc=2
```

**Fix:** Either restate the prose accurately ("`private_core` halts at rc 2 because the manifest does not configure it; `ai_workspace` resolves and must not be used as a work-item target repo"), or add an explicit allowlist on the work-item path so only `canonical` (and later `private_core`) is accepted as a `target_repo`. The stale sibling comments at ossify/lib/commands.sh:174 and ossify/lib/worktree.sh:6 ("Plan D adds `private_core`" — it is already in the case list) should move with it.

## [MINOR] `close_records` is write-only state built in Plan C1, and the `work_item` scope arm of `oss demo_record` has no call site while release-close.md asserts it does

**File:** `ossify/lib/demo.sh:94`

**Failure scenario:** `oss demo_record` is called at spine close step 11 and release close step 7, journaling `add_close_record` into `.close_records`. Nothing ever reads `.close_records` — no lib function, no skill prose, no ceremony (the release retro aggregates the walkthrough and the per-spine retrospective.md files, not the close records). Separately, `oss_demo_record_close` accepts scope `work_item`, and release-close.md:300 tells the reader "the same verb records `work_item` and `spine` closes" — but work-item close (close/SKILL.md §4's six steps and references/work-item-close.md's six steps) has no `demo_record` step at all, so no work_item close record is ever written. A reader who trusts that sentence and later queries close records by scope finds the work_item bucket permanently empty with no signal that it was never populated.

**Evidence:**

```
$ grep -rn 'close_records' ossify/skills ossify/lib | grep -v tests
ossify/lib/state.sh:24:    close_records:[],
ossify/lib/state.sh:181:…comment…  ossify/lib/state.sh:195:…migration…  ossify/lib/state.sh:212:      jq --argjson p "$payload" '.close_records += [$p]' ;;
ossify/lib/doctor.sh:53:  for key in … close_records mutations; do   # shape check only
# zero hits under ossify/skills — no prose reader.
$ grep -rn 'oss demo_record' ossify/skills
close/SKILL.md:202, close/SKILL.md:247, spine-close.md:356, cumulative-demo.md:148, release-close.md:294
# every one is scope `spine` or `release`; none is `work_item`.
$ sed -n '300p' ossify/skills/close/references/release-close.md
same verb records `work_item` and `spine` closes, and the scope is what
```

**Fix:** Either give the record a reader (the release retro is the natural one — "every close record for this release, with its demo outcome") or say plainly in prose that `.close_records` is an audit trail with no consumer in this release. And correct release-close.md:300, which claims a work_item close record that no ceremony writes.

## [MINOR] round-orchestration.md §1 hands the reader `oss spine_dir`'s relative path as the place to read the spine plan, with none of the `repo_root ai_workspace` prefixing every sibling consumer insists on

**File:** `ossify/skills/work-item/references/round-orchestration.md:23`

**Failure scenario:** The lane's very first step is "the rounds live in the spine plan document, under: `oss spine_dir "<release-id>" "<spine-id>" "<spine-slug>"` … Read them from there." That verb returns `docs/specs/<rel>/<spine>-<slug>` — a RELATIVE path. The orchestrator session's $PWD is unconstrained (close/SKILL.md §3 explicitly forbids `cd` for exactly this reason), so an agent following the line literally reads against $PWD and finds nothing, or finds a same-named path in the wrong repo. Every other consumer of the verb warns about this in the same breath — work-item-close.md:94, harvest.md:75-78, release-close.md:236-239 and its anti-pattern at :349 ("Feeding `oss spine_dir`'s relative path to a file test unprefixed — every spine then looks retro-less"). §1 is the one place the warning is missing, and it is the first instruction in the lane.

**Evidence:**

```
$ sed -n '22,25p' ossify/skills/work-item/references/round-orchestration.md
```bash
oss spine_dir "<release-id>" "<spine-id>" "<spine-slug>"   # docs/specs/<release-id>/<spine-id>-<slug>
```
$ sed -n '94,95p' ossify/skills/close/references/work-item-close.md
- **`oss spine_dir` returns a RELATIVE path** — `docs/specs/<rel>/<spine>-<slug>`
$ sed -n '236,239p' ossify/skills/close/references/release-close.md
**`oss spine_dir` returns a relative path**; prefix it with
`oss repo_root ai_workspace`. Feeding the relative path straight to `[ -f ... ]`
resolves it against `$PWD` and answers "absent" for every spine…
```

**Fix:** Prefix it in §1 the way the siblings do: `"$(oss repo_root ai_workspace)/$(oss spine_dir …)"`, with the same one-line warning.

## [MINOR] fake-ledger-discipline.md states the release-close expiry gate does not read `status`; it does, and acting on the false version produces a phantom blocking finding

**File:** `ossify/skills/plan-spine/references/fake-ledger-discipline.md:67`

**Failure scenario:** A project has a fake on `boundary: broker` that was genuinely resolved — `oss fake_status broker replaced "real adapter landed"` — but whose `expiry_release` still reads `r1`. At r2's close, an agent that has read fake-ledger-discipline.md §3 ("the release-close expiry check reads `expiry_release`, not `status`") reasons that the past expiry blocks regardless of status, and reports `broker` as a blocking fake-expiry finding. Release close halts on a fake that the real gate correctly passes, and the only unblocks the ceremony offers (replace / renew) are both meaningless for a fake that is already `replaced`. The statement is also the exact inverse of the doctrine fake-expiry.md §3 is built on — that `renewed` being *inside* the selector is what stops a renewal escaping its own deadline — so the two shipped docs contradict each other about the same three lines of jq.

**Evidence:**

```
$ sed -n '66,68p' ossify/skills/plan-spine/references/fake-ledger-discipline.md
deadline. `expiry_release` stays exactly what it was. This is deliberate: the
release-close expiry check reads `expiry_release`, not `status`, so a
`renewed` call with no new expiry changes nothing that check enforces.

The selector reads BOTH (lib/registries.sh:107):
      | select(.status == "active" or .status == "renewed")

EXECUTED against a two-fake fixture, both with expiry r1, closing r2:
$ cat /tmp/fk.json
{"fakes":[{"boundary":"broker","status":"replaced","expiry_release":"r1",...},
          {"boundary":"vendor","status":"renewed","expiry_release":"r1",...}]}
$ bash -c '. lib/registries.sh; oss_reg_expired_fakes /tmp/fk.json r2; echo rc=$?'
vendor	renewed	r1	sandbox ships
rc=1

The `replaced` fake with the identical past expiry does not appear — status is read, and it is decisive.

Contradicted head-on by the peer doc:
$ sed -n '83,85p' ossify/skills/close/references/fake-expiry.md
### `renewed` is inside the selector, and it is the entry most in need of it
The fake vocabulary is `active | replaced | renewed`, and **`replaced` is the
only resolving status**.
```

**Fix:** Replace the false clause at fake-ledger-discipline.md:66-68 with the true reason, which reaches the same conclusion: the gate selects on `status == active or renewed` AND on `expiry_release`, so a `renewed` call with no new expiry keeps the record inside the selector with its old deadline — it stays due and stays blocking. Cross-reference `close/references/fake-expiry.md` §3 so the two files cannot drift again.

## [MINOR] spine-close.md's merge block uses `$spine_slug` with no assignment anywhere in the document, and the section it cites for the recovery contains no recovery code

**File:** `ossify/skills/close/references/spine-close.md:82`

**Failure scenario:** An agent runs `/close r1.s2` standalone and works spine-close.md §3 top to bottom. The prose says the spine slug is "recovered, not guessed" and points at `round-orchestration.md` §2 — which only says in prose to "recover it from that directory name" and offers no code. Nothing in spine-close.md assigns `spine_slug`, so the very first line of the merge block expands it empty (or aborts on unbound under `set -u`). `oss branch_name r1.s2 ""` returns `spine/r1.s2-`, the HEAD assertion on the next line fails, and the close halts reporting `canonical is on 'spine/r1.s2-toc', not 'spine/r1.s2-'` — which reads as "canonical is parked on the wrong branch" (a real and different failure with a different recovery) rather than "you never resolved the slug". The contrast is visible five lines down: `base_branch`, the sibling unpersisted fact, gets an explicit `[ -n "${base_branch:-}" ]` guard with its own named halt; `spine_slug` gets neither a guard nor a citation to the code that produces it.

**Evidence:**

```
$ grep -n 'spine_slug' ossify/skills/close/references/spine-close.md ossify/skills/close/SKILL.md
ossify/skills/close/references/spine-close.md:82:spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"
(single occurrence in the whole close skill; close/SKILL.md §5 ships no bash at all)

The cited section has no code for it:
$ sed -n '88,93p' ossify/skills/work-item/references/round-orchestration.md
**The slug is not in state.** Spines store `name`, work items store `title`;
neither is a kebab slug, and nothing persists one. `plan-spine` minted the spine
slug when it created the spine directory — **recover it from that directory
name** rather than re-kebabing `name`, ...

The code that does exist is in a file spine-close.md never cites for this:
$ sed -n '81,86p' ossify/skills/close/references/work-item-close.md
matches="$(find "$ai_root/docs/specs/$rel_id" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "close: expected exactly one spine dir for $spine_id, found $n - halt"; exit 1; }
spine_dir_abs="$matches"
spine_slug="$(basename "$spine_dir_abs")"; spine_slug="${spine_slug#"$spine_id-"}"

EXECUTED the empty case:
$ ./bin/oss branch_name r1.s2 ""
spine/r1.s2-

(harvest.md §2 hits the same need and handles it correctly — it inlines the glob and cites `work-item-close.md` §1 Route B by name.)
```

**Fix:** In spine-close.md §3, either inline the four-line glob-and-strip recovery (as harvest.md §2 already does for the same fact) or cite `work-item-close.md` §1 Route B explicitly instead of `round-orchestration.md` §2, and add a `[ -n "${spine_slug:-}" ] || { echo "close: could not recover the spine slug for $spine_id - halt"; exit 1; }` guard beside the existing `base_branch` guard so the failure names itself.

## [MINOR] Bare $HOME under `set -u` aborts every state-resolving verb when HOME is unset

**File:** `ossify/lib/manifest.sh:71`

**Failure scenario:** bin/oss runs `set -euo pipefail`. manifest.sh:71 (`ai_root="${ai_root//\$\{HOME\}/$HOME}"`), manifest.sh:56 and harvest.sh:79 dereference `$HOME` bare. In an environment where HOME is unset — a bare `env -i` invocation, a cron/launchd job, a container entrypoint, a CI runner that scrubs the env — the parameter expansion is a fatal set -u error raised before any of the function's own rc machinery, so `oss state_path`, `oss doctor`, and every verb routed through `_oss_resolve_state` die with an unbound-variable message pointing at a lib file rather than the documented refusal. commands.sh:143-147 documents this exact hazard for `${HOME:-}` in oss_cmd_critic_detect and asserts the sibling was already guarded; these three sites were not.

**Evidence:**

```
$ cd <fixture ws with a pairing manifest>
$ env -u HOME bash ossify/bin/oss state_path; echo "rc=$?"
/Users/draco/projects/claude-agent-scaffolding/ossify/lib/manifest.sh: line 71: HOME: unbound variable
rc=1
$ env -u HOME bash ossify/bin/oss doctor; echo "rc=$?"
/Users/draco/projects/claude-agent-scaffolding/ossify/lib/manifest.sh: line 71: HOME: unbound variable
rc=1

$ grep -n 'HOME' ossify/lib/manifest.sh ossify/lib/harvest.sh ossify/lib/commands.sh
ossify/lib/manifest.sh:56:  result="${result//\$\{HOME\}/$HOME}"
ossify/lib/manifest.sh:71:  ai_root="${ai_root//\$\{HOME\}/$HOME}"
ossify/lib/harvest.sh:79:  ai_root="${ai_root//\$\{HOME\}/$HOME}"
ossify/lib/commands.sh:148:  for cache in "${HOME:-}/.claude/plugins/cache" "${CLAUDE_PLUGINS_DIR:-}"; do   # already guarded

Contrast: `env -u HOME bash ossify/bin/oss critic_detect` -> `absent`, rc 1 (the guarded site behaves correctly).
```

**Fix:** Use the same `${HOME:-}` form the guarded site already uses, at manifest.sh:56, manifest.sh:71 and harvest.sh:79 — e.g. `ai_root="${ai_root//\$\{HOME\}/${HOME:-}}"`. An unset HOME then leaves the token unresolved, which the existing `case "$dest" in ''|*'${'*)` guard at manifest.sh:79-81 / harvest.sh:87-89 already turns into the documented 'unresolved state path' refusal at rc 1.

## [MINOR] The work-item and release status enum guards are unasserted; test-entities.sh's header claims coverage for all three setters

**File:** `ossify/lib/entities.sh:77`

**Failure scenario:** `oss work_item_status r0.s1.w1 completed` (or any other misspelling) is accepted and journaled. Spine close's §2 selector is `.status != "complete"`, so the item is reported open forever and the spine can never close — the ceremony halts naming an item the operator believes is done. The guard exists to catch exactly this; it can be widened to accept anything with no test failure. The same holds for `oss_entity_set_release_status` at line 87.

**Evidence:**

```
Guards confirmed at HEAD:
  $ sed -n '76,78p;86,88p' ossify/lib/entities.sh
    local sf="$1" wi="$2" st="$3"
    case "$st" in planned|active|complete) ;; *)
      echo "oss: work item status must be planned|active|complete" >&2; return 2;; esac
    local sf="$1" rel="$2" st="$3"
    case "$st" in planned|active|closed) ;; *)
      echo "oss: release status must be planned|active|closed" >&2; return 2;; esac

No test references either message:
  $ grep -rn 'work item status must be|release status must be' ossify/tests/*.sh
  (no output)

MUTATION in a scratch copy, both case lists widened to `...|anything`, echoed back:
    case "$st" in planned|active|complete|anything) ;; *)
    case "$st" in planned|active|closed|anything) ;; *)
Result: test-entities.sh pass=33 fail=0, test-close.sh pass=158 fail=0, test-integration-close.sh pass=84 fail=0, test-spine-planning.sh pass=86 fail=0, test-release-planning.sh pass=39 fail=0.

The claim: tests/test-entities.sh:80 reads `# Status transitions: bad enum -> rc 2; unknown id -> rc 7 AND nothing mutated.` but only the SPINE setter's enum arm is asserted (line 84, `t_assert_rc 2 "spine status rejects an unknown enum value"`); the work-item and release setters get only their rc-7 unknown-id arms (lines 92-96). Fails closed, hence minor.
```

**Fix:** Add the two missing enum assertions next to the existing spine one in tests/test-entities.sh: `t_capture oss_entity_set_work_item_status "$S" "$WI" completed; t_assert_rc 2 ...` and `t_capture oss_entity_set_release_status "$S" r0 shipped; t_assert_rc 2 ...`, each paired with a journal-count-unchanged read like the spine case already has.

## [MINOR] critic_detect's v0.2 arm is unassertable — only v0.3 has a hermetic fixture and the ambient assertions accept any legal answer

**File:** `ossify/lib/commands.sh:155`

**Failure scenario:** On a machine with architect-critic v0.2 installed, `oss critic_detect` misreports the version (or reports a value the skills' prose does not document). skills/start/references/critic-moment.md:32 and close/references/spine-close.md:255 both document `v0.2` as a distinct answer. Mutating line 155 to emit any other string is invisible to the suite: the two ambient assertions (tests/test-dispatcher-ops.sh:137 and :144) accept `v0.2|v0.3|absent`, and the only hermetic fixture builds the v0.3 directory shape.

**Evidence:**

```
Guard confirmed at HEAD:
  $ grep -n 'found="v0.2"' ossify/lib/commands.sh
  155:        found="v0.2"

Only hermetic case is v0.3:
  $ grep -n 'v0.3" "$T_OUT"' ossify/tests/test-dispatcher-ops.sh
  178:t_assert_eq "v0.3" "$T_OUT" "a cache carrying managing-async-critique reports v0.3"

MUTATION in a scratch copy, echoed back to confirm it applied:
  $ sed -n '155p' lib/commands.sh
          found="v9.9"
Full suite (all 24 files): NO RED ANYWHERE — every file reported fail=0.
```

**Fix:** Add the mirror of the existing v0.3 fixture (tests/test-dispatcher-ops.sh:169-178): build `$CTMP/mk/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` WITHOUT the managing-async-critique sibling, run with `HOME=/nonexistent CLAUDE_PLUGINS_DIR=$CTMP`, and `t_assert_eq "v0.2"`. Optionally add the mixed-cache case (v0.2 dir + v0.3 dir -> v0.3) that the function's own comment says the rewrite exists for.

## [NIT] demo-authoring.md's section heading says "five floors" over a table of six

**File:** `ossify/skills/plan-spine/references/demo-authoring.md:14`

**Failure scenario:** An agent loading demo-authoring.md to judge a spine's demo contribution reads "## 1. The five floors" and may enumerate F1-F5, dropping F6 — the Release-0 golden-journey `auto:` line, the one floor that plan-spine/SKILL.md:303-306 says Release 0 "does not close without". The table and the §2 read-out both list six, so the error is recoverable, but the heading is the line a skimmer trusts.

**Evidence:**

```
  $ grep -n "five floors\|six floors" ossify/skills/plan-spine/references/demo-authoring.md ossify/skills/plan-spine/SKILL.md
  ossify/skills/plan-spine/references/demo-authoring.md:14:## 1. The five floors
  ossify/skills/plan-spine/SKILL.md:308:Judge the spine's whole contribution once, out loud, against all six floors, and

The table immediately under that heading (demo-authoring.md:16-23) lists F1 through F6, and the read-out at :29-42 has six rows.
```

**Fix:** Change the heading to "## 1. The six floors".

## [NIT] spec-authoring.md names `implementation-checking` — a scaffold-dev skill that does not exist in ossify — as the runner of work-item ACs

**File:** `ossify/skills/plan-spine/references/spec-authoring.md:79`

**Failure scenario:** The §4 table row that tells an author who will run a work-item AC points at `implementation-checking`. That is the predecessor stack's skill name; ossify has no such skill and no such reference file. In ossify the work-item gate is `close` §4 via `close/references/impl-check.md`. An author (or an agent) following the citation to decide what an AC must be shaped for goes looking for a contract that ships nowhere in this plugin — and the harness cannot see it, because check 5 only resolves `references/*.md` pointers, not bare skill names.

**Evidence:**

```
$ sed -n '79p' ossify/skills/plan-spine/references/spec-authoring.md
| Run by | `implementation-checking` at the item's gate | The cumulative demo, at every future spine close |
$ ls ossify/skills
close  plan-release  plan-spine  start  work-item
$ grep -rn 'implementation-checking' ossify/skills | wc -l
       1
```

**Fix:** Replace with ossify's own owner: `close` §4 / `close/references/impl-check.md`.

## [NIT] demo-authoring.md's floor table is headed "The five floors" over six rows, contradicting plan-spine/SKILL.md's "all six floors"

**File:** `ossify/skills/plan-spine/references/demo-authoring.md:14`

**Failure scenario:** An agent authoring a Release 0 spine's demo contribution opens demo-authoring.md — the depth file for the floor rules — and reads `## 1. The five floors` above a table listing F1 through F6. The count in the heading is the summary a skimmer trusts, and F6 (Release 0's golden-journey `auto:` line) is the one floor that only applies to r0 and is therefore the easiest to drop as "the extra one". The parent skill says the opposite at SKILL.md:308, so the two documents disagree on how many floors are binding.

**Evidence:**

```
$ grep -n 'The five floors' ossify/skills/plan-spine/references/demo-authoring.md
14:## 1. The five floors
$ sed -n '16,23p' ossify/skills/plan-spine/references/demo-authoring.md | grep -c '^| \*\*F'
6
$ grep -n 'against all six floors' ossify/skills/plan-spine/SKILL.md
308:Judge the spine's whole contribution once, out loud, against all six floors, and
$ grep -nE '^#{2,3} ' ossify/skills/plan-spine/references/demo-authoring.md | tail -2
263:## 7. F6 — Release 0's golden-journey `auto:` line
312:## 8. Anti-patterns
```

**Fix:** Change demo-authoring.md:14 to `## 1. The six floors`.


---

# Checked and found CLEAN

## state and replay safety (spec §9.2) — ossify/lib/state.sh

- All 26 `_oss_apply_op` cases are pure deterministic jq transforms. Enumerated them mechanically (`awk 'NR>=45&&NR<=216' lib/state.sh | grep -oE '^    [a-z_]+\)'` → 26 names: set_posture, set_composition, set_overlay, add_release, add_spine, add_work_item, set_spine_class, add_bone, add_risk_gate, add_fake, add_feature, add_demo_line, set_demo_line_status, set_demo_line_pending, apply_demo_pending, clear_demo_pending, set_fake_status, add_patch_record, set_release_meta, add_veto_disposition, set_spine_status, set_work_item_status, set_release_status, set_work_item_exec, migrate_schema, add_close_record). Grepped the same range for impure jq builtins (now/env/$ENV/input/inputs/input_filename/localtime/strftime/gmtime/mktime/todate/fromdate) → NONE. No `date`, no `$RANDOM`, no filesystem read, no `$ENV` inside any case.
- Timestamps are minted by the CALLER and baked into the payload before journaling. Every `at`/`ts` field is built with `--arg ts "$(_oss_now)"` in the payload builder (entities.sh:5,17,28,40,61,72,82,92; ledger.sh:23,36,58,155; registries.sh:9,16,23,29,128; demo.sh:100), i.e. outside `_oss_apply_op`. `_oss_now` is called exactly once on the write path (state.sh:285) and its value is stored in the journal record, never recomputed at apply time.
- Ids are minted inside the lock and injected into the payload BEFORE journaling (state.sh:276-283), so replay reproduces them verbatim; a caller-supplied id is overridden (verified: `oss_state_mutate ... '{"id":"r99"}' release` stores `r0`).
- Replay is byte-identical on a real 25-op multi-op journal. Built a fixture exercising 22 of the 26 ops (release/spine/work-item add + status + exec, class override, bone, risk gate, fake + fake_status, feature, auto + user demo lines, two competing pending amendments from two different spines, apply_pending, quarantine, release_set_meta, veto, patch). Independently re-derived base+journal in a separate process and compared with `cmp` on `jq -S` output → byte-identical. `oss doctor` → `ok: replay - replay: clean (25 mutations)`.
- `set_release_meta`'s allowlist holds: passing `{"exit_criteria":["a"],"id":"HACK"}` left the release record as `{...,"id":"r0","exit_criteria":["a"]}` — the identity key was dropped, not spliced.
- Lock: no leak on any constructible in-band failure. Ran failure injections under real `set -euo pipefail` through a sourced strict-mode script (unknown op, invalid-JSON payload, bogus mint spec, mint-on-missing-parent, empty payload, restore-with-no-base) — every one returned its documented rc with `lockdir=free`. The `|| rc=$?` body-function pattern (state.sh:264, 360) does suspend errexit for the whole body, and every command substitution inside the bodies is itself a subshell, so a `set -u` fatal cannot escape past the `rmdir`.
- Lock: real 12-way concurrent `oss release_add` race — 1×rc 0, 11×rc 3, one release stored, zero duplicate ids, `[.mutations[].seq]` == `[0]`, replay clean, no orphan `*.tmp.*`, lock free. mkdir-based mutual exclusion holds; contention is a hard refuse (rc 3), which matches §9.2's 'defined, not undefined'.
- Migration v1 → v3 with a NON-EMPTY journal replays clean and never re-baselines. Built a genuine v1 fixture (no `close_records` key, no `pending_*` fields, schema_version 1 in BOTH live and base) carrying a 5-entry journal: mutation refused rc 6 naming `oss migrate`; `oss migrate` → v3; `$sf.base.json` still reports `{"sv":1,"cr":false}`; `oss doctor` → `ok: replay - replay: clean (6 mutations)`; concrete values survive (r0, r0.s1, d1 with `pending_amendments:[]`, ADR-1, posture private, close_records []). Note: the shipped tests/test-migration.sh exercises both the v1 and v2 fixtures with an EMPTY journal, so the cross-boundary replay claim was previously untested — it does hold.
- Migration v2 → v3 with a non-empty journal replays clean across the scalar→list `pending_amendments` conversion. Downgraded a real 7-op state to genuine v2 shape (scalar `pending_status/by/reason/at`, base at v2), migrated → `replay: clean (8 mutations)`, base still v2, and d1's list entry carries the original `by:r0.s1` / `at` verbatim with `has("pending_status") == false`.
- `state_restore` genuinely recovers on the drift path, asserted on concrete surviving values (not just a clean-replay rc). Corrupted a 25-op state by wiping `.spines`, `.bones`, `.demo_ledger`, nulling `.project.posture` and rolling `releases[0].status` back to "planned" while leaving `.mutations` intact; `oss state_restore` → rc 0 and the live file came back with spines [r0.s1, r0.s2], class overrides applied (r0.s1 == flesh), bones [ADR-0001], ledger [d1 superseded, d2 quarantined], posture private, release status closed, work item {complete, br/x, abc123}, patch [deadbeef], fake {payments, replaced, r0}, 25 mutations preserved.
- No state-file writer bypasses the lock: the only `> "$1"` outside state.sh is harvest.sh:110, which writes memory-bank markdown, not project-state.json.
- Prose contracts about state safety are accurate where they exist: skills/close/SKILL.md:114-115 names `oss state_restore` and describes it correctly as 'rebuilds the live state from base + journal'; no reference doc claims tamper-evidence or a recovery capability the code lacks.

## Spec delivery + deferral honesty (main spec §6/§6.1/§6.2; companion §4.2/§4.3; §9.1 skill allocation)

- §6.1 core rows are all present in the shipped ceremony and none is conditional: impl-check (close/SKILL.md:137 step 2 -> references/impl-check.md), cumulative demo (SKILL.md:187 step 4), harvest (step 9), state updates (step 11), worktree+branch cleanup (step 10, after harvest). spine-close.md:29-33 restates 'core rows are never skippable' and the class table (spine-close.md:16-27) scopes bone/flesh only to critic depth, retro length and grill offers — never to a core row.
- §6.1's two non-core rows that C1 does NOT ship are named rather than implied: the standalone ADR check (spine-close.md:38-41 'not shipped in this release ... Recorded here as a known gap rather than papered over') and grill gates (spine-close.md:36-37, correctly attributed to plan-spine). The session-handoff half of the 'Handoff / state updates' row is explicitly deferred at spine-close.md:362-365 and again at release-close.md:28.
- §6.2's seven steps are delivered as a status table (release-close.md:21-32): steps 1-4 built (§2/§3/§6/§7 of that file), steps 5 (docs increment), 6 (handoff cleanup) and 7 (release tag / PR gate) each carry an explicit 'not shipped' row with its reason. close/SKILL.md:254-259 repeats the three deferrals in the always-loaded body, so the deferral is visible without loading the reference.
- D2's machine-checkable-rule-evaluator deferral is stated where a reader looks for the feature: impl-check.md:118-124 ('This layer is agent judgment in this release, and that is a decision rather than an omission') and harvest.md:126-130 ('rule authoring is deferred to Plan C2 — this release ships none').
- §6.1's ledger-operations contract is delivered end to end: the wall-clock budget is set only at release planning (plan-release/SKILL.md:184-206, 'No later ceremony sets this budget') and surfaced-never-pruned at close (cumulative-demo.md:121-138); quarantine-as-parking-ticket is enforced at the release boundary (release-close.md:161-206); the 'grouped by feature' walk is derived rather than read off a nonexistent field (release-close.md:117-130) and the spot-check-rotation valve is present and explicitly non-silent (release-close.md:132-134).
- Verified the release-close blocking gates actually fire rather than being decorative. Built a fixture state (oss_state_init -> release r0 -> spine r0.s1 -> ledger_add_auto d1 -> ledger_quarantine d1 ... r0 -> release r1) and ran oss_ledger_expired_quarantines on r1: rc=1 with 'd1\tr0\tflaky infra'. Polarity (0 clean / 1 blocking / 2 inconclusive) matches the prose in release-close.md:167-179 and the numeric-comparison claim is implemented as a jq tonumber compare (ledger.sh:141-143), not a string compare.
- §6's execution-engine bullets are all present: RED gate (work-item/SKILL.md:153), gaps-mode as a pre-flight-only exit (SKILL.md:147), staged-never-commit with the commit boundary owned by close (close/SKILL.md:146-149), the 3-iteration cap sited orchestrator-side with the reason the worker cannot own it (round-orchestration.md:181-186), strict-order verification as the round barrier (round-orchestration.md:198-207), merge halt-on-conflict at both tiers (spine-close.md:128-132). Mode C (Codex backend) is shipped, not dropped (work-item/SKILL.md:35).
- Companion §4.2's repo dimension IS left extensible, not hardcoded. Every worktree entry point takes a repo key as argument 1 (worktree.sh:26,31,77,84,94), _oss_repo_root accepts canonical|ai_workspace|private_core (worktree.sh:14) and deliberately refuses to fall back to canonical for an unconfigured key (worktree.sh:18-22). The close ceremony reads the key from state rather than assuming it (spine-close.md:337 passes .work_items[].target_repo into worktree_remove), and the spawn does the same (round-orchestration.md:103-104). Companion §4.3's composition root is honoured by the demo runner (demo.sh:15-25, explicit > composition_root > canonical).
- §9.1's sixth entry skill (doctor) is genuinely absent and nothing invokes it: grep for '/doctor', 'Skill(ossify:doctor' and 'ossify:doctor' across skills/, commands/ and agents/ returns zero hits. The five shipped entry skills each carry a commands/ wrapper and no reference file is orphaned (checked every references/*.md is cited by its own SKILL.md — zero orphans).
- Every `oss <verb>` cited anywhere in skills/, agents/ and commands/ resolves to a real dispatcher function. Extracted all cited verbs and diffed against the 60 oss_cmd_* definitions in lib/*.sh: the only non-matches are the literal 'help' (real) and the truncated 'ledger_add_' from a prose fragment. No phantom entry point of the sd_rules_apply class survived into C1's prose.
- The demo runner's shipped behaviour matches cumulative-demo.md's description of it line for line: quarantined lines are SKIPped and excluded from the pass count (demo.sh:38-41,79), the vacuous-green guard is scoped to an exit:0 expectation only (demo.sh:70), and all three unrecognised/malformed expectation arms fail closed (demo.sh:59-77) rather than counting as a pass.

## producer/consumer wiring — does every dispatcher verb, lib function, and cross-file seam have a real caller at HEAD, and does every seam actually connect

- Built the full 61-verb consumer table by grepping the dispatcher-verb form (`oss <verb>`, word-bounded) across ossify/skills, ossify/commands, ossify/agents and ossify/README.md. 58 of 61 verbs have at least one real non-test prose caller. The only zero-consumer verbs are the two already recorded (`worktree_list`, `manifest_get`) plus `migrate` (reported below).
- Reverse direction is clean: extracted every `oss <token>` occurrence from all skill prose and diffed against the 61 `oss_cmd_*` definitions. The only non-resolving token is `oss ledger_add_` / `oss ledger_add_*`, which is a deliberate family reference and is excluded by rule in tests/test-skill-bash-blocks.sh check 2. No phantom verb is cited anywhere.
- Cross-file section citations: wrote a resolver over all 5 SKILL.md + 43 references/*.md that maps every `` `<file>.md` §N `` citation to its target and checks the target actually has a `## N.`/`### N.M` heading. 0 bad citations. The 20 the naive matcher could not resolve were hand-checked cross-skill pointers (`handoff-contract.md` §3, `returns.md` §2, `dag-rounds.md` §7, `fake-ledger-discipline.md` §1/§2/§3, `bones-registry.md` §4, `demo-authoring.md` §7, `skeleton-cut.md` §4) — every one resolves. This is the class the project has shipped defects in before; it is clean here.
- report.md §9 harvest seam: the producer heading `## 9. Suggestions for memory bank` in ossify/skills/work-item/references/report-contract.md:22 (pinned again at :40 and :123) is byte-identical to the consumer string in close/references/spine-close.md:316 and close/references/harvest.md:103/235. The handoff path shape `<spine_dir>/work-<wi-id>/handoff.md` in harvest.md:71-73 matches the writer's shape in round-orchestration.md:137 and handoff-contract.md:16.
- EXECUTED the whole plan→execute→close git seam in a scratch fixture (manifest + real canonical repo): `oss init` → `release_add`/`spine_add`/`work_item_add` → round-orchestration §2 `checkout -b spine/r0.s1-first-spine` → `oss worktree_add canonical r0.s1.w1 slug $spine_branch` → branch read back → `oss work_item_exec` → stage+commit in the worktree → work-item-close §4 merge with the HEAD assertion and `merge-base --is-ancestor` → `oss work_item_status complete` → spine-close §2 checkout back to `main` + `--no-ff` merge + reachability → §6 `diff --name-only $merge_sha^1 $merge_sha` → `oss touch_check` → §10 `oss worktree_remove`. Every step behaved as the prose documents; `work_items[].branch` written by the lane is exactly what close reads back; `worktree_remove`'s `git branch -d` succeeded because the merge had landed.
- Argument-arity check of every prose invocation against its `oss_cmd_*` wrapper (demo_record scope/id/passed/count/notes, demo_user_lines optional spine, ledger_quarantine line/reason/release, fake_status boundary/status/reason/expiry, class_set 3-arg, veto_add 4-arg, worktree_add 4-arg, verify_step/redgate 3-arg, harvest_apply 1-arg, get with optional explicit state file). No mismatch found — notably `oss demo_run` is called with no arguments everywhere, so its `$1=state-file` slot is never accidentally fed a spine id.
- rc-polarity contracts: `oss_reg_touch_check` (0=hit/1=clean/2=inconclusive) vs `oss_reg_expired_fakes` and `oss_ledger_expired_quarantines` (0=clean/1=blocking/2=inconclusive). Every prose call site branches on the correct polarity with a three-arm case and an explicit rc-2 halt (spine-close.md:182-187, release-close.md:144-150 and :168-174).
- Claimed test coverage in round-orchestration.md §8 is real: tests/test-worktree.sh:150-244 does assert the spine tip is the worktree base, distinct branches/worktrees per item, post-merge reachability from the spine branch, AND a negative control proving rc 0 alone proves nothing (:235) plus a vacuity guard on the fixture (:176). No inflated coverage header here.
- tests/test-skill-bash-blocks.sh runs green (pass=33 fail=0) — 141 bash blocks parse, 394 verb citations all resolve, 43 reference files all reachable from their own SKILL.md, no parameterized `Skill()`, no positionals in commands/*.md.
- state.sh `set_release_meta` allowlist (exit_criteria/spine_dag/ledger_budget/next_sketch/real_use_findings) matches release-close.md:278-280's five named keys exactly, including the documented drop-not-reject behaviour.
- `oss id_parse` output shape (`work_item 1 2 3` / `spine 1 2` / `release 1`) matches close/SKILL.md §2's routing contract and the awk field extraction in work-item-close.md:77-79 and harvest.md:57-58.

## the prose is the product — cross-skill contracts, citations, and executability

- Reference reachability: re-ran `ossify/tests/test-skill-bash-blocks.sh` on the shipped tree — 33/33 pass, 141 bash blocks all parse under `bash -n`, 394 oss-verb citations all resolve, 43 reference files, 0 orphans, 0 dangling pointers, all 5 SKILL.md within budget.
- Verb ARITY and argument ORDER (which the harness does NOT check) — hand-checked every `oss <verb> <args>` citation in skills/, commands/ and agents/ against lib/commands.sh: id_parse, get, branch_name, spine_dir, work_item_branch, worktree_add/resolve/remove, work_item_exec/status, spine_status, release_status, class_set(3 args), veto_add(4), ledger_add_auto(4)/add_user(3)/supersede(3)/retire(3)/quarantine(3)/apply_pending(1)/unplan(2), demo_run/demo_user_lines/demo_record(5), touch_check(@), expired_fakes(1), expired_quarantines(1), fake_add(5)/fake_status(3-4), feature_add(4)/feature_list, release_add(2)/release_set_meta(2)/spine_add(3-4)/work_item_add(2-3), harvest_dir/harvest_apply(1), verify_acs/verify_step(3)/redgate(3)/zero_tests_guard(1)/report_cross_check(2), patch_add(2), bone_add(3-4)/risk_gate_add(3)/posture_set/overlay_set/composition_set/init/state_path/repo_root/manifest_require/doctor/spine_list. Every one matches.
- Phantom-lib-function class (the `sd_rules_apply` shape the harness explicitly says it cannot see): the only four lib symbols named in prose — `oss_id_parse`, `oss_worktree_remove`, `_oss_resolve_state`, `oss_check` (in `report_cross_check`) — all exist in lib/.
- Both `file:line` citations verified at HEAD: `registries.sh:23-24` (fake payload builder — and `oss fake_add`'s *fourth* argument really is the trigger) and `ledger.sh:35-39` (the exact `{type,text,outcome,source_spine,status,status_reason,status_by,at}` payload release-close.md §3 quotes to prove there is no `.feature` field).
- Every `§N` citation across all 48 prose files resolved mechanically, then the non-obvious ones by hand — including the bold-inline pseudo-heading forms (`**5a.`/`**5b.`/`**5d.` in plan-release §5, `**4a.`/`**4c.` in plan-spine §4, `### 8a`-`8e`), critic-moment.md §3.1, bones-registry.md §4, class-declaration.md §5, skeleton-cut.md §4, demo-authoring.md §7, spec-authoring.md §6, round-orchestration.md §2/§6/§7, report-contract.md §1/§2, returns.md §2, handoff-contract.md §2/§3, memory-bank-brief.md §1, work-item/SKILL.md §6/§7. All resolve and say what the citer claims.
- rc-polarity discipline (the deliberately inverted pair): `touch_check` 0=hit / 1=clean / 2=inconclusive vs `expired_fakes` and `expired_quarantines` 0=CLEAN / 1=BLOCKING / 2=inconclusive is stated correctly and consistently in all seven places that state it (close/SKILL.md §5/§6/§7, spine-close.md §6, release-close.md §4/§5, fake-expiry.md §2, patch-lane.md §2), matching lib/registries.sh:100 and lib/ledger.sh's `oss_ledger_expired_quarantines`.
- EXECUTED `oss id_parse` on all five documented inputs (r1 / r1.s2 / r1.s2.w3 / VS-1.1.1 / empty): output shape `release 1` / `spine 1 2` / `work_item 1 2 3` matches routing.md §2's table exactly, and the 'rc 1 with empty stdout AND empty stderr' claim holds for both rejection cases.
- EXECUTED `printf 'collected 0 items' | oss zero_tests_guard "pytest tests/"` -> rc 0, and the non-zero-tests case -> rc 1. tdd-loop.md:131-135's piped usage and its 'rc 0 means the guard fired' warning are both correct, and the dispatcher does pass stdin through.
- EXECUTED bash 3.2's `set -u` behaviour for spine-close.md §6's `set --` / `"$@"` rationale: `"$@"` with zero positionals is fine, `"${arr[@]}"` on an empty array aborts with 'unbound variable'. The prose's stated reason for preferring positionals over an array is empirically correct on the shipped bash.
- `oss harvest_apply`'s full documented rc contract in harvest.md §7 and spine-close.md §9 (0 = wrote or empty payload, 1 = non-empty but nothing written, 2 = whole-payload rejection before any write; both 0 and 1 echo `harvest: wrote <N>, skipped <M>`; only 09-known-issues.md / 10-decisions-log.md appendable) matches lib/harvest.sh line for line, including the content-hash provenance trailer shape.
- EXECUTED the fake-status preservation claim: `set_fake_status` (state.sh:144) keeps `expiry_release` when the 5th argument is empty and overwrites it when supplied — fake-expiry.md §5's blockquote ('renewed with no fifth argument does not move the deadline') is exactly right.
- `release_set_meta`'s five-key allowlist and its silent-drop-at-rc-0 behaviour (state.sh:158) match release-close.md §7 and real-use-findings.md §3, including the 'read it back before believing it landed' warning.
- Status enums: spine `planned|active|closed|abandoned`, release `planned|active|closed` (entities.sh:67/87) — release-close.md §2 and §8's claims about `abandoned` existing on one and not the other are correct.
- `oss get` is `jq -r` without `-e` (state.sh:41), so an empty `select` exits 0 — the 'test the output, never the rc' warning is stated in all four places it needs to be (routing.md §4, spine-close.md §2, release-close.md §2, harvest.md §2).
- `oss_worktree_remove` really does use `git branch -d` (not -D) and return rc 8 on both an unmerged branch and a dirty worktree (worktree.sh:94-115) — the three files that use this as the cleanup-ordering argument (spine-close.md §9, work-item-close.md §6, harvest.md §1) all state it correctly.
- The `[internal]` cross-skill semantic marker the harness names as invisible to it: producer (`plan-release/references/class-declaration.md:174/178`) and consumers (`plan-spine/SKILL.md:118`, `demo-authoring.md:142/147`) agree on the literal.
- `## 9. Suggestions for memory bank` is byte-identical between report-contract.md §1 (the pinned copy) and harvest.md §4 (the exact-string grep), and the work-item docs-directory path shape is byte-identical across round-orchestration.md §4, handoff-contract.md's preamble, work-item-close.md §1 Route B, and harvest.md §3.
- `Skill()` / `Task()` shapes: no parameterized `Skill(x, y=z)` anywhere; `Task(subagent_type="ossify:implementer-agent")` matches `agents/implementer-agent.md`'s `name: implementer-agent`; `oss manifest_require`'s refusal literal carries `/init-workspace` and `/pair-workspace` verbatim (manifest.sh:7).
- The four bare cross-skill pointers the harness reports-but-does-not-fail (bone-touch-judge -> start's bones-registry, demo-authoring -> plan-release's class-declaration and start's skeleton-cut, skeleton-cut -> plan-spine's demo-authoring) are each qualified by possessive prose naming the owning skill in the same sentence, and every target section exists.
- `oss doctor`'s output vocabulary: close/SKILL.md §3's claim that `warn:` lines (held lock, pending amendment, outstanding fake) are non-blocking while `schema` and `replay` must be green matches doctor.sh's `ok:`/`warn:`/`skip:`/`fail:` emission and its rc accumulation.

## shell and strict-mode correctness across the 12 libs and 24 test files

- TRAP 1 (pipeline | { ... return N; }) — exhaustive classification, all clean. `grep -n '| *{' lib/*.sh` yields exactly 3 real pipelines-into-brace-groups: id.sh:4, id.sh:5, id.sh:6. In all three the pipeline is the function's ONLY command, so the subshell's `return 1` IS the function's exit status. Verified through the dispatcher under bash: `bash bin/oss id_parse VS-1.1.1` -> rc 1 (test-close.sh:53-56 also asserts this). Every other `| {` hit in the grep is an `|| { ...; return N; }` OR-list, not a pipeline. There are NO multi-line pipeline continuations to re-check: `grep -n '|[[:space:]]*$' lib/*.sh` and `grep -n '|[[:space:]]*\\$' lib/*.sh` both return nothing.
- TRAP 2 (subshell accumulator loss) — clean. Every loop whose variables are read after the loop uses `< <(...)`, never `| while`: harvest.sh:171 and harvest.sh:203 (the `$i`/`$w`/`$s` counters), registries.sh:63 (`$hit`), verify.sh:136 (`$missing`). Verified the accumulators actually survive through bin/oss: `oss touch_check src/x.py` -> `bone ADR-1`, rc 0 after a bone_add and rc 1 before it; `oss harvest_apply '[...]'` -> `harvest: wrote 1, skipped 0` then `harvest: wrote 0, skipped 1` on replay. verify.sh:12-27's `{ grep || true; } | while` IS a pipeline-fed loop but is the function's last command and accumulates nothing (it prints to stdout) — safe.
- pipefail + SIGPIPE on `printf | grep -q` — REFUTED after measurement, do not re-flag. verify.sh:68, :99, :100 pipe a possibly-huge `$out` into an early-exiting `grep -q` under `set -o pipefail`. Measured: `bash -c 'set -o pipefail; out="MARKER$(head -c 5000000 /dev/zero|tr \\0 x)"; printf "%s" "$out" | grep -Fq MARKER; echo $? ${PIPESTATUS[*]}'` -> `0` / `0 0`, because bash's BUILTIN printf handles EPIPE instead of dying; the same shape with an external producer gives `141` / `141 0`. End-to-end: `bash bin/oss verify_step . 'printf MARKER; head -c 5000000 /dev/zero | tr "\\0" x' 'output contains MARKER'` -> rc 0.
- AND-list errexit exemption — clean at every site. `[ ... ] && cmd` appears as a non-final statement at doctor.sh:58/63/65/67, state.sh:302, state.sh:362, commands.sh:160, worktree.sh:73, manifest.sh:54/55, demo.sh:17, _oss_mint_id (state.sh:224). Confirmed empirically that a failing non-last member of an AND-OR list does not trip errexit: `bash -c 'set -euo pipefail; f(){ [ -f /etc/hosts ] && grep -q ZZZNOMATCH /etc/hosts && return 0; echo reached; }; f'` -> prints `reached`, rc 0. The two shapes that would be the function's true last command (state.sh:302, state.sh:362) are both followed by an explicit `return`.
- `local x="$(cmd)"` rc-masking — zero instances. `grep -n 'local .*="\$(' lib/*.sh` returns 48 hits and every one is the safe two-step form `local sf; sf="$(...)" || return $?` (commands.sh throughout, doctor.sh:5, worktree.sh:27/78/85, verify.sh:98).
- Unguarded bare `x="$(cmd)"` under set -e — swept and clean. `grep -nE '^[[:space:]]*[a-z_]+="\$\(' lib/*.sh | grep -v '||'` leaves only assignments from commands that cannot meaningfully fail (`_oss_now`, `printf|tr`, `printf|sed`, `oss_id_work_item_branch`) or that are already gated by a preceding readability check (demo.sh:35-43 sits behind demo.sh:31's guarded jq).
- BSD/macOS portability — clean. `grep -rn 'readarray|mapfile|grep -P|sed -i|date -f|date -d|stat -c|xargs -r|sort -V' ossify/` returns nothing. doctor.sh:23's `find "$sf.lock" -maxdepth 0 -mmin +30` verified working on this macOS (both the held-lock and the `touch -t 202001010000` stale-lock arms produce their correct doctor lines). `cksum`, `sed -E`, `tr -d '[:space:]'`, `grep -qxF`, `grep -Fq --`, `mktemp TEMPLATE.XXXXXX` all BSD-clean.
- Error branches driven through bin/oss under real `set -euo pipefail` — every one returns its documented rc with a diagnostic, none aborts: replay drift -> doctor rc 1 + `oss state_restore` rc 0; schema v99 -> doctor rc 1 / migrate rc 6 / release_add rc 6; corrupt-JSON state -> doctor rc 1, touch_check rc 2, expired_fakes rc 2, expired_quarantines rc 2, demo_run rc 1 (all INCONCLUSIVE, never folded into clean); held lock -> mutate rc 3 and the lock is not leaked; worktree add/resolve/list/remove incl. the unmerged-branch refusal; harvest bad-target rc 2, missing-payload rc 2, duplicate rc 1.
- AC commands do NOT inherit the dispatcher's strict mode. `bash bin/oss verify_step /tmp 'echo "opts=[${SHELLOPTS:-unset}]"' 'output contains opts='` reports `opts=[braceexpand:hashall:interactive-comments]` — SHELLOPTS is not exported by bin/oss, so `false; echo REACHED` inside an AC behaves as the author typed it (verified: rc 0 with the echo reached).
- Prose bash blocks (the executable artifact) — 141 blocks extracted from all 54 skills/commands/agents markdown files. All parse under `bash -n`. None contains a `pipeline | { ... return }` or an accumulator-losing `| while` (impl-check.md:45 and spine-close.md's touch block both use `< <(...)` with an explicit warning comment). No block's last effective command is a bare `[ ... ] && ...` that would make a sourced block return 1 under set -e. spine-close.md's merge-back block is fully hardened against the historic wrong-target-merge P0s (derives the branch instead of reading HEAD, `${base_branch:-}` guard, post-checkout HEAD re-assert, `merge-base --is-ancestor` reachability check).
- Test-suite strict-mode posture — structurally sound despite no test file setting -e/-u. 21 of 24 test files drive `bin/oss` directly, and test-close.sh extracts the shipped close-ceremony prose blocks and executes them under real `set -euo pipefail` (test-close.sh:313-328, 621-633) with an explicit vacuity guard that goes red if extraction stops working. No stale-`$T_OUT`/`$T_RC` assertion found by scanning every assert against its preceding t_capture. The historic `[ -f ]`-against-a-mkdir-lock bug is fixed — test-state-replay.sh:58 and :80 now use `-d`. `bash test-verify.sh` -> pass=33 fail=0; `bash test-close.sh` -> pass=158 fail=0 at HEAD.
- `_oss_repo_root` (worktree.sh:17) does not run the `${...}` token resolution that oss_manifest_state_path and oss_harvest_memory_bank_dir do — checked workspace-init/lib/manifest.sh:285-296 and `.ai_workspace.root`/`.canonical.root` are emitted as already-resolved literals (only well_known_paths/during_dev carry tokens), so there is no live trigger. Noting it only so a future manifest change does not silently create a `${HOME}` directory under $PWD.

## tests that cannot fail — 940 assertions across 24 files audited for the five known vacuity modes (tautological round-trip, fixture never trips precondition, t_capture ambient-state absorption, mutation never applied, fixtures coupled through shared state), with mutation testing on the load-bearing guards

- MUTATION (RED, named): ossify/lib/worktree.sh:112 `git branch -d` -> `-D`. Mutant applied (line echoed back) and still ran its happy path. test-worktree.sh went 53/0 -> 50/3 with three named failures including `FAIL: unmerged work-item branch was destroyed`. Restored byte-identical (shasum 60a985d818581bac822ff7410c751e9b455fa282).
- MUTATION (RED, named): spine-close.md:84-85 HEAD-matches-spine-branch guard neutered to `true`. test-close.sh 158/0 -> 152/6, including `FAIL: wrong-branch halt - the spine reached master anyway` and three follow-on `the spine reached master anyway` lines. The shipped prose block IS executed under real strict mode by test-close.sh section E.
- MUTATION (RED, named): lib/registries.sh:107 `select(.status == "active" or .status == "renewed")` -> active-only. test-close.sh 158/0 -> 154/4, naming the exact discriminating row `f-renewed-at-r2\trenewed\tr2`. Also line 110 `$e <= $cut` -> `$e == $cut`: 158/0 -> 153/5, naming `f-active-at-r1` and the r10 lexicographic row.
- MUTATION (RED, named): lib/verify.sh:135 word-boundary regex -> `grep -Fq -- "${label}"`. test-verify.sh 33/0 -> 31/2 on the AC-10/AC-1 prefix-collision assertions.
- MUTATION (RED, named): lib/harvest.sh:193 `h:${h} -->` -> `h:${h}` (unanchored cksum). test-harvest.sh 80/0 -> 77/3, naming the prefix-hash skip.
- MUTATION (RED, named): mode-3 probe. lib/demo.sh:52 `if out="$( cd "$wd" && bash -c ... )"` rewritten to leak the `cd` into the caller's shell. test-demo-runner.sh 26/0 -> 25/1 on `the runner's subshell cd did NOT mutate the process cwd` — the one cwd assertion in the suite is deliberately NOT wrapped in t_capture and genuinely fails.
- MODE 3 sweep: `grep -n 't_capture' tests/*.sh` -> 60 sites; none asserts ambient state (cwd/env/umask/traps) through the command substitution. The single $PWD assertion (test-demo-runner.sh:115) is a bare statement call with a documented rationale. `grep PWD|umask|trap` over tests/ confirms no other ambient assertion.
- STALE-T_RC sweep: an awk pass over all 24 files found zero `t_assert_rc` that is not immediately preceded by a `t_capture` (or its line continuation). No assertion reads a stale T_RC.
- MODE 1 (tautology) in test-state-replay.sh: `oss_state_replay` compares base+journal against live with full-document `jq -S` equality (lib/state.sh:328), not a subset. The restore test explicitly refuses to treat a clean replay as evidence and pins a concrete surviving value (`fully-private`) plus `.mutations | length == 2`. The G1/G2 fixtures build the `live` side by literal jq assignment, never by calling `_oss_apply_op` — the tautology trap is named and avoided in-file.
- REFUTED FINDING: lib/registries.sh:110 `select($e == null or $e <= $cut)` — dropping the `$e == null or` clause reds nothing. Executed `jq -n 'null <= 2'` -> `true`; jq's total ordering puts null below numbers, so the mutation is semantically equivalent, not a coverage hole.
- GIT ASSERTIONS (mandate 1): every git-touching test asserts concrete observables, never rc alone. test-worktree.sh pins `merge-base --is-ancestor` reachability against a sha captured BEFORE the spawn, plus a negative control that asserts rc 0 on a wrong-branch merge and then proves the commit did NOT reach the spine. test-close.sh sections C/D/E do the same, with explicit `the guard's precondition` assertions (spine tip != base tip, canonical parked on the spine branch, `f.txt` is not a branch, the empty-merge fixture really changes no path).
- MODE 2 (fixture never trips precondition): the suite systematically pre-asserts preconditions — test-close.sh:563 pins `jq -n '"r2" <= "r10"' == false` before relying on it; the seven fake fixtures each get a status+expiry read-back assertion before the selector is exercised; test-doctor.sh asserts the warn-fixture actually seeded (`REL/SP/L1/L2` non-empty) before asserting on doctor output.
- test-skill-bash-blocks.sh self-test: each of the six checks runs twice — shipped tree (expect 0) and a purpose-built fixture with exactly one plant (expect exactly 1, named, with file:line). Block extraction is cross-checked against an independently-written `grep -cE '^[[:space:]]*```bash'` opener count, and the fixture asserts an EXACT block count (2), so a collapsed extractor reds rather than passing vacuously.
- bin/oss dispatches generically via `declare -F "oss_cmd_${cmd}"`, so check 2's `oss_cmd_*` symbol resolution is a sound proxy for routability — no case-arm can drift away from a defined function.
- eval/lib/aggregate-scores.sh walks FIXTURES (authoritative) rather than results/, so a surface authored but never scored fails the gate with `GATE FAILED: N fixture(s) unscored` and exit 1 — the self-incompleteness blind spot is explicitly closed.
- MODE 5 (fixtures coupled through shared state): the two multi-spine ledger fixtures deliberately close spines out of planning order (test-spine-planning.sh, r0.s2 closes first though it is index 1) precisely so `apply the first entry` and `apply the calling spine's entry` cannot agree by coincidence.
