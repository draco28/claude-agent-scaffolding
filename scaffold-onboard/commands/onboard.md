---
description: Guided 10-phase onboarding conversation that authors MASTER-SPEC.md as source of truth for this project.
argument-hint: ""
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Run the onboarding setup block, then conduct the per-phase conversation per the protocol below.

```bash
bash -c '
set -u
source "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "scaffold-onboard: not inside a git repo. Run \`git init\` first."
  exit 1
fi
cd "$REPO_ROOT"

# Acquire onboarding lock
if ! sf_state_lock_acquire; then
  echo "scaffold-onboard: onboarding already in progress in another session."
  exit 1
fi
trap "sf_state_lock_release" EXIT

MODE="$(sf_state_mode)"
echo "scaffold-onboard: mode=$MODE"

case "$MODE" in
  new)
    sf_state_init
    echo "scaffold-onboard: initialized state at $(sf_state_path)"
    # symlink for in-repo visibility (gitignored)
    mkdir -p .claude
    ln -sf "$(sf_state_path)" .claude/.onboarding-state.json
    ;;
  resume)
    echo "scaffold-onboard: resuming at phase $(sf_state_read_field current_phase)"
    ;;
  reonboard)
    echo "scaffold-onboard: prior onboarding complete. Type re-onboard to overwrite MASTER-SPEC.md, or cancel."
    # The user reply is interpreted by Claude per the protocol below.
    ;;
esac

echo "current_phase=$(sf_state_read_field current_phase)"
echo "phases_yaml=${CLAUDE_PLUGIN_ROOT}/templates/onboarding-questions/phases.yaml"
echo "master_spec_tmpl=${CLAUDE_PLUGIN_ROOT}/templates/master-spec/MASTER-SPEC.md.tmpl"
echo "exec_summary_tmpl=${CLAUDE_PLUGIN_ROOT}/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl"
'
```

---

## Onboarding protocol (Claude follows this loop)

After the setup block runs, follow this protocol step-by-step. The setup output tells you `current_phase`, paths to `phases.yaml` and templates, and the mode.

**Per-phase loop (run once for the current phase, then re-invoke `/onboard` to continue or wait for user):**

1. **Read `phases.yaml`** for the current phase's question list using `sf_phases_questions_for <yaml> <phase_id>`.

2. **Check Phase 5 / Phase 7 entry signals.** If `current_phase` is 5 or 7:
   - Source `${CLAUDE_PLUGIN_ROOT}/lib/compose.sh` (Phase F — soft-fail if not present yet).
   - If `ai-mentor` detected: print `💡 Phase {N} ({Architecture|Implementation}) is judgment-dense. Consider /z2-decide for spotter mode.`
   - If `superpowers` detected with `brainstorming_available=true`: print `💡 superpowers:brainstorming is available for visual trade-off exploration on this phase.`

3. **Ask each question** in `phases.yaml` for this phase, in order:
   - For each question ID, call `sf_phases_question_text <yaml> <qid>` to get the question text.
   - Call `sf_phases_question_gate <yaml> <qid>` — if non-empty, evaluate with `sf_state_gate_passes`. If the gate fails, skip the question.
   - Present the question to the user. Accept their answer or `TBD`.
   - Persist immediately: `sf_state_write_answer <qid> <value>`.
   - Move to the next question.

4. **After all questions in this phase are answered:**
   - Re-render MASTER-SPEC.md to incorporate the new answers:
     `sf_master_spec_update_phase "${master_spec_tmpl}" <phase_id>`.
   - Generate a 3–5 line recap of this phase's section (read MASTER-SPEC.md's Phase N section back; summarize what the user said).

5. **Phase 5 + Phase 7 recap critic gate:**
   - If `current_phase` is 5 or 7 AND `architect-critic` detected (via `composition.json`):
   - Announce: `Running architect-critic premise audit on Phase {N} recap. Type 'skip' to bypass this fire.`
   - Watch for user's next message in the current turn:
     - If it's exactly `skip` (case-insensitive): log "skipped by user" and proceed to step 6.
     - Otherwise: build the critic request JSON per SPEC §8.3 and write to `${CLAUDE_PLUGIN_DATA}/architect-critic/inbox/<request-id>.json`. Invoke `/critique`. Read the outbox response. Present challenges to the user. The user may iterate on the recap or accept.

6. **Recap acceptance:** present the (possibly-revised) recap and ask user `accept / edit / append a note`. Apply their choice — `edit` means re-prompt; `append` means add the user's text as an addendum to the Phase N section of MASTER-SPEC.md.

7. **Advance state:** `sf_state_advance_phase`.

8. **If `sf_state_read_field status` is `complete` (i.e., Phase 10 just finished):**
   - Generate the executive summary (~500 words synthesized from all phases).
   - Re-render `EXECUTIVE-SUMMARY.md` using `sf_render "${exec_summary_tmpl}" project_name="$(basename "$PWD")" project_class="$(sf_state_read_answer 1.3.1)" created_date="$(date -u +%Y-%m-%d)" executive_summary="<the synthesized text>"`.
   - If `architect-critic` detected: announce `Running architect-critic close audit (claude + codex). Type 'skip' to bypass.` Process same as step 5 with `depth=close, adversaries=[claude, codex]`.
   - Report: `MASTER-SPEC.md authored. Next: /scaffold-project`.

9. **Otherwise:** report `Phase {N} complete. Re-invoke /onboard to continue.` and exit.

**Mode-specific entry:**

- **new mode:** start at Phase 1.
- **resume mode:** pick up at `current_phase`; if there are unanswered questions in that phase (check via `sf_state_read_answer` returning `null`), resume from the first unanswered one.
- **reonboard mode:** ask the user `re-onboard (overwrites MASTER-SPEC.md) / resume Phase N / cancel`. On `re-onboard`, set `status=in_progress`, `current_phase=1`, clear `.answers`, and restart at Phase 1. Default is `cancel`.

**Discipline:**

- Persist state after every single answer. Interruptions never lose work.
- Never modify state for `ai-mentor` or `architect-critic` — only read.
- Skip-flag mechanism is per-occurrence inline (user types `skip` in the turn the critic announces).
