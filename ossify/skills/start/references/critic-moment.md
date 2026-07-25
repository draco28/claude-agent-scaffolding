# The spec-core critic moment

Depth for SKILL.md §11. Mirrors `scaffold-onboard:onboarding-project`'s
critic-moment mechanism, re-anchored to ossify's single spec-core fire.

**One invocation, no more, no less.** It fires at spec-core close — after the
lean MASTER-SPEC is authored and before the bones harden into Release-0
planning. This restores the old stack's Phase-5/7/close critic cadence that the
capability-catalog mapping had silently dropped.

---

## 1. The moment

| Trigger | `target` | `depth` | `artifact_path` |
|---|---|---|---|
| Spec-core close (lean MASTER-SPEC authored; before `plan-release`) | `master-spec-full` | `close` | the lean MASTER-SPEC path |

architect-critic v0.2 detects host-agent and adversary availability **internally**
(its contract / spec §12.2). The caller passes only `target`, `depth`, and
`artifact_path`. Do **not** pass an `adversaries` argument — it is not part of
the invocation contract.

`plan-release` owns a *different* critic pass (the class-declaration veto,
spec §5.2 step 3). That one is not this one, and it is not owned by `start`.

---

## 2. Detection — filesystem probe, binary v0.2-or-absent

```bash
oss critic_detect     # echoes "v0.2" (rc 0) or "absent" (rc 1)
```

The probe walks the known plugin cache directories looking for
`architect-critic/*/skills/critiquing-spec/SKILL.md`. It is stateless (no state
file, no manifest), cheap (<5ms typical), and runs **lazily at the moment** —
not at skill entry.

There is **no fallback to pre-v0.2 architect-critic**: those versions shipped
with no `skills/` directory, so the `Skill(architect-critic:critiquing-spec)`
grammar cannot resolve against them. v0.2 is a hard breaking change (ac spec §3
NG1).

Detection is **filesystem-only**. Do not read `composition.json` — architect-critic
dropped its entry from that registry in v0.2 (ac settlement #1).

---

## 3. The sequence

1. **Announce**, then end the turn:

   > Spec-core close — invoking architect-critic for a `close` audit on the lean
   > MASTER-SPEC + bones registry + skeleton-cut before the bones harden. Type
   > `skip` to bypass.

2. **Wait.** If the user types exactly `skip` (case-insensitive), log it and
   continue to the next block. Do not argue, do not re-offer.

3. **Probe:** `oss critic_detect`.
   - `v0.2` → step 4.
   - `absent` → warn once (§4) and continue. Do not stall.

4. **Invoke**, in-conversation:

   ```text
   Skill(architect-critic:critiquing-spec,
         target=master-spec-full,
         depth=close,
         artifact_path="<lean MASTER-SPEC path>")
   ```

   architect-critic runs its own challenge-resolution loop internally
   (sequential rebuttal, concession scoring, auto-promotion checks). You do not
   mediate its internals. Control returns via its structured summary block —
   a message opening *"Audit complete for …"* listing the challenges that stood.

5. **Disposition-triage** the standing challenges (§5).

6. Continue to the Release-0-minimums recap and the outputs block.

---

## 4. Absent — warn and skip

Emit exactly one warning, then continue:

> architect-critic not installed — skipping spec-core audit. Install via
> `/plugin install architect-critic` (v0.2+).

Do not stall the conversation, do not prompt to install interactively, and do
not retry the probe. Spec-core close is robust to the critic's absence; the
critic is a strength-multiplier, not a gate.

---

## 5. Disposition triage — advisory, never a gate

This is the part that distinguishes the critic moment from a quality gate.
Control has returned to you; you decide what happens to each standing challenge.

| Challenge kind | Disposition |
|---|---|
| **Spec-aligned** — the challenge asks for something the methodology already mandates (a missing bone category, an un-named touch surface, an unverified claim not marked, a moat item leaking into the public artifact) | **Auto-accept.** Fold it into the spec + the relevant bone ADR yourself, and say what you folded. |
| **Load-bearing / vision-touching** — it questions the skeleton cut, the product's core hypothesis, the posture, or a bone the user chose deliberately | **Escalate to the user.** Present it as a decision, with the critic's reasoning and your read. |
| **Out of scope** — it asks for the artifacts spec-core deliberately retired (exhaustive FR/NFR, a roadmap, a PROJECT_PLAN) | **Reject with a reason**, and say so out loud: those grow at release closes. |
| **Ambiguous, contradictory, or stale** | **Escalate.** Never silently pass. |

Then surface a short digest: what was auto-accepted, what was escalated, what
was rejected and why. A silent triage is indistinguishable from ignoring the
critic.

**Never block on the critic.** A standing challenge the user declines to act on
is recorded and the flow continues. The critic's findings do not gate
`plan-release`.

> Note the asymmetry with the *release-planning* veto (spec §5.2): there, an
> ambiguous or stale finding defaults to ESCALATE and a veto **auto-applies** as
> reclassification, because misclassification is a safety property. Here the
> stakes are lower and the pass is advisory. Do not import the veto's fail-closed
> semantics into this moment, and do not export this moment's advisory semantics
> into the veto.

---

## 6. What NOT to do

- **Do not gate on the critic.** Advisory. Always.
- **Do not fire more than once.** One `close` audit per spec-core close. Per-block
  critic fires were considered and rejected as disruptive.
- **Do not fire before the lean MASTER-SPEC exists.** The critic audits a real
  artifact on disk; there is no phase-recap file in ossify's flow.
- **Do not read `composition.json`** to detect architect-critic (§2).
- **Do not invoke `Skill(architect-critic:critique)`** — the v0.1.x
  slash-command name. The v0.2 skill is `critiquing-spec`.
- **Do not use file-IPC** (`inbox/`, `outbox/`) — removed in ac v0.2.
- **Do not auto-apply a vision-touching challenge.** Auto-accept covers
  spec-aligned mechanics only.
- **Do not retry on critic failure.** If it errors or returns a malformed
  summary, log it and continue; the user can re-run it manually from
  architect-critic's own surface.
