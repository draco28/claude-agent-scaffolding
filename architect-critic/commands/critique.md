---
description: Run an architect-critic audit on a spec or plan with claude-self-audit + (optionally) codex fresh-frame review
argument-hint: "[--phase N] [--depth premise-audit|close] [--spec PATH]"
allowed-tools: Bash, Read, Edit, SlashCommand
---

# /critique

Run the envelope synthesis + validation block, then proceed to the audit pipeline.

```bash
# $ARGUMENTS is substituted by Claude Code at template-render time with the
# raw arg string the user typed. Pass it into bash via env var so the inner
# single-quoted bash -c body can reference it as $RAW_ARGS without colliding
# with $1/$2/etc. (which Claude Code also tries to substitute).
RAW_ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"

source "${PLUGIN_ROOT}/lib/_helpers.sh"
source "${PLUGIN_ROOT}/lib/state.sh"
source "${PLUGIN_ROOT}/lib/principles.sh"
source "${PLUGIN_ROOT}/lib/inbox.sh"

# ── Argument parsing ────────────────────────────────────────────────────────
# Note: Claude Code substitutes $1/$2/etc. at slash-command-template render
# time, BEFORE bash sees the script (this bit us in v0.1.1). Parse args
# instead by extracting from $ARGUMENTS (the raw arg string) using sed/grep
# patterns that never reference positional $N.

RAW_ARGS="${RAW_ARGS_FROM_CLAUDE:-}"

REQUEST_ID=""
PHASE_ARG=""
DEPTH_ARG=""
SPEC_ARG=""

# Strip leading @ from --spec values (Claude Code uses @path to load file content
# into conversation context; the leading @ should be stripped before fs access).
_extract_flag() {
  local flag="$1"
  printf "%s" "$RAW_ARGS" | sed -nE "s|.*${flag}[= ]+([^ ]+).*|\\1|p" | head -1 | sed "s|^@||"
}

SPEC_ARG="$(_extract_flag '--spec')"
PHASE_ARG="$(_extract_flag '--phase')"
DEPTH_ARG="$(_extract_flag '--depth')"
REQUEST_ID="$(printf "%s" "$RAW_ARGS" | grep -oE "crit-[a-zA-Z0-9._-]+" | head -1 || true)"

INBOX_DIR="$(ac_inbox_dir)"

# ── Mode detection ───────────────────────────────────────────────────────────
# Programmatic: request_id given AND inbox file exists
# Manual:       synthesize envelope from defaults

MODE="manual"
if [[ -n "$REQUEST_ID" && -f "${INBOX_DIR}/${REQUEST_ID}.json" ]]; then
  MODE="programmatic"
fi

ac_log_info "mode=${MODE}"

# ── Data dir bootstrap ───────────────────────────────────────────────────────
DATA_DIR="$(ac_data_dir)"
mkdir -p "${DATA_DIR}/inbox" "${DATA_DIR}/outbox"

ac_state_init

# ── Resolve envelope ─────────────────────────────────────────────────────────
if [[ "$MODE" == "programmatic" ]]; then
  ENVELOPE="$(ac_inbox_read "$REQUEST_ID")" || exit 1

else
  # Manual mode: synthesize envelope from defaults, apply arg overrides.

  # 1. Locate MASTER-SPEC.md
  if [[ -n "$SPEC_ARG" ]]; then
    SPEC_PATH="$SPEC_ARG"
  else
    SPEC_PATH="$(pwd)/MASTER-SPEC.md"
  fi

  if [[ ! -r "$SPEC_PATH" ]]; then
    echo "architect-critic: No MASTER-SPEC.md found at ${SPEC_PATH}." >&2
    echo "  Pass --spec PATH or run /onboard first." >&2
    exit 1
  fi

  # 2. Principles path
  PRINCIPLES_PATH="${DATA_DIR}/principles.md"

  # 3. Infer project_class from .onboarding-state.json (or "unknown")
  PROJECT_CLASS="unknown"
  STATE_LINK="$(pwd)/.claude/.onboarding-state.json"
  if [[ -r "$STATE_LINK" ]]; then
    PC="$(jq -r ".answers[\"1.3.1\"] // empty" "$STATE_LINK" 2>/dev/null || true)"
    [[ -n "$PC" ]] && PROJECT_CLASS="$PC"
  fi

  # 4. Defaults
  DEPTH="close"
  [[ -n "$DEPTH_ARG" ]] && DEPTH="$DEPTH_ARG"

  # Accumulated phases default: 1..10
  ACC_PHASES="[1,2,3,4,5,6,7,8,9,10]"

  # Target type + phase
  if [[ -n "$PHASE_ARG" ]]; then
    TARGET_TYPE="master-spec-phase"
    PHASE_NUM="$PHASE_ARG"
    # phase implies premise-audit depth unless overridden
    [[ -z "$DEPTH_ARG" ]] && DEPTH="premise-audit"
  else
    TARGET_TYPE="master-spec-full"
    PHASE_NUM="null"
  fi

  # 5. Generate request_id
  ENTROPY="$(LC_ALL=C tr -dc "a-z0-9" < /dev/urandom 2>/dev/null | head -c6 || echo "xxxxxx")"
  ISO_NOW="$(date -u +"%Y%m%dT%H%M%SZ")"
  if [[ -n "$PHASE_ARG" ]]; then
    REQUEST_ID="crit-${ISO_NOW}-phase${PHASE_NUM}-${ENTROPY}"
  else
    REQUEST_ID="crit-${ISO_NOW}-close-${ENTROPY}"
  fi

  # 6. Build envelope JSON
  INBOX_PATH="${INBOX_DIR}/${REQUEST_ID}.json"

  if [[ "$TARGET_TYPE" == "master-spec-phase" ]]; then
    TARGET_JSON="$(jq -n \
      --arg type "$TARGET_TYPE" \
      --arg path "$SPEC_PATH" \
      --argjson phase_id "$PHASE_NUM" \
      "{type: \$type, path: \$path, phase_id: \$phase_id}")"
  else
    TARGET_JSON="$(jq -n \
      --arg type "$TARGET_TYPE" \
      --arg path "$SPEC_PATH" \
      "{type: \$type, path: \$path}")"
  fi

  ENVELOPE="$(jq -n \
    --arg request_id "$REQUEST_ID" \
    --arg depth "$DEPTH" \
    --argjson adversaries "[\"claude\",\"codex\"]" \
    --argjson target "$TARGET_JSON" \
    --arg principles "$PRINCIPLES_PATH" \
    --argjson accumulated_phases "$ACC_PHASES" \
    --argjson concession_threshold 4 \
    --arg project_class "$PROJECT_CLASS" \
    "{
       request_id: \$request_id,
       depth: \$depth,
       adversaries: \$adversaries,
       target: \$target,
       sources: {
         principles: \$principles,
         accumulated_phases: \$accumulated_phases
       },
       concession_threshold: \$concession_threshold,
       project_class: \$project_class
     }")"

  # 7. Write envelope to inbox (atomic via tmp+mv)
  TMP_INBOX="$(mktemp "${INBOX_PATH}.XXXXXX")"
  printf "%s\n" "$ENVELOPE" > "$TMP_INBOX"
  mv "$TMP_INBOX" "$INBOX_PATH"
  ac_log_info "envelope written to inbox: ${INBOX_PATH}"
fi

# ── Validate envelope ────────────────────────────────────────────────────────
if ! ac_inbox_validate "$ENVELOPE"; then
  echo "architect-critic: envelope validation failed. Fix the envelope and retry." >&2
  exit 1
fi

ac_log_info "envelope validated OK (request_id=${REQUEST_ID})"

echo ""
echo "=== architect-critic: envelope synthesis complete ==="
echo "  request_id : ${REQUEST_ID}"
echo "  mode       : ${MODE}"
DEPTH_DISP="$(printf "%s" "$ENVELOPE" | jq -r ".depth")"
echo "  depth      : ${DEPTH_DISP}"
ADV_DISP="$(printf "%s" "$ENVELOPE" | jq -r ".adversaries | join(\", \")")"
echo "  adversaries: ${ADV_DISP}"
TPATH_DISP="$(printf "%s" "$ENVELOPE" | jq -r ".target.path")"
echo "  spec       : ${TPATH_DISP}"
echo ""

# ── Step 2: principles compose ───────────────────────────────────────────────
source "${PLUGIN_ROOT}/lib/principles.sh"
SPEC_PATH_ENV="$(printf "%s" "$ENVELOPE" | jq -r ".target.path")"
ACC_PHASES_CSV="$(printf "%s" "$ENVELOPE" | jq -r ".sources.accumulated_phases | join(\",\")")"
PRINCIPLES_BLOCK="$(ac_principles_compose "$SPEC_PATH_ENV" "$ACC_PHASES_CSV")"

# ── Step 3: record in_flight ─────────────────────────────────────────────────
DEPTH_FIELD="$(printf "%s" "$ENVELOPE" | jq -r ".depth")"
PHASE_ID_FIELD="$(printf "%s" "$ENVELOPE" | jq -r ".target.phase_id // \"null\"")"
ac_state_append_in_flight "$REQUEST_ID" "$DEPTH_FIELD" "$PHASE_ID_FIELD" || \
  ac_log_warn "could not record in_flight for $REQUEST_ID (non-fatal)"

START_MS="$(date +%s 2>/dev/null || echo 0)"

# ── Step 4: claude-self-audit ────────────────────────────────────────────────
# Read spec content for the prompt
SPEC_CONTENT="$(cat "$SPEC_PATH_ENV" 2>/dev/null || true)"

# Build the audit prompt (claude reads this and writes JSON to a tmp file)
CLAUDE_AUDIT_TMP="$(mktemp /tmp/ac-claude-audit.XXXXXX.json)"

# If ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK is set, use that path (test hook).
if [[ -n "${ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK:-}" && -f "${ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK}" ]]; then
  cp "${ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK}" "$CLAUDE_AUDIT_TMP"
else
  # Claude will write the JSON audit result to $CLAUDE_AUDIT_TMP via the
  # heredoc below.  The surrounding bash session executes this in-context.
  cat > "$CLAUDE_AUDIT_TMP" << AUDIT_PROMPT_EOF
{"challenges":[],"gaps":[]}
AUDIT_PROMPT_EOF
  # Note: the real claude-self-audit prompt is presented to Claude inline.
  # The block below is the audit instruction that Claude (the session running
  # this command) must execute and then write the result to CLAUDE_AUDIT_TMP.
  :
fi

# Present the audit prompt to Claude for in-context reasoning.
# Claude will process the following and overwrite CLAUDE_AUDIT_TMP with real JSON.
# ┌─────────────────────────────────────────────────────────────────────────────
# │ CLAUDE SELF-AUDIT INSTRUCTIONS
# │
# │ You are the architect-critic. Analyse the spec content below against the
# │ composed principles. Return a JSON object with this exact schema (no prose,
# │ no markdown fences — raw JSON only):
# │
# │   {
# │     "challenges": [
# │       {
# │         "severity": "premise"|"gap"|"alternative",
# │         "text": "<challenge text>",
# │         "references": ["<phase or section ref>", ...]
# │       }
# │     ],
# │     "gaps": [
# │       { "text": "<gap text>", "severity": "info"|"warning" }
# │     ]
# │   }
# │
# │ Scoring rubric (use when assessing severity):
# │   1 = bare contradiction  2 = cite-self  3 = partial address
# │   4 = material new info   5 = premise invalidated
# │
# │ severity="premise"     → a foundational assumption that appears unsound
# │ severity="gap"         → a missing element the spec needs to address
# │ severity="alternative" → a viable alternative approach not considered
# │
# │ PRINCIPLES CONTEXT:
# $PRINCIPLES_BLOCK
# │
# │ SPEC CONTENT:
# $SPEC_CONTENT
# │
# │ Write the JSON result to: $CLAUDE_AUDIT_TMP
# └─────────────────────────────────────────────────────────────────────────────

# After Claude writes the result, read it back.
CLAUDE_AUDIT_JSON=""
if [[ -f "$CLAUDE_AUDIT_TMP" ]]; then
  CLAUDE_AUDIT_JSON="$(cat "$CLAUDE_AUDIT_TMP" 2>/dev/null || true)"
fi

# Validate claude audit JSON; fall back to empty if unparseable.
if ! printf "%s" "$CLAUDE_AUDIT_JSON" | jq -e . >/dev/null 2>&1; then
  ac_log_warn "claude-self-audit returned unparseable JSON; using empty result"
  CLAUDE_AUDIT_JSON='"'"'"{"challenges":[],"gaps":[]}'"'"'"
fi
rm -f "$CLAUDE_AUDIT_TMP"

# ── Step 5: codex audit (depth=close only) ────────────────────────────────────
source "${PLUGIN_ROOT}/lib/codex.sh"
CODEX_AUDIT_JSON='{"challenges":[],"gaps":[]}'

if [[ "$DEPTH_FIELD" == "close" ]]; then
  CODEX_PROMPT="You are an independent architectural reviewer. Analyse the following spec for challenges and gaps. Return JSON only — no prose, no fences:
{\"challenges\":[{\"severity\":\"premise\"|\"gap\"|\"alternative\",\"text\":\"...\",\"references\":[\"...\"]}],\"gaps\":[{\"text\":\"...\",\"severity\":\"info\"|\"warning\"}]}

SPEC:
${SPEC_CONTENT}"

  CODEX_RESULT="$(ac_codex_audit "$CODEX_PROMPT" 2>/dev/null || true)"
  if [[ -n "$CODEX_RESULT" ]] && printf "%s" "$CODEX_RESULT" | jq -e . >/dev/null 2>&1; then
    CODEX_AUDIT_JSON="$CODEX_RESULT"
  else
    ac_log_warn "codex audit unavailable or failed; continuing claude-only"
  fi
fi

# ── Step 6: consolidator ─────────────────────────────────────────────────────
source "${PLUGIN_ROOT}/lib/consolidator.sh"
CONSOLIDATED_JSON="$(ac_consolidator_merge "$CLAUDE_AUDIT_JSON" "$CODEX_AUDIT_JSON")" || {
  ac_log_warn "consolidator failed; using claude-only result"
  CONSOLIDATED_JSON="$(jq -n \
    --argjson ch "$(printf "%s" "$CLAUDE_AUDIT_JSON" | jq ".challenges // []")" \
    --argjson gp "$(printf "%s" "$CLAUDE_AUDIT_JSON" | jq ".gaps // []")" \
    "{challenges:\$ch,gaps:\$gp,divergences:[],adversaries_used:[\"claude\"]}")"
}

# ── Step 7: outbox write ──────────────────────────────────────────────────────
source "${PLUGIN_ROOT}/lib/outbox.sh"
END_MS="$(date +%s 2>/dev/null || echo 0)"
ELAPSED_MS=$(( (END_MS - START_MS) * 1000 ))

# Codex cost: tokens not exposed by all codex CLIs; default to 0.
CODEX_TOKENS_IN=0
CODEX_TOKENS_OUT=0
source "${PLUGIN_ROOT}/lib/cost.sh"
CODEX_COST_USD="$(ac_cost_compute "$CODEX_TOKENS_IN" "$CODEX_TOKENS_OUT")"

ac_outbox_write "$REQUEST_ID" "$CONSOLIDATED_JSON" "$ELAPSED_MS" "$CODEX_COST_USD" || \
  ac_log_warn "outbox write failed for $REQUEST_ID"

# ── Step 8: rebuttal cycle ───────────────────────────────────────────────────
source "${PLUGIN_ROOT}/lib/scorer.sh"
CHALLENGES_ARR="$(printf "%s" "$CONSOLIDATED_JSON" | jq -c ".challenges[]?" 2>/dev/null)"
if [[ -z "$CHALLENGES_ARR" ]]; then
  echo ""
  echo "No challenges. Spec passes premise audit at this depth."
elif [[ -t 0 ]] || [[ -n "${ARCHITECT_CRITIC_REBUT_INPUT:-}" ]]; then
  echo ""
  echo "=== Rebuttal cycle ==="
  while IFS= read -r ch_json; do
    [[ -z "$ch_json" ]] && continue
    ch_text="$(printf "%s" "$ch_json" | jq -r .text)"
    ch_sev="$(printf "%s" "$ch_json" | jq -r .severity)"
    ch_refs="$(printf "%s" "$ch_json" | jq -r ".references | join(\", \")")"
    echo ""
    echo "[${ch_sev}] ${ch_text}"
    [[ -n "$ch_refs" ]] && echo "  refs: ${ch_refs}"
    while true; do
      printf "  Your response (accept | edit | note | <rebuttal>): "
      IFS= read -r rebut || break 2
      case "$rebut" in
        accept|edit|note|"")
          echo "  → recorded as: ${rebut:-accept}"
          break
          ;;
        *)
          score="$(ac_scorer_score_rebuttal "$ch_text" "$rebut")"
          decision="$(ac_scorer_decide "$score")"
          if [[ "$decision" == "concede" ]]; then
            echo "  → Acknowledged — your rebuttal addresses this (score=${score})."
            break
          else
            echo "  → That doesn'\''t address it (score=${score}). The challenge stands."
            break
          fi
          ;;
      esac
    done
  done < <(printf "%s\n" "$CHALLENGES_ARR")
else
  echo ""
  echo "(non-interactive session — skipping rebuttal cycle)"
fi

# ── Step 9: auto-promotion offer ─────────────────────────────────────────────
source "${PLUGIN_ROOT}/lib/promotion.sh"
CURRENT_CH="$(printf "%s" "$CONSOLIDATED_JSON" | jq -c ".challenges // []")"
WR_CANDS="$(ac_promotion_within_run_candidates "$CURRENT_CH" 2>/dev/null || echo "[]")"
CR_CANDS="$(ac_promotion_cross_run_candidates "$CURRENT_CH" 2>/dev/null || echo "[]")"
ALL_CANDS="$(jq -n --argjson w "$WR_CANDS" --argjson c "$CR_CANDS" "\$w + \$c")"
ALL_CANDS="$(ac_promotion_filter_suppressed "$ALL_CANDS" 2>/dev/null || echo "[]")"
ac_promotion_record_candidates "$ALL_CANDS" 2>/dev/null || true

CAND_COUNT="$(printf "%s" "$ALL_CANDS" | jq "length" 2>/dev/null || echo 0)"
if [[ "$CAND_COUNT" -gt 0 ]] && { [[ -t 0 ]] || [[ -n "${ARCHITECT_CRITIC_OFFER_INPUT:-}" ]]; }; then
  echo ""
  echo "=== Auto-promotion offer ==="
  while IFS= read -r cand_json; do
    [[ -z "$cand_json" ]] && continue
    cand_text="$(printf "%s" "$cand_json" | jq -r .text)"
    if [[ -n "${ARCHITECT_CRITIC_PROMOTION_MOCK:-}" ]]; then
      cand_text="$ARCHITECT_CRITIC_PROMOTION_MOCK"
    fi
    echo ""
    echo "I noticed a pattern across recent runs:"
    echo "  \"${cand_text}\""
    printf "Add to principles.md? [y]es / [n]o / [e]dit: "
    IFS= read -r ans || break
    case "$ans" in
      y|Y|yes)
        ac_state_append_promotion "auto" "$cand_text" "user" || true
        PFILE="$(ac_principles_path)"
        printf "%s [promoted %s source:auto]\n" "$cand_text" "$(date -u +%Y-%m-%d)" >> "$PFILE"
        echo "  → promoted to principles.md"
        ;;
      n|N|no)
        ac_promotion_record_decline "$cand_text" || true
        echo "  → declined (suppressed for 30 days)"
        ;;
      e|E|edit)
        TMP="$(mktemp)"
        printf "%s\n" "$cand_text" > "$TMP"
        "${EDITOR:-true}" "$TMP" 2>/dev/null || true
        edited="$(head -1 "$TMP")"
        rm -f "$TMP"
        if [[ -n "$edited" ]]; then
          ac_state_append_promotion "auto" "$edited" "user" || true
          PFILE="$(ac_principles_path)"
          printf "%s [promoted %s source:auto]\n" "$edited" "$(date -u +%Y-%m-%d)" >> "$PFILE"
          echo "  → promoted (edited) to principles.md"
        else
          echo "  → cancelled"
        fi
        ;;
    esac
  done < <(printf "%s\n" "$(printf "%s" "$ALL_CANDS" | jq -c ".[]")")
elif [[ "$CAND_COUNT" -gt 0 ]]; then
  echo ""
  echo "(non-interactive — ${CAND_COUNT} promotion candidate(s) recorded but not offered)"
fi

# ── Step 10: cost line ───────────────────────────────────────────────────────
echo ""
ac_cost_print "$CODEX_COST_USD" "0"

# ── Step 11: record completion in state ──────────────────────────────────────
CHALLENGE_COUNT="$(printf "%s" "$CONSOLIDATED_JSON" | jq ".challenges | length" 2>/dev/null || echo 0)"
DIVERGENCE_COUNT="$(printf "%s" "$CONSOLIDATED_JSON" | jq ".divergences | length" 2>/dev/null || echo 0)"
ADVERSARIES_USED="$(printf "%s" "$CONSOLIDATED_JSON" | jq -c ".adversaries_used // [\"claude\"]" 2>/dev/null || echo "[\"claude\"]")"
COMPLETED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")"

RUN_JSON="$(jq -n \
  --arg rid "$REQUEST_ID" \
  --arg cat "$COMPLETED_AT" \
  --arg dep "$DEPTH_FIELD" \
  --argjson adv "$ADVERSARIES_USED" \
  --argjson cc "$CHALLENGE_COUNT" \
  --argjson dc "$DIVERGENCE_COUNT" \
  --argjson em "$ELAPSED_MS" \
  --argjson cu "$CODEX_COST_USD" \
  "{request_id:\$rid,completed_at:\$cat,depth:\$dep,adversaries_used:\$adv,challenge_count:\$cc,divergence_count:\$dc,elapsed_ms:\$em,cost_usd:\$cu}")"

ac_state_remove_in_flight "$REQUEST_ID" || ac_log_warn "could not remove in_flight for $REQUEST_ID"
ac_state_append_recent_run "$RUN_JSON" || ac_log_warn "could not append recent_run for $REQUEST_ID"

echo ""
echo "=== architect-critic: audit complete ==="
echo "  request_id  : ${REQUEST_ID}"
echo "  challenges  : ${CHALLENGE_COUNT}"
echo "  divergences : ${DIVERGENCE_COUNT}"
echo "  outbox      : $(ac_outbox_dir)/${REQUEST_ID}.json"
echo ""
'
```

After the bash block completes the audit pipeline has run end-to-end:
- Envelope validated, principles composed, in_flight recorded.
- Claude-self-audit executed (or mocked via `ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK`).
- Codex audit dispatched if `depth=close` (graceful fallback on failure).
- Consolidator merged both adversaries.
- Outbox written atomically; state updated (in_flight removed, recent_run appended).
- Phase E will replace the rebuttal-cycle and auto-promotion stubs.
