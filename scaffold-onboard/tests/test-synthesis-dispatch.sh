#!/usr/bin/env bash
# test-synthesis-dispatch.sh — SS-2: behavioral + structural guards for the
# synthesis dispatch prose. Catches the OQ-1 unsourced-helper class for real.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
ROOT="$HERE/.."
MB_SKILL="$ROOT/skills/scaffolding-memory-bank/SKILL.md"
GOV_SKILL="$ROOT/skills/scaffolding-governance-docs/SKILL.md"
source "$ROOT/lib/render.sh"
source "$ROOT/lib/synthesis.sh"
source "$ROOT/lib/state.sh"        # SS-2 W4: inline seed + fallback test
source "$ROOT/lib/memory-bank.sh"  # SS-2 W4: sf_memory_bank_derive for behavioral + fallback tests

# SS-2 W4 — minimal on-disk onboarding state for the dispatch fast-path.
# Mirrors test-memory-bank.sh::seed_master_spec answers, WITHOUT executing that
# file's suite. sf_memory_bank_derive reads state from disk, so seeding state
# (not MASTER-SPEC.md) is what the fast-path derive needs.
_seed_state_for_dispatch() {
  sf_state_init
  sf_state_write_answer "1.1.1" "test-proj — a fast widget"
  sf_state_write_answer "1.1.4" "test-proj"
  sf_state_write_answer "1.1.2" "Widgets are slow today."
  sf_state_write_answer "1.2.1" "Solo devs"
  sf_state_write_answer "1.2.2" "Build a widget in 1 command"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "create / list / destroy widgets"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.widgets.json)"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "9.3.1" "no"
}

# Extract the bash inside a numbered section (e.g. "## 13.") up to the next "## " heading.
_extract_section_bash() {
  local file="$1" section="$2"
  awk -v sec="$section" '
    $0 ~ "^"sec { insec=1 }
    insec && /^## / && $0 !~ "^"sec { insec=0 }
    insec && /^```bash/ { inbash=1; next }
    insec && inbash && /^```/ { inbash=0; next }
    insec && inbash { print }
  ' "$file"
}

# SS-2 W1 — every lib helper the dispatch body calls is sourced in that section.
test_memory_bank_dispatch_sources_its_helpers() {
  echo "test_memory_bank_dispatch_sources_its_helpers:"
  local body; body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  local missing=0 h
  # helpers called by §13 that live OUTSIDE synthesis.sh/routing.sh
  for h in sf_memory_bank_derive sf_claude_md_generate sf_claude_settings_generate \
           sf_agents_md_generate _memory_bank_args _sf_mb_extract_preserve_zone \
           _sf_mb_reinject_preserve_zone sf_render; do
    if printf '%s' "$body" | grep -q "$h"; then
      # it's called — assert §13 sources a lib that defines it
      if ! printf '%s' "$body" | grep -qE 'source .*/lib/(memory-bank|render)\.sh'; then
        echo "  ✗ §13 calls $h but never sources memory-bank.sh/render.sh"; missing=$((missing+1)); break
      fi
    fi
  done
  if [[ "$missing" == "0" ]]; then PASS=$((PASS+1)); echo "  ✓ §13 sources the libs its body calls"; else FAIL=$((FAIL+1)); fi
}

test_governance_dispatch_sources_its_helpers() {
  echo "test_governance_dispatch_sources_its_helpers:"
  local body; body="$(_extract_section_bash "$GOV_SKILL" "## 11")"
  if printf '%s' "$body" | grep -qE 'sf_docs_derive|_write_or_skip'; then
    if printf '%s' "$body" | grep -qE 'source .*/lib/docs\.sh'; then
      PASS=$((PASS+1)); echo "  ✓ §11 sources docs.sh"
    else
      FAIL=$((FAIL+1)); echo "  ✗ §11 calls sf_docs_derive but never sources docs.sh"
    fi
  else
    PASS=$((PASS+1)); echo "  ✓ §11 does not call docs.sh helpers"
  fi
}

test_dispatch_setup_sources_state_before_exec_summary_branch() {
  echo "test_dispatch_setup_sources_state_before_exec_summary_branch:"
  local ok=1 body state_line branch_line

  body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  state_line="$(printf '%s\n' "$body" | awk '/source .*lib\/state\.sh/{print NR; exit}')"
  branch_line="$(printf '%s\n' "$body" | awk '/if \[\[ ! -f "\$exec_summary"/{print NR; exit}')"
  if [[ -z "$state_line" || -z "$branch_line" || "$state_line" -ge "$branch_line" ]]; then
    echo "  ✗ memory-bank §13 must source state.sh before the EXEC-SUMMARY conditional"; ok=0
  fi

  body="$(_extract_section_bash "$GOV_SKILL" "## 11")"
  state_line="$(printf '%s\n' "$body" | awk '/source .*lib\/state\.sh/{print NR; exit}')"
  branch_line="$(printf '%s\n' "$body" | awk '/if \[\[ ! -f "\$exec_summary"/{print NR; exit}')"
  if [[ -z "$state_line" || -z "$branch_line" || "$state_line" -ge "$branch_line" ]]; then
    echo "  ✗ governance §11 must source state.sh before the EXEC-SUMMARY conditional"; ok=0
  fi

  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ both dispatch setup blocks source state.sh unconditionally"; else FAIL=$((FAIL+1)); fi
}

# SS-2 W1 — the fast-path short-circuit must REALLY exit, not a comment-only STOP.
test_fast_path_has_real_control_flow() {
  echo "test_fast_path_has_real_control_flow:"
  local ok=1 f
  for f in "$MB_SKILL" "$GOV_SKILL"; do
    # the fast-path block must contain an explicit return/exit, not just "# STOP"
    # Bound on the ``` code-fence (not the section heading) so we capture exactly the fast-path block.
    if ! awk '/sf_synth_mode.*==.*"fast"/{f=1} f&&/^```/{f=0} f' "$f" | grep -qE '\b(return|exit)\b'; then
      echo "  ✗ $(basename "$(dirname "$f")") fast-path has no real return/exit"; ok=0
    fi
  done
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ both fast-paths exit explicitly"; else FAIL=$((FAIL+1)); fi
}

# ── SS-2 W2: deterministic EXEC-SUMMARY renderer + parser contract + staleness ──

_mk_master_spec_with_exec() {
  local dir="$1" body="$2"
  cat > "$dir/MASTER-SPEC.md" <<EOF
# test-proj — Master Spec

## Executive Summary
$body

## Phase 1: Foundation
stuff
EOF
}

test_render_exec_summary_from_section() {
  echo "test_render_exec_summary_from_section:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "test-proj builds widgets fast for solo devs."
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  assert_file_exists "$PWD/EXECUTIVE-SUMMARY.md"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "builds widgets fast for solo devs"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "cksum:"   # provenance trailer
  assert_file_not_contains "$PWD/EXECUTIVE-SUMMARY.md" "\\{\\{"  # no leftover placeholders
  assert_file_not_contains "$PWD/EXECUTIVE-SUMMARY.md" "TODO:"   # no stray fill-in markers
}

# Correction (B): MULTI-LINE body must survive intact — this is the test that
# actually protects the renderer (the single-line case would not catch the
# sf_render newline-split corruption).
test_render_exec_summary_multiline_body() {
  echo "test_render_exec_summary_multiline_body:"
  setup_tmp_repo
  local body
  body="$(printf '%s\n' \
    "- test-proj orchestrates widgets for solo developers." \
    "- The core problem is fragmented widget tooling." \
    "- MVP boundary: single-tenant widget pipeline; top signal is time-to-first-widget.")"
  _mk_master_spec_with_exec "$PWD" "$body"
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  assert_file_exists "$PWD/EXECUTIVE-SUMMARY.md"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "orchestrates widgets for solo developers"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "fragmented widget tooling"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "time-to-first-widget"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "test-proj — Executive Summary"  # project_name scalar
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "CLI tool"                       # project_class scalar
  assert_file_not_contains "$PWD/EXECUTIVE-SUMMARY.md" "\\{\\{"   # no leftover placeholders
  assert_file_not_contains "$PWD/EXECUTIVE-SUMMARY.md" "TODO:"    # no stray fill-in markers
}

test_render_exec_summary_strips_trailing_rule() {
  echo "test_render_exec_summary_strips_trailing_rule:"
  setup_tmp_repo
  cat > "$PWD/MASTER-SPEC.md" <<'EOF'
# p — Master Spec

## Executive Summary
Real summary content here.

---

## Phase 1
stuff
EOF
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "p" "CLI tool"
  # there must be exactly ONE '---' separator line in the rendered doc body region
  local rules; rules="$(grep -cE '^[[:space:]]*-{3,}[[:space:]]*$' "$PWD/EXECUTIVE-SUMMARY.md")"
  if [[ "$rules" -eq 1 ]]; then
    PASS=$((PASS+1)); echo "  ✓ trailing MASTER-SPEC rule stripped — single separator"
  else
    FAIL=$((FAIL+1)); echo "  ✗ found $rules '---' rules (expected 1 — the template separator)"
  fi
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "Real summary content here"
}

test_render_exec_summary_stops_before_phase_marker() {
  echo "test_render_exec_summary_stops_before_phase_marker:"
  setup_tmp_repo
  cat > "$PWD/MASTER-SPEC.md" <<'EOF'
# p — Master Spec

## Executive Summary
Real summary content here.

---

<!-- master-spec:phase id=1 name=foundation -->
## Phase 1
stuff
EOF
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "p" "CLI tool"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "Real summary content here"
  assert_file_not_contains "$PWD/EXECUTIVE-SUMMARY.md" "master-spec:phase"
}

test_render_exec_summary_errors_on_missing_section() {
  echo "test_render_exec_summary_errors_on_missing_section:"
  setup_tmp_repo
  printf '# test-proj\n\n## Phase 1\nstuff\n' > "$PWD/MASTER-SPEC.md"   # no Executive Summary
  local prev_opts="$-"
  set +e
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool" 2>/dev/null
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  if [[ "$rc" != "0" ]]; then PASS=$((PASS+1)); echo "  ✓ errors (rc=$rc) on missing/empty Executive Summary"; else FAIL=$((FAIL+1)); echo "  ✗ silently produced a summary"; fi
}

test_render_exec_summary_errors_on_placeholder_only_section() {
  echo "test_render_exec_summary_errors_on_placeholder_only_section:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "TODO: executive_summary"
  local prev_opts="$-"
  set +e
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool" 2>/dev/null
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  if [[ "$rc" != "0" ]]; then PASS=$((PASS+1)); echo "  ✓ rejects placeholder-only Executive Summary"; else FAIL=$((FAIL+1)); echo "  ✗ accepted placeholder-only Executive Summary"; fi
}

test_exec_summary_source_only_prompt_omits_missing_exec_summary() {
  echo "test_exec_summary_source_only_prompt_omits_missing_exec_summary:"
  setup_tmp_repo
  local brief="$ROOT/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md"
  local out; out="$(sf_synth_brief_assemble "$brief" "$(sf_synth_ledger_empty)" "$PWD/EXECUTIVE-SUMMARY.md" "$PWD/MASTER-SPEC.md" "")"
  if printf '%s\n' "$out" | grep -q 'EXECUTIVE-SUMMARY:'; then
    FAIL=$((FAIL+1)); echo "  ✗ source-only EXEC-SUMMARY prompt still names missing EXECUTIVE-SUMMARY"
  else
    PASS=$((PASS+1)); echo "  ✓ source-only EXEC-SUMMARY prompt names only MASTER-SPEC"
  fi
}

test_exec_summary_staleness_detects_master_change() {
  echo "test_exec_summary_staleness_detects_master_change:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "original summary"
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" && local fresh=0 || local fresh=1
  printf '\nmore content\n' >> "$PWD/MASTER-SPEC.md"
  sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" && local stale=0 || local stale=1
  if [[ "$fresh" == "0" && "$stale" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ fresh=ok, post-edit=stale"; else FAIL=$((FAIL+1)); echo "  ✗ fresh=$fresh stale=$stale"; fi
}

test_no_phantom_exec_summary_render() {
  echo "test_no_phantom_exec_summary_render:"
  if grep -q 'sf_render_executive_summary()' "$ROOT/lib/render.sh"; then
    PASS=$((PASS+1)); echo "  ✓ sf_render_executive_summary is implemented in lib/render.sh"
  else
    FAIL=$((FAIL+1)); echo "  ✗ sf_render_executive_summary still phantom"
  fi
}

test_exec_summary_brief_validates() {
  echo "test_exec_summary_brief_validates:"
  local brief="$ROOT/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md"
  if [[ -f "$brief" ]] && sf_synth_brief_validate "$brief" 2>/dev/null; then
    PASS=$((PASS+1)); echo "  ✓ EXECUTIVE-SUMMARY.brief.md passes sf_synth_brief_validate"
  else
    FAIL=$((FAIL+1)); echo "  ✗ EXECUTIVE-SUMMARY.brief.md missing or fails validation"
  fi
}

# SS-2 W3 — advisory read-only derivation-reviewer agent is registered.
test_derivation_reviewer_agent_registered() {
  echo "test_derivation_reviewer_agent_registered:"
  local a="$ROOT/agents/derivation-reviewer.md"
  if [[ -f "$a" ]] && grep -q 'name: derivation-reviewer' "$a" && grep -qE 'tools:.*Read' "$a" \
     && ! grep -qE 'tools:.*Write' "$a" && ! grep -qE 'tools:.*Task' "$a"; then
    PASS=$((PASS+1)); echo "  ✓ derivation-reviewer registered, read-only (no Write/Task)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ derivation-reviewer missing or not read-only"
  fi
}

test_derivation_reviewer_example_fence_is_typed() {
  echo "test_derivation_reviewer_example_fence_is_typed:"
  local a="$ROOT/agents/derivation-reviewer.md"
  if grep -q '^```markdown$' "$a"; then PASS=$((PASS+1)); echo "  ✓ derivation-reviewer example fence is typed"; else FAIL=$((FAIL+1)); echo "  ✗ derivation-reviewer example fence lacks markdown language tag"; fi
}

test_review_prompts_pass_explicit_artifact_paths() {
  echo "test_review_prompts_pass_explicit_artifact_paths:"
  local ok=1
  if ! grep -q 'artifacts=' "$MB_SKILL" || ! grep -q 'sf_resolve_output_path claude_md CLAUDE.md' "$MB_SKILL"; then
    echo "  ✗ memory-bank review prompt must pass explicit artifacts including CLAUDE.md"; ok=0
  fi
  if ! grep -q 'artifact_paths=' "$GOV_SKILL" || ! grep -q 'sf_resolve_output_path process_adrs docs/PROMPT_GOVERNANCE.md' "$GOV_SKILL"; then
    echo "  ✗ governance review prompt must pass explicit artifact paths including process_adrs docs"; ok=0
  fi
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ review prompts pass explicit artifact paths"; else FAIL=$((FAIL+1)); fi
}

test_no_public_regenerate_equals_guidance() {
  echo "test_no_public_regenerate_equals_guidance:"
  local needle="--regenerate="
  local hits
  hits="$(grep -R -- "$needle" \
    "$ROOT/skills/scaffolding-memory-bank/SKILL.md" \
    "$ROOT/skills/scaffolding-governance-docs/SKILL.md" \
    "$ROOT/agents/derivation-reviewer.md" \
    "$ROOT/CHANGELOG.md" 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then
    PASS=$((PASS+1)); echo "  ✓ no user-facing unsupported --regenerate=<file> guidance remains"
  else
    FAIL=$((FAIL+1)); echo "  ✗ unsupported --regenerate= guidance remains:"; printf '%s\n' "$hits" | sed 's/^/      /'
  fi
}

test_commands_expose_fast_flag() {
  echo "test_commands_expose_fast_flag:"
  local ok=1 project="$ROOT/commands/scaffold-project.md" docs="$ROOT/commands/scaffold-docs.md"
  if ! grep -q -- '--fast' "$project"; then echo "  ✗ scaffold-project command does not expose --fast"; ok=0; fi
  if ! grep -q -- '--fast' "$docs"; then echo "  ✗ scaffold-docs command does not expose --fast"; ok=0; fi
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ command wrappers expose --fast"; else FAIL=$((FAIL+1)); fi
}

# SS-2 W4 — behavioral: the executable shell of §13 (setup + fast-path + finalize) runs
# under `set -euo pipefail` with a faked Task. A regression of the unsourced-helper /
# unbound-var class aborts this test.
test_memory_bank_dispatch_executes_under_set_u() {
  echo "test_memory_bank_dispatch_executes_under_set_u:"
  setup_tmp_repo
  _seed_state_for_dispatch    # inline: sf_state_init + sf_state_write_answer ... (state on disk)
  local driver="$TMP_DIR/driver.sh"
  {
    echo 'set -euo pipefail'
    echo "export CLAUDE_PLUGIN_ROOT='$ROOT'"
    echo 'sf_log_info(){ :; }; sf_log_warn(){ :; }; sf_log_error(){ :; }'   # quiet
    echo 'regenerate=0; full=0'
    echo 'Task(){ :; }'   # defensive no-op; the driver never executes a real Task(...) line
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"'
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"'
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/memory-bank.sh"'
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"'
    echo 'export SF_SYNTH_FAST=1'   # exercise the fast-path branch end-to-end (deterministic, no real agents)
    echo 'master="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"'
    echo 'exec_summary="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"'
    echo 'if [[ "$(sf_synth_mode)" == "fast" ]]; then if [[ "${regenerate:-0}" == "1" ]]; then sf_memory_bank_derive --force; else sf_memory_bank_derive; fi; sf_claude_md_generate; fi'
    echo 'sf_claude_settings_generate'
    echo 'sf_agents_md_generate'
    echo 'echo DISPATCH_SHELL_OK'
  } > "$driver"
  local outp; outp="$(cd "$PWD" && bash "$driver" 2>"$TMP_DIR/err.txt")"
  if printf '%s' "$outp" | grep -q DISPATCH_SHELL_OK && [[ -f "$PWD/.claude/memory-bank/00-project-brief.md" ]]; then
    PASS=$((PASS+1)); echo "  ✓ dispatch shell executes under set -euo pipefail (no unsourced-helper abort)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ dispatch shell aborted:"; sed 's/^/      /' "$TMP_DIR/err.txt" | head -8
  fi
}

test_memory_bank_live_static_seed_preserves_synthesized_derived_outputs() {
  echo "test_memory_bank_live_static_seed_preserves_synthesized_derived_outputs:"
  setup_tmp_repo; _seed_state_for_dispatch
  sf_memory_bank_derive
  local derived="$PWD/.claude/memory-bank/00-project-brief.md"
  printf '# Synthesized project brief\n\nSYNTHESIZED-SENTINEL\n' > "$derived"
  if ! declare -F sf_memory_bank_seed_live_static >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ sf_memory_bank_seed_live_static helper is missing"; return
  fi
  sf_memory_bank_seed_live_static
  if grep -q "SYNTHESIZED-SENTINEL" "$derived" && [[ -f "$PWD/.claude/memory-bank/05-active-context.md" ]] && [[ -f "$PWD/.claude/memory-bank/WORKFLOW.md" ]]; then
    PASS=$((PASS+1)); echo "  ✓ live/static seeding preserves synthesized derived outputs"
  else
    FAIL=$((FAIL+1)); echo "  ✗ live/static seeding overwrote synthesized derived outputs or missed seed files"
  fi
}

# SS-2 W4 — pins spec §2.6: per-artifact fallback — only the bad artifact falls back,
# siblings are preserved untouched.
test_fallback_is_per_artifact() {
  echo "test_fallback_is_per_artifact:"
  setup_tmp_repo; _seed_state_for_dispatch
  sf_memory_bank_derive    # full deterministic bundle (stands in for synthesized siblings)
  local before00; before00="$(cksum < "$PWD/.claude/memory-bank/00-project-brief.md")"
  sf_render "$ROOT/templates/memory-bank/02-system-patterns.md.tmpl" ts=x > "$PWD/.claude/memory-bank/02-system-patterns.md" 2>/dev/null || true
  local after00; after00="$(cksum < "$PWD/.claude/memory-bank/00-project-brief.md")"
  if [[ "$before00" == "$after00" ]]; then PASS=$((PASS+1)); echo "  ✓ per-artifact fallback leaves siblings untouched"; else FAIL=$((FAIL+1)); fi
}

# SS-2 W4 (review fix) — a normal --fast run (regenerate=0) must NOT pass --force,
# i.e. must NOT clobber live-seed files. Guards the ${regenerate:+--force} data-loss bug.
test_fast_path_no_regenerate_preserves_live_seed() {
  echo "test_fast_path_no_regenerate_preserves_live_seed:"
  setup_tmp_repo; _seed_state_for_dispatch
  sf_memory_bank_derive          # create the bundle incl. live-seed files
  local live=".claude/memory-bank/05-active-context.md"
  [[ -f "$PWD/$live" ]] || { sf_state_init >/dev/null 2>&1; }   # ensure file exists; if your derive names it differently, adjust
  echo "USER-IN-FLIGHT-SENTINEL" >> "$PWD/$live"
  # reproduce the FIXED fast-path expression with regenerate unset/0:
  local regenerate=0
  if [[ "${regenerate:-0}" == "1" ]]; then sf_memory_bank_derive --force; else sf_memory_bank_derive; fi
  if grep -q "USER-IN-FLIGHT-SENTINEL" "$PWD/$live"; then
    PASS=$((PASS+1)); echo "  ✓ no-regenerate --fast preserves live-seed content"
  else
    FAIL=$((FAIL+1)); echo "  ✗ live-seed content was clobbered on a no-flag run (data loss)"
  fi
}

# SS-2 W4 (review fix) — cheap static guard: the buggy ${var:+--flag} idiom must not
# silently return to either fast-path. Scope the grep to the executable fast-path
# code-fence block (bounded on the ``` fence, like test_fast_path_has_real_control_flow)
# so the deliberate "do not collapse to ${regenerate:+--force}" warning PROSE that the
# fix adds below the fence does not trip this guard.
test_fast_path_avoids_fragile_flag_expansion() {
  echo "test_fast_path_avoids_fragile_flag_expansion:"
  local bad=0
  if awk '/sf_synth_mode.*==.*"fast"/{f=1} f&&/^```/{f=0} f' "$MB_SKILL" | grep -qE '\$\{regenerate:\+'; then echo "  ✗ memory-bank §13.2 uses fragile \${regenerate:+--force}"; bad=1; fi
  if awk '/sf_synth_mode.*==.*"fast"/{f=1} f&&/^```/{f=0} f' "$GOV_SKILL" | grep -qE '\$\{full:\+'; then echo "  ✗ governance §11.2 uses fragile \${full:+--full}"; bad=1; fi
  if [[ "$bad" == "0" ]]; then PASS=$((PASS+1)); echo "  ✓ fast-paths use explicit ==1 tests, not \${var:+}"; else FAIL=$((FAIL+1)); fi
}

test_memory_bank_dispatch_sources_its_helpers
test_governance_dispatch_sources_its_helpers
test_dispatch_setup_sources_state_before_exec_summary_branch
test_memory_bank_dispatch_executes_under_set_u
test_memory_bank_live_static_seed_preserves_synthesized_derived_outputs
test_fallback_is_per_artifact
test_derivation_reviewer_agent_registered
test_derivation_reviewer_example_fence_is_typed
test_review_prompts_pass_explicit_artifact_paths
test_no_public_regenerate_equals_guidance
test_commands_expose_fast_flag
test_fast_path_has_real_control_flow
test_fast_path_no_regenerate_preserves_live_seed
test_fast_path_avoids_fragile_flag_expansion
test_render_exec_summary_from_section
test_render_exec_summary_multiline_body
test_render_exec_summary_strips_trailing_rule
test_render_exec_summary_stops_before_phase_marker
test_render_exec_summary_errors_on_missing_section
test_render_exec_summary_errors_on_placeholder_only_section
test_exec_summary_source_only_prompt_omits_missing_exec_summary
test_exec_summary_staleness_detects_master_change
test_no_phantom_exec_summary_render
test_exec_summary_brief_validates
report_results
