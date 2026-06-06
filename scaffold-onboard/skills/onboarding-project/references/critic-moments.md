# architect-critic moments

The three architect-critic invocation points during a `/onboard` run, with detection, invocation, and control-return details. Supplements SKILL.md §5 and SPEC §12.

This skill (`onboarding-project`) is responsible for **three** critic moments. SPEC §12.1 lists four total — the fourth (`/plan-roadmap` close, target=`roadmap`) is owned by the `planning-project-roadmap` skill and is out of scope for this doc.

---

## 1. The three moments

| # | Trigger                                | `target`             | `phase_id` | `depth`         | Adversaries          |
|---|-----------------------------------------|----------------------|------------|-----------------|----------------------|
| 1 | Phase 5 close (Architecture)            | `master-spec-phase`  | `5`        | `premise-audit` | `[claude]`           |
| 2 | Phase 7 close (Implementation Approach) | `master-spec-phase`  | `7`        | `premise-audit` | `[claude]`           |
| 3 | MASTER-SPEC close (post-Phase-10)       | `master-spec-full`   | (omitted)  | `close`         | `[claude, codex]`    |

Adversaries are inferred by architect-critic from `depth` per ac v0.2 settlement #6 (premise-audit → claude-only; close → claude + codex when user opts in via `--close`). scaffold-onboard does **not** pass an explicit adversaries list; it passes `depth` and lets architect-critic decide.

Phases 1-4, 6, 8, 9 have **no** critic moment. Phase 10's critic is the post-render close — it fires after the full MASTER-SPEC is assembled, not after the Phase 10 questions are answered.

---

## 2. Detection: filesystem probe, binary v0.2-or-absent

Per SPEC §12.2: detection is **filesystem-only**, not via composition.json. The composition.json file that scaffold-onboard maintains for ai-mentor + superpowers does **not** carry an `architect-critic` entry in v0.2 (ac settlement #1).

```bash
sf_compose_detect_architect_critic() {
  local cache_dirs=(
    "${HOME}/.claude/plugins/cache"
    "${CLAUDE_PLUGINS_DIR:-}"
  )
  for cache in "${cache_dirs[@]}"; do
    [[ -z "$cache" || ! -d "$cache" ]] && continue
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [[ -f "$skill_md" ]] && { echo "v0.2"; return 0; }
    done
  done
  echo "absent"
  return 1
}
```

Returns either `v0.2` or `absent`. Probe is cheap (<5ms typical) and runs lazily — once per critic moment, not once at skill entry. There is **no** v0.1.3 fallback. Pre-v0.2 architect-critic shipped with no `skills/` directory, so `Skill(architect-critic:critiquing-spec)` cannot resolve against it; v0.2 is a hard breaking change per its SPEC §3 NG1.

### Why filesystem-only (not composition.json)

architect-critic v0.2 dropped its entry from the shared composition.json registry per its settlement #1. Consumers (scaffold-onboard, others) detect ac via skill auto-discovery + filesystem probe. The composition.json file is reserved for ai-mentor + superpowers detection (which still uses the registry pattern). Mixing detection mechanisms in one file would conflate two release contracts.

---

## 3. Invocation pattern

At each critic moment, after the phase record is authored and the recap is surfaced but **before** asking the user `accept | edit | append`:

1. **Announce.** Surface a one-line announcement:

   > Phase 5 close — invoking `architect-critic:critiquing-spec` for `premise-audit` on the Phase 5 recap. Type `skip` if you want to bypass this fire.

2. **End the turn.** Wait for the user's next message.

3. **Branch on user response:**
   - If user typed exactly `skip` (case-insensitive): log it, jump to step 6 of the per-phase loop without invoking the critic.
   - Otherwise: proceed to step 4.

4. **Probe.** Call `sf_compose_detect_architect_critic`. Branch:
   - `v0.2`: continue to step 5.
   - `absent`: warn-and-skip per §4 below. Continue to step 6 of the per-phase loop.

5. **Invoke.** Emit a single `Skill(architect-critic:critiquing-spec, ...)` call with the arguments from the table in §1:

   ```
   Skill(architect-critic:critiquing-spec,
         target=master-spec-phase,
         phase_id=5,
         depth=premise-audit)
   ```

   For the MASTER-SPEC close (moment 3), omit `phase_id` and use `target=master-spec-full, depth=close`.

6. **Wait for control return.** architect-critic runs its own challenge-resolution loop internally: sequential rebuttal, scoring, auto-promotion checks. scaffold-onboard does **not** mediate this. Control returns via the structured summary block described in ac SPEC §10 — a single message that opens with *"Audit complete for &lt;target&gt; ..."* and lists challenges that stood.

7. **Present challenges as edit candidates.** Any challenges that stood are surfaced to the user as candidate edits to the phase recap:

   > Two architect-critic challenges stood. Want to edit the Phase 5 recap to address either?
   > - C-5.1: &lt;challenge text&gt;
   > - C-5.2: &lt;challenge text&gt;

8. **Apply edits.** If the user accepts any, re-author the phase record to capture the revision and re-call `sf state_write_phase_record <phase_id> <temp-file>` to persist it. If the user declines all, leave the recap as-is. (No MASTER-SPEC section is re-rendered per phase — MASTER-SPEC is synthesized once at close from the accumulated phase records + answers.)

9. **Resume the per-phase loop at step 6** (the `accept | edit | append` prompt).

---

## 4. Absent: warn-and-skip

If `sf_compose_detect_architect_critic` returns `absent`, emit exactly one warning and continue:

> [scaffold-onboard] architect-critic not installed — skipping `<phase-N>` premise audit. Install via `/plugin install architect-critic` (v0.2+) for adversarial review at this phase.

Then proceed to step 6 of the per-phase loop. **Do not stall** the conversation. The onboarding flow is robust to architect-critic's absence; the critic is a strength-multiplier, not a gate. Phase 10 will still emit MASTER-SPEC.md cleanly; the user simply hasn't had the adversarial review benefit at the listed phases.

---

## 5. Control-return behavior

architect-critic's control-return contract (per ac SPEC §10):

- A single assistant message ends with `Audit complete for <target>[ phase_id=<N>]. <K> challenges stood:` followed by a bulleted list.
- If `K=0`, the message is `Audit complete for <target>. 0 challenges stood — recap is solid.`
- The summary block is the boundary marker: everything before it is ac's internal loop (which scaffold-onboard ignores); everything after it is back in scaffold-onboard's flow.

scaffold-onboard parses the summary block for the list of standing challenges and presents them. It does **not** parse ac's internal rebuttal scoring or auto-promotion votes; those are ac's domain and ac documents them in its own logs.

---

## 6. What NOT to do at critic moments

- **Do not use file-IPC.** No `inbox/` or `outbox/` paths. `sf_compose_build_critic_request` and `sf_compose_read_critic_response` were removed in v0.2 per SPEC §12.3.
- **Do not invoke `Skill(architect-critic:critique)`.** That was the v0.1.x slash-command name. The v0.2 skill is `critiquing-spec`.
- **Do not read `composition.json` to detect architect-critic.** Use the filesystem probe.
- **Do not auto-apply challenges as edits.** The user decides which challenges become edits and which are ignored.
- **Do not invoke the critic mid-phase.** Critic moments fire at *phase close* (after the last question is answered + recap is rendered), not after individual question answers. Per-question critic invocation was considered and rejected in the v0.1.0 design as too disruptive to the conversational rhythm.
- **Do not retry on critic failure.** If ac returns a malformed summary or errors out, log it and continue — onboarding is not blocked. The user can re-run the critic manually via `/critique master-spec-phase --phase 5` from architect-critic's own slash-command surface.

---

## 7. Quick reference: invocation cheat-sheet

```
Phase 5 close:
  Skill(architect-critic:critiquing-spec,
        target=master-spec-phase,
        phase_id=5,
        depth=premise-audit)

Phase 7 close:
  Skill(architect-critic:critiquing-spec,
        target=master-spec-phase,
        phase_id=7,
        depth=premise-audit)

MASTER-SPEC close (post-Phase-10, after EXECUTIVE-SUMMARY render):
  Skill(architect-critic:critiquing-spec,
        target=master-spec-full,
        depth=close)
```

Three calls, no more, no less. The `/plan-roadmap` critic moment (target=`roadmap`, depth=`close`) is owned by a different skill.
