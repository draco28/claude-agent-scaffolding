#!/usr/bin/env bash
# test-docs.sh — governance doc-set CONTRACT (SS-7).
# The deterministic sf_docs_derive renderer was removed in v0.8.0; governance
# docs are agent-synthesized (scaffolding-governance-docs §11). Bash can no longer
# render + assert doc content, so this suite verifies the SKILL body still owns the
# authoritative doc catalog: the default-5 / --full / LLM-gate split + per-doc
# routing. Content + ID-minting (FR/NFR/BACKLOG) correctness moves to evals/.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

SKILL="$HERE/../skills/scaffolding-governance-docs/SKILL.md"
DOCS_LIB="$HERE/../lib/docs.sh"

test_skill_lists_default_5() {
  echo "test_skill_lists_default_5:"
  local d
  for d in PRD SRS BACKLOG PROJECT_PLAN 'ADR-0001'; do
    assert_file_contains "$SKILL" "$d"
  done
}

test_skill_lists_full_docs() {
  echo "test_skill_lists_full_docs:"
  local d
  for d in RISK_REGISTER THREAT_MODEL TEST_STRATEGY DEFINITION_OF_DONE CUTOVER_PLAN DEMO_RUNBOOK; do
    assert_file_contains "$SKILL" "$d"
  done
}

test_skill_names_three_llm_gated() {
  echo "test_skill_names_three_llm_gated:"
  local d
  for d in EVALS_PLAN MODEL_CARD PROMPT_GOVERNANCE; do
    assert_file_contains "$SKILL" "$d"
  done
  # The gate is Phase 9.3.1 (uses_llm) and is documented in the skill body.
  assert_file_contains "$SKILL" "9.3.1"
}

test_skill_documents_process_vs_product_routing() {
  echo "test_skill_documents_process_vs_product_routing:"
  # DEFINITION_OF_DONE / DEMO_RUNBOOK / PROMPT_GOVERNANCE route to process_adrs;
  # the rest of the ADR-family route to product_adrs. The §11.1 catalog table owns this.
  assert_file_contains "$SKILL" "process_adrs"
  assert_file_contains "$SKILL" "product_adrs"
}

test_skill_documents_default_vs_full_split() {
  echo "test_skill_documents_default_vs_full_split:"
  # §4 names the 5-default vs 14-full contract.
  assert_file_contains "$SKILL" "Default \\(5 docs\\) vs"
  assert_file_contains "$SKILL" "\\(14 docs\\)"
}

# SS-7 — no deterministic renderer / fast-mode toggle survives anywhere.
# (The skill body intentionally MENTIONS "--fast flag was removed" in a removal
# note, so we don't assert the bare string's absence — we assert the toggle
# mechanism + the renderer function are gone.)
test_no_deterministic_doc_renderer() {
  echo "test_no_deterministic_doc_renderer:"
  # The deterministic renderer function is gone from the lib.
  assert_file_not_contains "$DOCS_LIB" "^sf_docs_derive\\(\\)"
  assert_file_not_contains "$DOCS_LIB" "^_write_or_skip\\(\\)"
  # The fast-mode toggle is gone from the skill (these have no intentional mentions).
  assert_file_not_contains "$SKILL" "SF_SYNTH_FAST"
  assert_file_not_contains "$SKILL" "sf_synth_mode"
}

test_skill_lists_default_5
test_skill_lists_full_docs
test_skill_names_three_llm_gated
test_skill_documents_process_vs_product_routing
test_skill_documents_default_vs_full_split
test_no_deterministic_doc_renderer
report_results
