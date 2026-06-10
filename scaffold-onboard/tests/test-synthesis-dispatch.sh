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
source "$ROOT/lib/memory-bank.sh"  # mechanical helpers (seed_live_static, _sf_mb_*) for behavioral tests

# Minimal on-disk onboarding state for the dispatch tests. Mirrors
# test-memory-bank.sh::seed_master_spec answers, WITHOUT executing that file's suite.
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
  for h in sf_memory_bank_seed_live_static sf_claude_md_generate sf_claude_settings_generate \
           sf_agents_md_generate _sf_mb_extract_preserve_zone \
           _sf_mb_reinject_preserve_zone _sf_mb_migrate_harvested; do
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

test_exec_summary_synthesized_output_updates_master_spec_source() {
  echo "test_exec_summary_synthesized_output_updates_master_spec_source:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "{{executive_summary}}"
  cat > "$PWD/EXECUTIVE-SUMMARY.md" <<'EOF'
## Executive Summary

Synthesized summary from the agent.

It names the users, MVP boundary, and success signal.
EOF
  if ! declare -F sf_render_executive_summary_from_synthesized >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ sf_render_executive_summary_from_synthesized helper is missing"; return
  fi
  sf_render_executive_summary_from_synthesized "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  assert_file_contains "$PWD/MASTER-SPEC.md" "Synthesized summary from the agent"
  assert_file_not_contains "$PWD/MASTER-SPEC.md" "\\{\\{executive_summary\\}\\}"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "Synthesized summary from the agent"
  if sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md"; then
    PASS=$((PASS+1)); echo "  ✓ synthesized summary is copied into MASTER-SPEC before checksum"
  else
    FAIL=$((FAIL+1)); echo "  ✗ synthesized EXECUTIVE-SUMMARY is stale vs updated MASTER-SPEC"
  fi
}

# SS-2 PR#55 review — the MASTER-SPEC write-back choke point must refuse to write a
# body that contains a section delimiter (## heading / --- rule / phase marker), since
# the pinned "## Executive Summary" section's own extractor stops at those — writing one
# back silently truncates / corrupts MASTER-SPEC.
_mk_master_spec_two_sections() {
  cat > "$PWD/MASTER-SPEC.md" <<'EOF'
# test-proj — Master Spec

## Executive Summary
Original clean summary body.

## Phase 1: Foundation
phase one stuff
EOF
}

test_master_spec_writeback_rejects_embedded_rule() {
  echo "test_master_spec_writeback_rejects_embedded_rule:"
  setup_tmp_repo
  _mk_master_spec_two_sections
  local before; before="$(cksum < "$PWD/MASTER-SPEC.md")"
  local body
  body="$(printf '%s\n' "First sentence of the summary." "---" "Second sentence after a rule.")"
  local prev_opts="$-"; set +e
  _sf_master_spec_replace_section_body "$PWD/MASTER-SPEC.md" "Executive Summary" "$body" 2>/dev/null
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  local after; after="$(cksum < "$PWD/MASTER-SPEC.md")"
  if [[ "$rc" != "0" && "$before" == "$after" ]]; then
    PASS=$((PASS+1)); echo "  ✓ rejected embedded --- rule (rc=$rc) and left MASTER-SPEC byte-identical"
  else
    FAIL=$((FAIL+1)); echo "  ✗ rc=$rc; MASTER-SPEC changed=$([[ "$before" == "$after" ]] && echo no || echo YES)"
  fi
}

test_master_spec_writeback_rejects_embedded_heading() {
  echo "test_master_spec_writeback_rejects_embedded_heading:"
  setup_tmp_repo
  _mk_master_spec_two_sections
  local before; before="$(cksum < "$PWD/MASTER-SPEC.md")"
  local body
  body="$(printf '%s\n' "First sentence of the summary." "## Foo" "Tail after an injected heading.")"
  local prev_opts="$-"; set +e
  _sf_master_spec_replace_section_body "$PWD/MASTER-SPEC.md" "Executive Summary" "$body" 2>/dev/null
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  local after; after="$(cksum < "$PWD/MASTER-SPEC.md")"
  if [[ "$rc" != "0" && "$before" == "$after" ]]; then
    PASS=$((PASS+1)); echo "  ✓ rejected embedded ## heading (rc=$rc) and left MASTER-SPEC byte-identical"
  else
    FAIL=$((FAIL+1)); echo "  ✗ rc=$rc; MASTER-SPEC changed=$([[ "$before" == "$after" ]] && echo no || echo YES)"
  fi
}

test_master_spec_writeback_accepts_clean_prose_and_bullets() {
  echo "test_master_spec_writeback_accepts_clean_prose_and_bullets:"
  setup_tmp_repo
  _mk_master_spec_two_sections
  local body
  body="$(printf '%s\n' \
    "test-proj orchestrates widgets for solo developers." \
    "- It solves fragmented widget tooling." \
    "- MVP boundary: single-tenant pipeline.")"
  local prev_opts="$-"; set +e
  _sf_master_spec_replace_section_body "$PWD/MASTER-SPEC.md" "Executive Summary" "$body"
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  if [[ "$rc" != "0" ]]; then
    FAIL=$((FAIL+1)); echo "  ✗ clean prose+bullets body was rejected (rc=$rc)"; return
  fi
  # round-trip: the extractor must return EXACTLY the body we wrote
  local got; got="$(sf_master_spec_section "$PWD/MASTER-SPEC.md" "Executive Summary")"
  got="$(printf '%s\n' "$got" | sed -e '/./,$!d' | awk '{a[NR]=$0} END{n=NR; while(n>0 && a[n]~/^[[:space:]]*$/)n--; for(i=1;i<=n;i++)print a[i]}')"
  if [[ "$got" == "$body" ]]; then
    PASS=$((PASS+1)); echo "  ✓ clean body written and re-extracts EXACTLY (round-trip fidelity)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ round-trip mismatch"; echo "    want: $body"; echo "    got:  $got"
  fi
}

# SS-2 PR#55 Codex P2 (FINDING 1) — the from_synthesized path extracts the agent's
# Executive-Summary body with sf_master_spec_section, which STOPS at the next `## `/
# `---`/phase-marker. An agent body carrying an INTERIOR delimiter would be silently
# TRUNCATED before the write-back guard ever sees it. from_synthesized must instead
# detect the interior delimiter in the agent's raw region and REJECT loudly, leaving
# MASTER-SPEC byte-identical.
_mk_synth_master_spec_two_sections() {
  cat > "$PWD/MASTER-SPEC.md" <<'EOF'
# test-proj — Master Spec

## Executive Summary
{{executive_summary}}

## Phase 1: Foundation
phase one stuff
EOF
}

test_from_synthesized_rejects_interior_heading() {
  echo "test_from_synthesized_rejects_interior_heading:"
  setup_tmp_repo
  _mk_synth_master_spec_two_sections
  cat > "$PWD/EXECUTIVE-SUMMARY.md" <<'EOF'
## Executive Summary

Good first line.

## Sneaky Heading

Second.
EOF
  local before; before="$(cksum < "$PWD/MASTER-SPEC.md")"
  local prev_opts="$-"; set +e
  sf_render_executive_summary_from_synthesized "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "p" "CLI tool" 2>/dev/null
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  local after; after="$(cksum < "$PWD/MASTER-SPEC.md")"
  if [[ "$rc" != "0" && "$before" == "$after" ]]; then
    PASS=$((PASS+1)); echo "  ✓ rejected interior ## heading (rc=$rc), MASTER-SPEC byte-identical (no truncation)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ rc=$rc; MASTER-SPEC changed=$([[ "$before" == "$after" ]] && echo no || echo YES) (truncation/corruption slipped through)"
  fi
}

test_from_synthesized_rejects_interior_rule() {
  echo "test_from_synthesized_rejects_interior_rule:"
  setup_tmp_repo
  _mk_synth_master_spec_two_sections
  cat > "$PWD/EXECUTIVE-SUMMARY.md" <<'EOF'
## Executive Summary

Good first line.

---

Second sentence after a rule.
EOF
  local before; before="$(cksum < "$PWD/MASTER-SPEC.md")"
  local prev_opts="$-"; set +e
  sf_render_executive_summary_from_synthesized "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "p" "CLI tool" 2>/dev/null
  local rc=$?
  if [[ "$prev_opts" == *e* ]]; then set -e; fi
  local after; after="$(cksum < "$PWD/MASTER-SPEC.md")"
  if [[ "$rc" != "0" && "$before" == "$after" ]]; then
    PASS=$((PASS+1)); echo "  ✓ rejected interior --- rule (rc=$rc), MASTER-SPEC byte-identical"
  else
    FAIL=$((FAIL+1)); echo "  ✗ rc=$rc; MASTER-SPEC changed=$([[ "$before" == "$after" ]] && echo no || echo YES)"
  fi
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

test_missing_exec_summary_render_failure_clears_dispatch_source() {
  echo "test_missing_exec_summary_render_failure_clears_dispatch_source:"
  local ok=1 body
  body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  if ! printf '%s\n' "$body" | grep -q 'exec_summary=""'; then
    echo "  ✗ memory-bank setup does not clear EXEC-SUMMARY path after produce-once failure"; ok=0
  fi
  body="$(_extract_section_bash "$GOV_SKILL" "## 11")"
  if ! printf '%s\n' "$body" | grep -q 'exec_summary=""'; then
    echo "  ✗ governance setup does not clear EXEC-SUMMARY path after produce-once failure"; ok=0
  fi
  if [[ "$ok" == "1" ]]; then
    PASS=$((PASS+1)); echo "  ✓ failed produce-once render omits EXEC-SUMMARY from synthesis prompts"
  else
    FAIL=$((FAIL+1))
  fi
}

test_exec_summary_staleness_detects_master_change() {
  echo "test_exec_summary_staleness_detects_master_change:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "original summary"
  # SS-7: no deterministic renderer — produce the cksum'd EXEC-SUMMARY via the
  # surviving guarded write-back (agent output stand-in), as in §8.
  printf '## Executive Summary\n\noriginal summary\n' > "$PWD/EXECUTIVE-SUMMARY.md"
  sf_render_executive_summary_from_synthesized "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" && local fresh=0 || local fresh=1
  printf '\nmore content\n' >> "$PWD/MASTER-SPEC.md"
  sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" && local stale=0 || local stale=1
  if [[ "$fresh" == "0" && "$stale" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ fresh=ok, post-edit=stale"; else FAIL=$((FAIL+1)); echo "  ✗ fresh=$fresh stale=$stale"; fi
}

# SS-7 — the deterministic EXEC-SUMMARY renderers are REMOVED; only the mechanical
# guarded write-back survives.
test_deterministic_exec_summary_renderers_removed() {
  echo "test_deterministic_exec_summary_renderers_removed:"
  local ok=1
  if grep -qE '^sf_render_executive_summary\(\)' "$ROOT/lib/render.sh"; then
    echo "  ✗ sf_render_executive_summary (deterministic extract) still defined"; ok=0
  fi
  if grep -qE '^sf_render_executive_summary_from_state\(\)' "$ROOT/lib/render.sh"; then
    echo "  ✗ sf_render_executive_summary_from_state (deterministic bootstrap) still defined"; ok=0
  fi
  if ! grep -qE '^sf_render_executive_summary_from_synthesized\(\)' "$ROOT/lib/render.sh"; then
    echo "  ✗ sf_render_executive_summary_from_synthesized (mechanical write-back) must remain"; ok=0
  fi
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ deterministic EXEC-SUMMARY renderers removed; guarded write-back kept"; else FAIL=$((FAIL+1)); fi
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
    "$ROOT/CHANGELOG.md" \
    "$ROOT/../docs/agent-driven-program/specs/SS-2-synthesis-live-and-verified.md" \
    "$ROOT/../docs/agent-driven-program/plans/2026-06-04-ss2-synthesis-live-and-verified.md" \
    "$ROOT/../docs/agent-driven-program/handoffs/2026-06-04-ss2-ready-to-build.md" 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then
    PASS=$((PASS+1)); echo "  ✓ no user-facing unsupported --regenerate=<file> guidance remains"
  else
    FAIL=$((FAIL+1)); echo "  ✗ unsupported --regenerate= guidance remains:"; printf '%s\n' "$hits" | sed 's/^/      /'
  fi
}

# SS-7 — the --fast flag is REMOVED from the command wrappers' arg-handling.
test_commands_have_no_fast_flag() {
  echo "test_commands_have_no_fast_flag:"
  local ok=1 project="$ROOT/commands/scaffold-project.md" docs="$ROOT/commands/scaffold-docs.md"
  # No --fast in the argument-hint or the FAST= arg-parse (the bodies may mention
  # "no --fast deterministic path" in a removal note, so scope to the hint+parse).
  if grep -qE 'argument-hint.*--fast' "$project"; then echo "  ✗ scaffold-project still hints --fast"; ok=0; fi
  if grep -qE 'argument-hint.*--fast' "$docs"; then echo "  ✗ scaffold-docs still hints --fast"; ok=0; fi
  if grep -qE 'FAST=\$' "$project" "$docs"; then echo "  ✗ a command still parses a FAST flag"; ok=0; fi
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ command wrappers no longer expose --fast"; else FAIL=$((FAIL+1)); fi
}

# SS-7 — the dispatch skills no longer carry the fast-mode toggle.
test_skill_docs_have_no_fast_toggle() {
  echo "test_skill_docs_have_no_fast_toggle:"
  local ok=1 f
  for f in "$MB_SKILL" "$GOV_SKILL"; do
    if grep -q 'SF_SYNTH_FAST' "$f"; then echo "  ✗ $(basename "$(dirname "$f")") still references SF_SYNTH_FAST"; ok=0; fi
    if grep -q 'sf_synth_mode' "$f"; then echo "  ✗ $(basename "$(dirname "$f")") still references sf_synth_mode"; ok=0; fi
    # The Supported-flags list must not offer --fast.
    if awk '/Supported flags:/{f=1} f&&/^---/{exit} f' "$f" | grep -q -- '--fast'; then
      echo "  ✗ $(basename "$(dirname "$f")") supported-flags list still includes --fast"; ok=0
    fi
  done
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ dispatch skills carry no fast-mode toggle / --fast flag"; else FAIL=$((FAIL+1)); fi
}

test_memory_bank_live_static_seed_preserves_synthesized_derived_outputs() {
  echo "test_memory_bank_live_static_seed_preserves_synthesized_derived_outputs:"
  setup_tmp_repo; _seed_state_for_dispatch
  _seed_canned_derived_files   # stand in for the synthesis agents' derived outputs
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

test_memory_bank_synthesis_regenerate_migrates_harvest_before_dispatch() {
  echo "test_memory_bank_synthesis_regenerate_migrates_harvest_before_dispatch:"
  local body migrate_line wave_line
  body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  migrate_line="$(printf '%s\n' "$body" | awk '/_sf_mb_migrate_harvested/{print NR; exit}')"
  wave_line="$(printf '%s\n' "$body" | awk '/Wave 4 — all 9 artifacts/{print NR; exit}')"
  if [[ -n "$migrate_line" && -n "$wave_line" && "$migrate_line" -lt "$wave_line" ]]; then
    PASS=$((PASS+1)); echo "  ✓ synthesis regenerate migrates harvested entries before overwriting derived artifacts"
  else
    FAIL=$((FAIL+1)); echo "  ✗ synthesis regenerate does not run harvested-entry migration before Wave 4 dispatch"
  fi
}

# SS-2 PR#55 Codex P2 #3/#6 — the two NON-synthesis finalize steps on the
# synthesize path (_sf_mb_migrate_harvested + sf_memory_bank_seed_live_static)
# write/scan relative to cwd. In a manifest-routed workspace memory_bank resolves
# OUTSIDE pwd, so both must run AT the routed memory-bank root. Assert each call
# is wrapped in a `cd "$(sf_resolve_output_path memory_bank` (or `pushd ...memory_bank`)
# on the same logical block — i.e. neither appears as a bare §13.3 call.
test_synthesize_finalize_routes_to_memory_bank() {
  echo "test_synthesize_finalize_routes_to_memory_bank:"
  local ok=1 body
  body="$(_extract_section_bash "$MB_SKILL" "## 13")"

  # A "route" line opens a memory_bank-rooted subshell/block: it both routes via
  # sf_resolve_output_path memory_bank AND uses cd or pushd to enter it. The
  # _extract_section_bash helper concatenates §13's fenced blocks in order, so a
  # route line preceding the call satisfies the same-logical-block contract while
  # a bare top-of-§13.3 call (no preceding route) fails.

  # A route line is the most recent line opening a memory_bank-rooted subshell/block:
  # it routes via sf_resolve_output_path memory_bank AND uses cd or pushd. For each
  # call we require a route line within a small window above it (same logical block),
  # so a bare top-of-§13.3 call with no preceding wrapper fails. `route` carries the
  # line number of the last route line; `n` is the current line number.

  # 1) harvest migration must be wrapped in a memory_bank cd/pushd.
  if ! printf '%s\n' "$body" | awk '
      { n++ }
      /sf_resolve_output_path memory_bank/ && (/[ (]cd / || /^cd / || / pushd / || /^pushd /) { route=n }
      /_sf_mb_migrate_harvested/ { if (route && n - route <= 6) ok=1 }
      END { exit (ok?0:1) }'; then
    echo "  ✗ §13.3 _sf_mb_migrate_harvested is not wrapped in a memory_bank cd/pushd"; ok=0
  fi

  # 2) live/static seed must be wrapped in a memory_bank cd/pushd.
  if ! printf '%s\n' "$body" | awk '
      { n++ }
      /sf_resolve_output_path memory_bank/ && (/[ (]cd / || /^cd / || / pushd / || /^pushd /) { route=n }
      /sf_memory_bank_seed_live_static/ { if (route && n - route <= 6) ok=1 }
      END { exit (ok?0:1) }'; then
    echo "  ✗ §13.3 sf_memory_bank_seed_live_static is not wrapped in a memory_bank cd/pushd"; ok=0
  fi

  if [[ "$ok" == "1" ]]; then
    PASS=$((PASS+1)); echo "  ✓ §13.3 seed + harvest migration route to the manifest memory_bank destination"
  else
    FAIL=$((FAIL+1))
  fi
}

test_memory_bank_dispatch_sources_its_helpers
test_synthesize_finalize_routes_to_memory_bank
test_governance_dispatch_sources_its_helpers
test_dispatch_setup_sources_state_before_exec_summary_branch
test_memory_bank_live_static_seed_preserves_synthesized_derived_outputs
test_memory_bank_synthesis_regenerate_migrates_harvest_before_dispatch
test_derivation_reviewer_agent_registered
test_derivation_reviewer_example_fence_is_typed
test_review_prompts_pass_explicit_artifact_paths
test_no_public_regenerate_equals_guidance
test_commands_have_no_fast_flag
test_skill_docs_have_no_fast_toggle
test_exec_summary_synthesized_output_updates_master_spec_source
test_from_synthesized_rejects_interior_heading
test_from_synthesized_rejects_interior_rule
test_master_spec_writeback_rejects_embedded_rule
test_master_spec_writeback_rejects_embedded_heading
test_master_spec_writeback_accepts_clean_prose_and_bullets
test_exec_summary_source_only_prompt_omits_missing_exec_summary
test_missing_exec_summary_render_failure_clears_dispatch_source
test_exec_summary_staleness_detects_master_change
test_deterministic_exec_summary_renderers_removed
test_exec_summary_brief_validates
report_results
