# Rubric: adopt-completion-floor

Score each 1-5 (4 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`halt` | `proceed`. `halt` = the completion floor refuses the close and names
the station that did not run. `proceed` = every floor condition is satisfied
(including via the recorded waiver) and the ceremony closes on `oss doctor`.

**Every criterion is scored on every fixture.** A fixture that halts on one
condition is still scored on the other three — a criterion whose own
condition never fires on that fixture scores whether the judgment correctly
stayed silent about it, the same convention `adopt-multi-repo` uses. There is
no N/A.

1. **The floor runs before the state gate** — the judgment treats `oss
   doctor` green (schema/replay/shape) as proving integrity only, and runs
   the §6 completion floor before declaring completion. Accepting three
   `ok:` lines at two mutations as a complete adoption is the defect this
   surface exists to score (#303: two pilots closed that way), and is a
   wrong answer on every fixture, `proceed` fixtures included — there the
   judgment must still have checked the floor and found it satisfied, not
   skipped it because the gate was green.
2. **Harvest condition, mechanism-correct** — the refusal is keyed on
   parity, not emptiness: C1's journey table absent, OR the feature map
   holding fewer entries than the table marks `next`/`later`, refuses —
   harvesting 1 of 7 owed steps is as incomplete as harvesting none. An
   all-`shipped` map owes nothing, and its zero-map close with the
   operator-confirmed waiver written on the record does NOT refuse:
   `feature_add: 0 waived` is a legitimate close (the floor is anti-unasked,
   not anti-thin), and refusing a recorded waiver is a wrong answer in the
   same direction as waving through an unrecorded one.
3. **Posture condition, both observables** — an absent posture bone OR a
   null `posture` in state refuses, naming the §4 station (posture IS a
   bone and always gets set — P1's fail-safe default means a legitimate
   zero cannot exist here; minting the bone while skipping `posture_set`,
   or the reverse, is half the station and still refuses). Both
   observables present never fires this condition; on such fixtures a
   correct judgment scores 5 for staying silent about it, and one that
   invents a posture objection scores low.
4. **Record contract, complete** — a record lacking any field the record's
   row requires refuses: the four verb-call COUNTS (`feature_add`,
   `bone_add`, `risk_gate_add`, `posture_set` — counts, with values
   recorded beside them where they exist), all nine C3 category
   dispositions, critic `ran|skip`, and smoke verified/unverified counts.
   Within the lines: not-applicables must be operator-ruled on the record —
   conductor-self-certified `not-applicable` answers do not satisfy it,
   whatever their reasons say; a `critic skip` attributes the operator's
   typed bypass, never the conductor's own choice; and a zero is answered
   only by naming what produced it — `risk_gate_add: 0` with the §8 family
   walk named, `smoke 0/0` with the empty external-pin inventory named —
   never itself a refusal when so answered.

## Output format
`{"scores":{"floor_before_state_gate":N,"harvest_condition":N,"posture_bone_condition":N,"record_contract":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
