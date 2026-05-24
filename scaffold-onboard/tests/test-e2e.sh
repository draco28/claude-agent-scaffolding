#!/usr/bin/env bash
# End-to-end tests for scaffold-onboard.
# Each test runs the full bash pipeline (onboard helpers → scaffold-project →
# scaffold-docs) against a fresh tmp repo with scripted answers.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/memory-bank.sh"
source "$HERE/../lib/docs.sh"
source "$HERE/../lib/compose.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Scripted answers for a representative CLI project (no LLM, no UI).
script_answers_cli() {
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_state_write_answer "1.1.3" "Solo devs adopt as their default task tool."
  sf_state_write_answer "1.2.1" "Solo devs and ops engineers."
  sf_state_write_answer "1.2.2" "Add a task, see what's pending, mark done — all under 200ms."
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "add / list / complete tasks; persist to ~/.todo.json; tab-complete."
  sf_state_write_answer "2.1.1" "4 weeks"
  sf_state_write_answer "2.1.2" "Solo"
  sf_state_write_answer "2.2.1" "0 (no hosted infra)"
  sf_state_write_answer "2.2.2" "tech: dep drift; market: niche; resource: solo bandwidth"
  sf_state_write_answer "2.3.1" "Daily use by 1 user for 4 weeks."
  sf_state_write_answer "3.1.1" "Task, Project (optional)"
  sf_state_write_answer "3.1.2" "Task(id, title, status, due); Project(id, name)"
  sf_state_write_answer "3.2.1" "Project has many Tasks"
  sf_state_write_answer "3.3.1" "task, project, done, due"
  sf_state_write_answer "4.1.1" "none"
  sf_state_write_answer "4.1.2" "none"
  sf_state_write_answer "4.2.1" "none"
  sf_state_write_answer "4.2.2" "single-tenant (local only)"
  sf_state_write_answer "4.3.1" "local only"
  sf_state_write_answer "5.1.1" "CLI"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.todo.json)"
  sf_state_write_answer "5.3.1" "single user, <1MB data"
  sf_state_write_answer "5.3.2" "<200ms per command"
  sf_state_write_answer "6A.1.1" "CLI"
  sf_state_write_answer "6A.1.2" "todo add 'feed cat' → todo list → todo done 1"
  sf_state_write_answer "7.1.1" "src/{cli,store,model}"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "8.1.1" "cargo"
  sf_state_write_answer "8.2.1" "GitHub Actions"
  sf_state_write_answer "8.2.2" "dev only"
  sf_state_write_answer "8.3.1" "self-hosted (binary release)"
  sf_state_write_answer "9.1.1" "80%"
  sf_state_write_answer "9.1.2" "unit, integration"
  sf_state_write_answer "9.2.1" "tests pass, cargo clippy clean"
  sf_state_write_answer "9.3.1" "no"
  sf_state_write_answer "10.1.1" "direct"
  sf_state_write_answer "10.3.1" "solo / business hours"
}

run_full_pipeline_cli() {
  sf_state_init
  script_answers_cli
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
  sf_state_write_atomic status complete
  sf_memory_bank_derive
  sf_claude_md_generate
  sf_claude_settings_generate
  sf_docs_derive
}

test_e2e_fresh_repo_cli() {
  echo "test_e2e_fresh_repo_cli:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  run_full_pipeline_cli
  # MASTER-SPEC artifacts
  assert_file_exists "./MASTER-SPEC.md"
  assert_exit_code 0 sf_spec_validate ./MASTER-SPEC.md
  # Memory bank
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance index WORKFLOW; do
    assert_file_exists "./.claude/memory-bank/${f}.md"
  done
  # CLAUDE.md
  assert_file_exists "./CLAUDE.md"
  assert_file_contains "./CLAUDE.md" "todo-cli"
  assert_file_contains "./CLAUDE.md" "Tier 0"
  # Settings
  assert_file_exists "./.claude/settings.json"
  # Default docs
  assert_file_exists "./docs/PRD.md"
  assert_file_exists "./docs/SRS.md"
  assert_file_exists "./docs/BACKLOG.md"
  assert_file_exists "./docs/PROJECT_PLAN.md"
  assert_file_exists "./docs/adr/0001-record-architecture-decisions.md"
  # No --full docs
  assert_file_missing "./docs/RISK_REGISTER.md"
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_e2e_full_mode() {
  echo "test_e2e_full_mode:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  run_full_pipeline_cli
  sf_docs_derive --full
  assert_file_exists "./docs/RISK_REGISTER.md"
  assert_file_exists "./docs/TEST_STRATEGY.md"
  assert_file_exists "./docs/CUTOVER_PLAN.md"
  # LLM-gated still skipped (this project says no LLMs)
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_e2e_existing_repo_preserves_user_files() {
  echo "test_e2e_existing_repo_preserves_user_files:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  # Pre-seed user-authored files BEFORE running scaffold-onboard
  mkdir -p docs/adr
  echo "# My existing PRD" > docs/PRD.md
  echo "# Pre-existing ADR" > docs/adr/0001-record-architecture-decisions.md
  echo "# Existing settings note" > .claude_user_note  # canary

  run_full_pipeline_cli

  # docs/PRD.md is in docs-minimal — preserved unless --regenerate
  assert_file_contains "./docs/PRD.md" "My existing PRD"
  # ADR-0001 preserved
  assert_file_contains "./docs/adr/0001-record-architecture-decisions.md" "Pre-existing ADR"
  # User's canary untouched
  assert_file_contains "./.claude_user_note" "Existing settings note"
}

test_e2e_regenerate_overwrites_docs() {
  echo "test_e2e_regenerate_overwrites_docs:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  echo "# My existing PRD" > docs/PRD.md 2>/dev/null || { mkdir -p docs; echo "# My existing PRD" > docs/PRD.md; }
  run_full_pipeline_cli
  sf_docs_derive --regenerate
  if grep -q "My existing PRD" docs/PRD.md; then
    FAIL=$((FAIL+1)); echo "  ✗ --regenerate did not overwrite"
  else
    PASS=$((PASS+1)); echo "  ✓ --regenerate overwrote existing PRD"
  fi
}

test_e2e_resume_mid_onboarding() {
  echo "test_e2e_resume_mid_onboarding:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"

  # Partial onboarding: answer phases 1-3 only, leave 4-10 unanswered
  sf_state_init
  sf_state_write_answer "1.1.1" "partial-proj"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "2.2.2" "risks here"
  sf_state_write_answer "3.1.1" "Thing"
  sf_state_write_atomic current_phase 4

  # Mode check: should be "resume"
  local mode
  mode="$(sf_state_mode)"
  assert_eq "mode is resume" "resume" "$mode"

  # Current phase persisted
  local phase
  phase="$(sf_state_read_field current_phase)"
  assert_eq "phase 4 persisted" "4" "$phase"

  # Resume by answering remaining phases
  sf_state_write_answer "4.1.1" "none"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_state_write_atomic current_phase 10
  sf_state_advance_phase  # → status=complete

  local status
  status="$(sf_state_read_field status)"
  assert_eq "completed after resume" "complete" "$status"
}

test_e2e_with_composition_mocked() {
  echo "test_e2e_with_composition_mocked:"
  setup_tmp_repo
  # Fake-install all three cross-cutting plugins
  mkdir -p "$TMP_DIR/fake-plugins/ai-mentor-x"
  : > "$TMP_DIR/fake-plugins/ai-mentor-x/state.json"
  mkdir -p "$TMP_DIR/fake-plugins/architect-critic-y"
  : > "$TMP_DIR/fake-plugins/architect-critic-y/principles.md"
  mkdir -p "$TMP_DIR/fake-plugins/superpowers-z/skills/brainstorming"
  : > "$TMP_DIR/fake-plugins/superpowers-z/skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"

  sf_compose_refresh
  run_full_pipeline_cli

  # CLAUDE.md should mention all three integrations
  assert_file_contains "./CLAUDE.md" "z2-decide"
  assert_file_contains "./CLAUDE.md" "/critique"
  assert_file_contains "./CLAUDE.md" "superpowers"

  # Mentor hint emits at Phase 5 + 7
  local hint5 hint7 hint2
  hint5="$(sf_compose_mentor_hint 5)"
  hint7="$(sf_compose_mentor_hint 7)"
  hint2="$(sf_compose_mentor_hint 2)"
  if [[ -n "$hint5" ]]; then PASS=$((PASS+1)); echo "  ✓ Phase 5 mentor hint emitted"; else FAIL=$((FAIL+1)); echo "  ✗ no Phase 5 mentor hint"; fi
  if [[ -n "$hint7" ]]; then PASS=$((PASS+1)); echo "  ✓ Phase 7 mentor hint emitted"; else FAIL=$((FAIL+1)); echo "  ✗ no Phase 7 mentor hint"; fi
  assert_eq "no Phase 2 hint" "" "$hint2"
}

test_e2e_onboarding_project_skill_present() {
  echo "test_e2e_onboarding_project_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/onboarding-project/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: onboarding-project, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*onboarding-project[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: onboarding-project"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: onboarding-project'"
  fi

  # Description must be non-empty (anything other than blank after the colon)
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 of the trigger phrases
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "onboard" "MASTER-SPEC" "10-phase" "start onboarding"; do
    if echo "$desc_block" | grep -qiF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body references architect-critic:critiquing-spec (not legacy :critique)
  assert_file_contains "$skill_path" "architect-critic:critiquing-spec"

  # 5. Body references sf_resolve_output_path (manifest routing helper)
  assert_file_contains "$skill_path" "sf_resolve_output_path"

  # 6. Body does NOT contain v0.1.3 (drift-resolution sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi
}

test_e2e_scaffolding_memory_bank_skill_present() {
  echo "test_e2e_scaffolding_memory_bank_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/scaffolding-memory-bank/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: scaffolding-memory-bank, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*scaffolding-memory-bank[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: scaffolding-memory-bank"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: scaffolding-memory-bank'"
  fi

  # Description must be non-empty
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 of the trigger phrases
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "memory bank" "scaffold-project" "derive" "set up project memory"; do
    if echo "$desc_block" | grep -qiF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body mentions ## Machine-checkable rules (R2 seeding marker)
  assert_file_contains "$skill_path" "## Machine-checkable rules"

  # 5. Body contains verbatim Karpathy attribution (literal string match; parens would break regex)
  if grep -qF "Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body contains verbatim Karpathy attribution"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body missing verbatim Karpathy attribution"
  fi

  # 6. Body references sf_resolve_output_path (manifest routing helper)
  assert_file_contains "$skill_path" "sf_resolve_output_path"

  # 7. Body references architect-critic:critiquing-spec (not legacy :critique)
  assert_file_contains "$skill_path" "architect-critic:critiquing-spec"

  # 8. Body does NOT contain v0.1.3 (drift-resolution sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi

  # 9. Body uses HTML-sentinel mcrule format (`<!-- mcrule:start`) if it shows any rule example —
  #    OR contains zero mcrule examples (this skill SEEDS the section, does NOT author rules).
  #    Forbid the fenced-block alternative (a bare ```mcrule fence) per SPEC §8.2.
  if grep -qE '^```[[:space:]]*mcrule' "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body uses fenced-block mcrule format (rejected by SPEC §8.2)"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body avoids fenced-block mcrule format"
  fi
}

test_e2e_scaffolding_governance_docs_skill_present() {
  echo "test_e2e_scaffolding_governance_docs_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/scaffolding-governance-docs/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: scaffolding-governance-docs, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*scaffolding-governance-docs[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: scaffolding-governance-docs"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: scaffolding-governance-docs'"
  fi

  # Description must be non-empty
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 trigger phrases (governance, scaffold-docs, PRD, SRS)
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "governance" "scaffold-docs" "PRD" "SRS"; do
    if echo "$desc_block" | grep -qF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body explicitly states PROJECT_PLAN.md is UNCHANGED from v0.1.0 — search literal pair
  if grep -qF "PROJECT_PLAN.md" "$skill_path" && \
     ( grep -qF "unchanged" "$skill_path" || grep -qF "v0.1.0" "$skill_path" ); then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references PROJECT_PLAN.md + unchanged/v0.1.0"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing PROJECT_PLAN.md / unchanged / v0.1.0 references"
  fi

  # 5. Body references ROADMAP.md as separate file from a different skill
  assert_file_contains "$skill_path" "ROADMAP.md"
  assert_file_contains "$skill_path" "planning-project-roadmap"

  # 6. Body references sf_resolve_output_path (manifest routing helper)
  assert_file_contains "$skill_path" "sf_resolve_output_path"

  # 7. Body does NOT contain v0.1.3 (drift sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi

  # 8. Body does NOT emit Phase→Sprint→VS hierarchy structure into PROJECT_PLAN.md.
  #    We allow the substring "VS-1.1.1" in this body only inside an explicit
  #    "NOT emitted here" / "do not emit" disclaimer. Detect via co-occurrence on
  #    the same line of an anti-pattern marker. If "VS-1.1.1" appears at all,
  #    require it to be on a line that also names this exclusion intent.
  if grep -qF "VS-1.1.1" "$skill_path"; then
    if grep -F "VS-1.1.1" "$skill_path" | grep -qiE "NOT emit|do not emit|never emit|not.*this skill|not authored by this skill"; then
      PASS=$((PASS+1)); echo "  $(_color_pass '✓') VS-1.1.1 appears only inside NOT-emitted disclaimer"
    else
      FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') VS-1.1.1 appears outside an explicit NOT-emitted disclaimer"
    fi
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') no VS-1.1.1 hierarchy example in body"
  fi
}

test_e2e_planning_project_roadmap_skill_present() {
  echo "test_e2e_planning_project_roadmap_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/planning-project-roadmap/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: planning-project-roadmap, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*planning-project-roadmap[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: planning-project-roadmap"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: planning-project-roadmap'"
  fi

  # Description must be non-empty
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 trigger phrases
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "plan-roadmap" "decompose into sprints" "author project roadmap" "what comes after onboarding"; do
    if echo "$desc_block" | grep -qiF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body contains R1.A verbatim 3-timelines prompt (use grep -qF for em-dash + punctuation)
  if grep -qF "Your Phases are your visionary horizon" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains verbatim R1.A 3-timelines prompt"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing verbatim R1.A 3-timelines prompt"
  fi

  # 5. Body contains R1.B verbatim 3-timelines prompt
  if grep -qF "Sprints are your value-building windows" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains verbatim R1.B 3-timelines prompt"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing verbatim R1.B 3-timelines prompt"
  fi

  # 6. Body contains R1.C verbatim 3-timelines prompt
  if grep -qF "Vertical slices are your visibility cycles" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains verbatim R1.C 3-timelines prompt"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing verbatim R1.C 3-timelines prompt"
  fi

  # 7. Body references all 5 re-run modes by name (use -- separator since patterns start with --)
  local re_run_hits=0
  for mode in "--add-phase" "--add-sprint" "--add-slice" "--refine-slice" "--reorganize"; do
    if grep -qF -- "$mode" "$skill_path"; then
      re_run_hits=$((re_run_hits+1))
    fi
  done
  if [[ "$re_run_hits" -eq 5 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references all 5 re-run modes"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body references only $re_run_hits/5 re-run modes"
  fi

  # 8. Body references ROADMAP.md (output filename)
  assert_file_contains "$skill_path" "ROADMAP.md"

  # 9. Body does NOT use PROJECT_PLAN.md as the R1 output — if present, must be flagged as anti-pattern
  if grep -qF "PROJECT_PLAN.md" "$skill_path"; then
    # Allowed only on lines that include anti-pattern / NOT / do not / never / different file language
    if grep -F "PROJECT_PLAN.md" "$skill_path" | grep -qiE "NOT |do not|never|different file|not.*R1|not the R1|anti-pattern|unchanged|v0.1.0|separate"; then
      PASS=$((PASS+1)); echo "  $(_color_pass '✓') PROJECT_PLAN.md appears only inside anti-pattern / unchanged disclaimer"
    else
      FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') PROJECT_PLAN.md appears as R1 output without anti-pattern flag"
    fi
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body does not reference PROJECT_PLAN.md"
  fi

  # 10. Body references sf_resolve_output_path (manifest routing)
  assert_file_contains "$skill_path" "sf_resolve_output_path"

  # 11. Body references architect-critic:critiquing-spec (critic invocation)
  assert_file_contains "$skill_path" "architect-critic:critiquing-spec"

  # 12. Body does NOT contain v0.1.3 (drift sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi

  # 13. Body documents state checkpoint field with R1.A/B/C sub-phases
  if grep -qF "checkpoint" "$skill_path" && \
     grep -qF "R1.A" "$skill_path" && \
     grep -qF "R1.B" "$skill_path" && \
     grep -qF "R1.C" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body documents checkpoint field + R1.A/B/C sub-phases"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing checkpoint field or R1.A/B/C sub-phase references"
  fi
}

test_e2e_authoring_mcrules_skill_present() {
  echo "test_e2e_authoring_mcrules_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/authoring-machine-checkable-rules/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: authoring-machine-checkable-rules, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*authoring-machine-checkable-rules[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: authoring-machine-checkable-rules"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: authoring-machine-checkable-rules'"
  fi

  # Description must be non-empty
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 trigger phrases (matching SPEC §5.5 triggers)
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "machine-checkable" "add a project rule" "mcrule" "rule"; do
    if echo "$desc_block" | grep -qiF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body contains all 4 rule type names literally (use -qF — names have underscores)
  local rule_type_hits=0
  for rt in "banned_imports" "coverage_floor" "style_invariants" "required_pattern"; do
    if grep -qF "$rt" "$skill_path"; then
      rule_type_hits=$((rule_type_hits+1))
    fi
  done
  if [[ "$rule_type_hits" -eq 4 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body names all 4 v0.2 rule types"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body names only $rule_type_hits/4 rule types"
  fi

  # 5. Body contains HTML-sentinel start marker (use -qF for the literal HTML comment)
  if grep -qF "<!-- mcrule:start" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains HTML-sentinel <!-- mcrule:start grammar"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing HTML-sentinel <!-- mcrule:start grammar"
  fi

  # 6. Body does NOT use a fenced ```mcrule code-fence as actual DSL grammar.
  #    Anti-pattern / rejected-alternative mentions are allowed IFF flagged as such
  #    (parallel to test #9's PROJECT_PLAN.md pattern in the planning-roadmap test).
  if grep -qF '```mcrule' "$skill_path"; then
    if grep -F '```mcrule' "$skill_path" | grep -qiE "reject|anti-pattern|do not|never|NOT |invisible|draft.*reject|alternative.*reject"; then
      PASS=$((PASS+1)); echo "  $(_color_pass '✓') fenced \`\`\`mcrule appears only inside rejected-alternative disclaimer"
    else
      FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body contains fenced \`\`\`mcrule grammar without anti-pattern flag"
    fi
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body has no fenced \`\`\`mcrule grammar references"
  fi

  # 7. Body references sf_rules_validate_block (single-block validator — NOT sf_rules_parse for write-validation)
  if grep -qF "sf_rules_validate_block" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references sf_rules_validate_block (single-block validator)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing sf_rules_validate_block reference"
  fi

  # 8. Body references manifest-aware routing for memory_bank → 03-code-patterns.md
  if grep -qF "sf_resolve_output_path" "$skill_path" && \
     grep -qF "memory_bank" "$skill_path" && \
     grep -qF "03-code-patterns.md" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references sf_resolve_output_path + memory_bank + 03-code-patterns.md"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing manifest routing pieces (sf_resolve_output_path / memory_bank / 03-code-patterns.md)"
  fi

  # 9. Body documents extensibility / warn-and-skip on unknown types (§8.5)
  if grep -qiE "warn.*(skip|unknown)|unknown.*(warn|skip)|skip.*unknown" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body documents warn-and-skip on unknown rule types"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing warn-and-skip / unknown-type extensibility language"
  fi

  # 10. Body does NOT contain v0.1.3 (drift sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi

  # 11. Body contains at least one fully-worked example per rule type (count ≥4 <!-- mcrule:start instances)
  local mcrule_start_count
  mcrule_start_count="$(grep -cF '<!-- mcrule:start' "$skill_path" || true)"
  if [[ "$mcrule_start_count" -ge 4 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body has $mcrule_start_count <!-- mcrule:start examples (≥4 expected)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body has only $mcrule_start_count <!-- mcrule:start examples (need ≥4)"
  fi
}

test_e2e_authoring_vs_demo_skill_present() {
  echo "test_e2e_authoring_vs_demo_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/authoring-vertical-slice-demo/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: authoring-vertical-slice-demo, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*authoring-vertical-slice-demo[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: authoring-vertical-slice-demo"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: authoring-vertical-slice-demo'"
  fi

  # Description must be non-empty
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 trigger phrases (per SPEC §5.6 + task brief)
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "demo criteria" "vertical slice" "VS-" "demo verification"; do
    if echo "$desc_block" | grep -qiF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body contains both grammar prefixes (auto: / user:) and the literal U+2192 arrow in `→ expected:`
  if grep -qF "auto: " "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains 'auto: ' grammar prefix"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing 'auto: ' grammar prefix"
  fi
  if grep -qF "user: " "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains 'user: ' grammar prefix"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing 'user: ' grammar prefix"
  fi
  if grep -qF "→ expected:" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body contains literal U+2192 arrow '→ expected:' grammar delimiter"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing literal U+2192 arrow '→ expected:' delimiter"
  fi

  # 5. Body contains slice ID convention VS-<phase>.<sprint>.<slice> (literal — use -qF)
  if grep -qF "VS-<phase>.<sprint>.<slice>" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body documents slice ID convention VS-<phase>.<sprint>.<slice>"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing slice ID convention 'VS-<phase>.<sprint>.<slice>'"
  fi

  # 6. Body references BOTH target modes ("state" + "markdown") + auto-detection
  if grep -qiF "target=state" "$skill_path" && \
     grep -qiF "target=markdown" "$skill_path" && \
     grep -qiE "auto-detect|auto detection|auto-detection|automatically detect" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body documents dual storage targets (state + markdown) + auto-detection"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing dual storage target docs (need target=state + target=markdown + auto-detection)"
  fi

  # 7. Body references --target= arg override (pattern starts with --, use grep -qF --)
  if grep -qF -- "--target=" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references --target= arg override"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing --target= arg override reference"
  fi

  # 8. Body references sf_demo_parse_line (validation API)
  if grep -qF "sf_demo_parse_line" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references sf_demo_parse_line (validation API)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing sf_demo_parse_line reference"
  fi

  # 9. Body references sf_resolve_output_path for markdown mode routing
  if grep -qF "sf_resolve_output_path" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body references sf_resolve_output_path (markdown-mode routing)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing sf_resolve_output_path reference"
  fi

  # 10. Body explicitly forbids ASCII '->' (drift sanity for the U+2192 arrow grammar)
  if grep -qF -- "->" "$skill_path" && grep -F -- "->" "$skill_path" | grep -qiE "NOT |do not|never|ASCII|forbid|wrong|anti-pattern|don't"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body explicitly forbids ASCII '->' in arrow grammar"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body does not explicitly forbid ASCII '->' as arrow grammar"
  fi

  # 11. Body does NOT contain v0.1.3 (drift sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi

  # 12. Body does NOT write to PROJECT_PLAN.md (mention allowed ONLY as anti-pattern flag)
  if grep -qF "PROJECT_PLAN.md" "$skill_path"; then
    if grep -F "PROJECT_PLAN.md" "$skill_path" | grep -qiE "NOT |do not|never|anti-pattern|don't|different file|unchanged|v0.1.0|wrong file"; then
      PASS=$((PASS+1)); echo "  $(_color_pass '✓') PROJECT_PLAN.md appears only inside anti-pattern flag"
    else
      FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') PROJECT_PLAN.md appears as a write target without anti-pattern flag"
    fi
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body does not reference PROJECT_PLAN.md as a write target"
  fi

  # 13. Body covers idempotence behavior (search idempoten* / duplicate)
  if grep -qiE "idempoten|duplicate" "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') body documents idempotence / no-duplicate behavior"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') body missing idempotence / no-duplicate language"
  fi
}

test_e2e_fresh_repo_cli
test_e2e_full_mode
test_e2e_existing_repo_preserves_user_files
test_e2e_regenerate_overwrites_docs
test_e2e_resume_mid_onboarding
test_e2e_with_composition_mocked
test_e2e_onboarding_project_skill_present
test_e2e_scaffolding_memory_bank_skill_present
test_e2e_scaffolding_governance_docs_skill_present
test_e2e_planning_project_roadmap_skill_present
test_e2e_authoring_mcrules_skill_present
test_e2e_authoring_vs_demo_skill_present
report_results
