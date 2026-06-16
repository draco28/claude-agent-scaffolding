#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/memory-bank.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Build a minimal valid MASTER-SPEC.md in $PWD using a fixture + state.
# The deterministic sf_memory_bank_derive was removed in v0.8.0 (SS-7); these
# tests drive the MECHANICAL orchestration via seed_memory_bank_synth_fixture
# (_helpers.sh) — harvest migration, mcrules-zone preserve, live/static seeding —
# with canned "synthesized" derived files substituted for the agent. Derived
# content-correctness moves to the evals/ LLM-judge.
seed_master_spec() {
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
  # Write a structurally valid MASTER-SPEC.md fixture.
  # seed_memory_bank_synth_fixture reads all template vars from state (not MASTER-SPEC.md),
  # so the fixture is just a valid placeholder on disk.
  seed_master_spec_fixture "./MASTER-SPEC.md" "test-proj" "CLI tool"
}

test_derive_00_project_brief() {
  echo "test_derive_00_project_brief:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  # Mechanical: the derived file lands at the routed path. Content-correctness
  # (pitch flows from MASTER-SPEC into 00) is agent-synthesized → asserted by the
  # evals/ LLM-judge, not here (SS-7).
  assert_file_exists "./.claude/memory-bank/00-project-brief.md"
}

test_live_files_preserved() {
  echo "test_live_files_preserved:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  # Hand-edit the live file
  echo "## My custom note" >> ".claude/memory-bank/05-active-context.md"
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/05-active-context.md" "My custom note"
}

test_live_files_force_overwritten() {
  echo "test_live_files_force_overwritten:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  echo "## My custom note" >> ".claude/memory-bank/05-active-context.md"
  seed_memory_bank_synth_fixture --force
  if grep -q "My custom note" "./.claude/memory-bank/05-active-context.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ --force should have overwritten"
  else
    PASS=$((PASS+1)); echo "  ✓ --force overwrote live file"
  fi
}

test_workflow_static_unchanged() {
  echo "test_workflow_static_unchanged:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  echo "## My workflow note" >> ".claude/memory-bank/WORKFLOW.md"
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "My workflow note"
}

# PR #27 / Codex round-3: --force refreshes the static WORKFLOW.md so existing
# projects pick up template rewrites (e.g. the corrected slice-workflow loop).
test_workflow_refreshed_on_force() {
  echo "test_workflow_refreshed_on_force:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  echo "## STALE-SENTINEL" >> ".claude/memory-bank/WORKFLOW.md"
  seed_memory_bank_synth_fixture --force
  assert_file_not_contains "./.claude/memory-bank/WORKFLOW.md" "STALE-SENTINEL"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Per-slice loop"
}

# PR #27 / Codex round-3: regenerating over an existing settings.json that still
# carries the #25 escape grants must WARN (and must NOT auto-edit the user file).
test_settings_warns_on_unsafe_grants() {
  echo "test_settings_warns_on_unsafe_grants:"
  setup_tmp_repo
  mkdir -p .claude
  printf '{"permissions":{"allow":["Bash(git status:*)","Bash(rg:*)","Bash(jq:*)"]}}\n' > .claude/settings.json
  local err; err="$(sf_claude_settings_generate 2>&1 >/dev/null)"
  if echo "$err" | grep -q 'escape-capable grants'; then PASS=$((PASS+1)); echo "  ✓ warned on unsafe grants"; else FAIL=$((FAIL+1)); echo "  ✗ no warning emitted: $err"; fi
  # user file preserved verbatim — not auto-edited
  assert_file_contains "./.claude/settings.json" "Bash\\(rg:"
}

test_settings_no_warn_when_clean() {
  echo "test_settings_no_warn_when_clean:"
  setup_tmp_repo
  mkdir -p .claude
  printf '{"permissions":{"allow":["Bash(git status:*)","Bash(git diff:*)"]}}\n' > .claude/settings.json
  local err; err="$(sf_claude_settings_generate 2>&1 >/dev/null)"
  if echo "$err" | grep -q 'escape-capable grants'; then FAIL=$((FAIL+1)); echo "  ✗ false warning on clean settings"; else PASS=$((PASS+1)); echo "  ✓ no warning on clean settings"; fi
}

test_all_derived_files_present() {
  echo "test_all_derived_files_present:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance 09-known-issues 10-decisions-log index WORKFLOW tech-debt; do
    assert_file_exists "./.claude/memory-bank/${f}.md"
  done
}

test_claude_md_generated() {
  echo "test_claude_md_generated:"
  setup_tmp_repo
  seed_master_spec
  sf_claude_md_generate
  assert_file_exists "./CLAUDE.md"
  assert_file_contains "./CLAUDE.md" "# Project: test-proj"
  assert_file_contains "./CLAUDE.md" "Tier 0"
  assert_file_contains "./CLAUDE.md" "Branch loading rules"
}

test_claude_md_plugin_awareness_when_no_composition() {
  echo "test_claude_md_plugin_awareness_when_no_composition:"
  setup_tmp_repo
  seed_master_spec
  # No composition.json present
  sf_claude_md_generate
  # ai-mentor / critic / superpowers sections should NOT appear. Sentinel is the
  # ai-mentor block label (its commands are /council /grill-me /eli10 /fool).
  if grep -q "cognitive modes (ai-mentor)" "./CLAUDE.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor section leaked without composition"
  else
    PASS=$((PASS+1)); echo "  ✓ ai-mentor section absent without composition"
  fi
}

# #21 — Karpathy opt-in: phase_10.4.include_karpathy=yes emits the Behavioral
# Discipline section with the verbatim attribution; any other value omits it.
test_claude_md_karpathy_opt_in() {
  echo "test_claude_md_karpathy_opt_in:"
  setup_tmp_repo
  seed_master_spec
  sf_state_write_answer phase_10.4.include_karpathy yes
  sf_claude_md_generate
  assert_file_contains "./CLAUDE.md" "Behavioral Discipline \(Karpathy-inspired\)"
  assert_file_contains "./CLAUDE.md" "Behavioral guidelines inspired by Karpathy's observations \(Chang, 2026; MIT\)"
  assert_file_contains "./CLAUDE.md" "Think Before Coding"
}

test_claude_md_karpathy_opt_out() {
  echo "test_claude_md_karpathy_opt_out:"
  setup_tmp_repo
  seed_master_spec
  # seed_master_spec does not set the karpathy answer → opt-out by default
  sf_claude_md_generate
  if grep -q "Behavioral Discipline (Karpathy-inspired)" "./CLAUDE.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ Karpathy section present without opt-in"
  else
    PASS=$((PASS+1)); echo "  ✓ Karpathy section absent without opt-in"
  fi
}

# T7.4 — R2 contract: 03-code-patterns.md seeds an empty "Machine-checkable
# rules" section so /add-project-rule (authoring-machine-checkable-rules) has
# a known heading to insert mcrule blocks under. SPEC §8.1.
test_derive_seeds_machine_checkable_rules_section() {
  echo "test_derive_seeds_machine_checkable_rules_section:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "^## Machine-checkable rules"
}

# SS-1 W1 — new pure-dev files seeded header-only and preserved on re-derive.
test_new_dev_files_seeded() {
  echo "test_new_dev_files_seeded:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  assert_file_exists "./.claude/memory-bank/09-known-issues.md"
  assert_file_exists "./.claude/memory-bank/10-decisions-log.md"
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "# Known Issues"
  assert_file_contains "./.claude/memory-bank/10-decisions-log.md" "# Decisions Log"
}

test_new_dev_files_preserved_on_rederive() {
  echo "test_new_dev_files_preserved_on_rederive:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  echo "- gotcha: widgets race on startup" >> ".claude/memory-bank/09-known-issues.md"
  echo "- decided: use file-lock for the registry" >> ".claude/memory-bank/10-decisions-log.md"
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "widgets race on startup"
  assert_file_contains "./.claude/memory-bank/10-decisions-log.md" "use file-lock for the registry"
}

# SS-1 W2 — a machine-checkable rule authored into 03 survives a plain re-derive;
# the derived prose around it still refreshes.
test_03_rules_zone_preserved_on_rederive() {
  echo "test_03_rules_zone_preserved_on_rederive:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  # Simulate authoring-machine-checkable-rules inserting a rule inside the zone:
  # insert a rule block immediately before the preserve:end marker.
  awk '
    /<!-- mcrules:preserve:end -->/ && !done {
      print "<!-- mcrule:start type=banned-imports -->"
      print "banned: requests"
      print "<!-- mcrule:end -->"
      done=1
    }
    { print }
  ' ".claude/memory-bank/03-code-patterns.md" > ".claude/memory-bank/03-code-patterns.md.tmp"
  mv ".claude/memory-bank/03-code-patterns.md.tmp" ".claude/memory-bank/03-code-patterns.md"
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "mcrule:start type=banned-imports"
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "banned: requests"
  # derived prose still present (the zone is not the whole file)
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "User-global defaults"
}

# SS-1 W2 — empty-zone idempotency: a fresh project with NO authored rules survives
# repeated re-derive without corrupting 03 (the [[ -n "$saved_zone" ]] guard path).
test_03_empty_zone_idempotent() {
  echo "test_03_empty_zone_idempotent:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  seed_memory_bank_synth_fixture
  seed_memory_bank_synth_fixture
  # Sentinels present exactly once each; heading intact; no duplication.
  local starts ends headings
  starts="$(grep -c 'mcrules:preserve:start' ".claude/memory-bank/03-code-patterns.md")"
  ends="$(grep -c 'mcrules:preserve:end' ".claude/memory-bank/03-code-patterns.md")"
  headings="$(grep -c '^## Machine-checkable rules' ".claude/memory-bank/03-code-patterns.md")"
  if [[ "$starts" == "1" && "$ends" == "1" && "$headings" == "1" ]]; then
    PASS=$((PASS+1)); echo "  ✓ empty zone stable across repeated re-derive"
  else
    FAIL=$((FAIL+1)); echo "  ✗ zone corrupted: starts=$starts ends=$ends headings=$headings"
  fi
}

# SS-1 review fix — legacy projects may have authored mcrule blocks under the
# heading-only section before preserve sentinels existed. First upgrade must wrap
# and preserve that legacy section instead of overwriting it.
test_legacy_rules_without_preserve_markers_survive_upgrade() {
  echo "test_legacy_rules_without_preserve_markers_survive_upgrade:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  cat > ".claude/memory-bank/03-code-patterns.md" <<'EOF'
# Code Patterns

## Module / package boundaries
legacy derived body

## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
forbid: [requests]
<!-- mcrule:end -->

## User-global defaults
- legacy defaults
EOF
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "mcrules:preserve:start"
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "mcrule:start type=banned_imports"
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "forbid: \\[requests\\]"
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "mcrules:preserve:end"
}

# #63 — when 03 synthesis DROPS the mcrules:preserve sentinels but still emits a
# bare "## Machine-checkable rules" heading, the mechanical re-attach must NOT
# leave two headings. The old blind-append fallback did, and the next regenerate
# extracted the sentinelled zone while rule-authoring wrote under the bare one →
# silent rule loss. _sf_mb_restore_preserve_zone must guarantee exactly one
# heading + one sentinel pair, with the saved rule intact and round-trippable.
test_03_reattach_no_duplicate_heading_when_sentinels_dropped() {
  echo "test_03_reattach_no_duplicate_heading_when_sentinels_dropped:"
  setup_tmp_repo
  # The captured zone the orchestrator is re-attaching: sentinel-wrapped, carrying
  # a real user-authored rule.
  local saved_zone
  saved_zone="$(cat <<'EOF'
<!-- mcrules:preserve:start -->
<!-- This zone is PRESERVED across /scaffold-project re-derive. -->
## Machine-checkable rules

<!-- mcrule:start type=banned-imports -->
banned: requests
<!-- mcrule:end -->
<!-- mcrules:preserve:end -->
EOF
)"
  # A synthesized 03 that dropped the sentinels but kept a bare heading, with
  # other ## sections on both sides (heading is NOT at EOF).
  cat > "03-bad.md" <<'EOF'
# Code Patterns

## Module / package boundaries
Synthesized content. User-global defaults apply.

## Machine-checkable rules

## User-global defaults
- synthesized defaults
EOF
  _sf_mb_restore_preserve_zone "03-bad.md" "$saved_zone"
  local starts ends headings extracted
  starts="$(grep -c 'mcrules:preserve:start' 03-bad.md)"
  ends="$(grep -c 'mcrules:preserve:end' 03-bad.md)"
  headings="$(grep -c '^## Machine-checkable rules' 03-bad.md)"
  # Round-trip: the extractor must recover the user's rule from the re-attached zone.
  extracted="$(_sf_mb_extract_preserve_zone 03-bad.md)"
  if [[ "$starts" == "1" && "$ends" == "1" && "$headings" == "1" ]] \
     && printf '%s\n' "$extracted" | grep -q 'banned: requests'; then
    PASS=$((PASS+1)); echo "  ✓ exactly one section; saved rule preserved + round-trips"
  else
    FAIL=$((FAIL+1)); echo "  ✗ starts=$starts ends=$ends headings=$headings (expected 1/1/1) or rule lost"
  fi
}

# #63 (Codex P2 sibling case) — when synthesis KEEPS the sentinels but ALSO emits
# a STRAY bare "## Machine-checkable rules" heading outside the preserved zone, the
# in-place reinject alone would leave that stray heading. If it precedes the zone,
# authoring-machine-checkable-rules targets it (the first heading) and rules land
# outside the sentinels → same loss mode. _sf_mb_restore_preserve_zone must strip
# any out-of-zone bare heading even on the sentinels-present path: exactly the
# sentinelled section survives.
test_03_restore_strips_stray_bare_heading_on_sentinel_path() {
  echo "test_03_restore_strips_stray_bare_heading_on_sentinel_path:"
  setup_tmp_repo
  local saved_zone
  saved_zone="$(cat <<'EOF'
<!-- mcrules:preserve:start -->
<!-- This zone is PRESERVED across /scaffold-project re-derive. -->
## Machine-checkable rules

<!-- mcrule:start type=banned-imports -->
banned: requests
<!-- mcrule:end -->
<!-- mcrules:preserve:end -->
EOF
)"
  # Synthesized 03 that KEPT the sentinels (fresh empty zone) but ALSO emitted a
  # stray bare heading BEFORE the zone — the Codex P2 loss path.
  cat > "03-stray.md" <<'EOF'
# Code Patterns

## Module / package boundaries
Synthesized content.

## Machine-checkable rules

## Notes

<!-- mcrules:preserve:start -->
<!-- This zone is PRESERVED across /scaffold-project re-derive. -->
## Machine-checkable rules

<!-- mcrules:preserve:end -->

## User-global defaults
- synthesized defaults
EOF
  _sf_mb_restore_preserve_zone "03-stray.md" "$saved_zone"
  local headings starts ends extracted
  headings="$(grep -c '^## Machine-checkable rules' 03-stray.md)"
  starts="$(grep -c 'mcrules:preserve:start' 03-stray.md)"
  ends="$(grep -c 'mcrules:preserve:end' 03-stray.md)"
  # The sole remaining heading must be the one INSIDE the sentinels; the rule must
  # round-trip through extract, and the unrelated "## Notes" prose must survive.
  extracted="$(_sf_mb_extract_preserve_zone 03-stray.md)"
  if [[ "$headings" == "1" && "$starts" == "1" && "$ends" == "1" ]] \
     && printf '%s\n' "$extracted" | grep -q 'banned: requests' \
     && grep -q '^## Notes' 03-stray.md \
     && grep -q '^## User-global defaults' 03-stray.md; then
    PASS=$((PASS+1)); echo "  ✓ stray out-of-zone heading removed; only sentinelled section + surrounding prose remain"
  else
    FAIL=$((FAIL+1)); echo "  ✗ headings=$headings starts=$starts ends=$ends (expected 1/1/1) or rule lost / prose clobbered"
  fi
}

# SS-1 W3 — the canonical cadence policy lives in WORKFLOW.md and carries the
# uniqueness marker; the three ownership classes are named.
test_cadence_policy_canonical() {
  echo "test_cadence_policy_canonical:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "cadence-policy:canonical"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Memory-bank update cadence"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Spec-derived"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Dev-authored"
}

# SS-1 W7 — provenance-trailed harvest content in a derived file is relocated to
# 09-known-issues.md before re-derive, never silently dropped.
test_migration_relocates_harvested_content() {
  echo "test_migration_relocates_harvested_content:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  # Simulate an old project: harvest content was appended into derived 04.
  {
    echo ""
    echo "- legacy harvested note: prefer atomic writes for the registry"
    echo "<!-- Added from VS-1.1.1 retrospective, 2026-05-01; source: report -->"
  } >> ".claude/memory-bank/04-tech-context.md"
  # Re-derive: migration must move it to 09 before 04 is regenerated.
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "prefer atomic writes for the registry"
  assert_file_not_contains "./.claude/memory-bank/04-tech-context.md" "prefer atomic writes for the registry"
}

# SS-1 review fix — pre-SS-1 harvest could target any file later classified as
# spec-derived, not only 03/04. All provenance-trailed entries must move before
# the derived-file render loop overwrites them.
test_migration_relocates_harvested_content_from_all_derived_files() {
  echo "test_migration_relocates_harvested_content_from_all_derived_files:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  local f note path
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    path=".claude/memory-bank/${f}.md"
    note="legacy harvested note from ${f}"
    {
      echo ""
      echo "- ${note}"
      echo "<!-- Added from VS-9.9.9 retrospective, 2026-05-03; source: report -->"
    } >> "$path"
  done
  seed_memory_bank_synth_fixture
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    note="legacy harvested note from ${f}"
    assert_file_contains "./.claude/memory-bank/09-known-issues.md" "$note"
    assert_file_not_contains "./.claude/memory-bank/${f}.md" "$note"
  done
}

# SS-1 review fix — --force refreshes live files, but if migration appended to
# 09-known-issues.md earlier in the same derive call, that migrated content must
# not be clobbered by the live-file force overwrite loop.
test_migration_preserves_09_on_force_after_relocation() {
  echo "test_migration_preserves_09_on_force_after_relocation:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  {
    echo ""
    echo "- legacy force note: preserve after migration"
    echo "<!-- Added from VS-4.4.4 retrospective, 2026-05-04; source: report -->"
  } >> ".claude/memory-bank/04-tech-context.md"
  seed_memory_bank_synth_fixture --force
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "legacy force note: preserve after migration"
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "Memory-bank update cadence"
}

# Idempotent — a second re-derive does not duplicate.
test_migration_idempotent() {
  echo "test_migration_idempotent:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  {
    echo ""
    echo "- legacy note: one-shot relocate me"
    echo "<!-- Added from VS-2.1.1 retrospective, 2026-05-02; source: handoff -->"
  } >> ".claude/memory-bank/03-code-patterns.md"
  seed_memory_bank_synth_fixture
  seed_memory_bank_synth_fixture
  local count
  count="$(grep -c "one-shot relocate me" "./.claude/memory-bank/09-known-issues.md")"
  if [[ "$count" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ relocated exactly once";
  else FAIL=$((FAIL+1)); echo "  ✗ expected 1 relocation, found $count"; fi
}

# SS-1 W7 — migration must not touch content inside the 03 preserve zone.
test_migration_leaves_preserve_zone() {
  echo "test_migration_leaves_preserve_zone:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  # Put a rule block inside the preserve zone (no provenance trailer).
  awk '
    /<!-- mcrules:preserve:end -->/ && !done {
      print "<!-- mcrule:start type=banned-imports -->"
      print "banned: requests"
      print "<!-- mcrule:end -->"
      done=1
    }
    { print }
  ' ".claude/memory-bank/03-code-patterns.md" > ".claude/memory-bank/03-code-patterns.md.tmp"
  mv ".claude/memory-bank/03-code-patterns.md.tmp" ".claude/memory-bank/03-code-patterns.md"
  seed_memory_bank_synth_fixture
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "banned: requests"
}

# SS-1 W7 (final-review fix) — legacy upgrade path: when 09 does NOT exist yet and
# 03/04 carry harvested content, migration must seed 09 from its TEMPLATE (full
# header/sections/cadence pointer), not a bare header — then preserve it.
test_migration_creates_09_with_full_template() {
  echo "test_migration_creates_09_with_full_template:"
  setup_tmp_repo
  seed_master_spec
  seed_memory_bank_synth_fixture
  # Simulate a legacy 12-file bank: remove 09, inject harvested content into 04.
  rm -f ".claude/memory-bank/09-known-issues.md"
  {
    echo ""
    echo "- legacy note: prefer atomic writes for the registry"
    echo "<!-- Added from VS-1.1.1 retrospective, 2026-05-01; source: report -->"
  } >> ".claude/memory-bank/04-tech-context.md"
  seed_memory_bank_synth_fixture
  # 09 has the migrated content AND the full template (cadence pointer + a section heading).
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "prefer atomic writes for the registry"
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "Memory-bank update cadence"
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "Caveats & gotchas"
}

test_derive_00_project_brief
test_live_files_preserved
test_live_files_force_overwritten
test_workflow_static_unchanged
test_workflow_refreshed_on_force
test_settings_warns_on_unsafe_grants
test_settings_no_warn_when_clean
test_all_derived_files_present
test_claude_md_generated
test_claude_md_plugin_awareness_when_no_composition
test_claude_md_karpathy_opt_in
test_claude_md_karpathy_opt_out
test_derive_seeds_machine_checkable_rules_section
test_new_dev_files_seeded
test_new_dev_files_preserved_on_rederive
test_03_rules_zone_preserved_on_rederive
test_03_empty_zone_idempotent
test_legacy_rules_without_preserve_markers_survive_upgrade
test_03_reattach_no_duplicate_heading_when_sentinels_dropped
test_03_restore_strips_stray_bare_heading_on_sentinel_path
test_cadence_policy_canonical
test_migration_relocates_harvested_content
test_migration_relocates_harvested_content_from_all_derived_files
test_migration_preserves_09_on_force_after_relocation
test_migration_idempotent
test_migration_leaves_preserve_zone
test_migration_creates_09_with_full_template
report_results
