#!/usr/bin/env bash
# tests/test-citations.sh — 16 tests for lib/citations.sh mechanical citation legs
# (#7 file/signature; #48 C/D doc-anchor + ADR-id resolution)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/citations.sh"

# 1. sd_citations_check_file on an existing file → returns 0
test_check_file_exists() {
  echo "test_check_file_exists:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/real.py"
  echo "# content" > "$f"
  set +e
  sd_citations_check_file "$f" >/dev/null 2>&1
  local rc=$?
  assert_eq "existing file returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 2. sd_citations_check_file on a missing file → returns 1
test_check_file_missing() {
  echo "test_check_file_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/no-such-file.py"
  set +e
  sd_citations_check_file "$f" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing file returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 3. sd_citations_check_signature where file contains the exact signature → returns 0
test_check_signature_exact_match() {
  echo "test_check_signature_exact_match:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/module.py"
  printf 'def foo(a, b):\n    pass\n' > "$f"
  set +e
  sd_citations_check_signature "$f" "def foo(a, b):" >/dev/null 2>&1
  local rc=$?
  assert_eq "exact signature found returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 4. sd_citations_check_signature where file has a DRIFTED signature → returns 1
test_check_signature_drifted() {
  echo "test_check_signature_drifted:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/module.py"
  # File now has an extra parameter — signature has drifted from the cited form
  printf 'def foo(a, b, c=False):\n    pass\n' > "$f"
  set +e
  sd_citations_check_signature "$f" "def foo(a, b):" >/dev/null 2>&1
  local rc=$?
  assert_eq "drifted signature returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 5. sd_citations_check_file returns status only; stdout is not a signal.
test_check_file_no_stdout() {
  echo "test_check_file_no_stdout:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/real.py"
  echo "# content" > "$f"
  local out
  set +e
  out="$(sd_citations_check_file "$f" 2>/dev/null)"
  local rc=$?
  assert_eq "existing file returns 0" "0" "$rc"
  assert_eq "existing file stdout is empty" "" "$out"
  rm -rf "$TMP_DIR"
}

# --- #48 Part C: doc-anchor resolution leg (sd_citations_check_anchor) ---

# 6. anchor present as a numbered heading → returns 0
test_check_anchor_numeric_present() {
  echo "test_check_anchor_numeric_present:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## 5.2 Token Lifecycle\n\nbody\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "numeric heading anchor returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 7. anchor present as a heading TITLE fragment → returns 0
test_check_anchor_title_present() {
  echo "test_check_anchor_title_present:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/SRS.md"
  printf '# SRS\n\n### FR-5 Authentication\n\nbody\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "FR-5" >/dev/null 2>&1
  local rc=$?
  assert_eq "title/id heading anchor returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 8. anchor absent from all headings → returns 1
test_check_anchor_missing() {
  echo "test_check_anchor_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## 5.2 Token Lifecycle\n\nbody\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "9.9" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing anchor returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 9. anchor token appears only in body prose, NOT in a heading → returns 1
test_check_anchor_body_only_not_heading() {
  echo "test_check_anchor_body_only_not_heading:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '# Spec\n\n## Overview\n\nsee section 5.2 for details\n' > "$f"
  set +e
  sd_citations_check_anchor "$f" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "anchor only in prose (no heading) returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 10. anchor host doc missing → returns 1
test_check_anchor_doc_missing() {
  echo "test_check_anchor_doc_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  set +e
  sd_citations_check_anchor "$TMP_DIR/no-such-doc.md" "5.2" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing host doc returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 11. anchor check returns status only; stdout is not a signal
test_check_anchor_no_stdout() {
  echo "test_check_anchor_no_stdout:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/MASTER-SPEC.md"
  printf '## 5.2 Token Lifecycle\n' > "$f"
  local out
  set +e
  out="$(sd_citations_check_anchor "$f" "5.2" 2>/dev/null)"
  local rc=$?
  assert_eq "anchor present returns 0" "0" "$rc"
  assert_eq "anchor present stdout is empty" "" "$out"
  rm -rf "$TMP_DIR"
}

# --- #48 Part D: ADR-id resolution leg (sd_citations_check_adr) ---

# 12. ADR id resolves in the (first) product dir → returns 0
test_check_adr_product_dir() {
  echo "test_check_adr_product_dir:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product" "$TMP_DIR/process"
  echo "# adr" > "$TMP_DIR/product/adr-0003-use-redis.md"
  set +e
  sd_citations_check_adr "ADR-0003" "$TMP_DIR/product" "$TMP_DIR/process" >/dev/null 2>&1
  local rc=$?
  assert_eq "ADR in product dir returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 13. ADR id resolves in the SECOND (process) dir → returns 0
test_check_adr_process_dir() {
  echo "test_check_adr_process_dir:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product" "$TMP_DIR/process"
  echo "# adr" > "$TMP_DIR/process/adr-0002-switch-backend.md"
  set +e
  sd_citations_check_adr "ADR-0002" "$TMP_DIR/product" "$TMP_DIR/process" >/dev/null 2>&1
  local rc=$?
  assert_eq "ADR in process dir returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 14. ADR id absent from all dirs → returns 1
test_check_adr_missing() {
  echo "test_check_adr_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product" "$TMP_DIR/process"
  echo "# adr" > "$TMP_DIR/product/adr-0003-use-redis.md"
  set +e
  sd_citations_check_adr "ADR-0099" "$TMP_DIR/product" "$TMP_DIR/process" >/dev/null 2>&1
  local rc=$?
  assert_eq "missing ADR returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 15. unpadded citation (ADR-3) resolves a 4-digit file (adr-0003-*) → returns 0
test_check_adr_zero_pad_tolerant() {
  echo "test_check_adr_zero_pad_tolerant:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product"
  echo "# adr" > "$TMP_DIR/product/adr-0003-use-redis.md"
  set +e
  sd_citations_check_adr "ADR-3" "$TMP_DIR/product" >/dev/null 2>&1
  local rc=$?
  assert_eq "unpadded ADR-3 resolves adr-0003 returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 16. malformed ADR id (no digits) → returns 1
test_check_adr_malformed() {
  echo "test_check_adr_malformed:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  mkdir -p "$TMP_DIR/product"
  set +e
  sd_citations_check_adr "ADR-foo" "$TMP_DIR/product" >/dev/null 2>&1
  local rc=$?
  assert_eq "malformed ADR id returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

test_check_file_exists
test_check_file_missing
test_check_signature_exact_match
test_check_signature_drifted
test_check_file_no_stdout
test_check_anchor_numeric_present
test_check_anchor_title_present
test_check_anchor_missing
test_check_anchor_body_only_not_heading
test_check_anchor_doc_missing
test_check_anchor_no_stdout
test_check_adr_product_dir
test_check_adr_process_dir
test_check_adr_missing
test_check_adr_zero_pad_tolerant
test_check_adr_malformed

sd_test_summary
