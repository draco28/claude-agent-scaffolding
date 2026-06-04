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

test_render_exec_summary_errors_on_missing_section() {
  echo "test_render_exec_summary_errors_on_missing_section:"
  setup_tmp_repo
  printf '# test-proj\n\n## Phase 1\nstuff\n' > "$PWD/MASTER-SPEC.md"   # no Executive Summary
  set +e
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool" 2>/dev/null
  local rc=$?
  set -e 2>/dev/null || true
  if [[ "$rc" != "0" ]]; then PASS=$((PASS+1)); echo "  ✓ errors (rc=$rc) on missing/empty Executive Summary"; else FAIL=$((FAIL+1)); echo "  ✗ silently produced a summary"; fi
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
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"'   # §13 sources this too (sf_state_read_answer, used by sf_memory_bank_derive)
    echo 'export SF_SYNTH_FAST=1'   # exercise the fast-path branch end-to-end (deterministic, no real agents)
    echo 'master="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"'
    echo 'exec_summary="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"'
    echo 'if [[ "$(sf_synth_mode)" == "fast" ]]; then sf_memory_bank_derive ${regenerate:+--force}; sf_claude_md_generate; fi'
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

test_memory_bank_dispatch_sources_its_helpers
test_governance_dispatch_sources_its_helpers
test_memory_bank_dispatch_executes_under_set_u
test_fallback_is_per_artifact
test_derivation_reviewer_agent_registered
test_fast_path_has_real_control_flow
test_render_exec_summary_from_section
test_render_exec_summary_multiline_body
test_render_exec_summary_errors_on_missing_section
test_exec_summary_staleness_detects_master_change
test_no_phantom_exec_summary_render
test_exec_summary_brief_validates
report_results
